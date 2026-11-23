import 'package:coffee_grind_ph/features/pos/widgets/cart_screen.dart';
import 'package:coffee_grind_ph/models/branch_product_serving_model.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/recipe_model.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  const santaCruzBranchId = 'br_1790905840872';
  const lspuBranchId = 'br_1790923872261';

  final spanishLatte = ProductModel(
    productId: 'spanish_latte',
    name: 'Spanish Latte',
    category: ProductCategory.coffee,
    categoryName: 'Coffee Series',
    description: 'Espresso with sweet condensed milk',
    imageUrl: '',
    isAvailable: true,
    availableBranches: [santaCruzBranchId, lspuBranchId],
    pricing: const ProductPricing(hotPrice: 120.0, icedPrice: 130.0),
    recipeId: 'rec_spanish_latte',
  );

  final americano = ProductModel(
    productId: 'americano',
    name: 'Americano',
    category: ProductCategory.coffee,
    categoryName: 'Coffee Series',
    description: 'Classic rich espresso with hot or iced water',
    imageUrl: '',
    isAvailable: true,
    availableBranches: [santaCruzBranchId, lspuBranchId],
    pricing: const ProductPricing(hotPrice: 100.0, icedPrice: 110.0),
    recipeId: 'rec_americano',
  );

  final spanishLatteRecipe = RecipeModel(
    recipeId: 'rec_spanish_latte',
    productId: 'spanish_latte',
    name: 'Spanish Latte',
    ingredients: const [
      RecipeIngredientRequirement(
        ingredientId: 'ing_beans',
        ingredientName: 'Espresso Beans',
        quantity: 18.0,
        unit: 'g',
      ),
      RecipeIngredientRequirement(
        ingredientId: 'ing_milk',
        ingredientName: 'Fresh Milk',
        quantity: 150.0,
        unit: 'ml',
      ),
    ],
  );

  final americanoRecipe = RecipeModel(
    recipeId: 'rec_americano',
    productId: 'americano',
    name: 'Americano',
    ingredients: const [
      RecipeIngredientRequirement(
        ingredientId: 'ing_beans',
        ingredientName: 'Espresso Beans',
        quantity: 18.0,
        unit: 'g',
      ),
    ],
  );

  final testRecipes = {
    'spanish_latte': spanishLatteRecipe,
    'americano': americanoRecipe,
  };

  List<InventoryItemModel> buildTestInventory({
    double beans = 5000.0,
    double milk = 10000.0,
    String branchId = santaCruzBranchId,
  }) {
    return [
      InventoryItemModel(
        id: 'inv_${branchId}_ing_beans',
        branchId: branchId,
        ingredientId: 'ing_beans',
        name: 'Espresso Beans',
        category: 'Ingredients',
        availableQuantity: beans,
        unit: 'g',
        minStock: 100.0,
      ),
      InventoryItemModel(
        id: 'inv_${branchId}_ing_milk',
        branchId: branchId,
        ingredientId: 'ing_milk',
        name: 'Fresh Milk',
        category: 'Ingredients',
        availableQuantity: milk,
        unit: 'ml',
        minStock: 500.0,
      ),
    ];
  }

  group('Checkpoint 4: Manual Servings Cart Validation Unit Tests', () {
    test('Cart quantity within manual quota: validation passes', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      final manualServings = {
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 5,
          isEnabled: true,
        ),
      };

      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isTrue);
      expect(result.manualQuotaDeficits, isEmpty);
      expect(result.deficits, isEmpty);
      expect(result.errorMessage, isNull);
    });

    test('Cart quantity exceeding manual quota: validation fails with clear deficit details', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Iced',
        unitPrice: 130.0,
        quantity: 6,
      );

      final manualServings = {
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 5,
          isEnabled: true,
        ),
      };

      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isFalse);
      expect(result.manualQuotaDeficits.length, 1);
      final deficit = result.manualQuotaDeficits.first;
      expect(deficit.productId, 'spanish_latte');
      expect(deficit.productName, 'Spanish Latte');
      expect(deficit.requestedQuantity, 6);
      expect(deficit.remainingServings, 5);
      expect(deficit.summary, 'Spanish Latte (6 in cart, only 5 manual servings available)');
      expect(result.errorMessage, contains('Manual servings limit exceeded'));
      expect(result.errorMessage, contains('Spanish Latte (6 in cart, only 5 manual servings available)'));
    });

    test('Hot and Iced variants share the same manual quota and aggregate by productId', () {
      final cart = PosCartProvider();
      // 3 Hot + 3 Iced = 6 total Spanish Latte
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 3,
      );
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Iced',
        unitPrice: 130.0,
        quantity: 3,
      );

      final manualServings = {
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 5,
          isEnabled: true,
        ),
      };

      // Total 6 > 5 remainingServings -> fails validation
      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isFalse);
      expect(result.manualQuotaDeficits.length, 1);
      final deficit = result.manualQuotaDeficits.first;
      expect(deficit.productId, 'spanish_latte');
      expect(deficit.requestedQuantity, 6);
      expect(deficit.remainingServings, 5);

      // Now reduce Hot to 2: 2 Hot + 3 Iced = 5 total <= 5 -> passes validation
      cart.updateQuantity('${spanishLatte.productId}_Hot_none', -1);
      expect(cart.items.fold(0, (sum, i) => sum + i.quantity), 5);

      final resultValid = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );
      expect(resultValid.isValid, isTrue);
      expect(resultValid.manualQuotaDeficits, isEmpty);
    });

    test('Disabled quota falls back to physical inventory', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Iced',
        unitPrice: 130.0,
        quantity: 10,
      );

      // Quota has 0 remaining, but isEnabled == false!
      final manualServings = {
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 0,
          isEnabled: false,
        ),
      };

      // Physical inventory has plenty (5000g beans = 277 servings)
      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isTrue);
      expect(result.manualQuotaDeficits, isEmpty);
    });

    test('Missing quota document falls back to physical inventory', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: americano,
        selectedTemperature: 'Hot',
        unitPrice: 100.0,
        quantity: 8,
      );

      // manualServings map only has spanish_latte, americano document is missing
      final manualServings = {
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 10,
          isEnabled: true,
        ),
      };

      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isTrue);
      expect(result.manualQuotaDeficits, isEmpty);
    });

    test('Enabled quota with 0 remainingServings rejects any positive cart quantity', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 1,
      );

      final manualServings = {
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 50,
          remainingServings: 0,
          isEnabled: true,
        ),
      };

      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isFalse);
      expect(result.manualQuotaDeficits.length, 1);
      final deficit = result.manualQuotaDeficits.first;
      expect(deficit.summary, 'Spanish Latte is out of stock (0 manual servings remaining)');
      expect(result.errorMessage, contains('Spanish Latte is out of stock (0 manual servings remaining)'));
    });

    test('Multiple cart lines with different sizes and temperatures are aggregated by productId', () {
      final cart = PosCartProvider();
      // Line 1: 16oz Hot
      cart.addToCart(
        product: americano,
        selectedTemperature: 'Hot',
        selectedSize: '16oz',
        unitPrice: 100.0,
        quantity: 2,
      );
      // Line 2: 12oz Hot
      cart.addToCart(
        product: americano,
        selectedTemperature: 'Hot',
        selectedSize: '12oz',
        unitPrice: 90.0,
        quantity: 3,
      );
      // Line 3: 16oz Iced
      cart.addToCart(
        product: americano,
        selectedTemperature: 'Iced',
        selectedSize: '16oz',
        unitPrice: 110.0,
        quantity: 2,
      );
      // Total Americano across 3 lines = 7

      final manualServings = {
        'americano': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'americano',
          manualMaxServings: 20,
          remainingServings: 6,
          isEnabled: true,
        ),
      };

      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isFalse);
      expect(result.manualQuotaDeficits.length, 1);
      expect(result.manualQuotaDeficits.first.requestedQuantity, 7);
      expect(result.manualQuotaDeficits.first.remainingServings, 6);
    });

    test('Lookup supports composite docId key {branchId}_{productId}', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 5,
      );

      // Keyed by full document ID as stored in Firestore: br_1790905840872_spanish_latte
      final compositeKey = '${santaCruzBranchId}_spanish_latte';
      final manualServings = {
        compositeKey: BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 3,
          isEnabled: true,
        ),
      };

      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isFalse);
      expect(result.manualQuotaDeficits.length, 1);
      expect(result.manualQuotaDeficits.first.remainingServings, 3);
    });

    test('Branch isolation: Santa Cruz and LSPU quotas operate independently', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      // Suppose LSPU has 2 remaining, Santa Cruz has 10 remaining
      final lspuServings = {
        '${lspuBranchId}_spanish_latte': BranchProductServingModel(
          branchId: lspuBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 2,
          isEnabled: true,
        ),
      };

      final scServings = {
        '${santaCruzBranchId}_spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 10,
          isEnabled: true,
        ),
      };

      // Validating against LSPU quota fails (4 in cart > 2 available)
      final lspuResult = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(branchId: lspuBranchId),
        manualServings: lspuServings,
      );
      expect(lspuResult.isValid, isFalse);
      expect(lspuResult.manualQuotaDeficits.first.remainingServings, 2);

      // Validating against Santa Cruz quota passes (4 in cart <= 10 available)
      final scResult = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(branchId: santaCruzBranchId),
        manualServings: scServings,
      );
      expect(scResult.isValid, isTrue);
    });

    test('Simultaneous manual quota deficit and physical inventory deficit are both reported', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 5,
      );

      final manualServings = {
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 3,
          isEnabled: true,
        ),
      };

      // Inventory only has 50g beans (need 5 * 18 = 90g)
      final lowInventory = buildTestInventory(beans: 50.0);

      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: lowInventory,
        manualServings: manualServings,
      );

      expect(result.isValid, isFalse);
      expect(result.manualQuotaDeficits.length, 1);
      expect(result.deficits.length, 1);
      expect(result.errorMessage, contains('Manual servings limit exceeded:'));
      expect(result.errorMessage, contains('Insufficient branch inventory:'));
    });

    test('Validation failure does NOT mutate or clear cart items', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 10,
      );

      final manualServings = {
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 2,
          isEnabled: true,
        ),
      };

      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
        manualServings: manualServings,
      );

      expect(result.isValid, isFalse);
      // Cart items remain completely intact
      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 10);
      expect(cart.totalAmount, 1200.0);
    });

    test('PosCartProvider internal _manualServings works seamlessly when setManualServings is used', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      cart.setManualServings({
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 2,
          isEnabled: true,
        ),
      });

      // Call validateCartStock without passing manualServings parameter
      final result = cart.validateCartStock(
        recipes: testRecipes,
        inventoryItems: buildTestInventory(),
      );

      expect(result.isValid, isFalse);
      expect(result.manualQuotaDeficits.length, 1);
      expect(result.manualQuotaDeficits.first.remainingServings, 2);
    });
  });

  group('Checkpoint 4: CartScreen UI Manual Quota Integration Tests', () {
    testWidgets('CartScreen displays deficit banner and disables checkout button when manual quota is exceeded', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      final productsProvider = ProductsProvider(firestore: fakeDb);
      productsProvider.setProductsForTesting([spanishLatte]);
      productsProvider.setRecipesForTesting(testRecipes);
      productsProvider.setManualServingsForTesting({
        'spanish_latte': BranchProductServingModel(
          branchId: santaCruzBranchId,
          productId: 'spanish_latte',
          manualMaxServings: 20,
          remainingServings: 2,
          isEnabled: true,
        ),
      });

      final inventoryProvider = InventoryProvider(firestore: fakeDb);
      inventoryProvider.setItemsForTesting(buildTestInventory());

      final cartProvider = PosCartProvider();
      // Add 4 Spanish Lattes (exceeds remaining manual servings of 2)
      cartProvider.addToCart(
        product: spanishLatte,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
              ChangeNotifierProvider<InventoryProvider>.value(value: inventoryProvider),
              ChangeNotifierProvider<PosCartProvider>.value(value: cartProvider),
            ],
            child: const Scaffold(
              body: CartScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the Stock Deficit banner appears
      expect(find.text('Stock Deficit Detected'), findsOneWidget);
      expect(find.textContaining('Manual servings limit exceeded:'), findsOneWidget);
      expect(find.textContaining('Spanish Latte (4 in cart, only 2 manual servings available)'), findsOneWidget);

      // Verify Checkout button displays "Stock Exceeded — Adjust Cart"
      expect(find.text('Stock Exceeded — Adjust Cart'), findsOneWidget);
      expect(find.text('Proceed to Checkout'), findsNothing);

      // Reduce cart quantity to 2 (within quota)
      cartProvider.updateQuantity('${spanishLatte.productId}_Hot_none', -2);
      await tester.pumpAndSettle();

      // Banner should disappear and "Proceed to Checkout" should appear
      expect(find.text('Stock Deficit Detected'), findsNothing);
      expect(find.text('Proceed to Checkout'), findsOneWidget);
    });
  });
}
