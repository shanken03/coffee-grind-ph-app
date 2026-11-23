import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_animations.dart';
import '../../models/product_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/pos_cart_provider.dart';
import '../../providers/transactions_provider.dart';
import 'widgets/product_card.dart';
import 'widgets/product_details_dialog.dart';
import 'widgets/cart_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final Set<String> _animatedProductKeys = <String>{};

  void _openCartScreen() {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.resolveDuration(
          context,
          const Duration(milliseconds: 280),
        ),
        reverseTransitionDuration: AppMotion.resolveDuration(
          context,
          const Duration(milliseconds: 220),
        ),
        pageBuilder: (_, _, _) => const CartScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.12, 0.0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// The only active category filters, exactly matching Web Admin:
  /// 1. All
  /// 2. Coffee Series
  /// 3. Non Coffee Series
  static const List<String> _categories = [
    'All',
    'Coffee Series',
    'Non Coffee Series',
  ];

  Widget _buildSlideFadeEntrance({
    Key? key,
    required Duration duration,
    required Offset startOffset,
    double beginScale = 0.96,
    required Widget child,
  }) {
    return AppFadeSlideScale(
      key: key,
      duration: duration,
      beginOffset: startOffset,
      beginScale: beginScale,
      child: child,
    );
  }

  bool _matchesProductCategory(ProductModel product, String filter) {
    // Obsolete categories (Frappe, Refreshers, Foods, Sweets) must NEVER appear under ANY filter or search
    if (!product.isSupportedCategory) return false;
    if (filter == 'All') return true;
    if (filter == 'Coffee Series') {
      return product.displayCategory == 'Coffee Series' ||
          product.category == ProductCategory.coffee;
    }
    if (filter == 'Non Coffee Series') {
      return product.displayCategory == 'Non Coffee Series' ||
          product.category == ProductCategory.nonCoffee;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final cart = context.watch<PosCartProvider>();
    TransactionsProvider? txProvider;
    try {
      txProvider = context.watch<TransactionsProvider>();
    } catch (_) {}

    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    final filteredProducts = productsProvider.products.where((p) {
      if (!p.isSupportedCategory) return false;
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _matchesProductCategory(p, _selectedCategory);
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.warmCream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Image.asset(
                'assets/images/coffee_grind_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Staff POS',
              style: AppTextStyles.pageTitle(
                color: AppColors.darkCoffee,
                fontSize: 19,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.darkCoffee,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (txProvider != null &&
              (txProvider.isOffline ||
                  txProvider.pendingOfflineCount > 0 ||
                  txProvider.isSyncingOffline))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: InkWell(
                  onTap: txProvider.isSyncingOffline
                      ? null
                      : () => txProvider?.syncPendingOrders(),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (txProvider.isSyncingOffline)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.amber,
                            ),
                          )
                        else
                          Icon(
                            txProvider.isOffline
                                ? Icons.cloud_off_rounded
                                : Icons.sync_rounded,
                            size: 14,
                            color: AppColors.amber,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          txProvider.isSyncingOffline
                              ? 'Syncing...'
                              : txProvider.pendingOfflineCount > 0
                                  ? '${txProvider.pendingOfflineCount} Pending Sync'
                                  : 'Offline Mode',
                          style: AppTextStyles.badge(
                            fontSize: 11,
                            color: AppColors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: AppAnimatedBounce(
                triggerValue: cart.itemCount,
                child: InkWell(
                  onTap: _openCartScreen,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warmCream,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Badge(
                      isLabelVisible: cart.itemCount > 0,
                      label: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: AppColors.forestGreen,
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 900;

            if (isTablet) {
              return Row(
                children: [
                  // Main Section: Product Catalog
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopFilterBar(),
                        const Divider(height: 1, color: AppColors.borderSubtle),
                        Expanded(
                          child: _buildProductCatalogGrid(
                            productsProvider: productsProvider,
                            filteredProducts: filteredProducts,
                            isTablet: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Side Section: Embedded Live Cart Panel
                  _buildSlideFadeEntrance(
                    duration: const Duration(milliseconds: 460),
                    startOffset: const Offset(40, 0),
                    child: Container(
                      width: 390,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceWhite,
                        border: Border(
                          left: BorderSide(color: AppColors.borderSubtle, width: 1.2),
                        ),
                      ),
                      child: const CartView(isEmbedded: true),
                    ),
                  ),
                ],
              );
            }

            // Mobile Layout (< 900 width)
            return Column(
              children: [
                _buildTopFilterBar(),
                const Divider(height: 1, color: AppColors.borderSubtle),
                Expanded(
                  child: _buildProductCatalogGrid(
                    productsProvider: productsProvider,
                    filteredProducts: filteredProducts,
                    isTablet: false,
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppMotion.resolveDuration(
                    context,
                    const Duration(milliseconds: 260),
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.35),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: cart.isEmpty
                      ? const SizedBox.shrink(
                          key: ValueKey<String>('mobile_cart_empty'),
                        )
                      : KeyedSubtree(
                          key: const ValueKey<String>('mobile_cart_bar'),
                          child: _buildMobileCartBottomBar(cart),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopFilterBar() {
    return _buildSlideFadeEntrance(
      duration: const Duration(milliseconds: 420),
      startOffset: const Offset(0, -24),
      child: Container(
        color: AppColors.surfaceWhite,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pill Search Bar
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              maxLength: 26,
              inputFormatters: [LengthLimitingTextInputFormatter(26)],
              style: AppTextStyles.inputField(),
              decoration: InputDecoration(
                hintText: 'Search menu...',
                hintStyle: AppTextStyles.inputHint(),
                counterText: '',
                filled: true,
                fillColor: AppColors.warmCream,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.darkCoffee,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(
                    color: AppColors.darkCoffee,
                    width: 1.4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Horizontal Scrolling Pill Category Chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  final IconData catIcon = cat == 'All'
                      ? Icons.grid_view_rounded
                      : cat == 'Coffee Series'
                          ? Icons.coffee_rounded
                          : Icons.local_drink_rounded;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      avatar: Icon(
                        catIcon,
                        size: 16,
                        color: isSelected
                            ? AppColors.surfaceWhite
                            : AppColors.darkCoffee,
                      ),
                      label: Text(
                        cat,
                        style: AppTextStyles.badge(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? AppColors.surfaceWhite
                              : AppColors.darkCoffee,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.darkCoffee,
                      backgroundColor: AppColors.surfaceWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.darkCoffee
                            : AppColors.borderSubtle,
                      ),
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                            _animatedProductKeys.clear();
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCatalogGrid({
    required ProductsProvider productsProvider,
    required List<ProductModel> filteredProducts,
    required bool isTablet,
  }) {
    if (productsProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.darkCoffee),
      );
    }

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No products available for this branch.',
              style: AppTextStyles.cardTitle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Products configured on Owner Web will appear here in real-time.',
              style: AppTextStyles.subtitle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = isTablet
            ? (width >= 800 ? 4 : (width >= 550 ? 3 : 2))
            : (width >= 600 ? 3 : 2);
        final childAspectRatio = isTablet ? 0.78 : (width >= 600 ? 0.82 : 0.74);

        return _buildSlideFadeEntrance(
          key: ValueKey<String>(_selectedCategory),
          duration: const Duration(milliseconds: 360),
          startOffset: const Offset(28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menu',
                      style: AppTextStyles.sectionHeading(
                        fontSize: 17,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                    Text(
                      '${filteredProducts.length} items',
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final animKey = '${_selectedCategory}_${product.productId}';
                    final shouldAnimate =
                        !_animatedProductKeys.contains(animKey);
                    if (shouldAnimate) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _animatedProductKeys.add(animKey);
                      });
                    }
                    final card = ProductCard(
                      product: product,
                      onTap: () => _openProductDetails(product),
                      onAdd: () => _onProductAdd(product),
                    );
                    if (!shouldAnimate) return card;
                    return _buildSlideFadeEntrance(
                      key: ValueKey<String>(animKey),
                      duration: Duration(
                        milliseconds: 280 + (index.clamp(0, 8) * 35),
                      ),
                      startOffset: const Offset(0, 22),
                      beginScale: 0.92,
                      child: card,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileCartBottomBar(PosCartProvider cart) {
    return _buildSlideFadeEntrance(
      duration: const Duration(milliseconds: 340),
      startOffset: const Offset(0, 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          border: const Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1.2),
          ),
          boxShadow: AppColors.floatingBarShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AppAnimatedBounce(
                  triggerValue: cart.itemCount,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warmCream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: AppColors.darkCoffee,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cart.itemCount} ${cart.itemCount == 1 ? 'Item' : 'Items'} in Cart',
                      style: AppTextStyles.subtitle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₱${cart.totalAmount.toStringAsFixed(2)}',
                      style: AppTextStyles.statNumber(
                        color: AppColors.darkCoffee,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            AppPressableScale(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkCoffee,
                  foregroundColor: AppColors.surfaceWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                onPressed: _openCartScreen,
                icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                label: Text(
                  'View Cart',
                  style: AppTextStyles.button(color: AppColors.surfaceWhite, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onProductAdd(ProductModel product) {
    if (!product.isAvailable) return;

    if (product.supportsTemperatureOptions) {
      _openProductDetails(product);
      return;
    }

    // Single regular price product: verify fresh availability and add directly
    final productsProvider = context.read<ProductsProvider>();
    final freshProduct = productsProvider.getProductById(product.productId);
    final effectiveProduct = freshProduct ?? product;
    if (!effectiveProduct.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is no longer available.'),
          backgroundColor: AppColors.mutedRed,
        ),
      );
      return;
    }

    final cart = context.read<PosCartProvider>();
    InventoryProvider? inventoryProvider;
    try {
      inventoryProvider = context.read<InventoryProvider>();
    } catch (_) {}

    if (inventoryProvider != null &&
        (productsProvider.recipes.isNotEmpty ||
            !productsProvider.isLoadingRecipes)) {
      final effectiveInventory = cart.getRemainingInventory(
        inventoryItems: inventoryProvider.items,
        recipes: productsProvider.recipes,
      );
      final servingsResult = productsProvider.calculateSellableServings(
        product: effectiveProduct,
        inventoryItems: effectiveInventory,
        temperature: effectiveProduct.fixedTemperature,
      );
      if (servingsResult.isOutOfStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot add more ${product.name}: Out of stock.'),
            backgroundColor: AppColors.mutedRed,
          ),
        );
        return;
      }
    }

    cart.addToCart(
          product: effectiveProduct,
          selectedTemperature: effectiveProduct.fixedTemperature,
          unitPrice: effectiveProduct.pricing.regularPrice,
          quantity: 1,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${product.name} to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.darkCoffee,
      ),
    );
  }

  void _openProductDetails(ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => ProductDetailsDialog(product: product),
    );
  }
}
