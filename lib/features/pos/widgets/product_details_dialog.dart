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
import 'quantity_edit_dialog.dart';

class ProductDetailsDialog extends StatefulWidget {
  final ProductModel product;

  const ProductDetailsDialog({super.key, required this.product});

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog> {
  String? _selectedTemp;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _selectedTemp = widget.product.initialTemperature;
  }

  double _getUnitPrice(ProductModel product) {
    final p = product.pricing;
    if (_selectedTemp == 'Hot' && p.hotPrice != null && p.hotPrice! > 0) {
      return p.hotPrice!;
    }
    if (_selectedTemp == 'Iced' && p.icedPrice != null && p.icedPrice! > 0) {
      return p.icedPrice!;
    }
    return p.regularPrice;
  }

  double get currentUnitPrice => _getUnitPrice(widget.product);

  double get totalPrice => currentUnitPrice * _quantity;

  IconData get categoryIcon {
    switch (widget.product.category) {
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

  Widget _buildDialogImage() {
    final hasValidUrl =
        widget.product.imageUrl.isNotEmpty &&
        (widget.product.imageUrl.startsWith('http://') ||
            widget.product.imageUrl.startsWith('https://'));

    if (hasValidUrl) {
      if (kIsWeb) {
        return Image.network(
          widget.product.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 160,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 160,
              width: double.infinity,
              color: AppColors.warmCream,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
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
        imageUrl: widget.product.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 160,
        placeholder: (context, url) => Container(
          height: 160,
          width: double.infinity,
          color: AppColors.warmCream,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
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
      height: 160,
      width: double.infinity,
      color: AppColors.warmCream,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkCoffee.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(categoryIcon, size: 40, color: AppColors.darkCoffee),
        ),
      ),
    );
  }

  ProductsProvider? _findProductsProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return Provider.of<ProductsProvider>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  InventoryProvider? _findInventoryProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return Provider.of<InventoryProvider>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  PosCartProvider? _findCartProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return Provider.of<PosCartProvider>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsProvider = _findProductsProvider(context, listen: true);
    final inventoryProvider = _findInventoryProvider(context, listen: true);
    final cartProvider = _findCartProvider(context, listen: true);
    final freshProduct = productsProvider?.getProductById(
      widget.product.productId,
    );
    final effectiveProduct = freshProduct ?? widget.product;
    final isProductFlagAvailable = effectiveProduct.isAvailable;
    final p = effectiveProduct.pricing;
    final showTemperature = effectiveProduct.supportsTemperatureOptions;

    final rawSelectedTemp = _selectedTemp?.trim();
    final effectiveTemp =
        (rawSelectedTemp != null && rawSelectedTemp.isNotEmpty)
        ? rawSelectedTemp
        : (effectiveProduct.fixedTemperature ??
              effectiveProduct.initialTemperature);

    SellableServingsResult? servingsResult;
    if (productsProvider != null &&
        inventoryProvider != null &&
        (productsProvider.recipes.isNotEmpty ||
            !productsProvider.isLoadingRecipes)) {
      final effectiveInventory =
          (cartProvider != null && !cartProvider.isEmpty)
          ? cartProvider.getRemainingInventory(
              inventoryItems: inventoryProvider.items,
              recipes: productsProvider.recipes,
            )
          : inventoryProvider.items;
      servingsResult = productsProvider.calculateSellableServings(
        product: effectiveProduct,
        inventoryItems: effectiveInventory,
        temperature: effectiveTemp,
      );
    }

    final isOutOfStock = servingsResult != null && servingsResult.isOutOfStock;
    final isAvailable = isProductFlagAvailable && !isOutOfStock;
    final maxServings = servingsResult?.servings;

    if (maxServings != null && maxServings > 0 && _quantity > maxServings) {
      _quantity = maxServings;
    }

    final unitPrice = _getUnitPrice(effectiveProduct);
    final dialogTotalPrice = unitPrice * _quantity;

    final String statusBadgeText = !isProductFlagAvailable
        ? 'NOT AVAILABLE'
        : (isOutOfStock ? 'OUT OF STOCK' : '');

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: AppFadeSlideScale(
        duration: AppMotion.standard,
        beginOffset: const Offset(0, 18),
        beginScale: 0.94,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Product Image Banner
              Stack(
                children: [
                  Container(
                    height: 170,
                    width: double.infinity,
                    color: AppColors.warmCream,
                    child: _buildDialogImage(),
                  ),
                  if (statusBadgeText.isNotEmpty)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mutedRed,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            statusBadgeText,
                            style: AppTextStyles.badge(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: CircleAvatar(
                      backgroundColor: AppColors.surfaceWhite.withValues(alpha: 0.92),
                      radius: 18,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.darkCoffee,
                          size: 18,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title, Price & Stock Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.name,
                            style: AppTextStyles.pageTitle(
                              fontSize: 21,
                              color: AppColors.darkCoffee,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${unitPrice.toStringAsFixed(unitPrice % 1 == 0 ? 0 : 2)}',
                          style: AppTextStyles.statNumberLarge(
                            fontSize: 20,
                            color: AppColors.forestGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.darkCoffee.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.product.displayCategory,
                                  style: AppTextStyles.badge(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkCoffee,
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final String statusLabel =
                                      !isProductFlagAvailable
                                      ? 'Unavailable'
                                      : (servingsResult?.statusBadgeLabel ??
                                            'Available');
                                  final Color statusColor = !isAvailable
                                      ? AppColors.mutedRed
                                      : (servingsResult?.isLowStock == true
                                            ? AppColors.warmBronze
                                            : AppColors.forestGreen);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: AppTextStyles.badge(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (widget.product.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        widget.product.description,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],

                    // --- TEMPERATURE SELECTION ---
                    if (showTemperature) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Temperature',
                        style: AppTextStyles.cardTitle(
                          fontSize: 14,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              avatar: Icon(
                                Icons.local_fire_department_rounded,
                                size: 16,
                                color: _selectedTemp == 'Hot'
                                    ? AppColors.surfaceWhite
                                    : AppColors.warmBronze,
                              ),
                              label: Text(
                                'Hot (₱${p.hotPrice!.toInt()})',
                                style: AppTextStyles.badge(
                                  fontWeight: _selectedTemp == 'Hot'
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedTemp == 'Hot'
                                      ? AppColors.surfaceWhite
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              selected: _selectedTemp == 'Hot',
                              selectedColor: AppColors.darkCoffee,
                              backgroundColor: AppColors.surfaceWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              side: BorderSide(
                                color: _selectedTemp == 'Hot'
                                    ? AppColors.darkCoffee
                                    : AppColors.borderSubtle,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedTemp = 'Hot');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              avatar: Icon(
                                Icons.ac_unit_rounded,
                                size: 16,
                                color: _selectedTemp == 'Iced'
                                    ? AppColors.surfaceWhite
                                    : AppColors.forestGreen,
                              ),
                              label: Text(
                                'Iced (₱${p.icedPrice!.toInt()})',
                                style: AppTextStyles.badge(
                                  fontWeight: _selectedTemp == 'Iced'
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedTemp == 'Iced'
                                      ? AppColors.surfaceWhite
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              selected: _selectedTemp == 'Iced',
                              selectedColor: AppColors.darkCoffee,
                              backgroundColor: AppColors.surfaceWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              side: BorderSide(
                                color: _selectedTemp == 'Iced'
                                    ? AppColors.darkCoffee
                                    : AppColors.borderSubtle,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedTemp = 'Iced');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 18),

                    // --- QUANTITY SELECTOR ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quantity',
                          style: AppTextStyles.cardTitle(
                            fontSize: 14,
                            color: AppColors.darkCoffee,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.warmCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.latteBeige),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: AppColors.darkCoffee,
                                ),
                                onPressed: () {
                                  if (_quantity > 1) {
                                    setState(() => _quantity--);
                                  }
                                },
                              ),
                              Tooltip(
                                message: 'Tap to edit quantity',
                                child: InkWell(
                                  onTap: () async {
                                    final newQty = await showQuantityEditDialog(
                                      context,
                                      title: 'Edit Quantity',
                                      itemName: widget.product.name,
                                      currentQuantity: _quantity,
                                      maxQuantity: maxServings,
                                    );
                                    if (newQty != null && mounted) {
                                      setState(() => _quantity = newQty);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceWhite,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.latteBeige,
                                      ),
                                    ),
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey<int>(_quantity),
                                      tween: Tween<double>(begin: 0.85, end: 1.0),
                                      duration: AppMotion.fast,
                                      curve: Curves.easeOutCubic,
                                      builder: (context, qScale, qChild) {
                                        return AppMotion.reduceMotion(context)
                                            ? qChild!
                                            : Transform.scale(
                                                scale: qScale,
                                                child: qChild,
                                              );
                                      },
                                      child: Text(
                                        '$_quantity',
                                        style: AppTextStyles.statNumber(
                                          fontSize: 16,
                                          color: AppColors.darkCoffee,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: AppColors.darkCoffee,
                                ),
                                onPressed:
                                    (maxServings == null ||
                                        _quantity < maxServings)
                                    ? () => setState(() => _quantity++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
                    const Divider(color: AppColors.borderSubtle),
                    const SizedBox(height: 12),

                    // --- TOTAL & ADD TO CART BUTTON ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Price',
                              style: AppTextStyles.subtitle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              key: ValueKey<double>(dialogTotalPrice),
                              tween: Tween<double>(begin: 0.92, end: 1.0),
                              duration: AppMotion.fast,
                              curve: Curves.easeOutCubic,
                              builder: (context, priceScale, priceChild) {
                                return AppMotion.reduceMotion(context)
                                    ? priceChild!
                                    : Transform.scale(
                                        scale: priceScale,
                                        alignment: Alignment.centerLeft,
                                        child: priceChild,
                                      );
                              },
                              child: Text(
                                '₱${dialogTotalPrice.toStringAsFixed(dialogTotalPrice % 1 == 0 ? 0 : 2)}',
                                style: AppTextStyles.statNumberLarge(
                                  fontSize: 22,
                                  color: AppColors.darkCoffee,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: AppPressableScale(
                            enabled: isAvailable,
                            child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAvailable
                                  ? AppColors.darkCoffee
                                  : AppColors.latteBeige,
                              foregroundColor: isAvailable
                                  ? AppColors.surfaceWhite
                                  : AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                            ),
                            onPressed: isAvailable
                                ? () {
                                    final freshCheck = _findProductsProvider(
                                      context,
                                      listen: false,
                                    )?.getProductById(widget.product.productId);
                                    final stillAvailable =
                                        freshCheck?.isAvailable ??
                                        isProductFlagAvailable;
                                    if (!stillAvailable) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${effectiveProduct.name} is no longer available.',
                                          ),
                                          backgroundColor: AppColors.mutedRed,
                                        ),
                                      );
                                      return;
                                    }

                                    if (maxServings != null &&
                                        _quantity > maxServings) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Cannot add more than $maxServings available servings.',
                                          ),
                                          backgroundColor: AppColors.mutedRed,
                                        ),
                                      );
                                      return;
                                    }

                                    context.read<PosCartProvider>().addToCart(
                                      product: effectiveProduct,
                                      selectedTemperature: effectiveTemp,
                                      unitPrice: unitPrice,
                                      quantity: _quantity,
                                    );
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added ${effectiveProduct.name} to cart',
                                        ),
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: AppColors.darkCoffee,
                                      ),
                                    );
                                  }
                                : null,
                            icon: Icon(
                              isAvailable
                                  ? Icons.shopping_bag_outlined
                                  : Icons.block_rounded,
                              size: 18,
                            ),
                            label: Text(
                              isAvailable
                                  ? 'Add to Cart'
                                  : (!isProductFlagAvailable
                                        ? 'Unavailable'
                                        : 'Out of Stock'),
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.button(
                                color: isAvailable
                                    ? AppColors.surfaceWhite
                                    : AppColors.textSecondary,
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
