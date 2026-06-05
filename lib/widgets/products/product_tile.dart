import 'package:flutter/material.dart';

import '../../api/models/product_model.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({
    required this.product,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: colorScheme.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: _buildImage(colorScheme),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(
                      product.name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${product.price.toStringAsFixed(2)} €',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(ColorScheme colorScheme) {
    if (product.picture == null) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }

    return Image.network(
      product.picture!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
