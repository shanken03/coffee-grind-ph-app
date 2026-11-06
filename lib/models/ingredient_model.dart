class IngredientModel {
  final String ingredientId;
  final String name;
  final String unit;
  final String itemType; // 'ingredient' | 'packaging'
  final String status; // 'active' | 'inactive'
  final double? packageSize;
  final String? packageUnit;
  final double? targetStock;
  final double? reorderPoint;

  const IngredientModel({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.itemType,
    this.status = 'active',
    this.packageSize,
    this.packageUnit,
    this.targetStock,
    this.reorderPoint,
  });

  bool get isActive {
    final s = status.toLowerCase();
    return s == 'active' || s.isEmpty || s == 'true';
  }

  bool get isPackaging {
    final t = itemType.toLowerCase();
    return t == 'packaging' || t == 'supplies' || t == 'packaging / supplies';
  }

  bool get isIngredient {
    final t = itemType.toLowerCase();
    return t == 'ingredient' || t == 'ingredients' || !isPackaging;
  }

  factory IngredientModel.fromMap(String docId, Map<String, dynamic> map) {
    final id = map['ingredientId'] as String? ?? map['id'] as String? ?? docId;
    final name = map['name'] as String? ?? map['ingredientName'] as String? ?? map['itemName'] as String? ?? id;
    final unit = map['unit'] as String? ?? map['packageUnit'] as String? ?? 'pcs';
    final itemType = map['itemType'] as String? ?? map['category'] as String? ?? 'ingredient';
    final status = map['status'] as String? ?? ((map['isActive'] == true || map['isActive'] == null) ? 'active' : 'inactive');

    return IngredientModel(
      ingredientId: id,
      name: name,
      unit: unit,
      itemType: itemType,
      status: status,
      packageSize: (map['packageSize'] as num?)?.toDouble(),
      packageUnit: map['packageUnit'] as String?,
      targetStock: (map['targetStock'] as num?)?.toDouble(),
      reorderPoint: (map['reorderPoint'] as num?)?.toDouble(),
    );
  }
}
