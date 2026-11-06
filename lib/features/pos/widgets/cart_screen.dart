import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
        (productsProvider.recipes.isNotEmpty ||
            !productsProvider.isLoadingRecipes) &&
        (inventoryProvider.items.isNotEmpty || !inventoryProvider.isLoading) &&
        !cart.isEmpty) {
      validationResult = cart.validateCartStock(
        recipes: productsProvider.recipes,
        inventoryItems: inventoryProvider.items,
        allowMissingRecipes: false,
      );
    }

    final bool isCartStockValid =
        validationResult == null || validationResult.isValid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cart (${cart.itemCount} Items)',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () {
                cart.clearCart();
              },
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: SafeArea(
        child: cart.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: AppTextStyles.cardTitle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add items from the POS menu to begin a sale.',
                      style: AppTextStyles.subtitle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (!isCartStockValid)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mutedRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.mutedRed.withValues(alpha: 0.4),
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
                                const SizedBox(height: 4),
                                Text(
                                  validationResult.errorMessage ?? 'One or more items exceed branch inventory.',
                                  style: AppTextStyles.bodySmall(
                                    fontSize: 12,
                                    color: AppColors.darkCoffee,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.latteBeige,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icon placeholder
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.darkCoffee.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.local_cafe_rounded,
                                  color: AppColors.darkCoffee,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Product details
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
                                    const SizedBox(height: 2),
                                    Text(
                                      item.variantLabel,
                                      style: AppTextStyles.caption(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₱${item.unitPrice.toStringAsFixed(2)} each',
                                      style: AppTextStyles.tableCell(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.darkCoffee,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Quantity selector
                              Builder(
                                builder: (context) {
                                  final totalInCart = cart.items
                                      .where(
                                        (i) =>
                                            i.product.productId ==
                                            item.product.productId,
                                      )
                                      .fold(0, (sum, i) => sum + i.quantity);

                                  SellableServingsResult? servingsResult;
                                  if (productsProvider != null &&
                                      inventoryProvider != null &&
                                      (productsProvider.recipes.isNotEmpty ||
                                          !productsProvider.isLoadingRecipes)) {
                                    servingsResult = productsProvider
                                        .calculateSellableServings(
                                          product: item.product,
                                          inventoryItems:
                                              inventoryProvider.items,
                                          temperature: item.selectedTemperature,
                                        );
                                  }

                                  final int? maxServings =
                                      servingsResult?.servings;
                                  final bool canIncrease =
                                      (servingsResult == null ||
                                      totalInCart < (maxServings ?? 0));

                                  return Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 22,
                                        ),
                                        color: AppColors.darkCoffee,
                                        onPressed: () =>
                                            cart.updateQuantity(item.id, -1),
                                      ),
                                      Tooltip(
                                        message: 'Tap to edit quantity',
                                        child: InkWell(
                                          onTap: () async {
                                            final otherInCart =
                                                totalInCart - item.quantity;
                                            final maxForItem =
                                                maxServings != null
                                                ? (maxServings - otherInCart)
                                                    .clamp(1, maxServings)
                                                : null;
                                            final newQty =
                                                await showQuantityEditDialog(
                                                  context,
                                                  title: 'Edit Quantity',
                                                  itemName:
                                                      '${item.product.name} (${item.variantLabel})',
                                                  currentQuantity:
                                                      item.quantity,
                                                  maxQuantity: maxForItem,
                                                );
                                            if (newQty != null) {
                                              cart.setItemQuantity(
                                                item.id,
                                                newQty,
                                              );
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.warmCream,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppColors.latteBeige,
                                              ),
                                            ),
                                            child: Text(
                                              '${item.quantity}',
                                              style: AppTextStyles.statNumber(
                                                fontSize: 16,
                                                color: AppColors.darkCoffee,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 22,
                                        ),
                                        color: canIncrease
                                            ? AppColors.darkCoffee
                                            : AppColors.textMuted.withValues(
                                                alpha: 0.3,
                                              ),
                                        onPressed: canIncrease
                                            ? () => cart.updateQuantity(
                                                item.id,
                                                1,
                                              )
                                            : null,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Summary Footer
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceWhite,
                      border: Border(
                        top: BorderSide(color: AppColors.latteBeige, width: 1),
                      ),
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
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₱${cart.totalAmount.toStringAsFixed(2)}',
                              style: AppTextStyles.statNumber(
                                fontSize: 16,
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
                                fontSize: 18,
                                color: AppColors.darkCoffee,
                              ),
                            ),
                            Text(
                              '₱${cart.totalAmount.toStringAsFixed(2)}',
                              style: AppTextStyles.statNumberLarge(
                                fontSize: 22,
                                color: AppColors.darkCoffee,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCartStockValid
                                  ? AppColors.darkCoffee
                                  : AppColors.latteBeige,
                              foregroundColor: isCartStockValid
                                  ? AppColors.surfaceWhite
                                  : AppColors.textSecondary,
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
                            icon: const Icon(Icons.payment_rounded),
                            label: Text(
                              isCartStockValid
                                  ? 'Proceed to Checkout'
                                  : 'Stock Exceeded — Adjust Cart',
                              style: AppTextStyles.button(
                                color: isCartStockValid
                                    ? AppColors.surfaceWhite
                                    : AppColors.textSecondary,
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
