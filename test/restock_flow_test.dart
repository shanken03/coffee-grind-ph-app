import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/models/ingredient_model.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/recipe_model.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/providers/restock_provider.dart';
import 'package:coffee_grind_ph/providers/branch_session_provider.dart';
import 'package:coffee_grind_ph/services/auth_service.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_card.dart';
import 'package:coffee_grind_ph/features/restock/widgets/create_restock_dialog.dart';

class FakeBranchSessionProvider extends ChangeNotifier
    implements BranchSessionProvider {
  @override
  String get branchId => 'br_santa_cruz';

  @override
  String get currentBranchName => 'Santa Cruz';

  @override
  String get currentBranchEmail => 'santacruz@gmail.com';

  @override
  BranchInfo get currentBranch => const BranchInfo(
    branchId: 'br_santa_cruz',
    name: 'Santa Cruz',
    email: 'santacruz@gmail.com',
  );

  @override
  bool get isAuthenticated => true;

  @override
  bool consumeLoginSuccessToast() => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Restock & Inventory Flow Focused Tests', () {
    late FakeFirebaseFirestore fakeDb;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
    });

    test(
      '1. InventoryProvider queries by branchId and isolates branch inventory',
      () async {
        // Seed inventory for Santa Cruz and LSPU
        await fakeDb.collection(FirebasePaths.inventory).doc('br_sc_beans').set(
          {
            'branchId': 'br_santa_cruz',
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 1000.0,
            'unit': 'g',
          },
        );

        await fakeDb
            .collection(FirebasePaths.inventory)
            .doc('br_lspu_beans')
            .set({
              'branchId': 'br_lspu',
              'ingredientId': 'ing_beans',
              'ingredientName': 'Espresso Beans',
              'quantity': 5000.0,
              'unit': 'g',
            });

        final provider = InventoryProvider(firestore: fakeDb);
        provider.bindToBranch('br_santa_cruz');
        await pumpEventQueue();

        expect(provider.items.length, 1);
        expect(provider.items.first.branchId, 'br_santa_cruz');
        expect(provider.items.first.availableQuantity, 1000.0);
        expect(provider.hasError, isFalse);

        // Switch to LSPU
        provider.bindToBranch('br_lspu');
        await pumpEventQueue();

        expect(provider.items.length, 1);
        expect(provider.items.first.branchId, 'br_lspu');
        expect(provider.items.first.availableQuantity, 5000.0);
      },
    );

    test('2. RestockProvider loads active master ingredients without requiring inventory documents', () async {
      // Seed 2 ingredients in master catalog
      await fakeDb.collection(FirebasePaths.ingredients).doc('ing_beans').set({
        'ingredientId': 'ing_beans',
        'name': 'Espresso Beans',
        'unit': 'g',
        'itemType': 'ingredient',
        'status': 'active',
      });

      await fakeDb.collection(FirebasePaths.ingredients).doc('pkg_cup').set({
        'ingredientId': 'pkg_cup',
        'name': '16oz Cup',
        'unit': 'pcs',
        'itemType': 'packaging',
        'status': 'active',
      });

      // Inactive ingredient should be filtered out
      await fakeDb
          .collection(FirebasePaths.ingredients)
          .doc('ing_inactive')
          .set({
            'ingredientId': 'ing_inactive',
            'name': 'Old Syrup',
            'unit': 'ml',
            'itemType': 'ingredient',
            'status': 'inactive',
          });

      final restockProvider = RestockProvider(firestore: fakeDb);
      restockProvider.bindToBranch('br_santa_cruz');
      await pumpEventQueue();

      expect(restockProvider.ingredients.length, 2);
      expect(
        restockProvider.ingredients.any((i) => i.ingredientId == 'ing_beans'),
        isTrue,
      );
      expect(
        restockProvider.ingredients.any((i) => i.ingredientId == 'pkg_cup'),
        isTrue,
      );
      expect(
        restockProvider.ingredients.any(
          (i) => i.ingredientId == 'ing_inactive',
        ),
        isFalse,
      );
      expect(restockProvider.isLoadingIngredients, isFalse);
    });

    test(
      '3. RestockProvider addRequest sets pending status and correct branchId',
      () async {
        final restockProvider = RestockProvider(firestore: fakeDb);
        await pumpEventQueue();

        await restockProvider.addRequest(
          branchId: 'br_santa_cruz',
          branchName: 'Santa Cruz Branch',
          category: 'Ingredients',
          itemType: 'Espresso Beans',
          quantity: 10,
          unit: 'kg',
          note: 'Low stock',
          ingredientId: 'ing_beans',
          ingredientName: 'Espresso Beans',
        );

        final snap = await fakeDb
            .collection(FirebasePaths.restockRequests)
            .get();
        expect(snap.docs.length, 1);

        final data = snap.docs.first.data();
        expect(data['branchId'], 'br_santa_cruz');
        expect(data['ingredientId'], 'ing_beans');
        expect(data['quantity'], 10);
        expect(data['status'], 'pending'); // Staff cannot approve
        expect(data['unit'], 'kg');
      },
    );

    testWidgets(
      '4. ProductCard does not require product stock records and derives availability from physical inventory',
      (tester) async {
        final productsProvider = ProductsProvider();
        final inventoryProvider = InventoryProvider();

        const prod = ProductModel(
          productId: 'PROD_TEST',
          name: 'Test Coffee',
          category: ProductCategory.coffee,
          description: 'Test',
          imageUrl: '',
          isAvailable: true,
          availableBranches: ['br_santa_cruz'],
          pricing: ProductPricing(hotPrice: 100.0),
          recipeId: 'rec_test',
        );

        productsProvider.setProductsForTesting([prod]);
        productsProvider.setRecipesForTesting({
          'PROD_TEST': RecipeModel.fromFirestore('rec_test', {
            'productId': 'PROD_TEST',
            'productName': 'Test Coffee',
            'ingredients': [
              {
                'ingredientId': 'ing_beans',
                'quantity': 18.0,
                'unit': 'g',
                'temperature': 'hot',
              },
            ],
          }),
        });

        // Provide physical inventory for Santa Cruz
        inventoryProvider.setItemsForTesting([
          const InventoryItemModel(
            id: 'br_sc_beans',
            branchId: 'br_santa_cruz',
            ingredientId: 'ing_beans',
            name: 'Espresso Beans',
            category: 'Ingredients',
            availableQuantity: 1000.0,
            unit: 'g',
            minStock: 100.0,
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 220,
                height: 320,
                child: MultiProvider(
                  providers: [
                    ChangeNotifierProvider<ProductsProvider>.value(
                      value: productsProvider,
                    ),
                    ChangeNotifierProvider<InventoryProvider>.value(
                      value: inventoryProvider,
                    ),
                  ],
                  child: ProductCard(product: prod, onTap: () {}, onAdd: () {}),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Verify UNINITIALIZED badge is never shown and Add button is enabled
        expect(find.text('UNINITIALIZED'), findsNothing);
        expect(find.text('Uninitialized'), findsNothing);
        expect(find.text('Add'), findsOneWidget);
      },
    );

    testWidgets(
      '5. CreateRestockDialog displays active master ingredients without requiring inventory documents',
      (tester) async {
        final restockProvider = RestockProvider(firestore: fakeDb);
        restockProvider.setIngredientsForTesting([
          const IngredientModel(
            ingredientId: 'ing_beans',
            name: 'Espresso Beans',
            unit: 'g',
            itemType: 'ingredient',
            status: 'active',
          ),
          const IngredientModel(
            ingredientId: 'pkg_cup',
            name: '16oz Iced Cup',
            unit: 'pcs',
            itemType: 'packaging',
            status: 'active',
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiProvider(
                providers: [
                  ChangeNotifierProvider<RestockProvider>.value(
                    value: restockProvider,
                  ),
                  ChangeNotifierProvider<BranchSessionProvider>.value(
                    value: FakeBranchSessionProvider(),
                  ),
                ],
                child: const CreateRestockDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initial category is 'Ingredients' -> Espresso Beans should be visible
        expect(find.text('Espresso Beans'), findsOneWidget);
        expect(
          find.text('No active ingredients found in master catalog'),
          findsNothing,
        );
      },
    );

    test('6. RestockProvider supports packaging restock requests (cups, lids, straws)', () async {
      final restockProvider = RestockProvider(firestore: fakeDb);
      restockProvider.bindToBranch('br_santa_cruz');
      await pumpEventQueue();

      await restockProvider.addRequest(
        branchId: 'br_santa_cruz',
        branchName: 'Santa Cruz Branch',
        category: 'Packaging / Supplies',
        itemType: '16oz Iced Cup',
        quantity: 50,
        unit: 'pcs',
        ingredientId: 'pkg_16oz_cup',
        ingredientName: '16oz Iced Cup',
        staffId: 'STAFF_01',
        staffName: 'Staff Maria',
      );

      final snap = await fakeDb
          .collection(FirebasePaths.restockRequests)
          .where('ingredientId', isEqualTo: 'pkg_16oz_cup')
          .get();

      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['category'], 'Packaging / Supplies');
      expect(data['itemType'], '16oz Iced Cup');
      expect(data['quantity'], 50);
      expect(data['unit'], 'pcs');
      expect(data['status'], 'pending');
      expect(data['branchId'], 'br_santa_cruz');
      expect(data['requestedByStaffId'], 'STAFF_01');
      expect(data['requestedByStaffName'], 'Staff Maria');
    });

    testWidgets(
      '7. CreateRestockDialog gracefully falls back to branch inventory items when master ingredients is empty',
      (tester) async {
        final restockProvider = RestockProvider(firestore: fakeDb);
        final inventoryProvider = InventoryProvider(firestore: fakeDb);

        // Master ingredients is EMPTY (as happens when Firestore rule is owner-only)
        restockProvider.setIngredientsForTesting([]);

        // But branch inventory contains items
        inventoryProvider.setItemsForTesting([
          const InventoryItemModel(
            id: 'br_sc_beans',
            branchId: 'br_santa_cruz',
            ingredientId: 'ing_beans',
            name: 'Inventory Coffee Beans',
            category: 'ingredient',
            availableQuantity: 500.0,
            unit: 'g',
            minStock: 50.0,
          ),
          const InventoryItemModel(
            id: 'br_sc_pkg_cup',
            branchId: 'br_santa_cruz',
            ingredientId: 'pkg_16oz_cup',
            name: 'Inventory 16oz Cups',
            category: 'packaging',
            availableQuantity: 100.0,
            unit: 'pcs',
            minStock: 20.0,
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiProvider(
                providers: [
                  ChangeNotifierProvider<RestockProvider>.value(
                    value: restockProvider,
                  ),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: inventoryProvider,
                  ),
                  ChangeNotifierProvider<BranchSessionProvider>.value(
                    value: FakeBranchSessionProvider(),
                  ),
                ],
                child: const CreateRestockDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should fall back and display Inventory Coffee Beans in Ingredients category
        expect(find.text('Inventory Coffee Beans'), findsOneWidget);
        expect(
          find.text('No active ingredients found in master catalog'),
          findsNothing,
        );

        // Switch category to Packaging / Supplies
        await tester.tap(find.text('Packaging / Supplies'));
        await tester.pumpAndSettle();

        // Should display Inventory 16oz Cups in Packaging category
        expect(find.text('Inventory 16oz Cups'), findsOneWidget);
      },
    );

    testWidgets(
      '8. CreateRestockDialog rejects invalid quantity and preserves form on error',
      (tester) async {
        final restockProvider = RestockProvider(firestore: fakeDb);
        restockProvider.setIngredientsForTesting([
          const IngredientModel(
            ingredientId: 'ing_beans',
            name: 'Espresso Beans',
            unit: 'g',
            itemType: 'ingredient',
            status: 'active',
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiProvider(
                providers: [
                  ChangeNotifierProvider<RestockProvider>.value(
                    value: restockProvider,
                  ),
                  ChangeNotifierProvider<BranchSessionProvider>.value(
                    value: FakeBranchSessionProvider(),
                  ),
                ],
                child: const CreateRestockDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter 0 or negative quantity
        final qtyField = find.widgetWithText(TextFormField, '10');
        await tester.enterText(qtyField, '0');
        await tester.pumpAndSettle();

        final submitButton = find.text('Submit Restock Request');
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Should display validation error and NOT close dialog
        expect(find.text('Enter valid quantity'), findsOneWidget);
        expect(find.text('Request Restocking'), findsOneWidget);

        final snap = await fakeDb
            .collection(FirebasePaths.restockRequests)
            .get();
        expect(snap.docs.length, 0);
      },
    );
  });
}
