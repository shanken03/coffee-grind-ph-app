import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/models/branch_product_serving_model.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/recipe_model.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_card.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_details_dialog.dart';

void main() {
  const testBranchId = 'br_1790905840872';

  // Shared test product: Spanish Latte with dual Hot/Iced pricing
  final spanishLatte = ProductModel(
    productId: 'spanish_latte',
    name: 'Spanish Latte',
    category: ProductCategory.coffee,
    categoryName: 'Coffee Series',
    description: 'Espresso with condensed milk',
    imageUrl: '',
    isAvailable: true,
    availableBranches: [testBranchId],
    pricing: const ProductPricing(hotPrice: 110.0, icedPrice: 120.0),
  );

  // Shared recipe: 18g beans per serving
  final spanishLatteRecipe = RecipeModel(
    recipeId: 'rec_spanish_latte',
    productId: 'spanish_latte',
    name: 'Spanish Latte Recipe',
    ingredients: const [
      RecipeIngredientRequirement(
        ingredientId: 'ing_beans',
        ingredientName: 'Espresso Beans',
        quantity: 18.0,
        unit: 'g',
      ),
    ],
  );

  // Helper to create test inventory items
  List<InventoryItemModel> buildTestInventory({required double beansGrams}) {
    return [
      InventoryItemModel(
        id: 'inv_${testBranchId}_ing_beans',
        branchId: testBranchId,
        ingredientId: 'ing_beans',
        name: 'Espresso Beans',
        category: 'Ingredients',
        availableQuantity: beansGrams,
        unit: 'g',
        minStock: 100.0,
      ),
    ];
  }

  group('Checkpoint 3: Manual Servings ProductsProvider Integration Tests', () {
    test('Missing quota fallback: uses full physical recipe capacity', () {
      final provider = ProductsProvider();
      provider.setProductsForTesting([spanishLatte]);
      provider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      // 360g beans / 18g per serving = 20 physical servings capacity
      final inventory = buildTestInventory(beansGrams: 360.0);

      final result = provider.calculateSellableServings(
        product: spanishLatte,
        inventoryItems: inventory,
      );

      expect(result.servings, 20);
      expect(result.isAvailable, isTrue);
      expect(result.isOutOfStock, isFalse);
      expect(result.statusBadgeLabel, 'AVAILABLE — 20 servings');
    });

    test('Disabled quota fallback: uses full physical recipe capacity even if remainingServings is 0', () {
      final provider = ProductsProvider();
      provider.setProductsForTesting([spanishLatte]);
      provider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      provider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 0,
          isEnabled: false, // Disabled quota!
        ),
      });

      final inventory = buildTestInventory(beansGrams: 360.0); // 20 physical servings
      final result = provider.calculateSellableServings(
        product: spanishLatte,
        inventoryItems: inventory,
      );

      // Must bypass manual quota and use physical capacity of 20
      expect(result.servings, 20);
      expect(result.isAvailable, isTrue);
      expect(result.isOutOfStock, isFalse);
      expect(result.statusBadgeLabel, 'AVAILABLE — 20 servings');
    });

    test('Enabled quota limits physical capacity when manual servings is lower', () {
      final provider = ProductsProvider();
      provider.setProductsForTesting([spanishLatte]);
      provider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      provider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 5,
          isEnabled: true,
        ),
      });

      // 360g beans = 20 physical servings, but manual quota is 5
      final inventory = buildTestInventory(beansGrams: 360.0);
      final result = provider.calculateSellableServings(
        product: spanishLatte,
        inventoryItems: inventory,
      );

      expect(result.servings, 5);
      expect(result.isAvailable, isTrue);
      expect(result.isLowStock, isTrue);
      expect(result.statusBadgeLabel, 'LOW STOCK — 5 servings');
      expect(result.limitingIngredientName, 'Manual Quota');
    });

    test('Physical stock limits quota when physical stock is lower than manual quota', () {
      final provider = ProductsProvider();
      provider.setProductsForTesting([spanishLatte]);
      provider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      provider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 40,
          isEnabled: true,
        ),
      });

      // Only 54g beans = 3 physical servings, which is lower than manual quota 40
      final inventory = buildTestInventory(beansGrams: 54.0);
      final result = provider.calculateSellableServings(
        product: spanishLatte,
        inventoryItems: inventory,
      );

      expect(result.servings, 3);
      expect(result.isAvailable, isTrue);
      expect(result.isLowStock, isTrue);
      expect(result.statusBadgeLabel, 'LOW STOCK — 3 servings');
      expect(result.limitingIngredientName, 'Espresso Beans');
    });

    test('Enabled zero quota shows OUT OF STOCK even when physical ingredients are abundant', () {
      final provider = ProductsProvider();
      provider.setProductsForTesting([spanishLatte]);
      provider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      provider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 0,
          isEnabled: true,
        ),
      });

      // 1000g beans in stock = 55 physical servings, but manual quota is 0
      final inventory = buildTestInventory(beansGrams: 1000.0);
      final result = provider.calculateSellableServings(
        product: spanishLatte,
        inventoryItems: inventory,
      );

      expect(result.servings, 0);
      expect(result.isAvailable, isFalse);
      expect(result.isOutOfStock, isTrue);
      expect(result.statusBadgeLabel, 'OUT OF STOCK — 0 servings');
      expect(result.limitingIngredientName, 'Manual Quota');
    });

    test('Hot and Iced variants share the same product quota', () {
      final provider = ProductsProvider();
      provider.setProductsForTesting([spanishLatte]);
      provider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      provider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 7,
          isEnabled: true,
        ),
      });

      final inventory = buildTestInventory(beansGrams: 500.0); // 27 physical servings

      // Calculate for Hot variant
      final hotResult = provider.calculateSellableServings(
        product: spanishLatte,
        inventoryItems: inventory,
        temperature: 'Hot',
      );
      // Calculate for Iced variant
      final icedResult = provider.calculateSellableServings(
        product: spanishLatte,
        inventoryItems: inventory,
        temperature: 'Iced',
      );

      // Both Hot and Iced share the single quota of 7
      expect(hotResult.servings, 7);
      expect(icedResult.servings, 7);
      expect(hotResult.statusBadgeLabel, 'AVAILABLE — 7 servings');
      expect(icedResult.statusBadgeLabel, 'AVAILABLE — 7 servings');
    });

    test('Live quota update updates sellable servings dynamically', () {
      final provider = ProductsProvider();
      provider.setProductsForTesting([spanishLatte]);
      provider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      final inventory = buildTestInventory(beansGrams: 500.0); // 27 physical servings

      // 1. Initial state: Manual quota is 10
      provider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 10,
          isEnabled: true,
        ),
      });
      expect(provider.calculateSellableServings(product: spanishLatte, inventoryItems: inventory).servings, 10);

      // 2. Owner updates quota to 2 in Web Admin
      provider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 2,
          isEnabled: true,
        ),
      });
      expect(provider.calculateSellableServings(product: spanishLatte, inventoryItems: inventory).servings, 2);

      // 3. Owner disables manual quota in Web Admin -> immediately falls back to 27 physical servings
      provider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 2,
          isEnabled: false,
        ),
      });
      expect(provider.calculateSellableServings(product: spanishLatte, inventoryItems: inventory).servings, 27);
    });

    test('Firestore snapshot stream correctly ingests branch_product_servings for branch', () async {
      final fakeDb = FakeFirebaseFirestore();
      final provider = ProductsProvider(firestore: fakeDb);

      // Add quota document in Firestore for testBranchId
      await fakeDb
          .collection(FirebasePaths.branchProductServings)
          .doc('${testBranchId}_spanish_latte')
          .set({
        'branchId': testBranchId,
        'productId': 'spanish_latte',
        'manualMaxServings': 50,
        'remainingServings': 14,
        'isEnabled': true,
      });

      // Add quota document for another branch (should NOT be ingested)
      await fakeDb
          .collection(FirebasePaths.branchProductServings)
          .doc('br_other_spanish_latte')
          .set({
        'branchId': 'br_other',
        'productId': 'spanish_latte',
        'manualMaxServings': 50,
        'remainingServings': 3,
        'isEnabled': true,
      });

      // Bind to branch
      provider.bindToBranch(testBranchId);

      // Pump microtasks to process snapshot stream
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final serving = provider.getManualServingForProduct('spanish_latte');
      expect(serving, isNotNull);
      expect(serving?.branchId, testBranchId);
      expect(serving?.remainingServings, 14);
    });
  });

  group('Checkpoint 3: Product UI Widgets Manual Servings Integration Tests', () {
    testWidgets('ProductCard displays OUT OF STOCK — 0 servings and disables tap when manual quota is 0', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      final productsProvider = ProductsProvider(firestore: fakeDb);
      productsProvider.setProductsForTesting([spanishLatte]);
      productsProvider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      productsProvider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 0,
          isEnabled: true,
        ),
      });

      final inventoryProvider = InventoryProvider(firestore: fakeDb);
      inventoryProvider.setItemsForTesting(buildTestInventory(beansGrams: 500.0));
      final cartProvider = PosCartProvider();

      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
              ChangeNotifierProvider<InventoryProvider>.value(value: inventoryProvider),
              ChangeNotifierProvider<PosCartProvider>.value(value: cartProvider),
            ],
            child: Scaffold(
              body: ProductCard(
                product: spanishLatte,
                onTap: () => wasTapped = true,
                onAdd: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card must display OUT OF STOCK — 0 servings badge and Out of Stock button
      expect(find.text('OUT OF STOCK — 0 servings'), findsOneWidget);
      expect(find.text('Out of Stock'), findsOneWidget);
    });

    testWidgets('ProductDetailsDialog displays exact manual quota and disables Add to Cart when 0', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      final productsProvider = ProductsProvider(firestore: fakeDb);
      productsProvider.setProductsForTesting([spanishLatte]);
      productsProvider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      productsProvider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 0,
          isEnabled: true,
        ),
      });

      final inventoryProvider = InventoryProvider(firestore: fakeDb);
      inventoryProvider.setItemsForTesting(buildTestInventory(beansGrams: 500.0));
      final cartProvider = PosCartProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
              ChangeNotifierProvider<InventoryProvider>.value(value: inventoryProvider),
              ChangeNotifierProvider<PosCartProvider>.value(value: cartProvider),
            ],
            child: Scaffold(
              body: ProductDetailsDialog(product: spanishLatte),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Product details shows 0 servings badge
      expect(find.text('OUT OF STOCK — 0 servings'), findsOneWidget);

      // Add to Cart button is replaced by Out of Stock button and is disabled
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Out of Stock');
      expect(buttonFinder, findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('ProductDetailsDialog clamps max stepper to enabled manual quota', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      final productsProvider = ProductsProvider(firestore: fakeDb);
      productsProvider.setProductsForTesting([spanishLatte]);
      productsProvider.setRecipesForTesting({'spanish_latte': spanishLatteRecipe});
      // Physical capacity is 27, but manual quota is 3
      productsProvider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: testBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 3,
          isEnabled: true,
        ),
      });

      final inventoryProvider = InventoryProvider(firestore: fakeDb);
      inventoryProvider.setItemsForTesting(buildTestInventory(beansGrams: 500.0));
      final cartProvider = PosCartProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
              ChangeNotifierProvider<InventoryProvider>.value(value: inventoryProvider),
              ChangeNotifierProvider<PosCartProvider>.value(value: cartProvider),
            ],
            child: Scaffold(
              body: ProductDetailsDialog(product: spanishLatte),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LOW STOCK — 3 servings'), findsOneWidget);

      // Increment button
      final plusFinder = find.byIcon(Icons.add);
      expect(plusFinder, findsOneWidget);

      // Tap + twice to reach 3
      await tester.tap(plusFinder);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      await tester.tap(plusFinder);
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      // Attempt to tap + past manual quota of 3: should stay capped at 3
      await tester.tap(plusFinder);
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
    });
  });
}

