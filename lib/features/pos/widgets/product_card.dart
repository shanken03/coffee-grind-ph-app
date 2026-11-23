import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../models/product_model.dart';
import '../../../providers/pos_cart_provider.dart';
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
    PosCartProvider? cartProvider;
    try {
      productsProvider = context.watch<ProductsProvider>();
    } catch (_) {}
    try {
      inventoryProvider = context.watch<InventoryProvider>();
    } catch (_) {}
    try {
      cartProvider = context.watch<PosCartProvider>();
    } catch (_) {}

    bool isOutOfStock = false;
    SellableServingsResult? servingsResult;

    if (productsProvider != null &&
        inventoryProvider != null &&
        (productsProvider.recipes.isNotEmpty ||
            !productsProvider.isLoadingRecipes)) {
      final inventoryItems = inventoryProvider.items;
      final effectiveInventory =
          (cartProvider != null && !cartProvider.isEmpty)
          ? cartProvider.getRemainingInventory(
              inventoryItems: inventoryItems,
              recipes: productsProvider.recipes,
            )
          : inventoryItems;

      servingsResult = productsProvider.calculateSellableServings(
        product: product,
        inventoryItems: effectiveInventory,
        temperature: product.fixedTemperature,
      );

      if (servingsResult.isOutOfStock) {
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

    final String? servingsBadgeText = servingsResult == null
        ? null
        : (!product.isAvailable
              ? 'OUT OF STOCK — 0 servings'
              : servingsResult.statusBadgeLabel);
    final Color servingsBadgeColor = !product.isAvailable || isOutOfStock
        ? AppColors.mutedRed
        : (servingsResult?.isLowStock == true
              ? AppColors.warmBronze
              : AppColors.forestGreen);

    return AppPressableScale(
      enabled: canAdd,
      pressedScale: 0.96,
      child: Opacity(
        opacity: canAdd ? 1.0 : 0.85,
        child: Card(
        color: AppColors.surfaceWhite,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Padded Rounded Image Header
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
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
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.mutedRed,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  statusBadgeText,
                                  style: AppTextStyles.badge(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Product info
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle(
                        fontSize: 14,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.displayCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (servingsBadgeText != null) ...[
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        key: ValueKey<String>(servingsBadgeText),
                        tween: Tween<double>(begin: 0.92, end: 1.0),
                        duration: AppMotion.resolveDuration(
                          context,
                          const Duration(milliseconds: 220),
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (context, scaleVal, child) {
                          return AppMotion.reduceMotion(context)
                              ? child!
                              : Transform.scale(
                                  scale: scaleVal,
                                  alignment: Alignment.centerLeft,
                                  child: child,
                                );
                        },
                        child: AnimatedContainer(
                          duration: AppMotion.resolveDuration(
                            context,
                            const Duration(milliseconds: 220),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: servingsBadgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            servingsBadgeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.badge(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: servingsBadgeColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            priceDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.price(
                              fontSize: 13,
                              color: AppColors.forestGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Material(
                              color: canAdd
                                  ? AppColors.darkCoffee
                                  : AppColors.latteBeige.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: canAdd ? onAdd : null,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        canAdd ? Icons.add_rounded : Icons.block_rounded,
                                        size: 13,
                                        color: canAdd
                                            ? AppColors.surfaceWhite
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 3),
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
      ),
    ),
    );
  }
}
