import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/features/pos/widgets/after_sale_confirmation_dialog.dart';
import 'package:coffee_grind_ph/models/branch_product_serving_model.dart';
import 'package:coffee_grind_ph/models/cart_item_model.dart';
import 'package:coffee_grind_ph/models/pending_offline_order.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/quota_transaction_model.dart';
import 'package:coffee_grind_ph/providers/transactions_provider.dart';
import 'package:coffee_grind_ph/services/inventory_resolver.dart';
import 'package:coffee_grind_ph/services/offline_order_queue_service.dart';

void main() {
  ProductModel createAmericanoProduct() {
    return ProductModel(
      productId: 'prod_americano',
      name: 'Americano',
      category: ProductCategory.coffee,
      description: 'Classic espresso and water',
      imageUrl: '',
      isActive: true,
      availableBranches: const ['br_1790905840872'],
      pricing: const ProductPricing(hotPrice: 65.0, icedPrice: 75.0),
    );
  }

  group('Offline Order Queue & Auto-Sync Tests', () {
    test('PendingOfflineOrder round-trip JSON serialization preserves all fields', () {
      final americano = createAmericanoProduct();
      final item = CartItemModel(
        id: 'item_1',
        product: americano,
        selectedTemperature: 'Iced',
        unitPrice: 75.0,
        quantity: 2,
      );

      final order = PendingOfflineOrder(
        clientSaleId: 'SALE_OFFLINE_1',
        branchId: 'br_1790905840872',
        branchName: 'Santa Cruz Branch',
        items: [item],
        totalAmount: 150.0,
        paymentMethod: 'Cash',
        cashierId: 'uid_sc',
        cashierName: 'Santa Cruz',
        createdAtMillis: 1700000000000,
      );

      final decoded = PendingOfflineOrder.fromJson(order.toJson());
      expect(decoded.clientSaleId, 'SALE_OFFLINE_1');
      expect(decoded.branchId, 'br_1790905840872');
      expect(decoded.totalAmount, 150.0);
      expect(decoded.items.length, 1);
      expect(decoded.items.first.product.name, 'Americano');
      expect(decoded.items.first.selectedTemperature, 'Iced');
      expect(decoded.items.first.quantity, 2);
      expect(decoded.createdAtMillis, 1700000000000);
    });

    test('Offline Americano order queues locally and syncs to Firestore when internet returns', () async {
      final fakeDb = FakeFirebaseFirestore();
      final storage = InMemoryOfflineOrderStorage();
      bool isOnline = false;

      // Seed recipe and inventory in Firestore
      await fakeDb.collection(FirebasePaths.recipes).doc('prod_americano').set({
        'productId': 'prod_americano',
        'productName': 'Americano',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'unitCost': 1.5,
          },
        ],
      });
      await fakeDb.collection(FirebasePaths.inventory).doc('br_1790905840872_ing_beans').set({
        'branchId': 'br_1790905840872',
        'ingredientId': 'ing_beans',
        'ingredientName': 'Espresso Beans',
        'quantity': 500.0,
        'unit': 'g',
      });

      final provider = TransactionsProvider(
        firestore: fakeDb,
        offlineStorage: storage,
        checkIsOnline: () async => isOnline,
      );
      await provider.bindToBranch('br_1790905840872');

      final americano = createAmericanoProduct();
      final item = CartItemModel(
        id: 'cart_1',
        product: americano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 2,
      );

      // 1. Place order while OFFLINE
      final offlineTx = await provider.addTransaction(
        branchId: 'br_1790905840872',
        branchName: 'Santa Cruz Branch',
        items: [item],
        totalAmount: 130.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_AMERICANO_1',
      );

      expect(offlineTx.status, 'Pending Sync');
      expect(provider.pendingOfflineCount, 1);
      expect(provider.transactions.length, 1);
      expect(provider.todaySales, 130.0);
      expect(provider.todayTransactionCount, 1);

      // Duplicate submission with same clientSaleId while offline does not duplicate
      await provider.addTransaction(
        branchId: 'br_1790905840872',
        branchName: 'Santa Cruz Branch',
        items: [item],
        totalAmount: 130.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_AMERICANO_1',
      );
      expect(provider.pendingOfflineCount, 1);

      // Firestore should still have 0 sales while offline
      final salesBeforeSync = await fakeDb.collection(FirebasePaths.sales).get();
      expect(salesBeforeSync.docs, isEmpty);

      // 2. Internet comes back -> trigger syncPendingOrders()
      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      // Queue should now be empty
      expect(provider.pendingOfflineCount, 0);

      // Sale should now be in Firestore with inventory deducted (500 - 36 = 464)
      final saleDoc = await fakeDb
          .collection(FirebasePaths.sales)
          .doc('SALE_OFFLINE_AMERICANO_1')
          .get();
      expect(saleDoc.exists, isTrue);
      expect(saleDoc.data()?['total'], 130.0);
      expect(saleDoc.data()?['timestamp'], isA<Timestamp>());

      final invDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('br_1790905840872_ing_beans')
          .get();
      expect((invDoc.data()?['quantity'] as num).toDouble(), 464.0);

      final auditDocs = await fakeDb
          .collection(FirebasePaths.inventoryTransactions)
          .get();
      expect(auditDocs.docs.length, 1);
      expect(auditDocs.docs.first.data()['saleId'], 'SALE_OFFLINE_AMERICANO_1');

      provider.dispose();
    });

    testWidgets('AfterSaleConfirmationDialog shows offline notice for Pending Sync orders', (tester) async {
      final americano = createAmericanoProduct();
      final pendingOrder = PendingOfflineOrder(
        clientSaleId: 'SALE_OFFLINE_UI',
        branchId: 'br_1790905840872',
        branchName: 'Santa Cruz Branch',
        items: [
          CartItemModel(
            id: 'c1',
            product: americano,
            selectedTemperature: 'Hot',
            unitPrice: 65.0,
            quantity: 1,
          ),
        ],
        totalAmount: 65.0,
        paymentMethod: 'Cash',
        cashierId: 'uid_sc',
        cashierName: 'Santa Cruz',
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AfterSaleConfirmationDialog(
              transaction: pendingOrder.toTransactionModel(),
              onNewSale: () {},
              onBackToDashboard: () {},
            ),
          ),
        ),
      );

      expect(find.text('Order Saved Offline'), findsOneWidget);
      expect(
        find.text('Will automatically push to Firebase when internet returns'),
        findsOneWidget,
      );
    });
  });

  group('Checkpoint 6.4: Full Offline Queue + Manual Servings Overdraft Integration Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late InventoryDocumentResolver resolver;
    late InMemoryOfflineOrderStorage storage;
    late TransactionsProvider provider;
    bool isOnline = false;

    const testBranchId = 'br_1790905840872';
    const testBranchName = 'Santa Cruz Branch';

    final prodAmericano = ProductModel(
      productId: 'prod_americano',
      name: 'Americano',
      category: ProductCategory.coffee,
      description: 'Classic espresso and water',
      imageUrl: '',
      isActive: true,
      availableBranches: const [testBranchId],
      pricing: const ProductPricing(hotPrice: 65.0, icedPrice: 75.0),
    );

    final prodSpanishLatte = ProductModel(
      productId: 'prod_spanish_latte',
      name: 'Spanish Latte',
      category: ProductCategory.coffee,
      description: 'Espresso with sweet milk',
      imageUrl: '',
      isActive: true,
      availableBranches: const [testBranchId],
      pricing: const ProductPricing(hotPrice: 85.0, icedPrice: 95.0),
    );

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      resolver = InventoryDocumentResolver(firestore: fakeDb);
      storage = InMemoryOfflineOrderStorage();
      isOnline = false;

      // Seed recipes
      await fakeDb.collection(FirebasePaths.recipes).doc('prod_americano').set({
        'productId': 'prod_americano',
        'productName': 'Americano',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'unitCost': 1.5,
          },
        ],
      });

      await fakeDb.collection(FirebasePaths.recipes).doc('prod_spanish_latte').set({
        'productId': 'prod_spanish_latte',
        'productName': 'Spanish Latte',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'unitCost': 1.5,
          },
          {
            'ingredientId': 'ing_milk',
            'ingredientName': 'Fresh Milk',
            'quantity': 150.0,
            'unit': 'ml',
            'unitCost': 0.1,
          },
        ],
      });

      // Seed physical inventory
      await fakeDb.collection(FirebasePaths.inventory).doc('br_1790905840872_ing_beans').set({
        'branchId': testBranchId,
        'ingredientId': 'ing_beans',
        'ingredientName': 'Espresso Beans',
        'quantity': 5000.0,
        'unit': 'g',
      });

      await fakeDb.collection(FirebasePaths.inventory).doc('br_1790905840872_ing_milk').set({
        'branchId': testBranchId,
        'ingredientId': 'ing_milk',
        'ingredientName': 'Fresh Milk',
        'quantity': 5000.0,
        'unit': 'ml',
      });

      provider = TransactionsProvider(
        firestore: fakeDb,
        resolver: resolver,
        offlineStorage: storage,
        checkIsOnline: () async => isOnline,
      );
      await provider.bindToBranch(testBranchId);
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. Offline sale synchronizes successfully when quota is sufficient', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c1',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 3,
      );

      final tx = await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 195.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_1',
      );

      expect(tx.status, 'Pending Sync');
      expect(provider.pendingOfflineCount, 1);

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      expect(provider.pendingOfflineCount, 0);

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 7);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_SCENARIO_1').get();
      expect(saleDoc.exists, isTrue);
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_SCENARIO_1', 'prod_americano'),
      ).get();
      expect(ledgerDoc.exists, isTrue);
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.deductedQuantity, 3);
      expect(ledger.overdraftQuantity, 0);
      expect(ledger.newRemaining, 7);
      expect(ledger.isOfflineSync, isTrue);
    });

    test('2. Offline sale synchronizes when quota is partially insufficient; overdraft is recorded', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c2',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 5,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 325.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_2',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      expect(provider.pendingOfflineCount, 0);

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 0);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_SCENARIO_2').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isTrue);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], {'prod_americano': 3});
      expect(saleDoc.data()!['notes'], contains('[OFFLINE OVERDRAFT]'));

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_SCENARIO_2', 'prod_americano'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.deductedQuantity, 2);
      expect(ledger.overdraftQuantity, 3);
      expect(ledger.newRemaining, 0);
    });

    test('3. Offline sale synchronizes when quota is already zero; full overdraft is recorded', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 0,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c3',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 4,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 260.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_3',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 0);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_SCENARIO_3').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isTrue);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], {'prod_americano': 4});

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_SCENARIO_3', 'prod_americano'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.deductedQuantity, 0);
      expect(ledger.overdraftQuantity, 4);
      expect(ledger.previousRemaining, 0);
      expect(ledger.newRemaining, 0);
    });

    test('4. Offline sale with disabled quota follows existing physical inventory behavior', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 1,
        'isEnabled': false,
      });

      final item = CartItemModel(
        id: 'c4',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 3,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 195.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_4',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 1); // Untouched

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_SCENARIO_4').get();
      expect(saleDoc.exists, isTrue);
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);

      final ledgers = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgers.docs, isEmpty);
    });

    test('5. Offline sale with no quota document follows existing physical inventory behavior', () async {
      final item = CartItemModel(
        id: 'c5',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 2,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 130.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_5',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_SCENARIO_5').get();
      expect(saleDoc.exists, isTrue);
      expect(saleDoc.data()!['inventoryDeducted'], isTrue);
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);

      final ledgers = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgers.docs, isEmpty);
    });

    test('6. Physical inventory deduction still occurs during offline synchronization', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 1,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c6',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 2, // 2 * 18g = 36g beans
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 130.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_6',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final invDoc = await fakeDb.collection(FirebasePaths.inventory).doc('br_1790905840872_ing_beans').get();
      expect(invDoc.data()!['quantity'], 5000.0 - 36.0);

      final auditDocs = await fakeDb.collection(FirebasePaths.inventoryTransactions).where('saleId', isEqualTo: 'SALE_SCENARIO_6').get();
      expect(auditDocs.docs.length, 1);
      expect(auditDocs.docs.first.data()['change'], -36.0);
    });

    test('7. Sale metadata correctly records hasManualQuotaOverdraft, manualQuotaOverdrafts, and relevant notes', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 1,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c7',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 3,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 195.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_7',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_SCENARIO_7').get();
      final data = saleDoc.data()!;
      expect(data['hasManualQuotaOverdraft'], isTrue);
      expect(data['manualQuotaOverdrafts'], {'prod_americano': 2});
      expect(data['notes'], '[OFFLINE OVERDRAFT] Americano (2 servings over quota)');
    });

    test('8. Quota ledger records the correct requested, deducted, overdraft, previous, and new remaining quantities', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 4,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c8',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 7,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 455.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_8',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_SCENARIO_8', 'prod_americano'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 7);
      expect(ledger.deductedQuantity, 4);
      expect(ledger.overdraftQuantity, 3);
      expect(ledger.previousRemaining, 4);
      expect(ledger.newRemaining, 0);
      expect(ledger.isOfflineSync, isTrue);
    });

    test('9. Repeated synchronization does not duplicate any writes', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c9',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 3,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 195.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_9',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc1 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc1.data()!['remainingServings'], 7);

      // Re-trigger sync or retry
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc2 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc2.data()!['remainingServings'], 7);

      final sales = await fakeDb.collection(FirebasePaths.sales).where('clientSaleId', isEqualTo: 'SALE_SCENARIO_9').get();
      expect(sales.docs.length, 1);
    });

    test('10. Multiple products in one offline order calculate overdrafts independently by productId', () async {
      final quotaAmericanoId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaAmericanoId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final quotaSpanishId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_spanish_latte');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaSpanishId).set({
        'branchId': testBranchId,
        'productId': 'prod_spanish_latte',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final itemAmericano = CartItemModel(
        id: 'c10_a',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 5, // 2 deducted, 3 overdrafted
      );

      final itemSpanish = CartItemModel(
        id: 'c10_s',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 85.0,
        quantity: 3, // 3 deducted, 0 overdrafted
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [itemAmericano, itemSpanish],
        totalAmount: 580.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_10',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final qDocA = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaAmericanoId).get();
      expect(qDocA.data()!['remainingServings'], 0);

      final qDocS = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaSpanishId).get();
      expect(qDocS.data()!['remainingServings'], 7);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_SCENARIO_10').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isTrue);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], {'prod_americano': 3});
    });

    test('11. Hot and Iced variants share the same manual quota per productId', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 3,
        'isEnabled': true,
      });

      final itemHot = CartItemModel(
        id: 'c11_hot',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 2,
      );

      final itemIced = CartItemModel(
        id: 'c11_iced',
        product: prodAmericano,
        selectedTemperature: 'Iced',
        unitPrice: 75.0,
        quantity: 3,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [itemHot, itemIced],
        totalAmount: 355.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_11',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 0);

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_SCENARIO_11', 'prod_americano'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 5); // 2 + 3
      expect(ledger.deductedQuantity, 3);
      expect(ledger.overdraftQuantity, 2);
    });

    test('12. Failed synchronization does not silently remove the queued order', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      // Deplete inventory so physical validation fails
      await fakeDb.collection(FirebasePaths.inventory).doc('br_1790905840872_ing_beans').update({
        'quantity': 0.0,
      });

      final item = CartItemModel(
        id: 'c12',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 2,
      );

      await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 130.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_12',
      );

      isOnline = true;
      await provider.syncPendingOrders();
      await pumpEventQueue();

      // Order must remain in queue with syncError
      expect(provider.pendingOfflineCount, 1);
      expect(provider.pendingOfflineOrders.first.syncError, isNotNull);
      expect(provider.pendingOfflineOrders.first.syncError, contains('Insufficient branch stock'));

      // Quota must not be changed
      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 10);
    });

    test('13. Existing online checkout still rejects insufficient quota', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c13',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 5,
      );

      isOnline = true;
      expect(
        () => provider.addTransaction(
          branchId: testBranchId,
          branchName: testBranchName,
          items: [item],
          totalAmount: 325.0,
          paymentMethod: 'Cash',
          clientSaleId: 'SALE_SCENARIO_13',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Insufficient manual quota for "Americano"'),
        )),
      );

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 2);
    });

    test('14. Existing POS checkout, inventory, and offline queue behavior remain intact', () async {
      // Normal online checkout with sufficient quota
      isOnline = true;
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'prod_americano');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'prod_americano',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'c14',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 65.0,
        quantity: 2,
      );

      final onlineTx = await provider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 130.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_SCENARIO_14',
      );

      expect(onlineTx.status, 'Completed');
      expect(provider.pendingOfflineCount, 0);

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 8);
    });
  });
}
