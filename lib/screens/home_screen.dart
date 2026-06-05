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

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('home_screen'),
      appBar: AppBar(
        title: const Text('Liste des produits'),
      ),
      backgroundColor: colorScheme.surface,
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

    if (_products.isEmpty) {
      return Center(
        child: Text(
          _searchValue.isEmpty
              ? 'Aucun produit pour le moment'
              : 'Aucun produit trouvé',
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _products.length + (_hasMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= _products.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final ProductModel product = _products[index];

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
