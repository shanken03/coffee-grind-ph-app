/// Supported unit conversions and calculation helpers for recipes and inventory.
class UnitConverter {
  UnitConverter._();

  /// Converts [quantity] from [fromUnit] to [toUnit].
  /// Returns `null` if the units are incompatible or conversion is not explicitly supported.
  static double? convert({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    if (quantity <= 0) return 0.0;

    final from = _normalize(fromUnit);
    final to = _normalize(toUnit);

    // Identical normalized units
    if (from == to) {
      return quantity;
    }

    // Weight conversions: grams <-> kilograms
    if (_isGram(from) && _isKilogram(to)) {
      return quantity / 1000.0;
    }
    if (_isKilogram(from) && _isGram(to)) {
      return quantity * 1000.0;
    }

    // Volume conversions: milliliters <-> liters
    if (_isMilliliter(from) && _isLiter(to)) {
      return quantity / 1000.0;
    }
    if (_isLiter(from) && _isMilliliter(to)) {
      return quantity * 1000.0;
    }

    // Piece / Count conversions
    if (_isPiece(from) && _isPiece(to)) {
      return quantity;
    }

    // Incompatible units (e.g. mass to volume without density, or piece to grams)
    return null;
  }

  static String _normalize(String unit) {
    return unit.toLowerCase().trim().replaceAll('.', '').replaceAll(' ', '');
  }

  static bool _isGram(String u) {
    return u == 'g' || u == 'gram' || u == 'grams';
  }

  static bool _isKilogram(String u) {
    return u == 'kg' ||
        u == 'kilo' ||
        u == 'kilos' ||
        u == 'kilogram' ||
        u == 'kilograms';
  }

  static bool _isMilliliter(String u) {
    return u == 'ml' || u == 'milliliter' || u == 'milliliters' || u == 'milli';
  }

  static bool _isLiter(String u) {
    return u == 'l' ||
        u == 'liter' ||
        u == 'liters' ||
        u == 'litre' ||
        u == 'litres';
  }

  static bool _isPiece(String u) {
    return u == 'pc' ||
        u == 'pcs' ||
        u == 'piece' ||
        u == 'pieces' ||
        u == 'unit' ||
        u == 'units' ||
        u == 'can' ||
        u == 'cans' ||
        u == 'pack' ||
        u == 'packs' ||
        u == 'bottle' ||
        u == 'bottles' ||
        u == 'box' ||
        u == 'boxes' ||
        u == 'cup' ||
        u == 'cups' ||
        u == 'lid' ||
        u == 'lids' ||
        u == 'straw' ||
        u == 'straws' ||
        u == 'item' ||
        u == 'items';
  }
}

/// A single ingredient or packaging requirement in a product's recipe.
class RecipeIngredientRequirement {
  final String ingredientId;
  final String ingredientName;
  final double quantity;
  final String unit;
  final String temperature; // 'hot', 'iced', 'both'
  final double? unitCost;
  final String itemType; // 'ingredient' | 'packaging'

  const RecipeIngredientRequirement({
    required this.ingredientId,
    this.ingredientName = '',
    required this.quantity,
    this.unit = 'g',
    this.temperature = 'both',
    this.unitCost,
    this.itemType = 'ingredient',
  });

  bool matchesTemperature(String? selectedTemp) {
    if (selectedTemp == null || selectedTemp.trim().isEmpty) return true;
    final t = temperature.toLowerCase().trim();
    if (t.isEmpty || t == 'both' || t == 'all') return true;

    final s = selectedTemp.toLowerCase().trim();
    if (t == s) return true;
    if ((t == 'iced' || t == 'cold') && (s == 'iced' || s == 'cold')) {
      return true;
    }
    return false;
  }

  factory RecipeIngredientRequirement.fromMap(Map<String, dynamic> map) {
    final id = (map['ingredientId'] ?? map['id'] ?? '').toString().trim();
    final name = (map['name'] ?? map['ingredientName'] ?? map['itemName'] ?? '')
        .toString()
        .trim();
    final rawQty = map['quantity'] ?? map['amount'] ?? 0.0;
    final qty = rawQty is num
        ? rawQty.toDouble()
        : double.tryParse(rawQty.toString()) ?? 0.0;
    final unit = (map['unit'] ?? map['packageUnit'] ?? 'g').toString().trim();
    final temp = (map['temperature'] ?? 'both').toString().trim().toLowerCase();
    final rawCost = map['unitCost'] ?? map['cost'];
    final cost = rawCost is num
        ? rawCost.toDouble()
        : double.tryParse(rawCost?.toString() ?? '');
    final type = (map['itemType'] ?? map['category'] ?? 'ingredient')
        .toString()
        .trim()
        .toLowerCase();

    return RecipeIngredientRequirement(
      ingredientId: id,
      ingredientName: name,
      quantity: qty,
      unit: unit,
      temperature: temp.isEmpty ? 'both' : temp,
      unitCost: cost,
      itemType: type.contains('pack') || type.contains('suppl')
          ? 'packaging'
          : 'ingredient',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      'quantity': quantity,
      'unit': unit,
      'temperature': temperature,
      'unitCost': unitCost,
      'itemType': itemType,
    };
  }
}

/// A product recipe defining all ingredients and packaging required per serving.
class RecipeModel {
  final String recipeId;
  final String productId;
  final String name;
  final List<RecipeIngredientRequirement> ingredients;

  const RecipeModel({
    required this.recipeId,
    required this.productId,
    this.name = '',
    required this.ingredients,
  });

  List<RecipeIngredientRequirement> getRequirementsForTemperature(
    String? temperature,
  ) {
    return ingredients
        .where((ing) => ing.matchesTemperature(temperature))
        .toList();
  }

  factory RecipeModel.fromFirestore(String docId, Map<String, dynamic> data) {
    final pId = (data['productId'] ?? docId).toString().trim();
    final name = (data['name'] ?? data['productName'] ?? '').toString().trim();
    final rawIngredients = data['ingredients'] ?? data['items'];

    final list = <RecipeIngredientRequirement>[];

    if (rawIngredients is List) {
      for (final item in rawIngredients) {
        if (item is Map<String, dynamic>) {
          list.add(RecipeIngredientRequirement.fromMap(item));
        } else if (item is Map) {
          list.add(
            RecipeIngredientRequirement.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    } else if (rawIngredients is Map) {
      rawIngredients.forEach((key, val) {
        final ingId = key.toString();
        if (val is Map) {
          final m = Map<String, dynamic>.from(val);
          m.putIfAbsent('ingredientId', () => ingId);
          list.add(RecipeIngredientRequirement.fromMap(m));
        } else if (val is num) {
          list.add(
            RecipeIngredientRequirement(
              ingredientId: ingId,
              quantity: val.toDouble(),
              unit: 'g',
              temperature: 'both',
            ),
          );
        }
      });
    }

    return RecipeModel(
      recipeId: docId,
      productId: pId,
      name: name,
      ingredients: list,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'productId': productId,
      'name': name,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
    };
  }
}
