import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_paths.dart';
import '../models/product_model.dart';
import '../models/recipe_model.dart';
import '../models/branch_product_stock_model.dart';
import 'inventory_provider.dart';

class SellableServingsResult {
  final int servings;
  final bool hasRecipe;
  final bool isAvailable;
  final String? limitingIngredientName;
  final double? limitingStock;
  final String? errorReason;
  final bool hasStockRecord;

  const SellableServingsResult({
    required this.servings,
    required this.hasRecipe,
    required this.isAvailable,
    this.limitingIngredientName,
    this.limitingStock,
    this.errorReason,
    this.hasStockRecord = true,
  });

  bool get isOutOfStock => servings <= 0;
}

class ProductsProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  ProductsProvider({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  StreamSubscription<QuerySnapshot>? _productsSubscription;
  StreamSubscription<QuerySnapshot>? _recipesSubscription;

  List<ProductModel> _products = [];
  Map<String, RecipeModel> _recipes = {};
  bool _isLoading = true;
  bool _isLoadingRecipes = true;
  String? _currentBranchId;

  List<ProductModel> get products => List.unmodifiable(_products);
  Map<String, RecipeModel> get recipes => Map.unmodifiable(_recipes);
  bool get isLoading => _isLoading;
  bool get isLoadingRecipes => _isLoadingRecipes;
  bool get hasRecipesLoaded => !_isLoadingRecipes && _recipes.isNotEmpty;
  String? get currentBranchId => _currentBranchId;

  // Legacy stubs kept for backward compatibility; not used in active workflows
  @Deprecated('Replaced by recipe-based physical inventory')
  Map<String, BranchProductStockModel> get branchProductStock => const {};
  @Deprecated('Replaced by recipe-based physical inventory')
  bool get isLoadingStock => false;
  @Deprecated('Replaced by recipe-based physical inventory')
  bool get isStockActive => false;
  @Deprecated('Replaced by recipe-based physical inventory')
  String? get stockErrorMessage => null;
  @Deprecated('Replaced by recipe-based physical inventory')
  bool get hasStockError => false;

  @Deprecated('Replaced by recipe-based physical inventory')
  @visibleForTesting
  void setBranchProductStockForTesting(
    Map<String, BranchProductStockModel> testStock,
  ) {}

  @visibleForTesting
  void setRecipesForTesting(Map<String, RecipeModel> testRecipes) {
    _recipes = testRecipes;
    _isLoadingRecipes = false;
    notifyListeners();
  }

  @visibleForTesting
  void setProductsForTesting(List<ProductModel> testProducts) {
    _products = testProducts;
    _isLoading = false;
    notifyListeners();
  }

  List<String> get categories {
    final set = <String>{};
    for (final p in _products) {
      if (p.displayCategory.isNotEmpty) {
        set.add(p.displayCategory);
      }
    }
    return set.toList();
  }

  RecipeModel? getRecipeForProduct(String productId) {
    if (_recipes.containsKey(productId)) return _recipes[productId];
    for (final r in _recipes.values) {
      if (r.productId == productId) return r;
    }
    return null;
  }

  SellableServingsResult calculateSellableServings({
    required ProductModel product,
    required List<InventoryItemModel> inventoryItems,
    String? temperature,
  }) {
    if (!product.isAvailable) {
      return const SellableServingsResult(
        servings: 0,
        hasRecipe: false,
        isAvailable: false,
        errorReason: 'Product marked unavailable',
      );
    }

    final recipe =
        getRecipeForProduct(product.productId) ??
        (product.recipeId != null ? _recipes[product.recipeId] : null);

    if (recipe == null) {
      if (_isLoadingRecipes) {
        return const SellableServingsResult(
          servings: 1,
          hasRecipe: false,
          isAvailable: true,
          errorReason: 'Loading recipe...',
        );
      }
      return SellableServingsResult(
        servings: 0,
        hasRecipe: false,
        isAvailable: false,
        errorReason: 'Recipe needed: Missing recipe for ${product.name}',
      );
    }

    SellableServingsResult physicalRes;
    final effectiveTemp = (temperature != null && temperature.isNotEmpty)
        ? temperature
        : product.fixedTemperature;

    if (product.supportsTemperatureOptions &&
        (effectiveTemp == null || effectiveTemp.isEmpty)) {
      final hotRes = _calculateForRequirements(
        recipe.getRequirementsForTemperature('hot'),
        inventoryItems,
      );
      final icedRes = _calculateForRequirements(
        recipe.getRequirementsForTemperature('iced'),
        inventoryItems,
      );

      final maxServings = math.max(hotRes.servings, icedRes.servings);
      final isAvail = maxServings > 0;
      final bottleneck = hotRes.servings <= icedRes.servings ? hotRes : icedRes;

      physicalRes = SellableServingsResult(
        servings: maxServings,
        hasRecipe: true,
        isAvailable: isAvail,
        limitingIngredientName: bottleneck.limitingIngredientName,
        limitingStock: bottleneck.limitingStock,
        errorReason: isAvail ? null : bottleneck.errorReason,
      );
    } else {
      final reqs = recipe.getRequirementsForTemperature(effectiveTemp);
      if (reqs.isEmpty) {
        physicalRes = SellableServingsResult(
          servings: 0,
          hasRecipe: true,
          isAvailable: false,
          errorReason: effectiveTemp != null && effectiveTemp.isNotEmpty
              ? 'No ingredients configured for $effectiveTemp'
              : 'Incomplete recipe for ${product.name}',
        );
      } else {
        physicalRes = _calculateForRequirements(reqs, inventoryItems);
      }
    }

    return physicalRes;
  }

  SellableServingsResult _calculateForRequirements(
    List<RecipeIngredientRequirement> reqs,
    List<InventoryItemModel> inventoryItems,
  ) {
    if (reqs.isEmpty) {
      return const SellableServingsResult(
        servings: 0,
        hasRecipe: true,
        isAvailable: false,
        errorReason: 'Empty recipe requirements',
      );
    }

    int minServings = 999999;
    String? bottleneckName;
    double? bottleneckStock;

    for (final req in reqs) {
      if (req.quantity <= 0) continue;

      InventoryItemModel? invItem;
      for (final item in inventoryItems) {
        final cleanReq = req.ingredientId.trim().toLowerCase();
        if (item.ingredientId.toLowerCase() == cleanReq ||
            item.id.toLowerCase() == cleanReq ||
            item.id.toLowerCase().endsWith('_$cleanReq')) {
          invItem = item;
          break;
        }
      }

      if (invItem == null) {
        return SellableServingsResult(
          servings: 0,
          hasRecipe: true,
          isAvailable: false,
          limitingIngredientName: req.ingredientName.isNotEmpty
              ? req.ingredientName
              : req.ingredientId,
          limitingStock: 0.0,
          errorReason:
              'Missing inventory record for ${req.ingredientName.isNotEmpty ? req.ingredientName : req.ingredientId}',
        );
      }

      final currentStock = invItem.availableQuantity < 0
          ? 0.0
          : invItem.availableQuantity;
      final convertedReq = UnitConverter.convert(
        quantity: req.quantity,
        fromUnit: req.unit,
        toUnit: invItem.unit,
      );

      if (convertedReq == null) {
        return SellableServingsResult(
          servings: 0,
          hasRecipe: true,
          isAvailable: false,
          limitingIngredientName: invItem.name,
          limitingStock: currentStock,
          errorReason:
              'Incompatible units: recipe has ${req.unit}, inventory has ${invItem.unit}',
        );
      }

      if (convertedReq <= 0) continue;

      final possibleServings = (currentStock / convertedReq).floor();
      if (possibleServings < minServings) {
        minServings = possibleServings;
        bottleneckName = invItem.name;
        bottleneckStock = currentStock;
      }
    }

    final finalServings = minServings == 999999 ? 0 : math.max(0, minServings);
    return SellableServingsResult(
      servings: finalServings,
      hasRecipe: true,
      isAvailable: finalServings > 0,
      limitingIngredientName: bottleneckName,
      limitingStock: bottleneckStock,
      errorReason: finalServings == 0 ? 'Out of stock ($bottleneckName)' : null,
    );
  }

  bool isProductAvailable(
    String productId, {
    List<InventoryItemModel>? inventoryItems,
  }) {
    try {
      final p = _products.firstWhere((item) => item.productId == productId);
      if (!p.isAvailable) return false;

      if (inventoryItems != null && _recipes.isNotEmpty) {
        final servings = calculateSellableServings(
          product: p,
          inventoryItems: inventoryItems,
        );
        return servings.isAvailable;
      }
      return p.isAvailable;
    } catch (_) {
      return false;
    }
  }

  ProductModel? getProductById(String productId) {
    try {
      return _products.firstWhere((item) => item.productId == productId);
    } catch (_) {
      return null;
    }
  }

  void bindToBranch(String branchId) {
    final cleanBranchId = branchId.trim();
    if (_currentBranchId == cleanBranchId && _productsSubscription != null) {
      return;
    }
    _currentBranchId = cleanBranchId;
    _listenToProducts(cleanBranchId);
    _listenToRecipes();
  }

  void _listenToRecipes() {
    _recipesSubscription?.cancel();
    _isLoadingRecipes = true;

    try {
      _recipesSubscription = _firestore
          .collection(FirebasePaths.recipes)
          .snapshots()
          .listen(
            (snapshot) {
              final map = <String, RecipeModel>{};
              for (final doc in snapshot.docs) {
                final recipe = RecipeModel.fromFirestore(doc.id, doc.data());
                map[doc.id] = recipe;
                if (recipe.productId.isNotEmpty) {
                  map[recipe.productId] = recipe;
                }
              }
              _recipes = map;
              _isLoadingRecipes = false;
              notifyListeners();
            },
            onError: (_) {
              _isLoadingRecipes = false;
              notifyListeners();
            },
          );
    } catch (_) {
      _isLoadingRecipes = false;
      notifyListeners();
    }
  }

  void _listenToProducts(String branchId) {
    _productsSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    try {
      _productsSubscription = _firestore
          .collection(FirebasePaths.products)
          .snapshots()
          .listen(
            (snapshot) {
              final loaded = snapshot.docs
                  .map((doc) => ProductModel.fromMap(doc.id, doc.data()))
                  .where((p) {
                    final bLower = branchId.toLowerCase().trim();
                    final isAvailableBranch =
                        p.availableBranches.isEmpty ||
                        p.availableBranches.any((b) {
                          final bStr = b.toLowerCase().trim();
                          return bStr == 'all' ||
                              bStr.isEmpty ||
                              bStr == bLower ||
                              bStr == 'br_santa_cruz' ||
                              bStr == 'br_lspu' ||
                              bStr == 'santa_cruz' ||
                              bStr == 'lspu' ||
                              (bLower.contains('santa') &&
                                  bStr.contains('santa')) ||
                              (bLower.contains('lspu') &&
                                  bStr.contains('lspu'));
                        });
                    return isAvailableBranch;
                  })
                  .toList();

              _products = loaded;
              _isLoading = false;
              notifyListeners();
            },
            onError: (_) {
              _isLoading = false;
              notifyListeners();
            },
          );
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _recipesSubscription?.cancel();
    super.dispose();
  }
}
