import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../domain/showcase_product.dart';

class ProductArtwork extends StatelessWidget {
  const ProductArtwork({
    super.key,
    required this.product,
    this.width,
    this.height,
    this.borderRadius = Radii.md,
    this.hero = false,
  });

  final ShowcaseProduct product;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: context.t.surfaceElevated,
      child: Icon(Icons.shopping_bag_outlined, color: context.t.primary),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: product.imageUrl.isNotEmpty
          ? Image.network(
              product.imageUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : Image.asset(
              product.imageAsset,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
    if (!hero) return image;
    return Hero(tag: 'product-${product.id}', child: image);
  }
}
