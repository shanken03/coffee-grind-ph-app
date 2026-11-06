import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/product_model.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/inventory_provider.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  String get priceDisplay {
    if (product.supportsTemperatureOptions) {
      final p = product.pricing;
      return '₱${p.hotPrice!.toInt()} / ₱${p.icedPrice!.toInt()}';
    }
    final reg = product.pricing.regularPrice;
    return '₱${reg.toStringAsFixed(reg % 1 == 0 ? 0 : 2)}';
  }

  IconData get categoryIcon {
    switch (product.category) {
      case ProductCategory.coffee:
        return Icons.coffee_rounded;
      case ProductCategory.nonCoffee:
        return Icons.local_drink_rounded;
      case ProductCategory.frappe:
        return Icons.icecream_rounded;
      case ProductCategory.refreshers:
        return Icons.local_bar_rounded;
      case ProductCategory.foods:
        return Icons.fastfood_rounded;
      case ProductCategory.sweets:
        return Icons.cake_rounded;
    }
  }

  Widget _buildProductImage() {
    final hasValidUrl =
        product.imageUrl.isNotEmpty &&
        (product.imageUrl.startsWith('http://') ||
            product.imageUrl.startsWith('https://'));

    if (hasValidUrl) {
      if (kIsWeb) {
        return Image.network(
          product.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: AppColors.warmCream,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.darkCoffee,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
        );
      }

      return CachedNetworkImage(
        imageUrl: product.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: AppColors.warmCream,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.darkCoffee,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallbackImage(),
      );
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Container(
      color: AppColors.warmCream,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            categoryIcon,
            size: 40,
            color: AppColors.darkCoffee.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              product.displayCategory,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ProductsProvider? productsProvider;
    InventoryProvider? inventoryProvider;
    try {
      productsProvider = context.watch<ProductsProvider>();
    } catch (_) {}
    try {
      inventoryProvider = context.watch<InventoryProvider>();
    } catch (_) {}

    bool isOutOfStock = false;

    if (productsProvider != null &&
        inventoryProvider != null &&
        (productsProvider.recipes.isNotEmpty ||
            !productsProvider.isLoadingRecipes)) {
      final inventoryItems = inventoryProvider.items;

      final result = productsProvider.calculateSellableServings(
        product: product,
        inventoryItems: inventoryItems,
        temperature: product.fixedTemperature,
      );

      if (result.isOutOfStock) {
        isOutOfStock = true;
      }
    }

    final bool canAdd = product.isAvailable && !isOutOfStock;

    String statusBadgeText = '';
    if (!product.isAvailable) {
      statusBadgeText = 'NOT AVAILABLE';
    } else if (isOutOfStock) {
      statusBadgeText = 'OUT OF STOCK';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.latteBeige, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Image Header with Fallback and Availability Overlay
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Container(
                  color: AppColors.warmCream,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildProductImage(),
                      if (statusBadgeText.isNotEmpty)
                        Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mutedRed,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              statusBadgeText,
                              style: AppTextStyles.badge(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.darkCoffee.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.displayCategory,
                          style: AppTextStyles.badge(
                            fontSize: 10,
                            color: AppColors.darkCoffee,
                          ),
                        ),
                      ),
                      if (!product.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mutedRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Unavailable',
                            style: AppTextStyles.badge(
                              fontSize: 10,
                              color: AppColors.mutedRed,
                            ),
                          ),
                        )
                      else if (isOutOfStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mutedRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Out of Stock',
                            style: AppTextStyles.badge(
                              fontSize: 10,
                              color: AppColors.mutedRed,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle(
                      fontSize: 13,
                      color: AppColors.darkCoffee,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          priceDisplay,
                          style: AppTextStyles.price(
                            fontSize: 13,
                            color: AppColors.darkCoffee,
                          ),
                        ),
                      ),
                      Material(
                        color: canAdd
                            ? AppColors.darkCoffee
                            : AppColors.latteBeige.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: canAdd ? onAdd : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  canAdd ? Icons.add : Icons.block_rounded,
                                  size: 14,
                                  color: canAdd
                                      ? AppColors.surfaceWhite
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  canAdd
                                      ? 'Add'
                                      : (!product.isAvailable
                                            ? 'Unavailable'
                                            : 'Out of Stock'),
                                  style: AppTextStyles.buttonSmall(
                                    color: canAdd
                                        ? AppColors.surfaceWhite
                                        : AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
