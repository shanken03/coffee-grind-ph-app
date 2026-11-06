import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/models/cart_item_model.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/providers/transactions_provider.dart';
import 'package:coffee_grind_ph/services/inventory_resolver.dart';

void main() {
  group('POS Checkout In-Memory Integration Tests (FakeFirebaseFirestore)', () {
    late FakeFirebaseFirestore fakeDb;
    late InventoryDocumentResolver resolver;
    late TransactionsProvider transactionsProvider;

    const branchA = 'test_branch_a';
    const branchB = 'test_branch_b';

    // Products
    final prodAmericano = ProductModel(
      productId: 'PROD_AMERICANO',
      name: 'Americano',
      category: ProductCategory.coffee,
      description: 'Espresso with hot/cold water',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [branchA, branchB],
      pricing: const ProductPricing(
        hotPrice: 100.0,
        icedPrice: 110.0,
      ),
      recipeId: 'rec_americano',
    );

    final prodSpanishLatte = ProductModel(
      productId: 'PROD_SPANISH',
      name: 'Spanish Latte',
      category: ProductCategory.coffee,
      description: 'Espresso, milk, and spanish syrup',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [branchA, branchB],
      pricing: const ProductPricing(
        hotPrice: 120.0,
        icedPrice: 130.0,
      ),
      recipeId: 'rec_spanish_latte',
    );

    final prodBiscoff = ProductModel(
      productId: 'PROD_BISCOFF',
      name: 'Biscoff Latte',
      category: ProductCategory.coffee,
      description: 'Cold-only Biscoff latte',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [branchA, branchB],
      pricing: const ProductPricing(
        icedPrice: 140.0,
        hotPrice: null, // Iced only
      ),
      recipeId: 'rec_biscoff_latte',
    );

    final prodCroissant = ProductModel(
      productId: 'PROD_CROISSANT',
      name: 'Butter Croissant',
      category: ProductCategory.sweets,
      description: 'Fresh butter pastry',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [branchA, branchB],
      pricing: const ProductPricing(
        flatPrice: 85.0,
      ),
      recipeId: null, // Food/Sweets currently lack recipes in DB
    );

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      resolver = InventoryDocumentResolver(firestore: fakeDb);
      transactionsProvider = TransactionsProvider(
        firestore: fakeDb,
        resolver: resolver,
      );

      // Seed recipes in fake Firestore
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
          },
          {
            'ingredientId': 'pkg_12oz_cup',
            'ingredientName': '12oz Hot Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'hot',
            'category': 'packaging',
          },
          {
            'ingredientId': 'pkg_hot_lid',
            'ingredientName': 'Hot Cup Lid',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'hot',
            'category': 'packaging',
          },
          {
            'ingredientId': 'pkg_16oz_cup',
            'ingredientName': '16oz Iced Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
          {
            'ingredientId': 'pkg_iced_lid',
            'ingredientName': 'Iced Cup Lid',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
          {
            'ingredientId': 'pkg_straw',
            'ingredientName': 'Paper Straw',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
        ],
      });

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
          },
          {
            'ingredientId': 'ing_milk',
            'ingredientName': 'Fresh Dairy Milk',
            'quantity': 150.0,
            'unit': 'ml',
            'temperature': 'both',
            'category': 'ingredient',
          },
          {
            'ingredientId': 'ing_spanish_syrup',
            'ingredientName': 'Spanish Syrup',
            'quantity': 20.0,
            'unit': 'ml',
            'temperature': 'both',
            'category': 'ingredient',
          },
          {
            'ingredientId': 'pkg_16oz_cup',
            'ingredientName': '16oz Iced Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
          {
            'ingredientId': 'pkg_iced_lid',
            'ingredientName': 'Iced Cup Lid',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
          {
            'ingredientId': 'pkg_straw',
            'ingredientName': 'Paper Straw',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
        ],
      });

      await fakeDb.collection(FirebasePaths.recipes).doc('rec_biscoff_latte').set({
        'productId': 'PROD_BISCOFF',
        'productName': 'Biscoff Latte',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'temperature': 'iced',
            'category': 'ingredient',
          },
          {
            'ingredientId': 'ing_milk',
            'ingredientName': 'Fresh Dairy Milk',
            'quantity': 150.0,
            'unit': 'ml',
            'temperature': 'iced',
            'category': 'ingredient',
          },
          {
            'ingredientId': 'ing_biscoff_spread',
            'ingredientName': 'Biscoff Spread',
            'quantity': 20.0,
            'unit': 'g',
            'temperature': 'iced',
            'category': 'ingredient',
          },
          {
            'ingredientId': 'ing_biscoff_crumbs',
            'ingredientName': 'Biscoff Crumbs',
            'quantity': 10.0,
            'unit': 'g',
            'temperature': 'iced',
            'category': 'ingredient',
          },
          {
            'ingredientId': 'pkg_16oz_cup',
            'ingredientName': '16oz Iced Cup',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
          {
            'ingredientId': 'pkg_iced_lid',
            'ingredientName': 'Iced Cup Lid',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
          {
            'ingredientId': 'pkg_straw',
            'ingredientName': 'Paper Straw',
            'quantity': 1.0,
            'unit': 'pcs',
            'temperature': 'iced',
            'category': 'packaging',
          },
        ],
      });

      // Seed inventory for Branch A
      final branchAInventory = {
        '${branchA}_ing_beans': {'quantity': 1000.0, 'unit': 'g', 'ingredientId': 'ing_beans', 'branchId': branchA, 'ingredientName': 'Espresso Beans'},
        '${branchA}_ing_milk': {'quantity': 2000.0, 'unit': 'ml', 'ingredientId': 'ing_milk', 'branchId': branchA, 'ingredientName': 'Fresh Dairy Milk'},
        '${branchA}_ing_spanish_syrup': {'quantity': 500.0, 'unit': 'ml', 'ingredientId': 'ing_spanish_syrup', 'branchId': branchA, 'ingredientName': 'Spanish Syrup'},
        '${branchA}_ing_biscoff_spread': {'quantity': 500.0, 'unit': 'g', 'ingredientId': 'ing_biscoff_spread', 'branchId': branchA, 'ingredientName': 'Biscoff Spread'},
        '${branchA}_ing_biscoff_crumbs': {'quantity': 500.0, 'unit': 'g', 'ingredientId': 'ing_biscoff_crumbs', 'branchId': branchA, 'ingredientName': 'Biscoff Crumbs'},
        '${branchA}_pkg_12oz_cup': {'quantity': 100.0, 'unit': 'pcs', 'ingredientId': 'pkg_12oz_cup', 'branchId': branchA, 'ingredientName': '12oz Hot Cup'},
        '${branchA}_pkg_hot_lid': {'quantity': 100.0, 'unit': 'pcs', 'ingredientId': 'pkg_hot_lid', 'branchId': branchA, 'ingredientName': 'Hot Cup Lid'},
        '${branchA}_pkg_16oz_cup': {'quantity': 100.0, 'unit': 'pcs', 'ingredientId': 'pkg_16oz_cup', 'branchId': branchA, 'ingredientName': '16oz Iced Cup'},
        '${branchA}_pkg_iced_lid': {'quantity': 100.0, 'unit': 'pcs', 'ingredientId': 'pkg_iced_lid', 'branchId': branchA, 'ingredientName': 'Iced Cup Lid'},
        '${branchA}_pkg_straw': {'quantity': 100.0, 'unit': 'pcs', 'ingredientId': 'pkg_straw', 'branchId': branchA, 'ingredientName': 'Paper Straw'},
      };

      for (final entry in branchAInventory.entries) {
        await fakeDb.collection(FirebasePaths.inventory).doc(entry.key).set(entry.value);
      }

      // Seed inventory for Branch B (isolation test)
      final branchBInventory = {
        '${branchB}_ing_beans': {'quantity': 5000.0, 'unit': 'g', 'ingredientId': 'ing_beans', 'branchId': branchB, 'ingredientName': 'Espresso Beans'},
        '${branchB}_pkg_16oz_cup': {'quantity': 500.0, 'unit': 'pcs', 'ingredientId': 'pkg_16oz_cup', 'branchId': branchB, 'ingredientName': '16oz Iced Cup'},
      };

      for (final entry in branchBInventory.entries) {
        await fakeDb.collection(FirebasePaths.inventory).doc(entry.key).set(entry.value);
      }

      // Seed branch_product_stock for test branches
      final stockDocs = {
        '${branchA}_${prodAmericano.productId}': {
          'branchId': branchA,
          'productId': prodAmericano.productId,
          'remainingServings': 50,
          'maxServings': 50,
        },
        '${branchA}_${prodSpanishLatte.productId}': {
          'branchId': branchA,
          'productId': prodSpanishLatte.productId,
          'remainingServings': 50,
          'maxServings': 50,
        },
        '${branchA}_${prodBiscoff.productId}': {
          'branchId': branchA,
          'productId': prodBiscoff.productId,
          'remainingServings': 50,
          'maxServings': 50,
        },
        '${branchB}_${prodAmericano.productId}': {
          'branchId': branchB,
          'productId': prodAmericano.productId,
          'remainingServings': 50,
          'maxServings': 50,
        },
      };

      for (final entry in stockDocs.entries) {
        await fakeDb.collection(FirebasePaths.branchProductStock).doc(entry.key).set(entry.value);
      }
    });

    test('1. Successful checkout of one sellable serving with a known recipe deducts ingredients and packaging', () async {
      final cartItem = CartItemModel(
        id: 'cart_1',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: branchA,
        branchName: 'Branch A',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'Cash',
      );

      expect(tx.transactionId, isNotEmpty);
      expect(tx.totalAmount, 100.0);

      // Verify inventory deductions for Hot Americano (18g beans, 1 hot cup, 1 hot lid)
      final beansSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_beans').get();
      expect(beansSnap.data()?['quantity'], 982.0); // 1000 - 18

      final cupSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_12oz_cup').get();
      expect(cupSnap.data()?['quantity'], 99.0); // 100 - 1

      final lidSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_hot_lid').get();
      expect(lidSnap.data()?['quantity'], 99.0); // 100 - 1

      // Verify cold packaging was NOT touched
      final icedCupSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_16oz_cup').get();
      expect(icedCupSnap.data()?['quantity'], 100.0);

      final strawSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_straw').get();
      expect(strawSnap.data()?['quantity'], 100.0);
    });

    test('2. Aggregated deductions: multiple products sharing the same ingredient combine quantities into one batch write', () async {
      // 2x Hot Americano (36g beans) + 1x Iced Spanish Latte (18g beans, 150ml milk, 20ml syrup)
      final item1 = CartItemModel(
        id: 'cart_1',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 2,
      );
      final item2 = CartItemModel(
        id: 'cart_2',
        product: prodSpanishLatte,
        selectedTemperature: 'Iced',
        unitPrice: 130.0,
        quantity: 1,
      );

      await transactionsProvider.addTransaction(
        branchId: branchA,
        branchName: 'Branch A',
        items: [item1, item2],
        totalAmount: 330.0,
        paymentMethod: 'Cash',
      );

      // Total beans required = 2 * 18 + 1 * 18 = 54g
      final beansSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_beans').get();
      expect(beansSnap.data()?['quantity'], 946.0); // 1000 - 54

      // Milk deducted = 150ml
      final milkSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_milk').get();
      expect(milkSnap.data()?['quantity'], 1850.0); // 2000 - 150

      // Spanish syrup deducted = 20ml
      final syrupSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_spanish_syrup').get();
      expect(syrupSnap.data()?['quantity'], 480.0); // 500 - 20
    });

    test('3. Packaging deduction: hot vs iced items deduct respective packaging requirements', () async {
      final hotItem = CartItemModel(
        id: 'cart_hot',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );
      final icedItem = CartItemModel(
        id: 'cart_iced',
        product: prodAmericano,
        selectedTemperature: 'Iced',
        unitPrice: 110.0,
        quantity: 1,
      );

      await transactionsProvider.addTransaction(
        branchId: branchA,
        branchName: 'Branch A',
        items: [hotItem, icedItem],
        totalAmount: 210.0,
        paymentMethod: 'Cash',
      );

      // Hot cup & lid deducted by 1
      final hotCupSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_12oz_cup').get();
      expect(hotCupSnap.data()?['quantity'], 99.0);

      final hotLidSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_hot_lid').get();
      expect(hotLidSnap.data()?['quantity'], 99.0);

      // Iced cup, lid, straw deducted by 1
      final icedCupSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_16oz_cup').get();
      expect(icedCupSnap.data()?['quantity'], 99.0);

      final icedLidSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_iced_lid').get();
      expect(icedLidSnap.data()?['quantity'], 99.0);

      final strawSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_straw').get();
      expect(strawSnap.data()?['quantity'], 99.0);
    });

    test('4. Iced-only products deduct only iced recipe requirements even if selectedTemperature is null', () async {
      // Added without explicit temperature in cart
      final icedOnlyItem = CartItemModel(
        id: 'cart_biscoff',
        product: prodBiscoff,
        selectedTemperature: null, // Should resolve via prodBiscoff.fixedTemperature == 'Iced'
        unitPrice: 140.0,
        quantity: 1,
      );

      await transactionsProvider.addTransaction(
        branchId: branchA,
        branchName: 'Branch A',
        items: [icedOnlyItem],
        totalAmount: 140.0,
        paymentMethod: 'GCash',
      );

      // Cold items deducted
      final spreadSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_biscoff_spread').get();
      expect(spreadSnap.data()?['quantity'], 480.0); // 500 - 20

      final crumbsSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_biscoff_crumbs').get();
      expect(crumbsSnap.data()?['quantity'], 490.0); // 500 - 10

      final icedCupSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_16oz_cup').get();
      expect(icedCupSnap.data()?['quantity'], 99.0);

      // Hot items NOT deducted
      final hotCupSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_pkg_12oz_cup').get();
      expect(hotCupSnap.data()?['quantity'], 100.0);
    });

    test('5. Branch isolation: Branch A checkout never deducts or affects Branch B inventory', () async {
      final cartItem = CartItemModel(
        id: 'cart_branch_a',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );

      await transactionsProvider.addTransaction(
        branchId: branchA,
        branchName: 'Branch A',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'Cash',
      );

      // Branch A deducted
      final branchABeans = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_beans').get();
      expect(branchABeans.data()?['quantity'], 982.0);

      // Branch B completely unchanged
      final branchBBeans = await fakeDb.collection(FirebasePaths.inventory).doc('${branchB}_ing_beans').get();
      expect(branchBBeans.data()?['quantity'], 5000.0);

      final branchBCups = await fakeDb.collection(FirebasePaths.inventory).doc('${branchB}_pkg_16oz_cup').get();
      expect(branchBCups.data()?['quantity'], 500.0);
    });

    test('6. Insufficient stock aborts checkout cleanly and writes zero Firestore records', () async {
      // Reduce milk stock to 50ml at Branch A
      await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_milk').update({'quantity': 50.0});

      final cartItem = CartItemModel(
        id: 'cart_spanish',
        product: prodSpanishLatte,
        selectedTemperature: 'Iced',
        unitPrice: 130.0,
        quantity: 1, // Requires 150ml milk
      );

      expect(
        () => transactionsProvider.addTransaction(
          branchId: branchA,
          branchName: 'Branch A',
          items: [cartItem],
          totalAmount: 130.0,
          paymentMethod: 'Cash',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Insufficient branch stock for "Fresh Dairy Milk": required 150.0 ml, but only 50.0 ml available'),
          ),
        ),
      );

      // Verify zero sales records written
      final salesSnap = await fakeDb.collection(FirebasePaths.sales).get();
      expect(salesSnap.docs, isEmpty);

      // Verify inventory milk balance remains 50.0 (untouched)
      final milkSnap = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_milk').get();
      expect(milkSnap.data()?['quantity'], 50.0);

      // Verify zero audit transactions written
      final txSnap = await fakeDb.collection(FirebasePaths.inventoryTransactions).get();
      expect(txSnap.docs, isEmpty);
    });

    test('7. Missing inventory record aborts checkout cleanly and writes zero records', () async {
      // Delete beans document at Branch A
      await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_beans').delete();

      final cartItem = CartItemModel(
        id: 'cart_americano',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );

      expect(
        () => transactionsProvider.addTransaction(
          branchId: branchA,
          branchName: 'Branch A',
          items: [cartItem],
          totalAmount: 100.0,
          paymentMethod: 'Cash',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Missing inventory record for ingredient "Espresso Beans" at branch "Branch A"'),
          ),
        ),
      );

      // Verify zero writes
      final salesSnap = await fakeDb.collection(FirebasePaths.sales).get();
      expect(salesSnap.docs, isEmpty);
    });

    test('8. Ambiguous duplicate inventory records abort checkout cleanly for safety', () async {
      // Create duplicate beans record with same branchId and ingredientId
      await fakeDb.collection(FirebasePaths.inventory).doc('doc_duplicate_beans').set({
        'branchId': branchA,
        'ingredientId': 'ing_beans',
        'quantity': 500.0,
        'unit': 'g',
        'ingredientName': 'Espresso Beans',
      });

      // Also ensure direct canonical lookup falls through to field query to trigger duplicate check
      await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_beans').delete();
      await fakeDb.collection(FirebasePaths.inventory).doc('doc_duplicate_beans_2').set({
        'branchId': branchA,
        'ingredientId': 'ing_beans',
        'quantity': 600.0,
        'unit': 'g',
        'ingredientName': 'Espresso Beans',
      });

      final cartItem = CartItemModel(
        id: 'cart_americano',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );

      expect(
        () => transactionsProvider.addTransaction(
          branchId: branchA,
          branchName: 'Branch A',
          items: [cartItem],
          totalAmount: 100.0,
          paymentMethod: 'Cash',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Ambiguous inventory records (2 found) for ingredient "Espresso Beans" at branch "Branch A". Checkout aborted for safety.'),
          ),
        ),
      );

      final salesSnap = await fakeDb.collection(FirebasePaths.sales).get();
      expect(salesSnap.docs, isEmpty);
    });

    test('9. Repeated submission / clientSaleId idempotency prevents duplicate sales and deductions', () async {
      const clientTxId = 'CLIENT_SALE_UUID_9999';

      final cartItem = CartItemModel(
        id: 'cart_americano',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );

      // First submission
      final tx1 = await transactionsProvider.addTransaction(
        branchId: branchA,
        branchName: 'Branch A',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'Cash',
        clientSaleId: clientTxId,
      );

      // Verify beans deducted by 18g (1000 -> 982)
      final beansSnap1 = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_beans').get();
      expect(beansSnap1.data()?['quantity'], 982.0);

      // Second identical submission (e.g. network retry or rapid tap)
      final tx2 = await transactionsProvider.addTransaction(
        branchId: branchA,
        branchName: 'Branch A',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'Cash',
        clientSaleId: clientTxId,
      );

      // Expect identical transaction model returned
      expect(tx2.transactionId, tx1.transactionId);

      // Verify inventory was NOT deducted a second time (still 982.0, not 964.0)
      final beansSnap2 = await fakeDb.collection(FirebasePaths.inventory).doc('${branchA}_ing_beans').get();
      expect(beansSnap2.data()?['quantity'], 982.0);

      // Exactly 1 sale document in collection
      final salesSnap = await fakeDb.collection(FirebasePaths.sales).get();
      expect(salesSnap.docs.length, 1);
    });

    test('10. Sale record, inventory deduction, and inventory_transactions audit log remain completely consistent', () async {
      final cartItem = CartItemModel(
        id: 'cart_americano',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: branchA,
        branchName: 'Branch A',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'Cash',
      );

      // Check sale record
      final saleSnap = await fakeDb
          .collection(FirebasePaths.sales)
          .where('saleId', isEqualTo: tx.transactionId)
          .get();
      expect(saleSnap.docs.isNotEmpty, isTrue);
      final saleData = saleSnap.docs.first.data();
      expect(saleData['total'], 100.0);
      expect(saleData['status'], 'Completed');
      expect(saleData['inventoryDeducted'], isTrue);
      expect(saleData['branchId'], branchA);

      // Check inventory_transactions audit logs (3 items for Hot Americano: beans, cup, lid)
      final auditSnap = await fakeDb
          .collection(FirebasePaths.inventoryTransactions)
          .where('saleId', isEqualTo: tx.transactionId)
          .get();

      expect(auditSnap.docs.length, 3);
      for (final doc in auditSnap.docs) {
        final d = doc.data();
        expect(d['type'], 'sale');
        expect(d['branchId'], branchA);
        expect(d['saleId'], tx.transactionId);
        expect(d['change'], isNegative);
      }
    });

    test('11. Food and sweets products without recipes fail cleanly without writing partial transactions (Documented Existing Behavior)', () async {
      final croissantItem = CartItemModel(
        id: 'cart_croissant',
        product: prodCroissant,
        unitPrice: 85.0,
        quantity: 1,
      );

      expect(
        () => transactionsProvider.addTransaction(
          branchId: branchA,
          branchName: 'Branch A',
          items: [croissantItem],
          totalAmount: 85.0,
          paymentMethod: 'Cash',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Cannot complete sale: Missing recipe configuration for "Butter Croissant"'),
          ),
        ),
      );

      // Verify zero writes
      final salesSnap = await fakeDb.collection(FirebasePaths.sales).get();
      expect(salesSnap.docs, isEmpty);
      final txSnap = await fakeDb.collection(FirebasePaths.inventoryTransactions).get();
      expect(txSnap.docs, isEmpty);
    });

    test('12. Idempotency query scopes by branchId and clientSaleId for both Santa Cruz and LSPU dynamically', () async {
      const scBranchId = 'br_1790905840872';
      const lspuBranchId = 'br_1790923872261';

      // Seed Santa Cruz inventory
      await fakeDb.collection(FirebasePaths.inventory).doc('${scBranchId}_ing_beans').set({
        'branchId': scBranchId,
        'ingredientId': 'ing_beans',
        'ingredientName': 'Espresso Beans',
        'quantity': 1000.0,
        'unit': 'g',
        'availableQuantity': 1000.0,
      });
      await fakeDb.collection(FirebasePaths.inventory).doc('${scBranchId}_pkg_12oz_cup').set({
        'branchId': scBranchId,
        'ingredientId': 'pkg_12oz_cup',
        'ingredientName': '12oz Hot Cup',
        'quantity': 100.0,
        'unit': 'pcs',
        'availableQuantity': 100.0,
      });
      await fakeDb.collection(FirebasePaths.inventory).doc('${scBranchId}_pkg_hot_lid').set({
        'branchId': scBranchId,
        'ingredientId': 'pkg_hot_lid',
        'ingredientName': 'Hot Lid',
        'quantity': 100.0,
        'unit': 'pcs',
        'availableQuantity': 100.0,
      });

      // Seed LSPU inventory
      await fakeDb.collection(FirebasePaths.inventory).doc('${lspuBranchId}_ing_beans').set({
        'branchId': lspuBranchId,
        'ingredientId': 'ing_beans',
        'ingredientName': 'Espresso Beans',
        'quantity': 1000.0,
        'unit': 'g',
        'availableQuantity': 1000.0,
      });
      await fakeDb.collection(FirebasePaths.inventory).doc('${lspuBranchId}_pkg_12oz_cup').set({
        'branchId': lspuBranchId,
        'ingredientId': 'pkg_12oz_cup',
        'ingredientName': '12oz Hot Cup',
        'quantity': 100.0,
        'unit': 'pcs',
        'availableQuantity': 100.0,
      });
      await fakeDb.collection(FirebasePaths.inventory).doc('${lspuBranchId}_pkg_hot_lid').set({
        'branchId': lspuBranchId,
        'ingredientId': 'pkg_hot_lid',
        'ingredientName': 'Hot Lid',
        'quantity': 100.0,
        'unit': 'pcs',
        'availableQuantity': 100.0,
      });

      final cartItem = CartItemModel(
        id: 'cart_americano',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );

      // --- Santa Cruz: Initial sale & duplicate retry ---
      const scClientTxId = 'SALE_SC_IDEMPOTENCY_001';
      final scTx1 = await transactionsProvider.addTransaction(
        branchId: scBranchId,
        branchName: 'Santa Cruz Branch',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'Cash',
        clientSaleId: scClientTxId,
      );
      expect(scTx1.transactionId, scClientTxId);

      // Verify Santa Cruz inventory deducted (1000 -> 982)
      final scBeansSnap1 = await fakeDb.collection(FirebasePaths.inventory).doc('${scBranchId}_ing_beans').get();
      expect(scBeansSnap1.data()?['quantity'], 982.0);

      // Duplicate Santa Cruz submission
      final scTx2 = await transactionsProvider.addTransaction(
        branchId: scBranchId,
        branchName: 'Santa Cruz Branch',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'Cash',
        clientSaleId: scClientTxId,
      );
      expect(scTx2.transactionId, scTx1.transactionId);

      // Verify Santa Cruz inventory NOT deducted twice
      final scBeansSnap2 = await fakeDb.collection(FirebasePaths.inventory).doc('${scBranchId}_ing_beans').get();
      expect(scBeansSnap2.data()?['quantity'], 982.0);

      // Verify query on /sales with both branchId and clientSaleId
      final scSalesQuery = await fakeDb
          .collection(FirebasePaths.sales)
          .where('branchId', isEqualTo: scBranchId)
          .where('clientSaleId', isEqualTo: scClientTxId)
          .get();
      expect(scSalesQuery.docs.length, 1);
      expect(scSalesQuery.docs.first.data()['branchId'], scBranchId);

      // --- LSPU: Initial sale & duplicate retry ---
      const lspuClientTxId = 'SALE_LSPU_IDEMPOTENCY_001';
      final lspuTx1 = await transactionsProvider.addTransaction(
        branchId: lspuBranchId,
        branchName: 'LSPU Branch',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'GCash',
        clientSaleId: lspuClientTxId,
      );
      expect(lspuTx1.transactionId, lspuClientTxId);

      // Verify LSPU inventory deducted (1000 -> 982) while SC remains 982
      final lspuBeansSnap1 = await fakeDb.collection(FirebasePaths.inventory).doc('${lspuBranchId}_ing_beans').get();
      expect(lspuBeansSnap1.data()?['quantity'], 982.0);

      // Duplicate LSPU submission
      final lspuTx2 = await transactionsProvider.addTransaction(
        branchId: lspuBranchId,
        branchName: 'LSPU Branch',
        items: [cartItem],
        totalAmount: 100.0,
        paymentMethod: 'GCash',
        clientSaleId: lspuClientTxId,
      );
      expect(lspuTx2.transactionId, lspuTx1.transactionId);

      // Verify LSPU inventory NOT deducted twice
      final lspuBeansSnap2 = await fakeDb.collection(FirebasePaths.inventory).doc('${lspuBranchId}_ing_beans').get();
      expect(lspuBeansSnap2.data()?['quantity'], 982.0);

      // Verify query on /sales with both branchId and clientSaleId
      final lspuSalesQuery = await fakeDb
          .collection(FirebasePaths.sales)
          .where('branchId', isEqualTo: lspuBranchId)
          .where('clientSaleId', isEqualTo: lspuClientTxId)
          .get();
      expect(lspuSalesQuery.docs.length, 1);
      expect(lspuSalesQuery.docs.first.data()['branchId'], lspuBranchId);

      // Exactly 2 total sales in database (1 for Santa Cruz, 1 for LSPU)
      final allSalesSnap = await fakeDb.collection(FirebasePaths.sales).get();
      expect(allSalesSnap.docs.length, 2);
    });
  });
}
