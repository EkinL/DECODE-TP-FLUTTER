import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

import '../api/models/product_model.dart';
import '../api/repositories/model_repository.dart';
import '../helpers/exceptions.dart';
import '../helpers/validators.dart';
import '../services/toast_service.dart';
import '../widgets/buttons/loading_button.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final ModelRepository<ProductModel> _productRepository = const ModelRepository(
    uri: 'products',
    fromJson: ProductModel.fromJson,
  );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  bool _isSubmitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un produit'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              spacing: 16,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du produit',
                    border: OutlineInputBorder(),
                  ),
                  validator: isRequired,
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: isRequired,
                ),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Prix',
                    border: OutlineInputBorder(),
                    suffixText: '€',
                  ),
                  keyboardType: TextInputType.number,
                  validator: isPrice,
                ),
                LoadingButton(
                  onPressed: _onSubmit,
                  label: 'Enregistrer',
                  isLoading: _isSubmitted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitted = true;
    });

    try {
      await _productRepository.addOrUpdate(
        data: {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'price': double.parse(_priceController.text.replaceAll(',', '.')),
        },
      );

      if (!mounted) {
        return;
      }

      ToastService.showToast(
        'Produit créé avec succès',
        type: ToastificationType.success,
      );

      context.pop();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitted = false;
      });
      ToastService.showToast(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitted = false;
      });
      ToastService.showToast('Une erreur est survenue');
    }
  }
}
