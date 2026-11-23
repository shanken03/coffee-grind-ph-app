import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_paths.dart';
import '../models/branch_product_serving_model.dart';
import '../models/pending_offline_order.dart';
import '../models/quota_transaction_model.dart';
import '../models/transaction_model.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../models/recipe_model.dart';
import '../services/inventory_resolver.dart';
import '../services/offline_order_queue_service.dart';

class TransactionsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final InventoryDocumentResolver _resolver;
  final OfflineOrderStorage _offlineStorage;
  final Future<bool> Function()? _onlineChecker;

  StreamSubscription<QuerySnapshot>? _salesSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  TransactionsProvider({
    FirebaseFirestore? firestore,
    InventoryDocumentResolver? resolver,
    OfflineOrderStorage? offlineStorage,
    Future<bool> Function()? checkIsOnline,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _resolver =
           resolver ??
           InventoryDocumentResolver(
             firestore: firestore ?? FirebaseFirestore.instance,
           ),
       _offlineStorage = offlineStorage ?? FileOfflineOrderStorage(),
       _onlineChecker = checkIsOnline {
    _initConnectivityListener();
  }

  List<TransactionModel> _transactions = [];
  List<PendingOfflineOrder> _pendingOrders = [];
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isSyncingOffline = false;
  String? _currentBranchId;

  List<TransactionModel> get transactions {
    final syncedIds = _transactions.map((t) => t.transactionId).toSet();
    final pendingTx = _pendingOrders
        .where((o) => !syncedIds.contains(o.clientSaleId))
        .map((o) => o.toTransactionModel())
        .toList();
    final merged = [...pendingTx, ..._transactions]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(merged);
  }

  List<PendingOfflineOrder> get pendingOfflineOrders =>
      List.unmodifiable(_pendingOrders);
  int get pendingOfflineCount => _pendingOrders.length;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get isSyncingOffline => _isSyncingOffline;

  double get todaySales {
    final now = DateTime.now();
    return transactions
        .where((t) {
          return t.timestamp.year == now.year &&
              t.timestamp.month == now.month &&
              t.timestamp.day == now.day;
        })
        .fold(0.0, (acc, t) => acc + t.totalAmount);
  }

  int get todayTransactionCount {
    final now = DateTime.now();
    return transactions.where((t) {
      return t.timestamp.year == now.year &&
          t.timestamp.month == now.month &&
          t.timestamp.day == now.day;
    }).length;
  }

  void _initConnectivityListener() {
    if (_onlineChecker != null) return;
    try {
      // Ensure Flutter bindings are initialized before registering platform
      // stream listeners (plain Dart unit tests run without bindings).
      WidgetsBinding.instance;
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (results) {
          final hasNetwork =
              results.isNotEmpty &&
              results.any((r) => r != ConnectivityResult.none);
          final wasOffline = _isOffline;
          _isOffline = !hasNetwork;
          if (wasOffline != _isOffline) {
            notifyListeners();
          }
          if (hasNetwork && _pendingOrders.isNotEmpty) {
            unawaited(syncPendingOrders());
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Ignore in unit test environments without platform channels
    }
  }

  Future<bool> _isNetworkAvailable() async {
    if (_onlineChecker != null) {
      final online = await _onlineChecker();
      _isOffline = !online;
      return online;
    }
    try {
      final results = await Connectivity().checkConnectivity();
      final online =
          results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      _isOffline = !online;
      return online;
    } catch (_) {
      // Fallback to online in unit tests where connectivity plugin is unavailable
      return true;
    }
  }

  bool _isConnectivityError(Object error) {
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'network-request-failed') {
        return true;
      }
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('offline') ||
        msg.contains('unavailable') ||
        msg.contains('network-request-failed') ||
        msg.contains('socketexception') ||
        msg.contains('failed to get document');
  }

  Future<void> bindToBranch(String branchId) async {
    if (_currentBranchId == branchId && _salesSubscription != null) return;
    _currentBranchId = branchId;
    _pendingOrders = await _offlineStorage.load(branchId);
    _listenToSales(branchId);

    if (_pendingOrders.isNotEmpty && await _isNetworkAvailable()) {
      unawaited(syncPendingOrders());
    }
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

    Map<String, int> manualOverdrafts = {};
    if (data['manualQuotaOverdrafts'] is Map) {
      final rawMap = data['manualQuotaOverdrafts'] as Map;
      manualOverdrafts = rawMap.map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      );
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
      hasManualQuotaOverdraft: data['hasManualQuotaOverdraft'] as bool? ?? false,
      manualQuotaOverdrafts: manualOverdrafts,
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
    DateTime? orderTimestamp,
  }) async {
    final saleId = (clientSaleId != null && clientSaleId.isNotEmpty)
        ? clientSaleId
        : 'SALE-${DateTime.now().millisecondsSinceEpoch}';

    final online = await _isNetworkAvailable();
    if (!online) {
      return _enqueueOfflineOrder(
        clientSaleId: saleId,
        branchId: branchId,
        branchName: branchName,
        items: items,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        gcashReference: gcashReference,
        cashierId: cashierId,
        cashierName: cashierName,
      );
    }

    try {
      return await _executeOnlineTransaction(
        branchId: branchId,
        branchName: branchName,
        items: items,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        gcashReference: gcashReference,
        cashierId: cashierId,
        cashierName: cashierName,
        clientSaleId: saleId,
        orderTimestamp: orderTimestamp,
        isOfflineSync: false,
      );
    } catch (e) {
      if (_isConnectivityError(e)) {
        _isOffline = true;
        return _enqueueOfflineOrder(
          clientSaleId: saleId,
          branchId: branchId,
          branchName: branchName,
          items: items,
          totalAmount: totalAmount,
          paymentMethod: paymentMethod,
          gcashReference: gcashReference,
          cashierId: cashierId,
          cashierName: cashierName,
        );
      }
      rethrow;
    }
  }

  Future<TransactionModel> _enqueueOfflineOrder({
    required String clientSaleId,
    required String branchId,
    required String branchName,
    required List<CartItemModel> items,
    required double totalAmount,
    required String paymentMethod,
    String? gcashReference,
    required String cashierId,
    required String cashierName,
  }) async {
    final existingIdx = _pendingOrders.indexWhere(
      (o) => o.clientSaleId == clientSaleId,
    );
    if (existingIdx >= 0) {
      return _pendingOrders[existingIdx].toTransactionModel();
    }

    final order = PendingOfflineOrder(
      clientSaleId: clientSaleId,
      branchId: branchId,
      branchName: branchName,
      items: List<CartItemModel>.from(items),
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      gcashReference: gcashReference?.trim(),
      cashierId: cashierId,
      cashierName: cashierName,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    _pendingOrders.add(order);
    await _offlineStorage.save(branchId, _pendingOrders);
    notifyListeners();
    return order.toTransactionModel();
  }

  /// Pushes all queued offline orders to Firebase in FIFO order when online.
  Future<void> syncPendingOrders() async {
    final branchId = _currentBranchId;
    if (_isSyncingOffline || _pendingOrders.isEmpty || branchId == null) {
      return;
    }
    if (!await _isNetworkAvailable()) return;

    _isSyncingOffline = true;
    notifyListeners();

    try {
      final queueCopy = List<PendingOfflineOrder>.from(_pendingOrders);
      for (final order in queueCopy) {
        if (!await _isNetworkAvailable()) break;

        try {
          await _executeOnlineTransaction(
            branchId: order.branchId,
            branchName: order.branchName,
            items: order.items,
            totalAmount: order.totalAmount,
            paymentMethod: order.paymentMethod,
            gcashReference: order.gcashReference,
            cashierId: order.cashierId,
            cashierName: order.cashierName,
            clientSaleId: order.clientSaleId,
            orderTimestamp: order.createdAt,
            isOfflineSync: true,
          );

          _pendingOrders.removeWhere(
            (o) => o.clientSaleId == order.clientSaleId,
          );
          await _offlineStorage.save(branchId, _pendingOrders);
          notifyListeners();
        } catch (e) {
          if (_isConnectivityError(e)) {
            _isOffline = true;
            break;
          }
          // Record non-connectivity error on this order so it doesn't block
          // subsequent valid orders in the queue.
          final idx = _pendingOrders.indexWhere(
            (o) => o.clientSaleId == order.clientSaleId,
          );
          if (idx >= 0) {
            _pendingOrders[idx] = _pendingOrders[idx].copyWith(
              syncError: e.toString().replaceAll('Exception: ', ''),
            );
            await _offlineStorage.save(branchId, _pendingOrders);
            notifyListeners();
          }
        }
      }
    } finally {
      _isSyncingOffline = false;
      notifyListeners();
    }
  }

  Future<TransactionModel> _executeOnlineTransaction({
    required String branchId,
    required String branchName,
    required List<CartItemModel> items,
    required double totalAmount,
    required String paymentMethod,
    String? gcashReference,
    String cashierId = 'STAFF_DEVICE',
    String cashierName = 'Store Staff',
    String? clientSaleId,
    DateTime? orderTimestamp,
    bool isOfflineSync = false,
  }) async {
    final bool isOffline = isOfflineSync;

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

    // Aggregate cart/sale quantities by productId (combining all temperatures & sizes)
    final Map<String, int> productQuantities = {};
    final Map<String, String> productNames = {};
    for (final item in items) {
      final pId = item.product.productId;
      productQuantities[pId] = (productQuantities[pId] ?? 0) + item.quantity;
      productNames[pId] = item.product.name;
    }

    final itemsMap = items.map((i) {
      final rawTemp = i.selectedTemperature?.trim();
      final effectiveTemp = (rawTemp != null && rawTemp.isNotEmpty)
          ? rawTemp
          : (i.product.fixedTemperature ?? i.product.initialTemperature);
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
      final rawTemp = item.selectedTemperature?.trim();
      final effectiveTemp = (rawTemp != null && rawTemp.isNotEmpty)
          ? rawTemp
          : (item.product.fixedTemperature ?? item.product.initialTemperature);
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
      'productQuantities': productQuantities,
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
      'timestamp': orderTimestamp != null
          ? Timestamp.fromDate(orderTimestamp)
          : FieldValue.serverTimestamp(),
      'createdAt': orderTimestamp != null
          ? Timestamp.fromDate(orderTimestamp)
          : FieldValue.serverTimestamp(),
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

      // Step B.2: Read all applicable branch_product_servings documents inside transaction
      // (ALL READS MUST PRECEDE ANY WRITES)
      final Map<String, DocumentSnapshot> quotaSnapshots = {};
      final Map<String, DocumentReference> quotaDocRefs = {};
      for (final pId in productQuantities.keys) {
        final docId = BranchProductServingModel.buildDocumentId(branchId, pId);
        final qRef = _firestore
            .collection(FirebasePaths.branchProductServings)
            .doc(docId);
        quotaDocRefs[pId] = qRef;
        final qSnap = await transaction.get(qRef);
        quotaSnapshots[pId] = qSnap;
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

      // Step C.2: Validate manual product servings quota sufficiency
      final Map<String, int> quotaNewRemaining = {};
      final Map<String, int> quotaPreviousRemaining = {};
      final Map<String, int> quotaDeductedQty = {};
      final Map<String, int> quotaOverdraftQty = {};
      final Map<String, int> saleOverdraftMap = {};

      for (final entry in productQuantities.entries) {
        final pId = entry.key;
        final requested = entry.value;
        final qSnap = quotaSnapshots[pId];

        // Missing quota document: preserve physical inventory fallback
        if (qSnap == null || !qSnap.exists || qSnap.data() == null) {
          continue;
        }

        final qData = qSnap.data() as Map<String, dynamic>;
        final isEnabled = qData['isEnabled'] as bool? ?? true;

        // Disabled quota: preserve physical inventory fallback
        if (!isEnabled) {
          continue;
        }

        final currentRemaining =
            (qData['remainingServings'] as num?)?.toInt() ?? 0;
        quotaPreviousRemaining[pId] = currentRemaining;

        if (!isOffline) {
          // ONLINE SALE: Strict validation
          if (currentRemaining < requested) {
            final pName = productNames[pId] ?? pId;
            final summary = currentRemaining <= 0
                ? 'Manual quota for "$pName" is out of stock (0 servings remaining)'
                : 'Insufficient manual quota for "$pName": requested $requested, but only $currentRemaining servings remaining';
            throw Exception('Cannot complete sale: $summary');
          }

          final newRemaining = currentRemaining - requested;
          if (newRemaining < 0) {
            throw Exception(
              'Cannot complete sale: remaining manual servings cannot be negative ($newRemaining)',
            );
          }
          quotaNewRemaining[pId] = newRemaining;
          quotaDeductedQty[pId] = requested;
          quotaOverdraftQty[pId] = 0;
        } else {
          // OFFLINE SYNC: Allow overdraft, clamp remainingServings to 0
          final available = math.max(0, currentRemaining);
          final deducted = math.min(requested, available);
          final overdraft = requested - deducted;
          final newRemaining = math.max(0, currentRemaining - deducted);

          quotaNewRemaining[pId] = newRemaining;
          quotaDeductedQty[pId] = deducted;
          quotaOverdraftQty[pId] = overdraft;

          if (overdraft > 0) {
            saleOverdraftMap[pId] = overdraft;
          }
        }
      }

      // --- ALL READS & VALIDATIONS COMPLETE; PERFORM ALL ATOMIC WRITES ---

      // Step D: Write complete sale record with overdraft metadata
      final hasOverdraft = saleOverdraftMap.isNotEmpty;
      final finalSaleData = Map<String, dynamic>.from(saleData);
      finalSaleData['hasManualQuotaOverdraft'] = hasOverdraft;
      finalSaleData['manualQuotaOverdrafts'] = saleOverdraftMap;

      if (hasOverdraft) {
        final overdraftDetails = saleOverdraftMap.entries.map((e) {
          final pName = productNames[e.key] ?? e.key;
          return '$pName (${e.value} serving${e.value == 1 ? '' : 's'} over quota)';
        }).join(', ');
        final existingNotes = finalSaleData['notes'] as String?;
        final overdraftNote = '[OFFLINE OVERDRAFT] $overdraftDetails';
        finalSaleData['notes'] = (existingNotes != null && existingNotes.isNotEmpty)
            ? '$existingNotes | $overdraftNote'
            : overdraftNote;
      }

      transaction.set(docRef, finalSaleData);

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

      // Step E.2: Decrement enabled manual quota & write quota ledger records
      for (final pId in quotaNewRemaining.keys) {
        final newRemaining = quotaNewRemaining[pId]!;
        final prevRemaining = quotaPreviousRemaining[pId] ?? 0;
        final requested = productQuantities[pId] ?? 0;
        final deducted = quotaDeductedQty[pId] ?? requested;
        final overdraft = quotaOverdraftQty[pId] ?? 0;
        final qRef = quotaDocRefs[pId]!;

        transaction.update(qRef, {
          'remainingServings': newRemaining,
          'lastSaleId': saleId,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        final ledgerDocId = QuotaTransactionModel.buildTransactionId(
          saleId,
          pId,
        );
        final ledgerRef = _firestore
            .collection(FirebasePaths.quotaTransactions)
            .doc(ledgerDocId);

        final ledgerRecord = QuotaTransactionModel(
          transactionId: ledgerDocId,
          saleId: saleId,
          clientSaleId: clientSaleId ?? saleId,
          branchId: branchId,
          productId: pId,
          productName: productNames[pId] ?? '',
          requestedQuantity: requested,
          deductedQuantity: deducted,
          overdraftQuantity: overdraft,
          previousRemaining: prevRemaining,
          newRemaining: newRemaining,
          isOfflineSync: isOffline,
          cashierId: cashierId,
          cashierName: cashierName,
        );

        transaction.set(ledgerRef, ledgerRecord.toMap());
      }

      return TransactionModel(
        transactionId: saleId,
        timestamp: orderTimestamp ?? DateTime.now(),
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
        hasManualQuotaOverdraft: hasOverdraft,
        manualQuotaOverdrafts: saleOverdraftMap,
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
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
