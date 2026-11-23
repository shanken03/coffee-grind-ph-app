import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/branch_product_serving_model.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../models/recipe_model.dart';
import 'inventory_provider.dart';

class CartStockDeficit {
  final String ingredientId;
  final String ingredientName;
  final double requiredAmount;
  final double availableAmount;
  final String unit;

  const CartStockDeficit({
    required this.ingredientId,
    required this.ingredientName,
    required this.requiredAmount,
    required this.availableAmount,
    required this.unit,
  });

  String get summary =>
      '$ingredientName (Requires ${requiredAmount.toStringAsFixed(requiredAmount % 1 == 0 ? 0 : 1)} $unit, only ${availableAmount.toStringAsFixed(availableAmount % 1 == 0 ? 0 : 1)} $unit in stock)';
}

class CartManualQuotaDeficit {
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int remainingServings;

  const CartManualQuotaDeficit({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.remainingServings,
  });

  String get summary => remainingServings <= 0
      ? '$productName is out of stock (0 manual servings remaining)'
      : '$productName ($requestedQuantity in cart, only $remainingServings manual servings available)';
}

class CartValidationResult {
  final bool isValid;
  final List<CartStockDeficit> deficits;
  final List<CartManualQuotaDeficit> manualQuotaDeficits;
  final List<String> missingRecipes;
  final List<String> incompatibleUnits;
  final List<String> missingInventory;
  final String? errorMessage;

  const CartValidationResult({
    required this.isValid,
    this.deficits = const [],
    this.manualQuotaDeficits = const [],
    this.missingRecipes = const [],
    this.incompatibleUnits = const [],
    this.missingInventory = const [],
    this.errorMessage,
  });

  static const valid = CartValidationResult(isValid: true);
}

class PosCartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  Map<String, BranchProductServingModel> _manualServings = const {};

  List<CartItemModel> get items => List.unmodifiable(_items);

  Map<String, BranchProductServingModel> get manualServings => _manualServings;

  void setManualServings(Map<String, BranchProductServingModel> servings) {
    _manualServings = servings;
    notifyListeners();
  }

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  static String? resolveEffectiveTemperature(
    ProductModel product,
    String? selectedTemperature,
  ) {
    final trimmed = selectedTemperature?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return product.fixedTemperature ?? product.initialTemperature;
  }

  RecipeModel? _findRecipe(
    ProductModel product,
    Map<String, RecipeModel> recipes,
  ) {
    final pId = product.productId;
    if (recipes.containsKey(pId)) return recipes[pId];
    if (product.recipeId != null &&
        product.recipeId!.isNotEmpty &&
        recipes.containsKey(product.recipeId)) {
      return recipes[product.recipeId];
    }

    final cleanPId = pId.toLowerCase().trim();
    final cleanRecId = product.recipeId?.toLowerCase().trim();
    final cleanName = product.name.toLowerCase().trim();
    final recByNameId = cleanName.isNotEmpty
        ? 'rec_${cleanName.replaceAll(' ', '_')}'
        : null;
    for (final r in recipes.values) {
      if (r.productId.toLowerCase().trim() == cleanPId ||
          r.recipeId.toLowerCase().trim() == cleanPId ||
          (cleanRecId != null &&
              cleanRecId.isNotEmpty &&
              r.recipeId.toLowerCase().trim() == cleanRecId) ||
          (recByNameId != null &&
              r.recipeId.toLowerCase().trim() == recByNameId) ||
          (cleanName.isNotEmpty && r.name.toLowerCase().trim() == cleanName)) {
        return r;
      }
    }
    return null;
  }

  int _findInventoryIndex(
    RecipeIngredientRequirement req,
    List<InventoryItemModel> inventoryItems,
  ) {
    final cleanReq = req.ingredientId.trim().toLowerCase();
    for (int i = 0; i < inventoryItems.length; i++) {
      final item = inventoryItems[i];
      if (item.ingredientId.toLowerCase() == cleanReq ||
          item.id.toLowerCase() == cleanReq ||
          item.id.toLowerCase().endsWith('_$cleanReq')) {
        return i;
      }
    }
    return -1;
  }

  /// Returns a view of [inventoryItems] with [availableQuantity] reduced by
  /// ingredients already reserved in the current cart.
  List<InventoryItemModel> getRemainingInventory({
    required List<InventoryItemModel> inventoryItems,
    required Map<String, RecipeModel> recipes,
    String? excludeCartItemId,
  }) {
    if (_items.isEmpty || recipes.isEmpty || inventoryItems.isEmpty) {
      return inventoryItems;
    }

    final Map<int, double> reservedByIndex = {};

    for (final cartItem in _items) {
      if (excludeCartItemId != null && cartItem.id == excludeCartItemId) {
        continue;
      }
      final recipe = _findRecipe(cartItem.product, recipes);
      if (recipe == null || recipe.ingredients.isEmpty) continue;

      final effectiveTemp = resolveEffectiveTemperature(
        cartItem.product,
        cartItem.selectedTemperature,
      );
      final reqs = recipe.getRequirementsForTemperature(effectiveTemp);

      for (final req in reqs) {
        if (req.quantity <= 0) continue;
        final idx = _findInventoryIndex(req, inventoryItems);
        if (idx < 0) continue;

        final invItem = inventoryItems[idx];
        final converted = UnitConverter.convert(
          quantity: req.quantity,
          fromUnit: req.unit,
          toUnit: invItem.unit,
        );
        final perServing = converted ?? req.quantity;
        reservedByIndex[idx] =
            (reservedByIndex[idx] ?? 0.0) + (perServing * cartItem.quantity);
      }
    }

    if (reservedByIndex.isEmpty) return inventoryItems;

    return List<InventoryItemModel>.generate(inventoryItems.length, (i) {
      final inv = inventoryItems[i];
      final reserved = reservedByIndex[i] ?? 0.0;
      if (reserved <= 0) return inv;
      final remaining = math.max(0.0, inv.availableQuantity - reserved);
      return InventoryItemModel(
        id: inv.id,
        ingredientId: inv.ingredientId,
        name: inv.name,
        category: inv.category,
        availableQuantity: remaining,
        unit: inv.unit,
        minStock: inv.minStock,
        branchId: inv.branchId,
      );
    });
  }

  void addToCart({
    required ProductModel product,
    String? selectedTemperature,
    String? selectedSize,
    required double unitPrice,
    int quantity = 1,
  }) {
    if (!product.isAvailable) {
      return;
    }

    final effectiveTemp = resolveEffectiveTemperature(
      product,
      selectedTemperature,
    );

    // Generate unique ID for variant combination
    final variantKey =
        '${product.productId}_${effectiveTemp ?? 'none'}_${selectedSize ?? 'none'}';

    final existingIndex = _items.indexWhere((item) => item.id == variantKey);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(
        CartItemModel(
          id: variantKey,
          product: product,
          selectedTemperature: effectiveTemp,
          selectedSize: selectedSize,
          unitPrice: unitPrice,
          quantity: quantity,
        ),
      );
    }
    notifyListeners();
  }

  void updateQuantity(String itemId, int delta) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _items[index].quantity += delta;
      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void setItemQuantity(String itemId, int newQuantity) {
    if (newQuantity <= 0) return;
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _items[index].quantity = newQuantity;
      notifyListeners();
    }
  }

  void removeItem(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Aggregates all cart items and validates cumulative stock against branch ingredient and packaging inventory,
  /// as well as any branch-specific manual product servings quotas.
  CartValidationResult validateCartStock({
    required Map<String, RecipeModel> recipes,
    required List<InventoryItemModel> inventoryItems,
    Map<String, BranchProductServingModel>? manualServings,
    bool allowMissingRecipes = false,
  }) {
    if (_items.isEmpty) return CartValidationResult.valid;
    final effectiveManualServings = manualServings ?? _manualServings;
    if (recipes.isEmpty &&
        inventoryItems.isEmpty &&
        effectiveManualServings.isEmpty) {
      return CartValidationResult.valid;
    }

    // 1. Manual product servings quota validation
    // Aggregate all cart quantities by productId, regardless of variant.
    final Map<String, int> productCartQuantities = {};
    final Map<String, String> productNames = {};
    for (final item in _items) {
      final pId = item.product.productId;
      productCartQuantities[pId] =
          (productCartQuantities[pId] ?? 0) + item.quantity;
      productNames[pId] = item.product.name;
    }

    final List<CartManualQuotaDeficit> manualQuotaDeficits = [];
    if (effectiveManualServings.isNotEmpty) {
      for (final entry in productCartQuantities.entries) {
        final pId = entry.key;
        final requested = entry.value;

        // Lookup quota by exact productId or composite key ending in _$productId
        BranchProductServingModel? quota = effectiveManualServings[pId];
        if (quota == null) {
          for (final qEntry in effectiveManualServings.entries) {
            if (qEntry.key.endsWith('_$pId') || qEntry.value.productId == pId) {
              quota = qEntry.value;
              break;
            }
          }
        }

        // Missing quota document: preserve existing physical inventory validation.
        // Disabled quota: preserve existing physical inventory validation.
        // Enabled quota: total cart quantity must not exceed remainingServings.
        // Enabled quota with zero remaining: reject any positive cart quantity.
        if (quota != null && quota.isEnabled) {
          if (requested > quota.remainingServings) {
            manualQuotaDeficits.add(
              CartManualQuotaDeficit(
                productId: pId,
                productName: productNames[pId] ?? quota.productId,
                requestedQuantity: requested,
                remainingServings: quota.remainingServings,
              ),
            );
          }
        }
      }
    }

    final Map<String, double> aggregatedDemand = {};
    final Map<String, String> ingredientNames = {};
    final Map<String, String> ingredientUnits = {};
    final List<String> missingRecipes = [];
    final List<String> incompatibleUnits = [];
    final List<String> missingInventory = [];

    for (final cartItem in _items) {
      final recipe = _findRecipe(cartItem.product, recipes);

      if (recipe == null) {
        if (!allowMissingRecipes) {
          missingRecipes.add(cartItem.product.name);
        }
        continue;
      }

      final effectiveTemp = resolveEffectiveTemperature(
        cartItem.product,
        cartItem.selectedTemperature,
      );
      final reqs = recipe.getRequirementsForTemperature(effectiveTemp);
      if (reqs.isEmpty) {
        if (!allowMissingRecipes) {
          missingRecipes.add(
            '${cartItem.product.name} (${effectiveTemp ?? "Standard"})',
          );
        }
        continue;
      }

      for (final req in reqs) {
        if (req.quantity <= 0) continue;

        final cleanReq = req.ingredientId.trim().toLowerCase();
        final idx = _findInventoryIndex(req, inventoryItems);
        final invItem = idx >= 0 ? inventoryItems[idx] : null;

        if (invItem == null) {
          missingInventory.add(
            req.ingredientName.isNotEmpty
                ? req.ingredientName
                : req.ingredientId,
          );
          continue;
        }

        final converted = UnitConverter.convert(
          quantity: req.quantity,
          fromUnit: req.unit,
          toUnit: invItem.unit,
        );

        if (converted == null) {
          incompatibleUnits.add(
            '${invItem.name} (${req.unit} to ${invItem.unit})',
          );
          continue;
        }

        final totalNeeded = converted * cartItem.quantity;
        aggregatedDemand[cleanReq] =
            (aggregatedDemand[cleanReq] ?? 0.0) + totalNeeded;
        ingredientNames[cleanReq] = invItem.name;
        ingredientUnits[cleanReq] = invItem.unit;
      }
    }

    final List<CartStockDeficit> deficits = [];
    for (final entry in aggregatedDemand.entries) {
      final ingKey = entry.key;
      final needed = entry.value;

      InventoryItemModel? invItem;
      for (final item in inventoryItems) {
        if (item.ingredientId.toLowerCase() == ingKey ||
            item.id.toLowerCase() == ingKey ||
            item.id.toLowerCase().endsWith('_$ingKey')) {
          invItem = item;
          break;
        }
      }

      final available = invItem != null
          ? math.max(0.0, invItem.availableQuantity)
          : 0.0;
      if (needed > available) {
        deficits.add(
          CartStockDeficit(
            ingredientId: ingKey,
            ingredientName: ingredientNames[ingKey] ?? ingKey,
            requiredAmount: needed,
            availableAmount: available,
            unit: ingredientUnits[ingKey] ?? '',
          ),
        );
      }
    }

    final hasErrors =
        deficits.isNotEmpty ||
        manualQuotaDeficits.isNotEmpty ||
        missingRecipes.isNotEmpty ||
        incompatibleUnits.isNotEmpty ||
        missingInventory.isNotEmpty;

    if (!hasErrors) {
      return CartValidationResult.valid;
    }

    final errorLines = <String>[];
    if (manualQuotaDeficits.isNotEmpty) {
      errorLines.add(
        'Manual servings limit exceeded:\n• ${manualQuotaDeficits.map((d) => d.summary).join('\n• ')}',
      );
    }
    if (deficits.isNotEmpty) {
      errorLines.add(
        'Insufficient branch inventory:\n• ${deficits.map((d) => d.summary).join('\n• ')}',
      );
    }
    if (missingInventory.isNotEmpty) {
      errorLines.add(
        'Missing inventory records:\n• ${missingInventory.toSet().join('\n• ')}',
      );
    }
    if (incompatibleUnits.isNotEmpty) {
      errorLines.add(
        'Incompatible unit configurations:\n• ${incompatibleUnits.toSet().join('\n• ')}',
      );
    }
    if (missingRecipes.isNotEmpty) {
      errorLines.add(
        'Products missing recipe configuration:\n• ${missingRecipes.toSet().join('\n• ')}',
      );
    }

    return CartValidationResult(
      isValid: false,
      deficits: deficits,
      manualQuotaDeficits: manualQuotaDeficits,
      missingRecipes: missingRecipes,
      incompatibleUnits: incompatibleUnits,
      missingInventory: missingInventory,
      errorMessage: errorLines.join('\n\n'),
    );
  }
}
