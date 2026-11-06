enum ProductCategory { coffee, nonCoffee, frappe, refreshers, foods, sweets }

extension ProductCategoryX on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.coffee:
        return 'Coffee';
      case ProductCategory.nonCoffee:
        return 'Non Coffee';
      case ProductCategory.frappe:
        return 'Frappe';
      case ProductCategory.refreshers:
        return 'Refreshers';
      case ProductCategory.foods:
        return 'Foods';
      case ProductCategory.sweets:
        return 'Sweets';
    }
  }

  static ProductCategory fromString(String value) {
    final clean = value.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
    if (clean.contains('noncoffee')) return ProductCategory.nonCoffee;
    if (clean.contains('coffee')) return ProductCategory.coffee;
    if (clean.contains('frappe')) return ProductCategory.frappe;
    if (clean.contains('refresher')) return ProductCategory.refreshers;
    if (clean.contains('food') || clean.contains('meal')) return ProductCategory.foods;
    if (clean.contains('sweet') ||
        clean.contains('pastr') ||
        clean.contains('dessert') ||
        clean.contains('cookie') ||
        clean.contains('cake') ||
        clean.contains('muffin')) {
      return ProductCategory.sweets;
    }
    return ProductCategory.coffee;
  }
}

/// Handles all pricing shapes the Owner Web and Firestore menu uses:
/// - flat: single price (Frappe, Refreshers, Foods, Sweets, or general price)
/// - sizePrices: Small/Medium/Large prices (parsed from top-level `prices` map or `pricing.sizePrices` or `smallPrice`/`mediumPrice`/`largePrice`)
/// - hotPrice/icedPrice: Coffee & beverage hot/iced pricing
/// Any price not yet known stays null — never invented.
class ProductPricing {
  final double? flatPrice;
  final Map<String, double?>? sizePrices; // keys: 'small','medium','large'
  final double? hotPrice;
  final double? icedPrice;
  final Map<String, double?>? hotSizePrices;
  final Map<String, double?>? icedSizePrices;

  const ProductPricing({
    this.flatPrice,
    this.sizePrices,
    this.hotPrice,
    this.icedPrice,
    this.hotSizePrices,
    this.icedSizePrices,
  });

  factory ProductPricing.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProductPricing();
    return ProductPricing(
      flatPrice: (map['flatPrice'] as num?)?.toDouble() ?? (map['price'] as num?)?.toDouble(),
      sizePrices: _sizeMap(map['sizePrices'] ?? map['prices']),
      hotPrice: (map['hotPrice'] as num?)?.toDouble(),
      icedPrice: (map['icedPrice'] as num?)?.toDouble(),
      hotSizePrices: _sizeMap(map['hotSizePrices']),
      icedSizePrices: _sizeMap(map['icedSizePrices']),
    );
  }

  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim());
    return null;
  }

  /// Parses Firestore document data directly, handling top-level and nested pricing structures.
  factory ProductPricing.fromFirestore(Map<String, dynamic> map) {
    final pricingMap = map['pricing'] is Map<String, dynamic> ? map['pricing'] as Map<String, dynamic> : null;

    final flatPrice = _toDouble(map['price']) ??
        _toDouble(map['flatPrice']) ??
        _toDouble(map['regularPrice']) ??
        _toDouble(map['basePrice']) ??
        _toDouble(pricingMap?['flatPrice']) ??
        _toDouble(pricingMap?['price']) ??
        _toDouble(pricingMap?['regularPrice']) ??
        _toDouble(pricingMap?['basePrice']);

    final hotPrice = _toDouble(map['hotPrice']) ??
        _toDouble(pricingMap?['hotPrice']);
    final icedPrice = _toDouble(map['icedPrice']) ??
        _toDouble(pricingMap?['icedPrice']);

    // Parse size prices from 'prices' map or 'pricing.sizePrices'
    Map<String, double?>? sizePrices;
    final rawPrices = map['prices'] ?? pricingMap?['sizePrices'] ?? pricingMap?['prices'];
    if (rawPrices is Map) {
      sizePrices = {};
      rawPrices.forEach((k, v) {
        final parsed = _toDouble(v);
        if (parsed != null) {
          sizePrices![k.toString().toLowerCase()] = parsed;
        }
      });
    }

    // Top-level individual size price fields
    final sPrice = _toDouble(map['smallPrice']);
    final mPrice = _toDouble(map['mediumPrice']);
    final lPrice = _toDouble(map['largePrice']);
    if (sPrice != null || mPrice != null || lPrice != null) {
      sizePrices ??= {};
      if (sPrice != null) sizePrices['small'] = sPrice;
      if (mPrice != null) sizePrices['medium'] = mPrice;
      if (lPrice != null) sizePrices['large'] = lPrice;
    }

    return ProductPricing(
      flatPrice: flatPrice,
      sizePrices: sizePrices != null && sizePrices.isNotEmpty ? sizePrices : null,
      hotPrice: hotPrice,
      icedPrice: icedPrice,
      hotSizePrices: _sizeMap(pricingMap?['hotSizePrices']),
      icedSizePrices: _sizeMap(pricingMap?['icedSizePrices']),
    );
  }

  static Map<String, double?>? _sizeMap(dynamic raw) {
    if (raw == null) return null;
    final m = Map<String, dynamic>.from(raw as Map);
    return m.map((k, v) => MapEntry(k.toString().toLowerCase(), (v as num?)?.toDouble()));
  }

  Map<String, dynamic> toMap() {
    return {
      'flatPrice': flatPrice,
      'sizePrices': sizePrices,
      'hotPrice': hotPrice,
      'icedPrice': icedPrice,
      'hotSizePrices': hotSizePrices,
      'icedSizePrices': icedSizePrices,
    };
  }

  double get regularPrice {
    if (flatPrice != null && flatPrice! > 0) {
      return flatPrice!;
    }
    if (sizePrices != null && sizePrices!.isNotEmpty) {
      final valid = sizePrices!.values.whereType<double>().where((p) => p > 0);
      if (valid.isNotEmpty) {
        return sizePrices!['medium'] ?? sizePrices!['regular'] ?? valid.first;
      }
    }
    if (icedPrice != null && icedPrice! > 0) {
      return icedPrice!;
    }
    if (hotPrice != null && hotPrice! > 0) {
      return hotPrice!;
    }
    return 0.0;
  }

  bool get requiresSizeSelection => false;

  bool get requiresTemperatureSelection => hotPrice != null || icedPrice != null;

  /// Returns sorted list of available size names (e.g. ['Small', 'Medium', 'Large']) with valid prices.
  List<String> get availableSizes {
    if (sizePrices == null || sizePrices!.isEmpty) return const [];
    final list = <String>[];
    for (final key in ['small', 'medium', 'large']) {
      if (sizePrices!.containsKey(key) && sizePrices![key] != null) {
        list.add(key[0].toUpperCase() + key.substring(1));
      }
    }
    for (final k in sizePrices!.keys) {
      final cap = k[0].toUpperCase() + k.substring(1);
      if (!list.contains(cap) && sizePrices![k] != null) {
        list.add(cap);
      }
    }
    return list;
  }
}

