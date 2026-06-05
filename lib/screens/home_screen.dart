import 'package:flutter/material.dart';

import '../api/models/paginated_response.dart';
import '../api/models/product_model.dart';
import '../api/repositories/model_repository.dart';
import '../helpers/exceptions.dart';
import '../services/toast_service.dart';
import '../widgets/products/product_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ModelRepository<ProductModel> _productRepository = const ModelRepository(
    uri: 'products',
    fromJson: ProductModel.fromJson,
  );

  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    try {
      final PaginatedResponse<ProductModel> response =
          await _productRepository.getAll();

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

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('home_screen'),
      appBar: AppBar(
        title: const Text('Liste des produits'),
      ),
      backgroundColor: colorScheme.surface,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Text('Aucun produit pour le moment'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (BuildContext context, int index) {
        return ProductTile(product: _products[index]);
      },
    );
  }
}
