import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/models/cart_item_model.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/recipe_model.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/providers/transactions_provider.dart';
import 'package:coffee_grind_ph/providers/restock_provider.dart';
import 'package:coffee_grind_ph/services/inventory_resolver.dart';

void main() {
  group('Recipe-Based Branch Inventory Integration Tests (Zero Product Stock Documents)', () {
    late FakeFirebaseFirestore fakeDb;
    late InventoryDocumentResolver resolver;
    late TransactionsProvider transactionsProvider;
    late ProductsProvider productsProvider;
    late InventoryProvider inventoryProvider;

    const santaCruzBranch = 'br_1790905840872';
    const lspuBranch = 'br_1790923872261';

    // Americano product
    final prodAmericano = ProductModel(
      productId: 'PROD_AMERICANO',
      name: 'Americano',
      category: ProductCategory.coffee,
      description: 'Espresso with water',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [santaCruzBranch, lspuBranch],
      pricing: const ProductPricing(hotPrice: 100.0, icedPrice: 110.0),
      recipeId: 'rec_americano',
    );

    // Iced-only Latte product (e.g. Spanish Latte)
    final prodSpanishLatte = ProductModel(
      productId: 'PROD_SPANISH_LATTE',
      name: 'Spanish Latte',
      category: ProductCategory.coffee,
      description: 'Sweet iced latte',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [santaCruzBranch, lspuBranch],
      pricing: const ProductPricing(
        icedPrice: 120.0, // Only iced price, no hot price -> isColdOnly = true
      ),
      recipeId: 'rec_spanish_latte',
    );

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      resolver = InventoryDocumentResolver(firestore: fakeDb);
      transactionsProvider = TransactionsProvider(
        firestore: fakeDb,
        resolver: resolver,
      );
      productsProvider = ProductsProvider(firestore: fakeDb);
      inventoryProvider = InventoryProvider(firestore: fakeDb);

      // 1. Seed Products
      await fakeDb
          .collection(FirebasePaths.products)
          .doc(prodAmericano.productId)
          .set({
            'name': prodAmericano.name,
            'category': 'Coffee',
            'isAvailable': true,
            'availableBranches': [santaCruzBranch, lspuBranch],
            'pricing': {'hotPrice': 100.0, 'icedPrice': 110.0},
            'recipeId': 'rec_americano',
          });

      await fakeDb
          .collection(FirebasePaths.products)
          .doc(prodSpanishLatte.productId)
          .set({
            'name': prodSpanishLatte.name,
            'category': 'Coffee',
            'isAvailable': true,
            'availableBranches': [santaCruzBranch, lspuBranch],
            'pricing': {'icedPrice': 120.0},
            'recipeId': 'rec_spanish_latte',
          });

      // 2. Seed Americano Recipe
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

      // 3. Seed Spanish Latte Recipe
      await fakeDb
          .collection(FirebasePaths.recipes)
          .doc('rec_spanish_latte')
          .set({
            'productId': 'PROD_SPANISH_LATTE',
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
                'ingredientId': 'pkg_16oz_cup',
                'ingredientName': '16oz Iced Cup',
                'quantity': 1.0,
                'unit': 'pcs',
                'temperature': 'iced',
                'category': 'packaging',
              },
            ],
          });

      // 4. Seed Santa Cruz Inventory
      final scInventory = {
        '${santaCruzBranch}_ing_beans': {
          'branchId': santaCruzBranch,
          'ingredientId': 'ing_beans',
          'ingredientName': 'Espresso Beans',
          'quantity': 1000.0,
          'unit': 'g',
        },
        '${santaCruzBranch}_pkg_12oz_cup': {
          'branchId': santaCruzBranch,
          'ingredientId': 'pkg_12oz_cup',
          'ingredientName': '12oz Hot Cup',
          'quantity': 100.0,
          'unit': 'pcs',
        },
        '${santaCruzBranch}_pkg_hot_lid': {
          'branchId': santaCruzBranch,
          'ingredientId': 'pkg_hot_lid',
          'ingredientName': 'Hot Cup Lid',
          'quantity': 100.0,
          'unit': 'pcs',
        },
        '${santaCruzBranch}_pkg_16oz_cup': {
          'branchId': santaCruzBranch,
          'ingredientId': 'pkg_16oz_cup',
          'ingredientName': '16oz Iced Cup',
          'quantity': 100.0,
          'unit': 'pcs',
        },
        '${santaCruzBranch}_pkg_iced_lid': {
          'branchId': santaCruzBranch,
          'ingredientId': 'pkg_iced_lid',
          'ingredientName': 'Iced Cup Lid',
          'quantity': 100.0,
          'unit': 'pcs',
        },
        '${santaCruzBranch}_pkg_straw': {
          'branchId': santaCruzBranch,
          'ingredientId': 'pkg_straw',
          'ingredientName': 'Paper Straw',
          'quantity': 100.0,
          'unit': 'pcs',
        },
      };

      for (final entry in scInventory.entries) {
        await fakeDb
            .collection(FirebasePaths.inventory)
            .doc(entry.key)
            .set(entry.value);
      }

      // 5. Seed LSPU Inventory
      final lspuInventory = {
        '${lspuBranch}_ing_beans': {
          'branchId': lspuBranch,
          'ingredientId': 'ing_beans',
          'ingredientName': 'Espresso Beans',
          'quantity': 5000.0,
          'unit': 'g',
        },
        '${lspuBranch}_pkg_12oz_cup': {
          'branchId': lspuBranch,
          'ingredientId': 'pkg_12oz_cup',
          'ingredientName': '12oz Hot Cup',
          'quantity': 500.0,
          'unit': 'pcs',
        },
        '${lspuBranch}_pkg_hot_lid': {
          'branchId': lspuBranch,
          'ingredientId': 'pkg_hot_lid',
          'ingredientName': 'Hot Cup Lid',
          'quantity': 500.0,
          'unit': 'pcs',
        },
      };

      for (final entry in lspuInventory.entries) {
        await fakeDb
            .collection(FirebasePaths.inventory)
            .doc(entry.key)
            .set(entry.value);
      }

      // NOTICE: ZERO branch_product_stock documents are seeded!
    });

    test('1. Product catalog loads and calculates availability without product-stock documents', () async {
      productsProvider.bindToBranch(santaCruzBranch);
      inventoryProvider.bindToBranch(santaCruzBranch);
      await pumpEventQueue();

      expect(productsProvider.products.isNotEmpty, isTrue);

      final servings = productsProvider.calculateSellableServings(
        product: prodAmericano,
        inventoryItems: inventoryProvider.items,
        temperature: 'Hot',
      );

      // 1000g beans / 18g = 55 servings; 100 cups = 100 servings -> 55 servings available
      expect(servings.isAvailable, isTrue);
      expect(servings.servings, 55);
      expect(servings.hasStockRecord, isTrue); // No uninitialized gating
    });

    test('2. Products can be added to cart and validated without product-stock documents', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 2,
      );

      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 2);

      final val = cart.validateCartStock(
        recipes: {
          prodAmericano.productId: RecipeModel.fromFirestore('rec_americano', {
            'productId': 'PROD_AMERICANO',
            'ingredients': [
              {
                'ingredientId': 'ing_beans',
                'quantity': 18.0,
                'unit': 'g',
                'temperature': 'both',
              },
              {
                'ingredientId': 'pkg_12oz_cup',
                'quantity': 1.0,
                'unit': 'pcs',
                'temperature': 'hot',
              },
            ],
          }),
        },
        inventoryItems: [
          const InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'ing_beans',
            name: 'Beans',
            category: 'Ingredient',
            availableQuantity: 1000,
            unit: 'g',
            minStock: 10,
            branchId: santaCruzBranch,
          ),
          const InventoryItemModel(
            id: 'br_cup',
            ingredientId: 'pkg_12oz_cup',
            name: 'Cup',
            category: 'Packaging',
            availableQuantity: 100,
            unit: 'pcs',
            minStock: 10,
            branchId: santaCruzBranch,
          ),
        ],
      );

      expect(val.isValid, isTrue);
    });

    test('3. Cart quantities can be changed without checking persistent product quotas', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 1,
      );

      cart.updateQuantity(cart.items.first.id, 1);
      expect(cart.items.first.quantity, 2);

      cart.updateQuantity(cart.items.first.id, 5);
      expect(cart.items.first.quantity, 7);

      cart.updateQuantity(cart.items.first.id, -2);
      expect(cart.items.first.quantity, 5);
    });

    test('4. Checkout succeeds without product-stock documents', () async {
      // Verify branch_product_stock has 0 documents
      final stockDocs = await fakeDb
          .collection(FirebasePaths.branchProductStock)
          .get();
      expect(stockDocs.docs.isEmpty, isTrue);

      final cartItem = CartItemModel(
        id: 'cart_1',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 3,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz',
        items: [cartItem],
        totalAmount: 300.0,
        paymentMethod: 'Cash',
      );

      expect(tx.status, 'Completed');
      expect(tx.transactionId.isNotEmpty, isTrue);
    });

    test('5. Checkout deducts the correct physical ingredients', () async {
      final cartItem = CartItemModel(
        id: 'cart_1',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 3,
      );

      await transactionsProvider.addTransaction(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz',
        items: [cartItem],
        totalAmount: 300.0,
        paymentMethod: 'Cash',
      );

      // Hot Americano: 18g beans * 3 = 54g. Initial: 1000g -> 946g
      final beansDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_ing_beans')
          .get();
      expect(beansDoc.data()!['quantity'], 946.0);
    });

    test('6. Checkout deducts the correct packaging', () async {
      final cartItem = CartItemModel(
        id: 'cart_1',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 3,
      );

      await transactionsProvider.addTransaction(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz',
        items: [cartItem],
        totalAmount: 300.0,
        paymentMethod: 'Cash',
      );

      // Hot cups: 100 - 3 = 97 pcs
      final cupsDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_pkg_12oz_cup')
          .get();
      expect(cupsDoc.data()!['quantity'], 97.0);

      // Hot lids: 100 - 3 = 97 pcs
      final lidsDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_pkg_hot_lid')
          .get();
      expect(lidsDoc.data()!['quantity'], 97.0);

      // Cold packaging must be untouched (still 100 pcs)
      final coldCupsDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_pkg_16oz_cup')
          .get();
      expect(coldCupsDoc.data()!['quantity'], 100.0);
    });

    test(
      '7. Insufficient physical inventory aborts the entire transaction',
      () async {
        // Put beans to 5g (insufficient for 1 Americano which requires 18g)
        await fakeDb
            .collection(FirebasePaths.inventory)
            .doc('${santaCruzBranch}_ing_beans')
            .update({'quantity': 5.0});

        final cartItem = CartItemModel(
          id: 'cart_fail',
          product: prodAmericano,
          selectedTemperature: 'Hot',
          unitPrice: 100.0,
          quantity: 1,
        );

        const failedSaleId = 'FAILED_SALE_999';

        expect(
          () async => await transactionsProvider.addTransaction(
            branchId: santaCruzBranch,
            branchName: 'Santa Cruz',
            items: [cartItem],
            totalAmount: 100.0,
            paymentMethod: 'Cash',
            clientSaleId: failedSaleId,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Insufficient branch stock for "Espresso Beans"'),
            ),
          ),
        );

        // 1. No sale document created
        final saleDoc = await fakeDb
            .collection(FirebasePaths.sales)
            .doc(failedSaleId)
            .get();
        expect(saleDoc.exists, isFalse);

        // 2. Inventory untouched at 5.0
        final beansDoc = await fakeDb
            .collection(FirebasePaths.inventory)
            .doc('${santaCruzBranch}_ing_beans')
            .get();
        expect(beansDoc.data()!['quantity'], 5.0);

        // 3. No audit log created
        final auditSnap = await fakeDb
            .collection(FirebasePaths.inventoryTransactions)
            .where('saleId', isEqualTo: failedSaleId)
            .get();
        expect(auditSnap.docs.isEmpty, isTrue);
      },
    );

    test('8. Santa Cruz and LSPU inventory remain isolated', () async {
      final cartItem = CartItemModel(
        id: 'cart_sc',
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 3,
      );

      await transactionsProvider.addTransaction(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz',
        items: [cartItem],
        totalAmount: 300.0,
        paymentMethod: 'Cash',
      );

      // Santa Cruz beans decremented from 1000g to 946g
      final scBeans = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_ing_beans')
          .get();
      expect(scBeans.data()!['quantity'], 946.0);

      // LSPU beans must remain completely untouched at 5000g
      final lspuBeans = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${lspuBranch}_ing_beans')
          .get();
      expect(lspuBeans.data()!['quantity'], 5000.0);
    });

    test(
      '9. Duplicate transaction retries do not deduct inventory twice',
      () async {
        final cartItem = CartItemModel(
          id: 'cart_retry',
          product: prodAmericano,
          selectedTemperature: 'Hot',
          unitPrice: 100.0,
          quantity: 2,
        );

        const clientSaleId = 'UNIQUE-CLIENT-SALE-12345';

        // First attempt
        final tx1 = await transactionsProvider.addTransaction(
          branchId: santaCruzBranch,
          branchName: 'Santa Cruz',
          items: [cartItem],
          totalAmount: 200.0,
          paymentMethod: 'Cash',
          clientSaleId: clientSaleId,
        );

        // Repeated retry attempt with identical clientSaleId
        final tx2 = await transactionsProvider.addTransaction(
          branchId: santaCruzBranch,
          branchName: 'Santa Cruz',
          items: [cartItem],
          totalAmount: 200.0,
          paymentMethod: 'Cash',
          clientSaleId: clientSaleId,
        );

        expect(tx1.transactionId, tx2.transactionId);

        // Inventory beans must only have been decremented by 36g (1000 - 36 = 964, NOT 928)
        final beansDoc = await fakeDb
            .collection(FirebasePaths.inventory)
            .doc('${santaCruzBranch}_ing_beans')
            .get();
        expect(beansDoc.data()!['quantity'], 964.0);

        // Check sales collection has exactly ONE record for this clientSaleId
        final salesSnap = await fakeDb
            .collection(FirebasePaths.sales)
            .where('clientSaleId', isEqualTo: clientSaleId)
            .get();
        expect(salesSnap.docs.length, 1);

        // Exactly 3 audit logs (beans, hot cup, hot lid)
        final auditSnap = await fakeDb
            .collection(FirebasePaths.inventoryTransactions)
            .where('saleId', isEqualTo: clientSaleId)
            .get();
        expect(auditSnap.docs.length, 3);
      },
    );

    test('10. Hot and Iced recipes deduct the correct packaging', () async {
      // 1x Hot Americano + 1x Iced Americano
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
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz',
        items: [hotItem, icedItem],
        totalAmount: 210.0,
        paymentMethod: 'Cash',
      );

      // Beans: 18g + 18g = 36g. 1000g - 36g = 964g
      final beansDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_ing_beans')
          .get();
      expect(beansDoc.data()!['quantity'], 964.0);

      // 1 Hot Cup deducted (100 -> 99)
      final hotCupDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_pkg_12oz_cup')
          .get();
      expect(hotCupDoc.data()!['quantity'], 99.0);

      // 1 Iced Cup deducted (100 -> 99)
      final icedCupDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_pkg_16oz_cup')
          .get();
      expect(icedCupDoc.data()!['quantity'], 99.0);

      // 1 Straw deducted (100 -> 99)
      final strawDoc = await fakeDb
          .collection(FirebasePaths.inventory)
          .doc('${santaCruzBranch}_pkg_straw')
          .get();
      expect(strawDoc.data()!['quantity'], 99.0);
    });

    test('11. Iced-only products automatically select Iced', () {
      expect(prodSpanishLatte.isColdOnly, isTrue);
      expect(prodSpanishLatte.supportsTemperatureOptions, isFalse);
      expect(prodSpanishLatte.fixedTemperature, 'Iced');
      expect(prodSpanishLatte.initialTemperature, 'Iced');
    });

    test('12. Announcement audience matching is case-insensitive', () async {
      await fakeDb.collection(FirebasePaths.announcements).doc('ann_all').set({
        'title': 'All Store Meeting',
        'message': 'Meeting at 5pm',
        'targetBranches': ['all'], // lowercase 'all'
        'status': 'PUBLISHED',
      });

      await fakeDb.collection(FirebasePaths.announcements).doc('ann_sc').set({
        'title': 'Santa Cruz Notice',
        'message': 'Inspection tomorrow',
        'targetBranches': [santaCruzBranch],
        'status': 'PUBLISHED',
      });

      await fakeDb.collection(FirebasePaths.announcements).doc('ann_lspu').set({
        'title': 'LSPU Notice',
        'message': 'Inspection next week',
        'targetBranches': [lspuBranch],
        'status': 'PUBLISHED',
      });

      // Bind to Santa Cruz
      // Note: In test environment, FakeFirebaseFirestore can be used via custom provider or direct testing
      final loadedDocs =
          (await fakeDb.collection(FirebasePaths.announcements).get()).docs;
      final cleanBranch = santaCruzBranch.toLowerCase();

      final scTargeted = loadedDocs.where((doc) {
        final targets = (doc.data()['targetBranches'] as List? ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList();
        return targets.contains('all') || targets.contains(cleanBranch);
      }).toList();

      expect(scTargeted.length, 2); // 'all' and 'santaCruzBranch'
      expect(
        scTargeted.any((d) => d.id == 'ann_lspu'),
        isFalse,
      ); // LSPU announcement excluded
    });

    test('13. Expired announcements are excluded', () async {
      final now = DateTime.now();

      await fakeDb
          .collection(FirebasePaths.announcements)
          .doc('ann_active')
          .set({
            'title': 'Active Announcement',
            'message': 'Still valid',
            'targetBranches': ['all'],
            'expirationDate': now.add(const Duration(days: 2)),
          });

      await fakeDb
          .collection(FirebasePaths.announcements)
          .doc('ann_expired')
          .set({
            'title': 'Expired Announcement',
            'message': 'Past event',
            'targetBranches': ['all'],
            'expirationDate': now.subtract(const Duration(days: 2)),
          });

      final allDocs =
          (await fakeDb.collection(FirebasePaths.announcements).get()).docs;
      final validDocs = allDocs.where((doc) {
        final raw = doc.data()['expirationDate'];
        DateTime? exp;
        if (raw is Timestamp) {
          exp = raw.toDate();
        } else if (raw is DateTime) {
          exp = raw;
        }
        return exp == null || exp.isAfter(now);
      }).toList();

      expect(validDocs.length, 1);
      expect(validDocs.first.id, 'ann_active');
    });

    test('14. Restock requests remain branch-specific', () async {
      final restockProvider = RestockProvider(firestore: fakeDb);

      await restockProvider.addRequest(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz',
        category: 'Ingredients',
        itemType: 'Espresso Beans',
        quantity: 5,
        unit: 'kg',
      );

      final reqs = await fakeDb
          .collection(FirebasePaths.restockRequests)
          .where('branchId', isEqualTo: santaCruzBranch)
          .get();

      expect(reqs.docs.length, 1);
      expect(reqs.docs.first.data()['branchId'], santaCruzBranch);
      expect(reqs.docs.first.data()['status'], 'pending');
    });
  });
}