class ProductModel {
  final String productId;
  final String name;
  final ProductCategory category;
  final String categoryName;
  final String description;
  final String imageUrl;
  final bool isAvailable;
  bool get isActive => isAvailable; // Backward-compatible alias
  final List<String> availableBranches;
  final ProductPricing pricing;
  final String? recipeId;

  /// Whether this product's category and pricing configuration support Hot/Iced options.
  /// Only Coffee and Non-Coffee with both valid Hot and Iced pricing support temperature options.
  /// Frappe, Refreshers, Foods, and Sweets never support Hot/Iced by default.
  bool get supportsTemperatureOptions {
    if (category != ProductCategory.coffee && category != ProductCategory.nonCoffee) {
      return false;
    }
    final p = pricing;
    final hasValidHot = p.hotPrice != null && p.hotPrice! > 0;
    final hasValidIced = p.icedPrice != null && p.icedPrice! > 0;
    return hasValidHot && hasValidIced;
  }

  /// Whether this product is an iced/cold-only beverage that does not support hot preparation.
  /// Frappe and Refreshers are always cold-only.
  /// Coffee and Non-Coffee with iced pricing but no hot pricing are also cold-only.
  bool get isColdOnly {
    if (category == ProductCategory.frappe || category == ProductCategory.refreshers) {
      return true;
    }
    if (category == ProductCategory.coffee || category == ProductCategory.nonCoffee) {
      final p = pricing;
      final hasValidHot = p.hotPrice != null && p.hotPrice! > 0;
      final hasValidIced = p.icedPrice != null && p.icedPrice! > 0;
      return hasValidIced && !hasValidHot;
    }
    return false;
  }

  /// Whether this product is a hot-only beverage that does not support iced preparation.
  bool get isHotOnly {
    if (category == ProductCategory.coffee || category == ProductCategory.nonCoffee) {
      final p = pricing;
      final hasValidHot = p.hotPrice != null && p.hotPrice! > 0;
      final hasValidIced = p.icedPrice != null && p.icedPrice! > 0;
      return hasValidHot && !hasValidIced;
    }
    return false;
  }

  /// Fixed single temperature for products that only support one preparation.
  /// Returns 'Iced' for cold-only drinks, 'Hot' for hot-only drinks, or null otherwise.
  String? get fixedTemperature {
    if (isColdOnly) return 'Iced';
    if (isHotOnly) return 'Hot';
    return null;
  }

