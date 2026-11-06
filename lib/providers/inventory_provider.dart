import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firebase_paths.dart';

class InventoryItemModel {
  final String id;
  final String ingredientId;
  final String name;
  final String category;
  final double availableQuantity;
  final String unit;
  final double minStock;
  final String branchId;

  const InventoryItemModel({
    required this.id,
    this.ingredientId = '',
    required this.name,
    required this.category,
    required this.availableQuantity,
    required this.unit,
    required this.minStock,
    required this.branchId,
  });

  bool get isLowStock => availableQuantity <= minStock;

  factory InventoryItemModel.fromMap(String id, Map<String, dynamic> map, String branchId) {
    final qty = (map['quantity'] as num?)?.toDouble() ??
        (map['availableQuantity'] as num?)?.toDouble() ??
        (map['stock'] as num?)?.toDouble() ??
        0.0;
    final minS = (map['minimumStock'] as num?)?.toDouble() ??
        (map['minStock'] as num?)?.toDouble() ??
        10.0;

    final rawIngId = (map['ingredientId'] as String? ?? '').trim();
    final ingId = rawIngId.isNotEmpty
        ? rawIngId
        : (id.startsWith('${branchId}_')
            ? id.substring('${branchId}_'.length)
            : (id.contains('_') ? id.substring(id.indexOf('_') + 1) : id));

    return InventoryItemModel(
      id: id,
      ingredientId: ingId,
      name: map['ingredientName'] as String? ?? map['name'] as String? ?? 'Item',
      category: map['itemType'] as String? ?? map['category'] as String? ?? 'Ingredient',
      availableQuantity: qty,
      unit: map['unit'] as String? ?? 'pcs',
      minStock: minS,
      branchId: map['branchId'] as String? ?? branchId,
    );
  }
}

class InventoryProvider extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  InventoryProvider({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  StreamSubscription<QuerySnapshot>? _inventorySubscription;

  List<InventoryItemModel> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentBranchId;

  List<InventoryItemModel> get items => List.unmodifiable(_items);
  List<InventoryItemModel> get lowStockItems => _items.where((i) => i.isLowStock).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  @visibleForTesting
  void setItemsForTesting(List<InventoryItemModel> testItems) {
    _items = testItems;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  InventoryItemModel? getItemByIngredientId(String ingredientId) {
    final clean = ingredientId.trim().toLowerCase();
    for (final item in _items) {
      if (item.ingredientId.toLowerCase() == clean ||
          item.id.toLowerCase() == clean ||
          item.id.toLowerCase().endsWith('_$clean')) {
        return item;
      }
    }
    return null;
  }

  void bindToBranch(String branchId) {
    final cleanBranchId = branchId.trim();
    if (cleanBranchId.isEmpty) return;
    if (_currentBranchId == cleanBranchId &&
        _inventorySubscription != null &&
        _errorMessage == null) {
      return;
    }
    _inventorySubscription?.cancel();
    _inventorySubscription = null;
    _currentBranchId = cleanBranchId;
    _errorMessage = null;
    _listenToInventory(cleanBranchId);
  }

  void _listenToInventory(String branchId) {
    _inventorySubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanBranchId = branchId.trim();

      _inventorySubscription = _firestore
          .collection(FirebasePaths.inventory)
          .where('branchId', isEqualTo: cleanBranchId)
          .snapshots()
          .listen((snapshot) {
        final loaded = snapshot.docs
            .map((doc) => InventoryItemModel.fromMap(doc.id, doc.data(), cleanBranchId))
            .toList();

        _items = loaded;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      }, onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      });
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    super.dispose();
  }
}
