import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

import '../api/models/paginated_response.dart';
import '../api/models/product_model.dart';
import '../api/repositories/model_repository.dart';
import '../config/routes.dart';
import '../helpers/exceptions.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/products/product_grid_card.dart';
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

  final Set<String> _animatedIds = {};

  List<ProductModel> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  int _page = 1;
  bool _hasMore = true;

  Timer? _debounce;
  String _searchValue = '';

  bool _isGridView = false;

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
    _loadViewPreference();
    _loadProducts();
  }

  void _loadViewPreference() async {
    final String? value = await StorageService.get(StorageKey.viewMode);

    if (!mounted) {
      return;
    }

    setState(() => _isGridView = value == 'grid');
  }

  void _toggleView() {
    setState(() => _isGridView = !_isGridView);
    StorageService.save(StorageKey.viewMode, _isGridView ? 'grid' : 'list');
  }

  void _onDeletePressed(ProductModel product) async {
    final bool confirmed = await _confirmDelete(product);

    if (confirmed) {
      _deleteProduct(product);
    }
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

      // Avec un filtre actif, on charge tout pour filtrer sur l'ensemble
      // (et éviter un loader de pagination qui ne peut pas se déclencher).
      if (_hasActiveFilters && _hasMore) {
        await _loadRemaining();
        if (mounted) {
          setState(() {});
        }
      }
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
        _hasMore =
            response.rows.isNotEmpty && _products.length < response.count;
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

  Future<void> _loadRemaining() async {
    while (_hasMore && mounted) {
      final int nextPage = _page + 1;
      final PaginatedResponse<ProductModel> response = await _fetchPage(
        nextPage,
      );

      if (!mounted) {
        return;
      }

      _page = nextPage;

      // Garde-fou : si une page revient vide, on arrête (évite une boucle
      // infinie si le count ne correspond pas exactement aux lignes).
      if (response.rows.isEmpty) {
        _hasMore = false;
        return;
      }

      _products.addAll(response.rows);
      _hasMore = _products.length < response.count;
    }
  }

  void _ensurePriceBounds() async {
    if (_loadingBounds) {
      return;
    }

    // On charge tout pour filtrer sur l'ensemble (et non sur les seules
    // pages déjà paginées). À refaire si une recherche a relancé la pagination.
    if (_hasMore) {
      setState(() => _loadingBounds = true);

      try {
        await _loadRemaining();
      } on ApiException catch (e) {
        if (!mounted) {
          return;
        }
        setState(() => _loadingBounds = false);
        ToastService.showToast(e.message);
        return;
      }

      if (!mounted) {
        return;
      }
    }

    if (_priceMax == null && _products.isNotEmpty) {
      final List<double> prices = _products.map((p) => p.price).toList()
        ..sort();
      _priceMin = prices.first;
      _priceMax = prices.last;
      _priceRange = RangeValues(prices.first, prices.last);
    }

    if (mounted) {
      setState(() => _loadingBounds = false);
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
      backgroundColor: colorScheme.surface,
      endDrawer: _buildFilterDrawer(colorScheme),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(colorScheme),
          ..._buildContentSlivers(),
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

  Widget _buildSliverAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 220,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          onPressed: _toggleView,
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
        ),
        Builder(
          builder: (BuildContext context) {
            return IconButton(
              onPressed: () {
                _ensurePriceBounds();
                Scaffold.of(context).openEndDrawer();
              },
              icon: Badge(
                isLabelVisible: _hasActiveFilters,
                child: const Icon(Icons.filter_list),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 84),
        title: Text(
          'Mes produits',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        background: _buildHeroBackground(colorScheme),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Rechercher un produit',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colorScheme.surface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBackground(ColorScheme colorScheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.tertiary],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -8,
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 170,
              color: colorScheme.onPrimary.withValues(alpha: 0.12),
            ),
          ),
        ],
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

  List<Widget> _buildContentSlivers() {
    if (_isLoading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.builder(
            itemCount: 6,
            itemBuilder: (BuildContext context, int index) {
              return const ProductTileSkeleton();
            },
          ),
        ),
      ];
    }

    final List<ProductModel> visible = _applyFilters(_products);

    if (visible.isEmpty) {
      if (_hasMore && !_hasActiveFilters) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }

      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              _searchValue.isEmpty && !_hasActiveFilters
                  ? 'Aucun produit pour le moment'
                  : 'Aucun produit trouvé',
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: _isGridView
            ? SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.74,
                ),
                itemCount: visible.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildGridCard(visible[index]);
                },
              )
            : SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildTile(visible[index]);
                },
              ),
      ),
      if (_hasMore && !_hasActiveFilters)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
    ];
  }

  Widget _buildGridCard(ProductModel product) {
    final bool animate = _animatedIds.add(product.id);

    Widget card = ProductGridCard(
      product: product,
      onTap: () async {
        await context.push('/products/${product.id}/edit');

        if (!mounted) {
          return;
        }

        _loadProducts();
      },
      onDelete: () => _onDeletePressed(product),
    );

    if (animate) {
      card = AnimatedEntrance(child: card);
    }

    return card;
  }

  Widget _buildTile(ProductModel product) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool animate = _animatedIds.add(product.id);

    Widget tile = ProductTile(
      product: product,
      onTap: () async {
        await context.push('/products/${product.id}/edit');

        if (!mounted) {
          return;
        }

        _loadProducts();
      },
    );

    if (animate) {
      tile = AnimatedEntrance(child: tile);
    }

    return Dismissible(
      key: ValueKey(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      confirmDismiss: (direction) => _confirmDelete(product),
      onDismissed: (direction) => _deleteProduct(product),
      child: tile,
    );
  }
}
