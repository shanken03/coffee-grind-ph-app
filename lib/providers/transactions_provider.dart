import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_paths.dart';
import '../models/transaction_model.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../models/recipe_model.dart';
import '../services/inventory_resolver.dart';

class TransactionsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final InventoryDocumentResolver _resolver;
  StreamSubscription<QuerySnapshot>? _salesSubscription;

  TransactionsProvider({
    FirebaseFirestore? firestore,
    InventoryDocumentResolver? resolver,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _resolver =
           resolver ??
           InventoryDocumentResolver(
             firestore: firestore ?? FirebaseFirestore.instance,
           );

  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String? _currentBranchId;

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;

  double get todaySales {
    final now = DateTime.now();
    return _transactions
        .where((t) {
          return t.timestamp.year == now.year &&
              t.timestamp.month == now.month &&
              t.timestamp.day == now.day;
        })
        .fold(0.0, (acc, t) => acc + t.totalAmount);
  }

  int get todayTransactionCount {
    final now = DateTime.now();
    return _transactions.where((t) {
      return t.timestamp.year == now.year &&
          t.timestamp.month == now.month &&
          t.timestamp.day == now.day;
    }).length;
  }

  void bindToBranch(String branchId) {
    if (_currentBranchId == branchId && _salesSubscription != null) return;
    _currentBranchId = branchId;
    _listenToSales(branchId);
  }

  TransactionModel _mapDocToTransaction(
    String docId,
    Map<String, dynamic> data,
  ) {
    final rawItems = data['items'] as List? ?? [];
    final items = rawItems.map((itemMap) {
      final m = itemMap as Map<String, dynamic>;
      final pName = m['productName'] as String? ?? m['name'] as String? ?? '';
      final pId = m['productId'] as String? ?? '';
      final uPrice =
          (m['price'] as num?)?.toDouble() ??
          (m['unitPrice'] as num?)?.toDouble() ??
          0.0;
      final q = (m['quantity'] as num?)?.toInt() ?? 1;

      return CartItemModel(
        id: m['id'] as String? ?? docId,
        product: ProductModel(
          productId: pId,
          name: pName,
          category: ProductCategory.coffee,
          description: '',
          imageUrl: '',
          isActive: true,
          availableBranches: [],
          pricing: ProductPricing(flatPrice: uPrice),
        ),
        selectedTemperature: m['selectedTemperature'] as String?,
        selectedSize: m['selectedSize'] as String?,
        unitPrice: uPrice,
        quantity: q,
      );
    }).toList();

    DateTime ts = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      ts = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    }

    return TransactionModel(
      transactionId: data['saleId'] as String? ?? docId,
      timestamp: ts,
      branchName: data['branchName'] as String? ?? '',
      items: items,
      totalAmount: (data['total'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'Completed',
      paymentMethod: data['paymentMethod'] as String? ?? 'Cash',
      gcashReference: data['gcashReference'] as String? ?? data['gcash_reference'] as String?,
      cogs: (data['cogs'] as num?)?.toDouble(),
      grossProfit: (data['grossProfit'] as num?)?.toDouble(),
      otherExpenses: (data['otherExpenses'] as num?)?.toDouble(),
      netProfit: (data['netProfit'] as num?)?.toDouble(),
    );
  }

  void _listenToSales(String branchId) {
    _salesSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    try {
      final cleanBranchId = branchId.trim();
      _salesSubscription = _firestore
          .collection(FirebasePaths.sales)
          .where('branchId', isEqualTo: cleanBranchId)
          .snapshots()
          .listen(
            (snapshot) {
              final loaded =
                  snapshot.docs
                      .map((doc) => _mapDocToTransaction(doc.id, doc.data()))
                      .toList()
                    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              _transactions = loaded;
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

  Future<TransactionModel> addTransaction({
    required String branchId,
    required String branchName,
    required List<CartItemModel> items,
    required double totalAmount,
    required String paymentMethod,
    String? gcashReference,
    String cashierId = 'STAFF_DEVICE',
    String cashierName = 'Store Staff',
    String? clientSaleId,
  }) async {
    // 1. Idempotency Check: if clientSaleId is provided, check if transaction already exists
    if (clientSaleId != null && clientSaleId.isNotEmpty) {
      final existingSale = await _firestore
          .collection(FirebasePaths.sales)
          .where('branchId', isEqualTo: branchId)
          .where('clientSaleId', isEqualTo: clientSaleId)
          .limit(1)
          .get();

      if (existingSale.docs.isNotEmpty) {
        final existingDoc = existingSale.docs.first;
        final tx = _mapDocToTransaction(existingDoc.id, existingDoc.data());
        final existingIndex = _transactions.indexWhere(
          (t) => t.transactionId == tx.transactionId,
        );
        if (existingIndex < 0) {
          _transactions.insert(0, tx);
          notifyListeners();
        }
        return tx;
      }
    }

    final saleId = (clientSaleId != null && clientSaleId.isNotEmpty)
        ? clientSaleId
        : 'SALE-${DateTime.now().millisecondsSinceEpoch}';
    final docRef = _firestore.collection(FirebasePaths.sales).doc(saleId);

    final itemsMap = items.map((i) {
      final effectiveTemp = i.selectedTemperature ?? i.product.fixedTemperature;
      return {
        'productId': i.product.productId,
        'productName': i.product.name,
        'name': i.product.name,
        'category': i.product.displayCategory,
        'selectedTemperature': effectiveTemp,
        'selectedSize': i.selectedSize,
        'price': i.unitPrice,
        'unitPrice': i.unitPrice,
        'quantity': i.quantity,
        'subtotal': i.subtotal,
      };
    }).toList();

    // 2. Resolve Recipe requirements and calculate deductions & COGS
    final Map<String, double> requiredDeductions = {};
    final Map<String, String> ingredientNames = {};
    final Map<String, String> ingredientUnits = {};
    final Map<String, DocumentReference> resolvedDocRefs = {};
    double totalCogs = 0.0;
    bool hasCompleteCostData = true;

    for (final item in items) {
      final pId = item.product.productId;
      DocumentSnapshot recipeDoc = await _firestore
          .collection(FirebasePaths.recipes)
          .doc(pId)
          .get();
      if (!recipeDoc.exists &&
          item.product.recipeId != null &&
          item.product.recipeId!.isNotEmpty) {
        recipeDoc = await _firestore
            .collection(FirebasePaths.recipes)
            .doc(item.product.recipeId!)
            .get();
      }
      if (!recipeDoc.exists) {
        final querySnap = await _firestore
            .collection(FirebasePaths.recipes)
            .where('productId', isEqualTo: pId)
            .limit(1)
            .get();
        if (querySnap.docs.isNotEmpty) {
          recipeDoc = querySnap.docs.first;
        }
      }
      if (!recipeDoc.exists) {
        final querySnapLower = await _firestore
            .collection(FirebasePaths.recipes)
            .where('productId', isEqualTo: pId.toLowerCase())
            .limit(1)
            .get();
        if (querySnapLower.docs.isNotEmpty) {
          recipeDoc = querySnapLower.docs.first;
        }
      }
      if (!recipeDoc.exists) {
        final cleanName = item.product.name.toLowerCase().replaceAll(' ', '_');
        final byNameDoc = await _firestore
            .collection(FirebasePaths.recipes)
            .doc('rec_$cleanName')
            .get();
        if (byNameDoc.exists) {
          recipeDoc = byNameDoc;
        } else {
          final queryByName = await _firestore
              .collection(FirebasePaths.recipes)
              .where('name', isEqualTo: item.product.name)
              .limit(1)
              .get();
          if (queryByName.docs.isNotEmpty) {
            recipeDoc = queryByName.docs.first;
          }
        }
      }

      if (!recipeDoc.exists || recipeDoc.data() == null) {
        throw Exception(
          'Cannot complete sale: Missing recipe configuration for "${item.product.name}"',
        );
      }

      final recipe = RecipeModel.fromFirestore(
        recipeDoc.id,
        recipeDoc.data() as Map<String, dynamic>,
      );
      final effectiveTemp =
          item.selectedTemperature ?? item.product.fixedTemperature;
      final reqs = recipe.getRequirementsForTemperature(effectiveTemp);
      if (reqs.isEmpty) {
        throw Exception(
          'Cannot complete sale: No recipe requirements configured for "${item.product.name}" (${effectiveTemp ?? 'Standard'})',
        );
      }

      for (final req in reqs) {
        if (req.quantity <= 0) continue;

        // Fetch corresponding inventory item for this branch (resolved uniquely)
        if (!resolvedDocRefs.containsKey(req.ingredientId)) {
          final resolvedDoc = await _resolver.resolve(
            branchId: branchId,
            ingredientId: req.ingredientId,
            ingredientName: req.ingredientName,
            branchName: branchName,
          );

          final invData = resolvedDoc.data ?? {};
          final invUnit = (invData['unit'] as String? ?? req.unit).trim();
          final invName =
              (invData['ingredientName'] as String? ??
                      invData['name'] as String? ??
                      req.ingredientName)
                  .trim();

          ingredientNames[req.ingredientId] = invName;
          ingredientUnits[req.ingredientId] = invUnit;
          resolvedDocRefs[req.ingredientId] = resolvedDoc.reference;
        }

        final invUnit = ingredientUnits[req.ingredientId]!;
        final invName = ingredientNames[req.ingredientId]!;

        // Convert recipe unit to inventory unit
        final converted = UnitConverter.convert(
          quantity: req.quantity,
          fromUnit: req.unit,
          toUnit: invUnit,
        );

        if (converted == null) {
          throw Exception(
            'Cannot complete sale: Incompatible units for "$invName" (Recipe: ${req.unit}, Inventory: $invUnit)',
          );
        }

        final totalNeeded = converted * item.quantity;
        requiredDeductions[req.ingredientId] =
            (requiredDeductions[req.ingredientId] ?? 0.0) + totalNeeded;

        if (req.unitCost != null && req.unitCost! > 0) {
          totalCogs += totalNeeded * req.unitCost!;
        } else {
          hasCompleteCostData = false;
        }
      }
    }

    final double? finalCogs = (hasCompleteCostData && totalCogs > 0)
        ? totalCogs
        : null;
    final double? grossProfit = finalCogs != null
        ? totalAmount - finalCogs
        : null;
    const double otherExpenses = 0.0;
    final double? netProfit = grossProfit != null
        ? grossProfit - otherExpenses
        : null;

    final saleData = <String, dynamic>{
      'saleId': saleId,
      'transactionId': saleId,
      'clientSaleId': clientSaleId ?? saleId,
      'branchId': branchId,
      'branchName': branchName,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'employeeId': cashierId,
      'employeeName': cashierName,
      'items': itemsMap,
      'subtotal': totalAmount,
      'total': totalAmount,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      if (paymentMethod == 'GCash' &&
          gcashReference != null &&
          gcashReference.trim().isNotEmpty) ...{
        'gcashReference': gcashReference.trim(),
        'gcash_reference': gcashReference.trim(),
      },
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'Completed',
      'inventoryDeducted': true,
      'inventoryDeductedAt': FieldValue.serverTimestamp(),
    };

    if (finalCogs != null) {
      saleData['cogs'] = finalCogs;
      saleData['grossProfit'] = grossProfit;
      saleData['otherExpenses'] = otherExpenses;
      saleData['netProfit'] = netProfit;
    }

    // 3. Safe Atomic Execution via Firestore Transaction
    final committedTx = await _firestore.runTransaction<TransactionModel>((
      transaction,
    ) async {
      // Step A: Transaction-safe idempotency check (Read sale document inside transaction)
      final saleSnapshot = await transaction.get(docRef);
      if (saleSnapshot.exists && saleSnapshot.data() != null) {
        final existingData = saleSnapshot.data() as Map<String, dynamic>;
        return _mapDocToTransaction(saleSnapshot.id, existingData);
      }

      // Step B: Read all resolved inventory documents inside transaction
      final Map<String, double> currentInventoryStock = {};
      for (final ingId in requiredDeductions.keys) {
        final invRef = resolvedDocRefs[ingId]!;
        final invSnapshot = await transaction.get(invRef);

        if (!invSnapshot.exists || invSnapshot.data() == null) {
          final ingName = ingredientNames[ingId] ?? ingId;
          throw Exception(
            'Cannot complete sale: Missing inventory record for "$ingName".',
          );
        }

        final data = invSnapshot.data() as Map<String, dynamic>;
        final qty =
            (data['quantity'] as num?)?.toDouble() ??
            (data['availableQuantity'] as num?)?.toDouble() ??
            (data['stock'] as num?)?.toDouble() ??
            0.0;
        currentInventoryStock[ingId] = qty;
      }

      // Step C: Validate physical inventory stock sufficiency
      for (final entry in requiredDeductions.entries) {
        final ingId = entry.key;
        final needed = entry.value;
        final current = currentInventoryStock[ingId] ?? 0.0;
        if (current < needed) {
          final ingName = ingredientNames[ingId] ?? ingId;
          final unit = ingredientUnits[ingId] ?? '';
          throw Exception(
            'Insufficient branch stock for "$ingName": required ${needed.toStringAsFixed(1)} $unit, but only ${current.toStringAsFixed(1)} $unit available',
          );
        }
      }

      // --- ALL READS & VALIDATIONS COMPLETE; PERFORM ALL ATOMIC WRITES ---

      // Step D: Write complete sale record
      transaction.set(docRef, saleData);

      // Step E: Decrement branch inventory & write audit logs
      for (final entry in requiredDeductions.entries) {
        final ingId = entry.key;
        final deductQty = entry.value;
        final invRef = resolvedDocRefs[ingId]!;
        final currentStock = currentInventoryStock[ingId]!;
        final newStock = currentStock - deductQty;
        final ingName = ingredientNames[ingId] ?? ingId;
        final unit = ingredientUnits[ingId] ?? '';

        transaction.update(invRef, {
          'quantity': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        final auditRef = _firestore
            .collection(FirebasePaths.inventoryTransactions)
            .doc();
        transaction.set(auditRef, {
          'transactionId': auditRef.id,
          'branchId': branchId,
          'ingredientId': ingId,
          'ingredientName': ingName,
          'type': 'sale',
          'change': -deductQty,
          'previousQuantity': currentStock,
          'newQuantity': newStock,
          'unit': unit,
          'saleId': saleId,
          'referenceId': saleId,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'notes': 'POS Sale deduction ($saleId)',
        });
      }

      return TransactionModel(
        transactionId: saleId,
        timestamp: DateTime.now(),
        branchName: branchName,
        items: items,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        gcashReference: gcashReference?.trim(),
        status: 'Completed',
        cogs: finalCogs,
        grossProfit: grossProfit,
        otherExpenses: otherExpenses,
        netProfit: netProfit,
      );
    });

    final existingIndex = _transactions.indexWhere(
      (t) => t.transactionId == committedTx.transactionId,
    );
    if (existingIndex >= 0) {
      _transactions[existingIndex] = committedTx;
    } else {
      _transactions.insert(0, committedTx);
    }
    notifyListeners();
    return committedTx;
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    super.dispose();
  }
}
