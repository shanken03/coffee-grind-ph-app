import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class CartValidationResult {
  final bool isValid;
  final List<CartStockDeficit> deficits;
  final List<String> missingRecipes;
  final List<String> incompatibleUnits;
  final List<String> missingInventory;
  final String? errorMessage;

  const CartValidationResult({
    required this.isValid,
    this.deficits = const [],
    this.missingRecipes = const [],
    this.incompatibleUnits = const [],
    this.missingInventory = const [],
    this.errorMessage,
  });

  static const valid = CartValidationResult(isValid: true);
}

class PosCartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

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

    final effectiveTemp = selectedTemperature ?? product.fixedTemperature;

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

  /// Aggregates all cart items and validates cumulative stock against branch ingredient and packaging inventory.
  CartValidationResult validateCartStock({
    required Map<String, RecipeModel> recipes,
    required List<InventoryItemModel> inventoryItems,
    bool allowMissingRecipes = false,
  }) {
    if (_items.isEmpty) return CartValidationResult.valid;
    if (recipes.isEmpty && inventoryItems.isEmpty) {
      return CartValidationResult.valid;
    }

    final Map<String, double> aggregatedDemand = {};
    final Map<String, String> ingredientNames = {};
    final Map<String, String> ingredientUnits = {};
    final List<String> missingRecipes = [];
    final List<String> incompatibleUnits = [];
    final List<String> missingInventory = [];

    for (final cartItem in _items) {
      final pId = cartItem.product.productId;
      RecipeModel? recipe =
          recipes[pId] ??
          (cartItem.product.recipeId != null
              ? recipes[cartItem.product.recipeId]
              : null);

      if (recipe == null) {
        final cleanPId = pId.toLowerCase().trim();
        for (final r in recipes.values) {
          if (r.productId.toLowerCase().trim() == cleanPId ||
              r.recipeId.toLowerCase().trim() == cleanPId ||
              r.name.toLowerCase().trim() ==
                  cartItem.product.name.toLowerCase().trim()) {
            recipe = r;
            break;
          }
        }
      }

      if (recipe == null) {
        if (!allowMissingRecipes) {
          missingRecipes.add(cartItem.product.name);
        }
        continue;
      }

      final effectiveTemp =
          cartItem.selectedTemperature ?? cartItem.product.fixedTemperature;
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
        InventoryItemModel? invItem;
        for (final item in inventoryItems) {
          if (item.ingredientId.toLowerCase() == cleanReq ||
              item.id.toLowerCase() == cleanReq ||
              item.id.toLowerCase().endsWith('_$cleanReq')) {
            invItem = item;
            break;
          }
        }

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
        missingRecipes.isNotEmpty ||
        incompatibleUnits.isNotEmpty ||
        missingInventory.isNotEmpty;

    if (!hasErrors) {
      return CartValidationResult.valid;
    }

    final errorLines = <String>[];
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
      missingRecipes: missingRecipes,
      incompatibleUnits: incompatibleUnits,
      missingInventory: missingInventory,
      errorMessage: errorLines.join('\n\n'),
    );
  }
}
