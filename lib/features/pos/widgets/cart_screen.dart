import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../models/product_model.dart';
import '../../../providers/pos_cart_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/inventory_provider.dart';
import 'checkout_screen.dart';
import 'quantity_edit_dialog.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PosCartProvider>();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          'Cart (${cart.itemCount} Items)',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.darkCoffee,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!cart.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.darkCoffee),
              onPressed: () {
                cart.clearCart();
              },
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: const SafeArea(
        child: CartView(isEmbedded: false),
      ),
    );
  }
}

/// Reusable cart view widget supporting both standalone full-screen page (mobile)
/// and embedded side panel (tablet POS layout).
class CartView extends StatelessWidget {
  final bool isEmbedded;

  const CartView({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PosCartProvider>();

    ProductsProvider? productsProvider;
    InventoryProvider? inventoryProvider;
    try {
      productsProvider = context.watch<ProductsProvider>();
    } catch (_) {}
    try {
      inventoryProvider = context.watch<InventoryProvider>();
    } catch (_) {}

    CartValidationResult? validationResult;
    if (productsProvider != null &&
        inventoryProvider != null &&
        (productsProvider.recipes.isNotEmpty || !productsProvider.isLoadingRecipes) &&
        (inventoryProvider.items.isNotEmpty || !inventoryProvider.isLoading) &&
        !cart.isEmpty) {
      validationResult = cart.validateCartStock(
        recipes: productsProvider.recipes,
        inventoryItems: inventoryProvider.items,
        manualServings: productsProvider.manualServings,
        allowMissingRecipes: false,
      );
    }

    final bool isCartStockValid =
        validationResult == null || validationResult.isValid;

    if (cart.isEmpty) {
      return AppFadeSlideScale(
        key: const ValueKey<String>('cart_empty_state'),
        duration: AppMotion.standard,
        beginOffset: const Offset(0, 14),
        beginScale: 0.96,
        child: Container(
          color: AppColors.warmCream,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: isEmbedded ? 48 : 64,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Your cart is empty',
                  style: AppTextStyles.cardTitle(
                    fontSize: isEmbedded ? 16 : 18,
                    color: AppColors.darkCoffee,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add items from the POS menu to begin a sale.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle(
                    color: AppColors.textSecondary,
                    fontSize: isEmbedded ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }

    return AppFadeSlideScale(
      key: const ValueKey<String>('cart_active_state'),
      duration: AppMotion.standard,
      beginOffset: const Offset(0, 12),
      beginScale: 0.99,
      child: Container(
        color: AppColors.warmCream,
      child: Column(
        children: [
          // Embedded Tablet Header
          if (isEmbedded)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warmCream,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: AppColors.darkCoffee,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Order Cart (${cart.itemCount})',
                        style: AppTextStyles.cardTitle(
                          fontSize: 16,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mutedRed,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => cart.clearCart(),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: Text(
                      'Clear',
                      style: AppTextStyles.buttonSmall(
                        color: AppColors.mutedRed,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Stock Deficit Warning Banner
          if (!isCartStockValid)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mutedRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.mutedRed.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.mutedRed,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Deficit Detected',
                          style: AppTextStyles.cardTitle(
                            fontSize: 13,
                            color: AppColors.mutedRed,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          validationResult.errorMessage ??
                              'One or more items exceed branch inventory.',
                          style: AppTextStyles.bodySmall(
                            fontSize: 12,
                            color: AppColors.darkCoffee,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Cart Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items[index];
                final effectiveTemp =
                    PosCartProvider.resolveEffectiveTemperature(
                      item.product,
                      item.selectedTemperature,
                    );

                SellableServingsResult? servingsResult;
                SellableServingsResult? remainingAfterCartResult;
                if (productsProvider != null &&
                    inventoryProvider != null &&
                    (productsProvider.recipes.isNotEmpty ||
                        !productsProvider.isLoadingRecipes)) {
                  final remainingInventoryForMax = cart.getRemainingInventory(
                    inventoryItems: inventoryProvider.items,
                    recipes: productsProvider.recipes,
                    excludeCartItemId: item.id,
                  );
                  servingsResult = productsProvider.calculateSellableServings(
                    product: item.product,
                    inventoryItems: remainingInventoryForMax,
                    temperature: effectiveTemp,
                  );

                  final remainingInventoryAfterAllCart = cart
                      .getRemainingInventory(
                        inventoryItems: inventoryProvider.items,
                        recipes: productsProvider.recipes,
                      );
                  remainingAfterCartResult = productsProvider
                      .calculateSellableServings(
                        product: item.product,
                        inventoryItems: remainingInventoryAfterAllCart,
                        temperature: effectiveTemp,
                      );
                }

                final Color? remainingBadgeColor =
                    remainingAfterCartResult == null
                    ? null
                    : (remainingAfterCartResult.isOutOfStock
                          ? AppColors.mutedRed
                          : (remainingAfterCartResult.isLowStock
                                ? AppColors.warmBronze
                                : AppColors.forestGreen));

                return AppFadeSlideScale(
                  key: ValueKey<String>('cart_row_${item.id}'),
                  duration: Duration(
                    milliseconds: 240 + (index.clamp(0, 6) * 30),
                  ),
                  beginOffset: const Offset(0, 14),
                  beginScale: 0.97,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.warmCream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: item.product.imageUrl.isNotEmpty &&
                                    (item.product.imageUrl.startsWith('http://') ||
                                        item.product.imageUrl.startsWith('https://'))
                                ? Image.network(
                                    item.product.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      item.product.category == ProductCategory.coffee
                                          ? Icons.coffee_rounded
                                          : Icons.local_drink_rounded,
                                      color: AppColors.darkCoffee,
                                      size: 24,
                                    ),
                                  )
                                : Icon(
                                    item.product.category == ProductCategory.coffee
                                        ? Icons.coffee_rounded
                                        : Icons.local_drink_rounded,
                                    color: AppColors.darkCoffee,
                                    size: 24,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: AppTextStyles.cardTitle(
                                    fontSize: 15,
                                    color: AppColors.darkCoffee,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: item.selectedTemperature == 'Hot'
                                            ? AppColors.warmBronze.withValues(alpha: 0.12)
                                            : AppColors.forestGreen.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.variantLabel,
                                        style: AppTextStyles.badge(
                                          fontSize: 11,
                                          color: item.selectedTemperature == 'Hot'
                                              ? AppColors.warmBronze
                                              : AppColors.forestGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '₱${item.unitPrice.toStringAsFixed(2)} each',
                                      style: AppTextStyles.caption(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (remainingAfterCartResult != null &&
                                    remainingBadgeColor != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: remainingBadgeColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      remainingAfterCartResult.statusBadgeLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.badge(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: remainingBadgeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // 1-Tap Remove Button
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            tooltip: 'Remove',
                            onPressed: () => cart.removeItem(item.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      const SizedBox(height: 10),

                      // Stepper & Item Subtotal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Quantity Stepper
                          Builder(
                            builder: (context) {
                              final int? maxServings = servingsResult?.servings;
                              final bool canIncrease =
                                  (servingsResult == null ||
                                      item.quantity < (maxServings ?? 0));

                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.warmCream,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                      ),
                                      color: AppColors.darkCoffee,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          cart.updateQuantity(item.id, -1),
                                    ),
                                    Tooltip(
                                      message: 'Tap to edit quantity',
                                      child: InkWell(
                                        onTap: () async {
                                          final maxForItem = maxServings != null
                                              ? math.max(1, maxServings)
                                              : null;
                                          final newQty = await showQuantityEditDialog(
                                            context,
                                            title: 'Edit Quantity',
                                            itemName: '${item.product.name} (${item.variantLabel})',
                                            currentQuantity: item.quantity,
                                            maxQuantity: maxForItem,
                                          );
                                          if (newQty != null) {
                                            cart.setItemQuantity(item.id, newQty);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceWhite,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.borderSubtle),
                                          ),
                                            child: TweenAnimationBuilder<double>(
                                              key: ValueKey<int>(item.quantity),
                                              tween: Tween<double>(
                                                begin: 0.85,
                                                end: 1.0,
                                              ),
                                              duration: AppMotion.fast,
                                              curve: Curves.easeOutCubic,
                                              builder: (context, scaleVal, child) {
                                                return AppMotion.reduceMotion(
                                                      context,
                                                    )
                                                    ? child!
                                                    : Transform.scale(
                                                        scale: scaleVal,
                                                        child: child,
                                                      );
                                              },
                                              child: Text(
                                                '${item.quantity}',
                                                style: AppTextStyles.statNumber(
                                                  fontSize: 15,
                                                  color: AppColors.darkCoffee,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 20,
                                        ),
                                        color: canIncrease
                                            ? AppColors.darkCoffee
                                            : AppColors.textMuted.withValues(alpha: 0.3),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        onPressed: canIncrease
                                            ? () => cart.updateQuantity(item.id, 1)
                                            : null,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Line Subtotal
                            TweenAnimationBuilder<double>(
                              key: ValueKey<double>(item.subtotal),
                              tween: Tween<double>(begin: 0.90, end: 1.0),
                              duration: AppMotion.fast,
                              curve: Curves.easeOutCubic,
                              builder: (context, subScale, child) {
                                return AppMotion.reduceMotion(context)
                                    ? child!
                                    : Transform.scale(
                                        scale: subScale,
                                        alignment: Alignment.centerRight,
                                        child: child,
                                      );
                              },
                              child: Text(
                                '₱${item.subtotal.toStringAsFixed(2)}',
                                style: AppTextStyles.statNumber(
                                  fontSize: 16,
                                  color: AppColors.darkCoffee,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Summary Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              border: const Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1.2),
              ),
              boxShadow: AppColors.floatingBarShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: AppTextStyles.subtitle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₱${cart.totalAmount.toStringAsFixed(2)}',
                      style: AppTextStyles.statNumber(
                        fontSize: 15,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: AppTextStyles.sectionHeading(
                        fontSize: 17,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      key: ValueKey<double>(cart.totalAmount),
                      tween: Tween<double>(begin: 0.92, end: 1.0),
                      duration: AppMotion.fast,
                      curve: Curves.easeOutCubic,
                      builder: (context, totScale, child) {
                        return AppMotion.reduceMotion(context)
                            ? child!
                            : Transform.scale(
                                scale: totScale,
                                alignment: Alignment.centerRight,
                                child: child,
                              );
                      },
                      child: Text(
                        '₱${cart.totalAmount.toStringAsFixed(2)}',
                        style: AppTextStyles.statNumberLarge(
                          fontSize: 22,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: AppPressableScale(
                    enabled: isCartStockValid,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCartStockValid
                            ? AppColors.darkCoffee
                            : AppColors.latteBeige,
                        foregroundColor: isCartStockValid
                            ? AppColors.surfaceWhite
                            : AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isCartStockValid
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CheckoutScreen(),
                                ),
                              );
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please adjust quantities for items exceeding branch stock before checkout.',
                                  ),
                                  backgroundColor: AppColors.mutedRed,
                                ),
                              );
                            },
                      icon: const Icon(Icons.payment_rounded, size: 20),
                      label: Text(
                        isCartStockValid
                            ? 'Proceed to Checkout'
                            : 'Stock Exceeded — Adjust Cart',
                        style: AppTextStyles.button(
                          color: isCartStockValid
                              ? AppColors.surfaceWhite
                              : AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
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
}
