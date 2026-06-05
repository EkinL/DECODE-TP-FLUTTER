import 'package:flutter/material.dart';

class ProductTileSkeleton extends StatefulWidget {
  const ProductTileSkeleton({super.key});

  @override
  State<ProductTileSkeleton> createState() => _ProductTileSkeletonState();
}

class _ProductTileSkeletonState extends State<ProductTileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color boxColor = colorScheme.surfaceContainerHighest;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: colorScheme.surfaceContainer,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 1).animate(_controller),
        child: Row(
          children: [
            Container(width: 100, height: 100, color: boxColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    _bar(boxColor, double.infinity),
                    _bar(boxColor, 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, double width) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