  /// The initial temperature to use when selecting or adding this product.
  /// Returns 'Iced' for dual-temperature drinks and cold-only drinks.
  /// Returns 'Hot' for hot-only drinks.
  /// Returns null for foods, sweets, and items without beverage temperature options.
  String? get initialTemperature {
    if (supportsTemperatureOptions || isColdOnly) return 'Iced';
    if (isHotOnly) return 'Hot';
    return null;
  }

  const ProductModel({
    required this.productId,
    required this.name,
    required this.category,
    this.categoryName = '',
    required this.description,
    required this.imageUrl,
    bool isAvailable = true,
    bool? isActive,
    required this.availableBranches,
    required this.pricing,
    this.recipeId,
  }) : isAvailable = isActive ?? isAvailable;

  String get displayCategory {
    if (categoryName.isNotEmpty) {
      final lower = categoryName.toLowerCase().trim();
      if (lower == 'coffee') return 'Coffee Series';
      if (lower == 'non coffee' || lower == 'non-coffee' || lower == 'noncoffee') return 'Non Coffee Series';
      if (lower == 'frappe' || lower == 'frappes') return 'Frappe';
      if (lower == 'refreshers' || lower == 'refresher') return 'Refreshers';
      if (lower == 'foods' || lower == 'food') return 'Foods';
      if (lower == 'sweets' || lower == 'sweet') return 'Sweets';
      return categoryName;
    }
    switch (category) {
      case ProductCategory.coffee:
        return 'Coffee Series';
      case ProductCategory.nonCoffee:
        return 'Non Coffee Series';
      case ProductCategory.frappe:
        return 'Frappe';
      case ProductCategory.refreshers:
        return 'Refreshers';
      case ProductCategory.foods:
        return 'Foods';
      case ProductCategory.sweets:
        return 'Sweets';
    }
  }

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    // 1. Comprehensive availability parsing respecting Owner Web and legacy fields
    bool? availableBool;
    if (map['isAvailable'] is bool) {
      availableBool = map['isAvailable'] as bool;
    } else if (map['available'] is bool) {
      availableBool = map['available'] as bool;
    } else if (map['isActive'] is bool) {
      availableBool = map['isActive'] as bool;
    } else if (map['active'] is bool) {
      availableBool = map['active'] as bool;
    } else if (map['availability'] is bool) {
      availableBool = map['availability'] as bool;
    }

    final statusStr = (map['status'] as String? ?? map['availability'] as String? ?? '').toLowerCase().trim();
    if (availableBool == null) {
      if (statusStr.isNotEmpty) {
        if (statusStr == 'unavailable' ||
            statusStr == 'inactive' ||
            statusStr == 'disabled' ||
            statusStr == 'archived' ||
            statusStr == 'out_of_stock' ||
            statusStr == 'out-of-stock') {
          availableBool = false;
        } else if (statusStr == 'available' ||
            statusStr == 'active' ||
            statusStr == 'published' ||
            statusStr == 'in_stock') {
          availableBool = true;
        }
      }
    }

    // Default to true if no availability flag exists (backward compatibility)
    final isAvailableVal = availableBool ?? true;

    final rawCat = (map['category'] as String? ?? 'Coffee').trim();
    final categoryEnum = ProductCategoryX.fromString(rawCat);

    // Support both 'imageUrl' and 'image_url' fields from Firestore
    final rawImg = map['imageUrl'] as String? ?? map['image_url'] as String? ?? '';
    final imageUrl = rawImg.trim();

    // Use comprehensive pricing parser
    final pricingObj = ProductPricing.fromFirestore(map);

    final rawBranches = map['availableBranches'] as List? ?? [];
    final branches = rawBranches.map((e) => e.toString().trim()).toList();

    return ProductModel(
      productId: map['productId'] as String? ?? id,
      name: (map['name'] as String? ?? '').trim(),
      category: categoryEnum,
      categoryName: rawCat,
      description: (map['description'] as String? ?? '').trim(),
      imageUrl: imageUrl,
      isAvailable: isAvailableVal,
      availableBranches: branches,
      pricing: pricingObj,
      recipeId: map['recipeId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'category': categoryName,
      'description': description,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'isAvailable': isAvailable,
      'available': isAvailable,
      'isActive': isAvailable,
      'active': isAvailable,
      'status': isAvailable ? 'active' : 'inactive',
      'availableBranches': availableBranches,
      'pricing': pricing.toMap(),
      'price': pricing.flatPrice,
      'regularPrice': pricing.regularPrice,
      'hotPrice': pricing.hotPrice,
      'icedPrice': pricing.icedPrice,
      'prices': pricing.sizePrices,
      'recipeId': recipeId,
    };
  }
}