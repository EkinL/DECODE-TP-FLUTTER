import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

import '../api/models/paginated_response.dart';
import '../api/models/product_model.dart';
import '../api/repositories/model_repository.dart';
import '../config/routes.dart';
import '../helpers/exceptions.dart';
import '../services/toast_service.dart';
import '../widgets/products/product_tile.dart';
import '../widgets/products/product_tile_skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ModelRepository<ProductModel> _productRepository =
      const ModelRepository(
        uri: 'products',
        fromJson: ProductModel.fromJson,
      );

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ProductModel> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  int _page = 1;
  bool _hasMore = true;

  Timer? _debounce;
  String _searchValue = '';

  double? _priceMin;
  double? _priceMax;
  RangeValues? _priceRange;
  bool _loadingBounds = false;

  DateTime? _createdBefore;
  DateTime? _updatedBefore;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bool nearBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200;

    if (nearBottom) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchValue = value.trim();
      _loadProducts();
    });
  }

  Future<PaginatedResponse<ProductModel>> _fetchPage(int page) {
    final Map<String, String> queryParams = {'page': page.toString()};
    if (_searchValue.isNotEmpty) {
      queryParams['search_value'] = _searchValue;
    }

    return _productRepository.getAll(queryParams: queryParams);
  }

  void _loadProducts() async {
    _page = 1;
    _hasMore = true;

    try {
      final PaginatedResponse<ProductModel> response = await _fetchPage(1);

      if (!mounted) {
        return;
      }

      setState(() {
        _products = response.rows;
        _hasMore = _products.length < response.count;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ToastService.showToast(e.message);
    }
  }

  void _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final int nextPage = _page + 1;

    try {
      final PaginatedResponse<ProductModel> response = await _fetchPage(
        nextPage,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _page = nextPage;
        _products.addAll(response.rows);
        _hasMore = _products.length < response.count;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingMore = false;
      });

      ToastService.showToast(e.message);
    }
  }

  Future<bool> _confirmDelete(ProductModel product) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer le produit'),
          content: Text('Voulez-vous vraiment supprimer "${product.name}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  void _deleteProduct(ProductModel product) async {
    setState(() {
      _products.removeWhere((p) => p.id == product.id);
    });

    try {
      await _productRepository.delete(product.id);

      if (!mounted) {
        return;
      }

      ToastService.showToast(
        'Produit supprimé',
        type: ToastificationType.success,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ToastService.showToast(e.message);
      _loadProducts();
    }
  }

  bool get _isPriceFiltered =>
      _priceRange != null &&
      _priceMin != null &&
      _priceMax != null &&
      (_priceRange!.start > _priceMin! || _priceRange!.end < _priceMax!);

  bool get _hasActiveFilters =>
      _isPriceFiltered || _createdBefore != null || _updatedBefore != null;

  List<ProductModel> _applyFilters(List<ProductModel> products) {
    return products.where((product) {
      if (_priceRange != null &&
          (product.price < _priceRange!.start ||
              product.price > _priceRange!.end)) {
        return false;
      }
      if (_createdBefore != null &&
          !product.createdAt.isBefore(_createdBefore!)) {
        return false;
      }
      if (_updatedBefore != null &&
          !product.updatedAt.isBefore(_updatedBefore!)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _ensurePriceBounds() async {
    if (_priceMax != null || _loadingBounds) {
      return;
    }

    setState(() => _loadingBounds = true);

    try {
      final List<ProductModel> all = [];
      int page = 1;

      while (page <= 50) {
        final PaginatedResponse<ProductModel> response =
            await _productRepository.getAll(
              queryParams: {'page': page.toString()},
            );

        all.addAll(response.rows);

        if (response.rows.isEmpty || all.length >= response.count) {
          break;
        }
        page++;
      }

      if (!mounted || all.isEmpty) {
        return;
      }

      final List<double> prices = all.map((p) => p.price).toList()..sort();

      setState(() {
        _priceMin = prices.first;
        _priceMax = prices.last;
        _priceRange = RangeValues(prices.first, prices.last);
        _loadingBounds = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingBounds = false);
      ToastService.showToast(e.message);
    }
  }

  void _pickDate(DateTime? current, ValueChanged<DateTime> onPicked) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  void _resetFilters() {
    setState(() {
      if (_priceMin != null && _priceMax != null) {
        _priceRange = RangeValues(_priceMin!, _priceMax!);
      }
      _createdBefore = null;
      _updatedBefore = null;
    });
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('home_screen'),
      appBar: AppBar(
        title: const Text('Liste des produits'),
        actions: [
          Builder(
            builder: (BuildContext context) {
              return IconButton(
                onPressed: () {
                  _ensurePriceBounds();
                  Scaffold.of(context).openEndDrawer();
                },
                icon: Icon(
                  Icons.filter_list,
                  color: _hasActiveFilters ? colorScheme.primary : null,
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: colorScheme.surface,
      endDrawer: _buildFilterDrawer(colorScheme),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Rechercher un produit',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(rtProductCreate);

          if (!mounted) {
            return;
          }

          _loadProducts();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un produit'),
      ),
    );
  }

  Widget _buildPriceFilter() {
    if (_loadingBounds) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_priceRange == null || _priceMin == null || _priceMax == null) {
      return const Text('Prix indisponible');
    }

    if (_priceMin! >= _priceMax!) {
      return Text('Prix : ${_priceMin!.toStringAsFixed(0)} €');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prix : ${_priceRange!.start.toStringAsFixed(0)} € — '
          '${_priceRange!.end.toStringAsFixed(0)} €',
        ),
        RangeSlider(
          values: _priceRange!,
          min: _priceMin!,
          max: _priceMax!,
          labels: RangeLabels(
            _priceRange!.start.toStringAsFixed(0),
            _priceRange!.end.toStringAsFixed(0),
          ),
          onChanged: (RangeValues values) {
            setState(() => _priceRange = values);
          },
        ),
      ],
    );
  }

  Widget _buildFilterDrawer(ColorScheme colorScheme) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildPriceFilter(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  _pickDate(_createdBefore, (date) => _createdBefore = date),
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _createdBefore == null
                    ? 'Créé avant le...'
                    : 'Créé avant le ${_formatDate(_createdBefore!)}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _pickDate(_updatedBefore, (date) => _updatedBefore = date),
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _updatedBefore == null
                    ? 'Modifié avant le...'
                    : 'Modifié avant le ${_formatDate(_updatedBefore!)}',
              ),
            ),
            const SizedBox(height: 24),
            if (_hasActiveFilters)
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Réinitialiser les filtres'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (BuildContext context, int index) {
          return const ProductTileSkeleton();
        },
      );
    }

    final List<ProductModel> visible = _applyFilters(_products);

    if (visible.isEmpty) {
      if (_hasMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
        return const Center(child: CircularProgressIndicator());
      }

      return Center(
        child: Text(
          _searchValue.isEmpty && !_hasActiveFilters
              ? 'Aucun produit pour le moment'
              : 'Aucun produit trouvé',
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: visible.length + (_hasMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= visible.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final ProductModel product = visible[index];

        return Dismissible(
          key: ValueKey(product.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) => _confirmDelete(product),
          onDismissed: (direction) => _deleteProduct(product),
          child: ProductTile(
            product: product,
            onTap: () async {
              await context.push('/products/${product.id}/edit');

              if (!mounted) {
                return;
              }

              _loadProducts();
            },
          ),
        );
      },
    );
  }
}
