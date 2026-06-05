import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
  const ProductFormScreen({this.productId, super.key});

  final String? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final ModelRepository<ProductModel> _productRepository =
      const ModelRepository(
        uri: 'products',
        fromJson: ProductModel.fromJson,
      );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  bool _isLoading = false;
  bool _isSubmitted = false;

  Uint8List? _pickedImageBytes;
  String? _pickedImageBase64;
  String? _pickedImageName;
  String? _pickedImageExtension;
  String? _currentPictureUrl;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _isLoading = true;
      _loadProduct();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _loadProduct() async {
    try {
      final ProductModel product = await _productRepository.get(
        widget.productId!,
      );

      if (!mounted) {
        return;
      }

      _nameController.text = product.name;
      _descriptionController.text = product.description;
      _priceController.text = product.price.toString();
      _currentPictureUrl = product.picture;

      setState(() {
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ToastService.showToast(e.message);
      context.pop();
    }
  }

  void _pickImage() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.first.bytes == null) {
      return;
    }

    final PlatformFile file = result.files.first;

    setState(() {
      _pickedImageBytes = file.bytes;
      _pickedImageBase64 = base64Encode(file.bytes!);
      _pickedImageName = file.name;
      _pickedImageExtension = (file.extension ?? 'png').toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le produit' : 'Ajouter un produit'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SafeArea(
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
              _buildImageSection(),
              LoadingButton(
                onPressed: _onSubmit,
                label: 'Enregistrer',
                isLoading: _isSubmitted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (_pickedImageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _pickedImageBytes!,
              height: 180,
              fit: BoxFit.cover,
            ),
          )
        else if (_currentPictureUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              _currentPictureUrl!,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Choisir une image'),
        ),
      ],
    );
  }

  void _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitted = true;
    });

    final Map<String, dynamic> data = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'price': double.parse(_priceController.text.replaceAll(',', '.')),
    };

    if (_pickedImageBase64 != null) {
      data['picture'] = {
        'name': _pickedImageName,
        'base64': _pickedImageBase64,
        'extension': _pickedImageExtension,
        'status': 'CREATED',
      };
    }

    try {
      await _productRepository.addOrUpdate(
        id: widget.productId,
        data: data,
      );

      if (!mounted) {
        return;
      }

      ToastService.showToast(
        _isEditing ? 'Produit modifié avec succès' : 'Produit créé avec succès',
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
