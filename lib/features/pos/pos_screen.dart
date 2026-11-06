import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/product_model.dart';
import '../../providers/products_provider.dart';
import '../../providers/pos_cart_provider.dart';
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

  static const List<String> _baseCategories = [
    'All',
    'Coffee Series',
    'Non Coffee Series',
    'Frappe',
    'Refreshers',
    'Foods',
    'Sweets',
  ];

  List<String> _getCategories(List<String> providerCategories) {
    final list = List<String>.from(_baseCategories);
    for (final cat in providerCategories) {
      if (cat.trim().isEmpty) continue;
      final isCovered = list.any((c) => _matchesCategoryName(cat, c));
      if (!isCovered && !list.contains(cat)) {
        list.add(cat);
      }
    }
    return list;
  }

  bool _matchesCategoryName(String rawCategory, String filter) {
    if (filter == 'All') return true;
    final r = rawCategory.toLowerCase().trim();
    final f = filter.toLowerCase().trim();
    if (r == f) return true;

    switch (filter) {
      case 'Coffee Series':
        return (r.contains('coffee') && !r.contains('non')) || r == 'coffee';
      case 'Non Coffee Series':
        return (r.contains('non') && r.contains('coffee')) || r.contains('non-coffee') || r == 'non coffee';
      case 'Frappe':
        return r.contains('frappe');
      case 'Refreshers':
        return r.contains('refresher');
      case 'Foods':
        return r.contains('food') || r.contains('meal');
      case 'Sweets':
        return r.contains('sweet') ||
            r.contains('pastr') ||
            r.contains('dessert') ||
            r.contains('cookie') ||
            r.contains('cake') ||
            r.contains('muffin');
      default:
        return r == f;
    }
  }

  bool _matchesProductCategory(ProductModel product, String filter) {
    if (filter == 'All') return true;
    if (_matchesCategoryName(product.categoryName, filter)) return true;
    if (_matchesCategoryName(product.displayCategory, filter)) return true;
    if (_matchesCategoryName(product.category.label, filter)) return true;

    switch (filter) {
      case 'Coffee Series':
        return product.category == ProductCategory.coffee;
      case 'Non Coffee Series':
        return product.category == ProductCategory.nonCoffee;
      case 'Frappe':
        return product.category == ProductCategory.frappe;
      case 'Refreshers':
        return product.category == ProductCategory.refreshers;
      case 'Foods':
        return product.category == ProductCategory.foods;
      case 'Sweets':
        return product.category == ProductCategory.sweets;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final cart = context.watch<PosCartProvider>();

    final categories = _getCategories(productsProvider.categories);

    final filteredProducts = productsProvider.products.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _matchesProductCategory(p, _selectedCategory);
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Staff POS',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP SEARCH & CATEGORIES BAR ---
            Container(
              color: AppColors.surfaceWhite,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: AppTextStyles.inputField(),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: AppTextStyles.inputHint(),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.darkCoffee),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Horizontal Scrolling Category Chips
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = _selectedCategory == cat;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: AppTextStyles.badge(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.surfaceWhite : AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.forestGreen,
                            backgroundColor: AppColors.surfaceWhite,
                            side: BorderSide(
                              color: isSelected ? AppColors.forestGreen : AppColors.latteBeige,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCategory = cat);
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

            const Divider(height: 1, color: AppColors.latteBeige),

            // --- PRODUCT GRID / LOADING / EMPTY STATE ---
            Expanded(
              child: productsProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.darkCoffee),
                    )
                  : filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 64,
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No products available for this branch.',
                                style: AppTextStyles.cardTitle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Products configured on Owner Web will appear here in real-time.',
                                style: AppTextStyles.subtitle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final crossAxisCount = width >= 1200 ? 5 : width >= 900 ? 4 : width >= 600 ? 3 : 2;
                            final childAspectRatio = width >= 600 ? 0.82 : 0.72;

                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: childAspectRatio,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return ProductCard(
                                  product: product,
                                  onTap: () => _openProductDetails(product),
                                  onAdd: () => _onProductAdd(product),
                                );
                              },
                            );
                          },
                        ),
            ),

            // --- BOTTOM CART SUMMARY BAR ---
            if (!cart.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite,
                  border: Border(top: BorderSide(color: AppColors.latteBeige, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.darkCoffee.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_bag_rounded, color: AppColors.darkCoffee, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${cart.itemCount} ${cart.itemCount == 1 ? 'Item' : 'Items'}',
                              style: AppTextStyles.subtitle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '₱${cart.totalAmount.toStringAsFixed(2)}',
                              style: AppTextStyles.statNumber(
                                color: AppColors.darkCoffee,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkCoffee,
                        foregroundColor: AppColors.surfaceWhite,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CartScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                      label: Text(
                        'View Cart',
                        style: AppTextStyles.button(color: AppColors.surfaceWhite),
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

  void _onProductAdd(ProductModel product) {
    if (!product.isAvailable) return;

    if (product.supportsTemperatureOptions) {
      _openProductDetails(product);
      return;
    }

    // Single regular price product: verify fresh availability and add directly
    final freshProduct = context.read<ProductsProvider>().getProductById(product.productId);
    final stillAvailable = freshProduct?.isAvailable ?? product.isAvailable;
    if (!stillAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is no longer available.'),
          backgroundColor: AppColors.mutedRed,
        ),
      );
      return;
    }

    context.read<PosCartProvider>().addToCart(
          product: product,
          selectedTemperature: product.fixedTemperature,
          unitPrice: product.pricing.regularPrice,
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
