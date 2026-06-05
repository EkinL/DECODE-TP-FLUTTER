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

  List<ProductModel> _products = [];
  bool _isLoading = true;

  Timer? _debounce;
  String _searchValue = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchValue = value.trim();
      _loadProducts();
    });
  }

  void _loadProducts() async {
    try {
      final Map<String, String> queryParams = {};
      if (_searchValue.isNotEmpty) {
        queryParams['search_value'] = _searchValue;
      }

      final PaginatedResponse<ProductModel> response = await _productRepository
          .getAll(queryParams: queryParams.isEmpty ? null : queryParams);

      if (!mounted) {
        return;
      }

      setState(() {
        _products = response.rows;
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

  void _confirmDelete(ProductModel product) async {
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

    if (confirmed != true) {
      return;
    }

    try {
      await _productRepository.delete(product.id);

      if (!mounted) {
        return;
      }

      ToastService.showToast(
        'Produit supprimé',
        type: ToastificationType.success,
      );

      _loadProducts();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ToastService.showToast(e.message);
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
      return const Center(
        child: CircularProgressIndicator(),
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
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (BuildContext context, int index) {
        final ProductModel product = _products[index];

        return ProductTile(
          product: product,
          onTap: () async {
            await context.push('/products/${product.id}/edit');

            if (!mounted) {
              return;
            }

            _loadProducts();
          },
          onDelete: () => _confirmDelete(product),
        );
      },
    );
  }
}
