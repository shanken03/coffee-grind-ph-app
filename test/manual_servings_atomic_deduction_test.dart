import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/models/branch_product_serving_model.dart';
import 'package:coffee_grind_ph/models/cart_item_model.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/quota_transaction_model.dart';
import 'package:coffee_grind_ph/providers/transactions_provider.dart';
import 'package:coffee_grind_ph/services/inventory_resolver.dart';
import 'package:coffee_grind_ph/services/offline_order_queue_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Checkpoint 6.1: Atomic Manual Product Servings Deduction Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late InventoryDocumentResolver resolver;
    late TransactionsProvider transactionsProvider;

    const testBranchId = 'br_1790905840872';
    const testBranchName = 'Santa Cruz Branch';

    final prodSpanishLatte = ProductModel(
      productId: 'PROD_SPANISH',
      name: 'Spanish Latte',
      category: ProductCategory.coffee,
      description: 'Espresso with sweet milk',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [testBranchId],
      pricing: const ProductPricing(
        hotPrice: 120.0,
        icedPrice: 130.0,
      ),
      recipeId: 'rec_spanish_latte',
    );

    final prodAmericano = ProductModel(
      productId: 'PROD_AMERICANO',
      name: 'Americano',
      category: ProductCategory.coffee,
      description: 'Rich espresso and water',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [testBranchId],
      pricing: const ProductPricing(
        hotPrice: 100.0,
        icedPrice: 110.0,
      ),
      recipeId: 'rec_americano',
    );

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      resolver = InventoryDocumentResolver(firestore: fakeDb);
      transactionsProvider = TransactionsProvider(
        firestore: fakeDb,
        resolver: resolver,
      );

      // Seed Spanish Latte recipe: 18g beans, 150ml milk
      await fakeDb.collection(FirebasePaths.recipes).doc('rec_spanish_latte').set({
        'productId': 'PROD_SPANISH',
        'productName': 'Spanish Latte',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'temperature': 'both',
            'category': 'ingredient',
            'unitCost': 0.8,
          },
          {
            'ingredientId': 'ing_milk',
            'ingredientName': 'Fresh Milk',
            'quantity': 150.0,
            'unit': 'ml',
            'temperature': 'both',
            'category': 'ingredient',
            'unitCost': 0.1,
          },
          {
            'ingredientId': 'pkg_cup',
            'ingredientName': 'Coffee Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'both',
            'category': 'packaging',
            'unitCost': 2.5,
          },
        ],
      });

      // Seed Americano recipe: 18g beans, 1 cup
      await fakeDb.collection(FirebasePaths.recipes).doc('rec_americano').set({
        'productId': 'PROD_AMERICANO',
        'productName': 'Americano',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'temperature': 'both',
            'category': 'ingredient',
            'unitCost': 0.8,
          },
          {
            'ingredientId': 'pkg_cup',
            'ingredientName': 'Coffee Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'both',
            'category': 'packaging',
            'unitCost': 2.5,
          },
        ],
      });

      // Seed abundant physical inventory for Santa Cruz
      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').set({
        'branchId': testBranchId,
        'ingredientId': 'ing_beans',
        'name': 'Espresso Beans',
        'quantity': 5000.0,
        'unit': 'g',
      });

      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_milk').set({
        'branchId': testBranchId,
        'ingredientId': 'ing_milk',
        'name': 'Fresh Milk',
        'quantity': 10000.0,
        'unit': 'ml',
      });

      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_pkg_cup').set({
        'branchId': testBranchId,
        'ingredientId': 'pkg_cup',
        'name': 'Coffee Cup',
        'quantity': 500.0,
        'unit': 'pcs',
      });
    });

    test('1. Sufficient quota deducts the exact quantity atomically', () async {
      // Seed quota: 10 servings available
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 360.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_TEST_001',
      );

      expect(tx.transactionId, 'SALE_TEST_001');

      // Verify quota doc decremented from 10 to 7
      final quotaSnap = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(quotaSnap.data()!['remainingServings'], 7);
      expect(quotaSnap.data()!['lastSaleId'], 'SALE_TEST_001');

      // Verify quota_transactions ledger document created
      final ledgerDocId = QuotaTransactionModel.buildTransactionId('SALE_TEST_001', 'PROD_SPANISH');
      final ledgerSnap = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(ledgerDocId).get();
      expect(ledgerSnap.exists, isTrue);
      final ledgerData = ledgerSnap.data()!;
      expect(ledgerData['saleId'], 'SALE_TEST_001');
      expect(ledgerData['productId'], 'PROD_SPANISH');
      expect(ledgerData['requestedQuantity'], 3);
      expect(ledgerData['deductedQuantity'], 3);
      expect(ledgerData['overdraftQuantity'], 0);
      expect(ledgerData['previousRemaining'], 10);
      expect(ledgerData['newRemaining'], 7);
      expect(ledgerData['isOfflineSync'], isFalse);

      // Verify physical inventory was also decremented
      final beansSnap = await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').get();
      expect(beansSnap.data()!['quantity'], 5000.0 - (3 * 18.0));
    });

    test('2. Insufficient quota aborts the whole transaction atomically', () async {
      // Seed quota: only 2 remaining
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3, // Requires 3, only 2 available
      );

      expect(
        () => transactionsProvider.addTransaction(
          branchId: testBranchId,
          branchName: testBranchName,
          items: [item],
          totalAmount: 360.0,
          paymentMethod: 'Cash',
          clientSaleId: 'SALE_TEST_002',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Insufficient manual quota for "Spanish Latte": requested 3, but only 2 servings remaining'),
          ),
        ),
      );

      // Verify quota remained at 2 (Zero change)
      final quotaSnap = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(quotaSnap.data()!['remainingServings'], 2);

      // Verify zero sale document created
      final saleSnap = await fakeDb.collection(FirebasePaths.sales).doc('SALE_TEST_002').get();
      expect(saleSnap.exists, isFalse);

      // Verify zero ledger document created
      final ledgerSnap = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgerSnap.docs, isEmpty);

      // Verify zero physical inventory deducted
      final beansSnap = await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').get();
      expect(beansSnap.data()!['quantity'], 5000.0);
    });

    test('3. Multiple products deduct independently with distinct ledgers', () async {
      final spanishQuotaId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(spanishQuotaId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final americanoQuotaId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_AMERICANO');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(americanoQuotaId).set({
        'branchId': testBranchId,
        'productId': 'PROD_AMERICANO',
        'manualMaxServings': 50,
        'remainingServings': 8,
        'isEnabled': true,
      });

      final items = [
        CartItemModel(
          id: 'PROD_SPANISH_Hot_none',
          product: prodSpanishLatte,
          selectedTemperature: 'Hot',
          unitPrice: 120.0,
          quantity: 2,
        ),
        CartItemModel(
          id: 'PROD_AMERICANO_Iced_none',
          product: prodAmericano,
          selectedTemperature: 'Iced',
          unitPrice: 110.0,
          quantity: 3,
        ),
      ];

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: items,
        totalAmount: 570.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_TEST_003',
      );

      // Spanish Latte: 10 - 2 = 8
      final sSnap = await fakeDb.collection(FirebasePaths.branchProductServings).doc(spanishQuotaId).get();
      expect(sSnap.data()!['remainingServings'], 8);

      // Americano: 8 - 3 = 5
      final aSnap = await fakeDb.collection(FirebasePaths.branchProductServings).doc(americanoQuotaId).get();
      expect(aSnap.data()!['remainingServings'], 5);

      // Two independent ledger documents
      final sLedger = await fakeDb
          .collection(FirebasePaths.quotaTransactions)
          .doc(QuotaTransactionModel.buildTransactionId('SALE_TEST_003', 'PROD_SPANISH'))
          .get();
      expect(sLedger.exists, isTrue);
      expect(sLedger.data()!['deductedQuantity'], 2);

      final aLedger = await fakeDb
          .collection(FirebasePaths.quotaTransactions)
          .doc(QuotaTransactionModel.buildTransactionId('SALE_TEST_003', 'PROD_AMERICANO'))
          .get();
      expect(aLedger.exists, isTrue);
      expect(aLedger.data()!['deductedQuantity'], 3);
    });

    test('4. Hot and Iced variants combine and share one quota', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 5,
        'isEnabled': true,
      });

      // 2 Hot + 2 Iced = 4 Spanish Latte
      final items = [
        CartItemModel(
          id: 'PROD_SPANISH_Hot_none',
          product: prodSpanishLatte,
          selectedTemperature: 'Hot',
          unitPrice: 120.0,
          quantity: 2,
        ),
        CartItemModel(
          id: 'PROD_SPANISH_Iced_none',
          product: prodSpanishLatte,
          selectedTemperature: 'Iced',
          unitPrice: 130.0,
          quantity: 2,
        ),
      ];

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: items,
        totalAmount: 500.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_TEST_004',
      );

      // 5 - 4 = 1 remaining
      final quotaSnap = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(quotaSnap.data()!['remainingServings'], 1);

      // Ledger records aggregate total of 4
      final ledgerSnap = await fakeDb
          .collection(FirebasePaths.quotaTransactions)
          .doc(QuotaTransactionModel.buildTransactionId('SALE_TEST_004', 'PROD_SPANISH'))
          .get();
      expect(ledgerSnap.data()!['requestedQuantity'], 4);
      expect(ledgerSnap.data()!['deductedQuantity'], 4);
      expect(ledgerSnap.data()!['newRemaining'], 1);
    });

    test('5. Multiple sizes share one quota and aggregate by productId', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_AMERICANO');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_AMERICANO',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      // 1 12oz Hot + 2 16oz Hot = 3 Americanos
      final items = [
        CartItemModel(
          id: 'PROD_AMERICANO_Hot_12oz',
          product: prodAmericano,
          selectedTemperature: 'Hot',
          selectedSize: '12oz',
          unitPrice: 90.0,
          quantity: 1,
        ),
        CartItemModel(
          id: 'PROD_AMERICANO_Hot_16oz',
          product: prodAmericano,
          selectedTemperature: 'Hot',
          selectedSize: '16oz',
          unitPrice: 100.0,
          quantity: 2,
        ),
      ];

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: items,
        totalAmount: 290.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_TEST_005',
      );

      // 10 - 3 = 7
      final quotaSnap = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(quotaSnap.data()!['remainingServings'], 7);

      final ledgerSnap = await fakeDb
          .collection(FirebasePaths.quotaTransactions)
          .doc(QuotaTransactionModel.buildTransactionId('SALE_TEST_005', 'PROD_AMERICANO'))
          .get();
      expect(ledgerSnap.data()!['requestedQuantity'], 3);
      expect(ledgerSnap.data()!['deductedQuantity'], 3);
    });

    test('6. Missing quota falls back to physical inventory without error', () async {
      // Americano has NO branch_product_servings document seeded
      final item = CartItemModel(
        id: 'PROD_AMERICANO_Hot_none',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 2,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 200.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_TEST_006',
      );

      expect(tx.status, 'Completed');

      // Sale committed
      final saleSnap = await fakeDb.collection(FirebasePaths.sales).doc('SALE_TEST_006').get();
      expect(saleSnap.exists, isTrue);

      // Physical inventory deducted
      final beansSnap = await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').get();
      expect(beansSnap.data()!['quantity'], 5000.0 - (2 * 18.0));

      // No quota ledger written for unconfigured product
      final ledgerSnap = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgerSnap.docs, isEmpty);
    });

    test('7. Disabled quota does not deduct', () async {
      // Seed disabled quota with 0 remaining
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 0,
        'isEnabled': false, // Disabled!
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3,
      );

      // Physical inventory is abundant, so sale succeeds
      final tx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 360.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_TEST_007',
      );

      expect(tx.status, 'Completed');

      // Quota document remains untouched (remains 0)
      final quotaSnap = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(quotaSnap.data()!['remainingServings'], 0);
      expect(quotaSnap.data()!['lastSaleId'], isNull);

      // No quota ledger created
      final ledgerSnap = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgerSnap.docs, isEmpty);
    });

    test('8. Duplicate sale retry does not deduct quota twice', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      // First submission
      final tx1 = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_TEST_RETRY',
      );
      expect(tx1.transactionId, 'SALE_TEST_RETRY');

      final qSnap1 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qSnap1.data()!['remainingServings'], 8);

      // Immediate retry with the same clientSaleId
      final tx2 = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_TEST_RETRY',
      );
      expect(tx2.transactionId, 'SALE_TEST_RETRY');

      // Quota is STILL 8 (not decremented to 6)
      final qSnap2 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qSnap2.data()!['remainingServings'], 8);

      // Still only 1 ledger document
      final ledgers = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgers.docs.length, 1);
    });

    test('9. Concurrent checkout attempts cannot oversell quota', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 3, // Only 3 servings available
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      // First sale checks out 2 (succeeds, remaining becomes 1)
      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_CONCURRENT_1',
      );

      final qSnap1 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qSnap1.data()!['remainingServings'], 1);

      // Second sale immediately requests 2: fails because only 1 remains
      expect(
        () => transactionsProvider.addTransaction(
          branchId: testBranchId,
          branchName: testBranchName,
          items: [item],
          totalAmount: 240.0,
          paymentMethod: 'Cash',
          clientSaleId: 'SALE_CONCURRENT_2',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Insufficient manual quota'))),
      );

      // Remaining quota stays at 1
      final qSnap2 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qSnap2.data()!['remainingServings'], 1);
    });

    test('10. Failed inventory validation does not deduct quota', () async {
      // Plentiful quota (10 servings)
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      // Deplete espresso beans to 0 in physical inventory
      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').update({
        'quantity': 0.0,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      // Should fail due to physical ingredient shortage
      expect(
        () => transactionsProvider.addTransaction(
          branchId: testBranchId,
          branchName: testBranchName,
          items: [item],
          totalAmount: 240.0,
          paymentMethod: 'Cash',
          clientSaleId: 'SALE_TEST_INV_FAIL',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Insufficient branch stock for "Espresso Beans"'))),
      );

      // Quota remained at 10 (Zero deduction)
      final quotaSnap = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(quotaSnap.data()!['remainingServings'], 10);

      // Zero ledger entries written
      final ledgerSnap = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgerSnap.docs, isEmpty);
    });

    test('11. Ledger fields match the sale and quota update exactly', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 15,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 480.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_LEDGER_CHECK',
        cashierId: 'CASHIER_007',
        cashierName: 'Juan Dela Cruz',
      );

      final ledgerDocId = QuotaTransactionModel.buildTransactionId('SALE_LEDGER_CHECK', 'PROD_SPANISH');
      final snap = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(ledgerDocId).get();
      expect(snap.exists, isTrue);

      final model = QuotaTransactionModel.fromMap(snap.id, snap.data()!);
      expect(model.transactionId, ledgerDocId);
      expect(model.saleId, 'SALE_LEDGER_CHECK');
      expect(model.clientSaleId, 'SALE_LEDGER_CHECK');
      expect(model.branchId, testBranchId);
      expect(model.productId, 'PROD_SPANISH');
      expect(model.productName, 'Spanish Latte');
      expect(model.requestedQuantity, 4);
      expect(model.deductedQuantity, 4);
      expect(model.overdraftQuantity, 0);
      expect(model.previousRemaining, 15);
      expect(model.newRemaining, 11);
      expect(model.isOfflineSync, isFalse);
      expect(model.cashierId, 'CASHIER_007');
      expect(model.cashierName, 'Juan Dela Cruz');
    });

    test('12. Existing sale financial fields and productQuantities remain intact', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_FINANCIAL_CHECK',
      );

      expect(tx.totalAmount, 240.0);
      expect(tx.cogs, isNotNull);
      expect(tx.grossProfit, isNotNull);
      expect(tx.grossProfit, 240.0 - tx.cogs!);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_FINANCIAL_CHECK').get();
      final saleData = saleDoc.data()!;
      expect(saleData['totalAmount'], 240.0);
      expect(saleData['total'], 240.0);
      expect(saleData['subtotal'], 240.0);
      expect(saleData['inventoryDeducted'], isTrue);
      expect(saleData['productQuantities'], {'PROD_SPANISH': 2});
    });
  });

  group('Checkpoint 6.2: Offline Overdraft Synchronization Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late InventoryDocumentResolver resolver;
    late InMemoryOfflineOrderStorage storage;
    late TransactionsProvider transactionsProvider;
    bool isOnline = false;

    const testBranchId = 'br_1790905840872';
    const testBranchName = 'Santa Cruz Branch';

    final prodSpanishLatte = ProductModel(
      productId: 'PROD_SPANISH',
      name: 'Spanish Latte',
      category: ProductCategory.coffee,
      description: 'Espresso with sweet milk',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [testBranchId],
      pricing: const ProductPricing(
        hotPrice: 120.0,
        icedPrice: 130.0,
      ),
      recipeId: 'rec_spanish_latte',
    );

    final prodAmericano = ProductModel(
      productId: 'PROD_AMERICANO',
      name: 'Americano',
      category: ProductCategory.coffee,
      description: 'Rich espresso and water',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [testBranchId],
      pricing: const ProductPricing(
        hotPrice: 100.0,
        icedPrice: 110.0,
      ),
      recipeId: 'rec_americano',
    );

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      resolver = InventoryDocumentResolver(firestore: fakeDb);
      storage = InMemoryOfflineOrderStorage();
      isOnline = false;

      transactionsProvider = TransactionsProvider(
        firestore: fakeDb,
        resolver: resolver,
        offlineStorage: storage,
        checkIsOnline: () async => isOnline,
      );
      await transactionsProvider.bindToBranch(testBranchId);

      // Seed Spanish Latte recipe: 18g beans, 150ml milk, 1 cup
      await fakeDb.collection(FirebasePaths.recipes).doc('rec_spanish_latte').set({
        'productId': 'PROD_SPANISH',
        'productName': 'Spanish Latte',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'temperature': 'both',
            'category': 'ingredient',
            'unitCost': 0.8,
          },
          {
            'ingredientId': 'ing_milk',
            'ingredientName': 'Fresh Milk',
            'quantity': 150.0,
            'unit': 'ml',
            'temperature': 'both',
            'category': 'ingredient',
            'unitCost': 0.1,
          },
          {
            'ingredientId': 'pkg_cup',
            'ingredientName': 'Coffee Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'both',
            'category': 'packaging',
            'unitCost': 2.5,
          },
        ],
      });

      // Seed Americano recipe: 18g beans, 1 cup
      await fakeDb.collection(FirebasePaths.recipes).doc('rec_americano').set({
        'productId': 'PROD_AMERICANO',
        'productName': 'Americano',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'temperature': 'both',
            'category': 'ingredient',
            'unitCost': 0.8,
          },
          {
            'ingredientId': 'pkg_cup',
            'ingredientName': 'Coffee Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'both',
            'category': 'packaging',
            'unitCost': 2.5,
          },
        ],
      });

      // Seed branch physical inventory
      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').set({
        'branchId': testBranchId,
        'ingredientId': 'ing_beans',
        'name': 'Espresso Beans',
        'quantity': 5000.0,
        'unit': 'g',
      });

      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_milk').set({
        'branchId': testBranchId,
        'ingredientId': 'ing_milk',
        'name': 'Fresh Milk',
        'quantity': 5000.0,
        'unit': 'ml',
      });

      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_pkg_cup').set({
        'branchId': testBranchId,
        'ingredientId': 'pkg_cup',
        'name': 'Coffee Cup',
        'quantity': 500.0,
        'unit': 'pcs',
      });
    });

    test('1. Offline order with sufficient quota deducts normally', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 360.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_SUFFICIENT',
      );

      expect(tx.status, 'Pending Sync');
      expect(transactionsProvider.pendingOfflineCount, 1);

      // Now go online and sync
      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      expect(transactionsProvider.pendingOfflineCount, 0);

      // Verify quota updated: 10 - 3 = 7
      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 7);
      expect(qDoc.data()!['lastSaleId'], 'SALE_OFFLINE_SUFFICIENT');

      // Verify ledger record
      final ledgerDocId = QuotaTransactionModel.buildTransactionId('SALE_OFFLINE_SUFFICIENT', 'PROD_SPANISH');
      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(ledgerDocId).get();
      expect(ledgerDoc.exists, isTrue);
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 3);
      expect(ledger.deductedQuantity, 3);
      expect(ledger.overdraftQuantity, 0);
      expect(ledger.previousRemaining, 10);
      expect(ledger.newRemaining, 7);
      expect(ledger.isOfflineSync, isTrue);

      // Verify sale doc metadata
      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_SUFFICIENT').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], isEmpty);
    });

    test('2. Offline order exceeding quota clamps remainingServings to 0', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 3,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 5,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 600.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_CLAMP_0',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 0);
      expect(qDoc.data()!['lastSaleId'], 'SALE_OFFLINE_CLAMP_0');
    });

    test('3. Exact overdraft quantity recorded in ledger and sale document', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 5,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 600.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_EXACT_OVERDRAFT',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final ledgerDocId = QuotaTransactionModel.buildTransactionId('SALE_OFFLINE_EXACT_OVERDRAFT', 'PROD_SPANISH');
      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(ledgerDocId).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 5);
      expect(ledger.deductedQuantity, 2);
      expect(ledger.overdraftQuantity, 3);
      expect(ledger.previousRemaining, 2);
      expect(ledger.newRemaining, 0);
      expect(ledger.isOfflineSync, isTrue);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_EXACT_OVERDRAFT').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isTrue);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], {'PROD_SPANISH': 3});
      expect(saleDoc.data()!['notes'], contains('[OFFLINE OVERDRAFT] Spanish Latte (3 servings over quota)'));
    });

    test('4. Multiple products sync cleanly with separate ledger entries', () async {
      final spanishQuotaId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(spanishQuotaId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final americanoQuotaId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_AMERICANO');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(americanoQuotaId).set({
        'branchId': testBranchId,
        'productId': 'PROD_AMERICANO',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final itemSpanish = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 5, // 2 deducted, 3 overdrafted
      );

      final itemAmericano = CartItemModel(
        id: 'PROD_AMERICANO_Hot_none',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 3, // 3 deducted, 0 overdrafted
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [itemSpanish, itemAmericano],
        totalAmount: 900.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_MULTI_PRODUCT',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      // Check Spanish quota & ledger
      final spanishDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(spanishQuotaId).get();
      expect(spanishDoc.data()!['remainingServings'], 0);

      final spanishLedgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_OFFLINE_MULTI_PRODUCT', 'PROD_SPANISH'),
      ).get();
      final spanishLedger = QuotaTransactionModel.fromMap(spanishLedgerDoc.id, spanishLedgerDoc.data()!);
      expect(spanishLedger.requestedQuantity, 5);
      expect(spanishLedger.deductedQuantity, 2);
      expect(spanishLedger.overdraftQuantity, 3);
      expect(spanishLedger.newRemaining, 0);

      // Check Americano quota & ledger
      final americanoDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(americanoQuotaId).get();
      expect(americanoDoc.data()!['remainingServings'], 7);

      final americanoLedgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_OFFLINE_MULTI_PRODUCT', 'PROD_AMERICANO'),
      ).get();
      final americanoLedger = QuotaTransactionModel.fromMap(americanoLedgerDoc.id, americanoLedgerDoc.data()!);
      expect(americanoLedger.requestedQuantity, 3);
      expect(americanoLedger.deductedQuantity, 3);
      expect(americanoLedger.overdraftQuantity, 0);
      expect(americanoLedger.newRemaining, 7);

      // Check sale metadata
      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_MULTI_PRODUCT').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isTrue);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], {'PROD_SPANISH': 3});
    });

    test('5. Hot and Iced variants combine and share quota and overdraft together', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 3,
        'isEnabled': true,
      });

      final hotItem = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      final icedItem = CartItemModel(
        id: 'PROD_SPANISH_Iced_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Iced',
        unitPrice: 130.0,
        quantity: 3,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [hotItem, icedItem],
        totalAmount: 630.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_VARIANTS_SHARED',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 0);

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_OFFLINE_VARIANTS_SHARED', 'PROD_SPANISH'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 5); // 2 + 3
      expect(ledger.deductedQuantity, 3);
      expect(ledger.overdraftQuantity, 2);
      expect(ledger.newRemaining, 0);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_VARIANTS_SHARED').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isTrue);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], {'PROD_SPANISH': 2});
    });

    test('6. Missing quota falls back to physical inventory without error', () async {
      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_MISSING_QUOTA',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_MISSING_QUOTA').get();
      expect(saleDoc.exists, isTrue);
      expect(saleDoc.data()!['inventoryDeducted'], isTrue);
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);

      final invDoc = await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').get();
      expect(invDoc.data()!['quantity'], 5000.0 - 36.0); // 2 * 18g

      final ledgers = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgers.docs, isEmpty);
    });

    test('7. Disabled quota skips deduction and does not overdraft', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 1,
        'isEnabled': false,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 480.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_DISABLED_QUOTA',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 1); // Not changed

      final ledgers = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgers.docs, isEmpty);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_DISABLED_QUOTA').get();
      expect(saleDoc.exists, isTrue);
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);
    });

    test('8. Duplicate sync does not deduct twice (clientSaleId idempotency)', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 480.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_DUP_SYNC',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc1 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc1.data()!['remainingServings'], 6);

      // Re-run sync or addTransaction with same clientSaleId
      final retryTx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 480.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_DUP_SYNC',
      );

      expect(retryTx.transactionId, 'SALE_OFFLINE_DUP_SYNC');

      final qDoc2 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc2.data()!['remainingServings'], 6); // Still 6, not 2
    });

    test('9. FIFO queue preservation across multiple queued orders', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 4,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3,
      );

      // Queue Order 1 (needs 3)
      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 360.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_FIFO_1',
      );

      // Queue Order 2 (needs 3)
      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 360.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_FIFO_2',
      );

      expect(transactionsProvider.pendingOfflineCount, 2);

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      expect(transactionsProvider.pendingOfflineCount, 0);

      // Order 1 was synced first: 4 - 3 = 1 remaining, overdraft = 0
      final ledger1Doc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_FIFO_1', 'PROD_SPANISH'),
      ).get();
      final ledger1 = QuotaTransactionModel.fromMap(ledger1Doc.id, ledger1Doc.data()!);
      expect(ledger1.requestedQuantity, 3);
      expect(ledger1.deductedQuantity, 3);
      expect(ledger1.overdraftQuantity, 0);
      expect(ledger1.previousRemaining, 4);
      expect(ledger1.newRemaining, 1);

      // Order 2 was synced second: 1 - 1 = 0 remaining, overdraft = 2
      final ledger2Doc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_FIFO_2', 'PROD_SPANISH'),
      ).get();
      final ledger2 = QuotaTransactionModel.fromMap(ledger2Doc.id, ledger2Doc.data()!);
      expect(ledger2.requestedQuantity, 3);
      expect(ledger2.deductedQuantity, 1);
      expect(ledger2.overdraftQuantity, 2);
      expect(ledger2.previousRemaining, 1);
      expect(ledger2.newRemaining, 0);

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 0);
    });

    test('10. Failed physical inventory on offline sync rolls back cleanly', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      // Deplete inventory of beans to 0
      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').update({
        'quantity': 0.0,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_INV_FAIL',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      // Quota doc must NOT be modified
      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 10);

      // Sale doc must NOT exist
      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_INV_FAIL').get();
      expect(saleDoc.exists, isFalse);

      // Quota ledger must NOT exist
      final ledgers = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgers.docs, isEmpty);

      // Order should remain in pending queue with syncError
      expect(transactionsProvider.pendingOfflineCount, 1);
    });

    test('11. Sale metadata fields match ledger records', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 1,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 360.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_METADATA_MATCH',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_METADATA_MATCH').get();
      final saleData = saleDoc.data()!;
      expect(saleData['hasManualQuotaOverdraft'], isTrue);
      expect(saleData['manualQuotaOverdrafts'], {'PROD_SPANISH': 2});
      expect(saleData['notes'], '[OFFLINE OVERDRAFT] Spanish Latte (2 servings over quota)');

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_METADATA_MATCH', 'PROD_SPANISH'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.overdraftQuantity, saleData['manualQuotaOverdrafts']['PROD_SPANISH']);
      expect(ledger.deductedQuantity, 1);
      expect(ledger.requestedQuantity, 3);
    });

    test('12. Offline order with zero remaining servings records full requested quantity as overdraft and remaining stays 0', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 0,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 480.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_ZERO_REMAINING_OVERDRAFT',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 0);

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_ZERO_REMAINING_OVERDRAFT', 'PROD_SPANISH'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 4);
      expect(ledger.deductedQuantity, 0);
      expect(ledger.overdraftQuantity, 4);
      expect(ledger.previousRemaining, 0);
      expect(ledger.newRemaining, 0);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_ZERO_REMAINING_OVERDRAFT').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isTrue);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], {'PROD_SPANISH': 4});
    });

    test('13. No-overdraft offline order records hasManualQuotaOverdraft: false and empty map', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 20,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_NO_OVERDRAFT',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_NO_OVERDRAFT').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], isEmpty);
      expect(saleDoc.data()!['notes'], isNull);
    });

    test('14. Existing financial totals, COGS, gross profit, and payment method remain intact during overdraft sync', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 1,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3,
      );

      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 360.0,
        paymentMethod: 'GCash',
        gcashReference: 'GCASH-SYNC-REF-123',
        clientSaleId: 'SALE_FINANCIALS_OVERDRAFT',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_FINANCIALS_OVERDRAFT').get();
      final data = saleDoc.data()!;

      expect(data['totalAmount'], 360.0);
      expect(data['subtotal'], 360.0);
      expect(data['total'], 360.0);
      expect(data['paymentMethod'], 'GCash');
      expect(data['gcashReference'], 'GCASH-SYNC-REF-123');
      expect(data['cogs'], isNotNull);
      expect(data['grossProfit'], isNotNull);
      expect(data['grossProfit'], 360.0 - (data['cogs'] as num).toDouble());
      expect(data['hasManualQuotaOverdraft'], isTrue);
      expect(data['manualQuotaOverdrafts'], {'PROD_SPANISH': 2});
    });
  });

  group('Checkpoint 6.2.1: Explicit Offline Classification Regression Verification', () {
    late FakeFirebaseFirestore fakeDb;
    late InventoryDocumentResolver resolver;
    late InMemoryOfflineOrderStorage storage;
    late TransactionsProvider transactionsProvider;
    bool isOnline = true;

    const testBranchId = 'br_1790905840872';
    const testBranchName = 'Santa Cruz Branch';

    final prodSpanishLatte = ProductModel(
      productId: 'PROD_SPANISH',
      name: 'Spanish Latte',
      category: ProductCategory.coffee,
      description: 'Espresso with sweet milk',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [testBranchId],
      pricing: const ProductPricing(
        hotPrice: 120.0,
        icedPrice: 130.0,
      ),
      recipeId: 'rec_spanish_latte',
    );

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      resolver = InventoryDocumentResolver(firestore: fakeDb);
      storage = InMemoryOfflineOrderStorage();
      isOnline = true;

      transactionsProvider = TransactionsProvider(
        firestore: fakeDb,
        resolver: resolver,
        offlineStorage: storage,
        checkIsOnline: () async => isOnline,
      );
      await transactionsProvider.bindToBranch(testBranchId);

      // Seed Spanish Latte recipe
      await fakeDb.collection(FirebasePaths.recipes).doc('rec_spanish_latte').set({
        'productId': 'PROD_SPANISH',
        'productName': 'Spanish Latte',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'temperature': 'both',
            'category': 'ingredient',
            'unitCost': 0.8,
          },
          {
            'ingredientId': 'ing_milk',
            'ingredientName': 'Fresh Milk',
            'quantity': 150.0,
            'unit': 'ml',
            'temperature': 'both',
            'category': 'ingredient',
            'unitCost': 0.1,
          },
          {
            'ingredientId': 'pkg_cup',
            'ingredientName': 'Coffee Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'both',
            'category': 'packaging',
            'unitCost': 2.5,
          },
        ],
      });

      // Seed branch physical inventory
      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').set({
        'branchId': testBranchId,
        'ingredientId': 'ing_beans',
        'name': 'Espresso Beans',
        'quantity': 5000.0,
        'unit': 'g',
      });

      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_milk').set({
        'branchId': testBranchId,
        'ingredientId': 'ing_milk',
        'name': 'Fresh Milk',
        'quantity': 5000.0,
        'unit': 'ml',
      });

      await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_pkg_cup').set({
        'branchId': testBranchId,
        'ingredientId': 'pkg_cup',
        'name': 'Coffee Cup',
        'quantity': 500.0,
        'unit': 'pcs',
      });
    });

    test('1. Online sale with insufficient quota is rejected', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 5,
      );

      expect(
        () => transactionsProvider.addTransaction(
          branchId: testBranchId,
          branchName: testBranchName,
          items: [item],
          totalAmount: 600.0,
          paymentMethod: 'Cash',
          clientSaleId: 'SALE_ONLINE_INSUFFICIENT',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Insufficient manual quota for "Spanish Latte"'),
        )),
      );

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 2);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_ONLINE_INSUFFICIENT').get();
      expect(saleDoc.exists, isFalse);

      final ledgers = await fakeDb.collection(FirebasePaths.quotaTransactions).get();
      expect(ledgers.docs, isEmpty);
    });

    test('2. Online sale with sufficient quota deducts normally', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 480.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_ONLINE_SUFFICIENT',
      );

      expect(tx.status, 'Completed');

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 6);
      expect(qDoc.data()!['lastSaleId'], 'SALE_ONLINE_SUFFICIENT');

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_ONLINE_SUFFICIENT').get();
      expect(saleDoc.exists, isTrue);
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], isEmpty);

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_ONLINE_SUFFICIENT', 'PROD_SPANISH'),
      ).get();
      expect(ledgerDoc.exists, isTrue);
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 4);
      expect(ledger.deductedQuantity, 4);
      expect(ledger.overdraftQuantity, 0);
      expect(ledger.newRemaining, 6);
      expect(ledger.isOfflineSync, isFalse);
    });

    test('3. Online sale with an orderTimestamp still uses strict quota enforcement', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final itemOver = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3, // exceeds remaining 2
      );

      final explicitTimestamp = DateTime(2026, 11, 18, 9, 30);

      // Even with an explicit orderTimestamp, an online sale MUST reject insufficient quota
      expect(
        () => transactionsProvider.addTransaction(
          branchId: testBranchId,
          branchName: testBranchName,
          items: [itemOver],
          totalAmount: 360.0,
          paymentMethod: 'Cash',
          clientSaleId: 'SALE_ONLINE_TIMESTAMP_FAIL',
          orderTimestamp: explicitTimestamp,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Insufficient manual quota for "Spanish Latte"'),
        )),
      );

      final qDocBefore = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDocBefore.data()!['remainingServings'], 2);

      // Now with sufficient quantity (2 requested <= 2 available)
      final itemOk = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [itemOk],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_ONLINE_TIMESTAMP_OK',
        orderTimestamp: explicitTimestamp,
      );

      expect(tx.status, 'Completed');
      expect(tx.timestamp, explicitTimestamp);

      final qDocAfter = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDocAfter.data()!['remainingServings'], 0);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_ONLINE_TIMESTAMP_OK').get();
      expect(saleDoc.exists, isTrue);
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], isEmpty);

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_ONLINE_TIMESTAMP_OK', 'PROD_SPANISH'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.isOfflineSync, isFalse);
      expect(ledger.overdraftQuantity, 0);
      expect(ledger.deductedQuantity, 2);
    });

    test('4. Offline queued sale with insufficient quota records an overdraft', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 2,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 5,
      );

      // Rung up while offline
      isOnline = false;
      final pendingTx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 600.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_VERIF_OVERDRAFT',
      );

      expect(pendingTx.status, 'Pending Sync');
      expect(transactionsProvider.pendingOfflineCount, 1);

      // Synchronize online
      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      expect(transactionsProvider.pendingOfflineCount, 0);

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 0);

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_OFFLINE_VERIF_OVERDRAFT', 'PROD_SPANISH'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 5);
      expect(ledger.deductedQuantity, 2);
      expect(ledger.overdraftQuantity, 3);
      expect(ledger.newRemaining, 0);
      expect(ledger.isOfflineSync, isTrue);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_VERIF_OVERDRAFT').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isTrue);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], {'PROD_SPANISH': 3});
      expect(saleDoc.data()!['notes'], contains('[OFFLINE OVERDRAFT]'));
    });

    test('5. Offline queued sale with sufficient quota deducts normally', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3,
      );

      isOnline = false;
      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 360.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_VERIF_SUFFICIENT',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      expect(transactionsProvider.pendingOfflineCount, 0);

      final qDoc = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc.data()!['remainingServings'], 7);

      final ledgerDoc = await fakeDb.collection(FirebasePaths.quotaTransactions).doc(
        QuotaTransactionModel.buildTransactionId('SALE_OFFLINE_VERIF_SUFFICIENT', 'PROD_SPANISH'),
      ).get();
      final ledger = QuotaTransactionModel.fromMap(ledgerDoc.id, ledgerDoc.data()!);
      expect(ledger.requestedQuantity, 3);
      expect(ledger.deductedQuantity, 3);
      expect(ledger.overdraftQuantity, 0);
      expect(ledger.newRemaining, 7);
      expect(ledger.isOfflineSync, isTrue);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_OFFLINE_VERIF_SUFFICIENT').get();
      expect(saleDoc.data()!['hasManualQuotaOverdraft'], isFalse);
      expect(saleDoc.data()!['manualQuotaOverdrafts'], isEmpty);
    });

    test('6. Retried offline sale does not deduct twice', () async {
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 10,
        'isEnabled': true,
      });

      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      isOnline = false;
      await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 480.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_RETRY_CHECK',
      );

      isOnline = true;
      await transactionsProvider.syncPendingOrders();
      await pumpEventQueue();

      final qDoc1 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc1.data()!['remainingServings'], 6);

      // Simulate a network retry of the same sale
      final retryTx = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 480.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_OFFLINE_RETRY_CHECK',
      );

      expect(retryTx.transactionId, 'SALE_OFFLINE_RETRY_CHECK');

      final qDoc2 = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDoc2.data()!['remainingServings'], 6); // Not decremented again

      final salesQuery = await fakeDb.collection(FirebasePaths.sales).where('clientSaleId', isEqualTo: 'SALE_OFFLINE_RETRY_CHECK').get();
      expect(salesQuery.docs.length, 1);
    });

    test('7. Missing or disabled quota preserves existing fallback behavior', () async {
      final item = CartItemModel(
        id: 'PROD_SPANISH_Hot_none',
        product: prodSpanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      // Part A: Missing quota document falls back to physical inventory
      final txMissing = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_FALLBACK_MISSING',
      );

      expect(txMissing.status, 'Completed');
      final invDoc1 = await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').get();
      expect(invDoc1.data()!['quantity'], 5000.0 - 36.0); // 36g deducted

      // Part B: Disabled quota document falls back to physical inventory without deduction
      final quotaDocId = BranchProductServingModel.buildDocumentId(testBranchId, 'PROD_SPANISH');
      await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).set({
        'branchId': testBranchId,
        'productId': 'PROD_SPANISH',
        'manualMaxServings': 50,
        'remainingServings': 1,
        'isEnabled': false,
      });

      final txDisabled = await transactionsProvider.addTransaction(
        branchId: testBranchId,
        branchName: testBranchName,
        items: [item],
        totalAmount: 240.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_FALLBACK_DISABLED',
      );

      expect(txDisabled.status, 'Completed');
      final qDocDisabled = await fakeDb.collection(FirebasePaths.branchProductServings).doc(quotaDocId).get();
      expect(qDocDisabled.data()!['remainingServings'], 1); // Quota doc untouched

      final invDoc2 = await fakeDb.collection(FirebasePaths.inventory).doc('inv_${testBranchId}_ing_beans').get();
      expect(invDoc2.data()!['quantity'], 5000.0 - 72.0); // Further 36g deducted
    });
  });
}
