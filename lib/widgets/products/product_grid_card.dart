import 'package:flutter/material.dart';

import '../../api/models/product_model.dart';

class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    required this.product,
    required this.onTap,
    required this.onDelete,
    this.onLongPress,
    this.selected = false,
    super.key,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      color: selected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(colorScheme),
                  if (selected)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: colorScheme.surface.withValues(alpha: 0.85),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onDelete,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    product.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${product.price.toStringAsFixed(2)} €',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
        child: Icon(Icons.image_outlined, color: colorScheme.onSurfaceVariant),
      );
    }

    return Image.network(
      product.picture!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
