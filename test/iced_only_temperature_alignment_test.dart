import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/recipe_model.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_details_dialog.dart';

void main() {
  group('ProductModel Temperature Configuration Tests', () {
    test('Coffee with both hot and iced prices supports temperature options and defaults to Iced', () {
      const dualCoffee = ProductModel(
        productId: 'prod_americano',
        name: 'Americano',
        category: ProductCategory.coffee,
        description: 'Espresso with water',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(hotPrice: 70.0, icedPrice: 75.0),
      );

      expect(dualCoffee.supportsTemperatureOptions, isTrue);
      expect(dualCoffee.isColdOnly, isFalse);
      expect(dualCoffee.isHotOnly, isFalse);
      expect(dualCoffee.fixedTemperature, isNull);
      expect(dualCoffee.initialTemperature, 'Iced');
    });

    test('Coffee with icedPrice only (e.g., Biscoff Latte) is marked cold-only with fixed Iced temperature', () {
      const icedCoffee = ProductModel(
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte',
        category: ProductCategory.coffee,
        description: 'Espresso with Lotus Biscoff spread',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(icedPrice: 120.0),
      );

      expect(icedCoffee.supportsTemperatureOptions, isFalse);
      expect(icedCoffee.isColdOnly, isTrue);
      expect(icedCoffee.isHotOnly, isFalse);
      expect(icedCoffee.fixedTemperature, 'Iced');
      expect(icedCoffee.initialTemperature, 'Iced');
    });

    test('Non-Coffee with icedPrice only (e.g., Spanish Caramel Latte) is marked cold-only', () {
      const icedNonCoffee = ProductModel(
        productId: 'prod_spanish_caramel',
        name: 'Spanish Caramel Latte',
        category: ProductCategory.nonCoffee,
        description: 'Sweet iced caramel milk',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(icedPrice: 110.0),
      );

      expect(icedNonCoffee.supportsTemperatureOptions, isFalse);
      expect(icedNonCoffee.isColdOnly, isTrue);
      expect(icedNonCoffee.isHotOnly, isFalse);
      expect(icedNonCoffee.fixedTemperature, 'Iced');
      expect(icedNonCoffee.initialTemperature, 'Iced');
    });

    test('Frappes and Refreshers are always cold-only regardless of pricing configuration', () {
      const frappe = ProductModel(
        productId: 'prod_matcha_frappe',
        name: 'Matcha Frappe',
        category: ProductCategory.frappe,
        description: 'Blended matcha drink',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(flatPrice: 135.0),
      );

      const refresher = ProductModel(
        productId: 'prod_berry_refresher',
        name: 'Berry Refresher',
        category: ProductCategory.refreshers,
        description: 'Sparkling iced berry drink',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(flatPrice: 95.0),
      );

      expect(frappe.supportsTemperatureOptions, isFalse);
      expect(frappe.isColdOnly, isTrue);
      expect(frappe.fixedTemperature, 'Iced');
      expect(frappe.initialTemperature, 'Iced');

      expect(refresher.supportsTemperatureOptions, isFalse);
      expect(refresher.isColdOnly, isTrue);
      expect(refresher.fixedTemperature, 'Iced');
      expect(refresher.initialTemperature, 'Iced');
    });

    test('Foods and Sweets never invent temperature options and remain null', () {
      const food = ProductModel(
        productId: 'prod_waffle',
        name: 'Belgian Waffle',
        category: ProductCategory.foods,
        description: 'Crispy waffle',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(flatPrice: 85.0),
      );

      const sweet = ProductModel(
        productId: 'prod_cookie',
        name: 'Choco Chip Cookie',
        category: ProductCategory.sweets,
        description: 'Baked cookie',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(flatPrice: 55.0),
      );

      expect(food.supportsTemperatureOptions, isFalse);
      expect(food.isColdOnly, isFalse);
      expect(food.isHotOnly, isFalse);
      expect(food.fixedTemperature, isNull);
      expect(food.initialTemperature, isNull);

      expect(sweet.supportsTemperatureOptions, isFalse);
      expect(sweet.isColdOnly, isFalse);
      expect(sweet.isHotOnly, isFalse);
      expect(sweet.fixedTemperature, isNull);
      expect(sweet.initialTemperature, isNull);
    });

    test('Flat single-price item without hot/iced prices remains null', () {
      const flatItem = ProductModel(
        productId: 'prod_flat_choco',
        name: 'Choco Lava',
        category: ProductCategory.nonCoffee,
        description: 'Decadent chocolate',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(flatPrice: 105.0),
      );

      expect(flatItem.supportsTemperatureOptions, isFalse);
      expect(flatItem.isColdOnly, isFalse);
      expect(flatItem.isHotOnly, isFalse);
      expect(flatItem.fixedTemperature, isNull);
      expect(flatItem.initialTemperature, isNull);
    });
  });

  group('Recipe Ingredient Temperature Filtering Tests', () {
    final recipe = RecipeModel(
      recipeId: 'rec_biscoff',
      productId: 'prod_biscoff_latte',
      name: 'Biscoff Latte Recipe',
      ingredients: const [
        RecipeIngredientRequirement(
          ingredientId: 'beans',
          ingredientName: 'Espresso Beans',
          quantity: 18.0,
          unit: 'g',
          temperature: 'both',
        ),
        RecipeIngredientRequirement(
          ingredientId: 'milk',
          ingredientName: 'Fresh Milk',
          quantity: 150.0,
          unit: 'ml',
          temperature: 'both',
        ),
        RecipeIngredientRequirement(
          ingredientId: 'biscoff_spread',
          ingredientName: 'Biscoff Spread',
          quantity: 25.0,
          unit: 'g',
          temperature: 'both',
        ),
        RecipeIngredientRequirement(
          ingredientId: 'ice_cup',
          ingredientName: '16oz Iced Cup',
          quantity: 1.0,
          unit: 'pc',
          temperature: 'iced',
          itemType: 'packaging',
        ),
        RecipeIngredientRequirement(
          ingredientId: 'hot_cup',
          ingredientName: '12oz Hot Cup',
          quantity: 1.0,
          unit: 'pc',
          temperature: 'hot',
          itemType: 'packaging',
        ),
      ],
    );

    test('Explicit Iced temperature matches both/all/iced and strictly excludes hot packaging', () {
      final icedReqs = recipe.getRequirementsForTemperature('Iced');

      expect(icedReqs.length, 4);
      expect(icedReqs.any((r) => r.ingredientId == 'beans'), isTrue);
      expect(icedReqs.any((r) => r.ingredientId == 'milk'), isTrue);
      expect(icedReqs.any((r) => r.ingredientId == 'biscoff_spread'), isTrue);
      expect(icedReqs.any((r) => r.ingredientId == 'ice_cup'), isTrue);
      // Strictly excludes hot cup!
      expect(icedReqs.any((r) => r.ingredientId == 'hot_cup'), isFalse);
    });

    test('Null temperature matches all requirements including hot-only', () {
      final allReqs = recipe.getRequirementsForTemperature(null);
      expect(allReqs.length, 5);
      expect(allReqs.any((r) => r.ingredientId == 'hot_cup'), isTrue);
      expect(allReqs.any((r) => r.ingredientId == 'ice_cup'), isTrue);
    });
  });

  group('Sellable Servings Calculation with Iced-Only Products', () {
    test('Zero hot cups do NOT block sellable servings of an iced-only product', () {
      final productsProvider = ProductsProvider();

      const icedCoffee = ProductModel(
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte',
        category: ProductCategory.coffee,
        description: 'Espresso with Lotus Biscoff spread',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(icedPrice: 120.0),
      );

      final recipe = RecipeModel(
        recipeId: 'rec_biscoff',
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte Recipe',
        ingredients: const [
          RecipeIngredientRequirement(
            ingredientId: 'beans',
            ingredientName: 'Espresso Beans',
            quantity: 18.0,
            unit: 'g',
            temperature: 'both',
          ),
          RecipeIngredientRequirement(
            ingredientId: 'ice_cup',
            ingredientName: '16oz Iced Cup',
            quantity: 1.0,
            unit: 'pc',
            temperature: 'iced',
            itemType: 'packaging',
          ),
          RecipeIngredientRequirement(
            ingredientId: 'hot_cup',
            ingredientName: '12oz Hot Cup',
            quantity: 1.0,
            unit: 'pc',
            temperature: 'hot',
            itemType: 'packaging',
          ),
        ],
      );

      productsProvider.setRecipesForTesting({'prod_biscoff_latte': recipe});

      // Branch inventory: Plenty of beans and iced cups, but 0 hot cups
      final List<InventoryItemModel> inventoryItems = [
        const InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Espresso Beans',
          category: 'Ingredient',
          availableQuantity: 360.0, // 20 servings
          unit: 'g',
          minStock: 10,
          branchId: 'br1',
        ),
        const InventoryItemModel(
          id: 'br_ice_cup',
          ingredientId: 'ice_cup',
          name: '16oz Iced Cup',
          category: 'Packaging',
          availableQuantity: 15.0, // 15 servings
          unit: 'pc',
          minStock: 10,
          branchId: 'br1',
        ),
        const InventoryItemModel(
          id: 'br_hot_cup',
          ingredientId: 'hot_cup',
          name: '12oz Hot Cup',
          category: 'Packaging',
          availableQuantity: 0.0, // 0 hot cups in stock!
          unit: 'pc',
          minStock: 10,
          branchId: 'br1',
        ),
      ];

      // Because icedCoffee.fixedTemperature is 'Iced', calculateSellableServings
      // automatically ignores hot_cup and calculates 15 servings based on ice_cup!
      final result = productsProvider.calculateSellableServings(
        product: icedCoffee,
        inventoryItems: inventoryItems,
      );

      expect(result.isAvailable, isTrue);
      expect(result.servings, 15);
      expect(result.limitingIngredientName, '16oz Iced Cup');
    });
  });

  group('ProductDetailsDialog UI & Cart Integration for Iced-Only, Frappe, and Foods', () {
    late PosCartProvider cartProvider;

    setUp(() {
      cartProvider = PosCartProvider();
    });

    Widget createDialogApp(ProductModel product) {
      return ChangeNotifierProvider.value(
        value: cartProvider,
        child: MaterialApp(
          home: Scaffold(
            body: ProductDetailsDialog(product: product),
          ),
        ),
      );
    }

    testWidgets('Iced-only Coffee (Biscoff Latte) does not show temperature chips and adds with Iced variant', (tester) async {
      const icedCoffee = ProductModel(
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: 'Espresso with Lotus Biscoff spread',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(icedPrice: 120.0),
      );

      await tester.pumpWidget(createDialogApp(icedCoffee));

      // No temperature selector displayed
      expect(find.text('Temperature'), findsNothing);
      expect(find.text('Hot'), findsNothing);
      expect(find.text('Iced'), findsNothing);

      // Price displayed is ₱120
      expect(find.text('₱120'), findsWidgets);

      // Add to cart
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      expect(cartProvider.items.length, 1);
      final item = cartProvider.items.first;
      expect(item.product.name, 'Biscoff Latte');
      expect(item.unitPrice, 120.0);
      expect(item.selectedTemperature, 'Iced');
      expect(item.variantLabel, 'Iced');
      expect(cartProvider.totalAmount, 120.0);
    });

    testWidgets('Frappe does not show temperature chips and adds with Iced variant', (tester) async {
      const frappe = ProductModel(
        productId: 'prod_matcha_frappe',
        name: 'Matcha Frappe',
        category: ProductCategory.frappe,
        categoryName: 'Frappe',
        description: 'Blended matcha drink',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(flatPrice: 135.0),
      );

      await tester.pumpWidget(createDialogApp(frappe));

      expect(find.text('Temperature'), findsNothing);
      expect(find.text('₱135'), findsWidgets);

      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      expect(cartProvider.items.length, 1);
      final item = cartProvider.items.first;
      expect(item.product.name, 'Matcha Frappe');
      expect(item.unitPrice, 135.0);
      expect(item.selectedTemperature, 'Iced');
      expect(item.variantLabel, 'Iced');
    });

    testWidgets('Foods (Belgian Waffle) does not show temperature chips and adds with null temperature', (tester) async {
      const food = ProductModel(
        productId: 'prod_waffle',
        name: 'Belgian Waffle',
        category: ProductCategory.foods,
        categoryName: 'Foods',
        description: 'Crispy waffle',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(flatPrice: 85.0),
      );

      await tester.pumpWidget(createDialogApp(food));

      expect(find.text('Temperature'), findsNothing);
      expect(find.text('₱85'), findsWidgets);

      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      expect(cartProvider.items.length, 1);
      final item = cartProvider.items.first;
      expect(item.product.name, 'Belgian Waffle');
      expect(item.unitPrice, 85.0);
      expect(item.selectedTemperature, isNull);
      expect(item.variantLabel, 'Regular');
    });

    testWidgets('PosCartProvider.addToCart automatically assigns fixedTemperature when temperature is omitted', (tester) async {
      const icedCoffee = ProductModel(
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: 'Espresso with Lotus Biscoff spread',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(icedPrice: 120.0),
      );

      // Add to cart without explicitly providing selectedTemperature
      cartProvider.addToCart(
        product: icedCoffee,
        unitPrice: 120.0,
        quantity: 1,
      );

      expect(cartProvider.items.length, 1);
      final item = cartProvider.items.first;
      expect(item.selectedTemperature, 'Iced');
      expect(item.variantLabel, 'Iced');
    });

    test('PosCartProvider.validateCartStock for iced drink ignores 0 stock of hot cup', () {
      const icedCoffee = ProductModel(
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: 'Espresso with Lotus Biscoff spread',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(icedPrice: 120.0),
      );

      final recipe = RecipeModel(
        recipeId: 'rec_biscoff',
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte Recipe',
        ingredients: const [
          RecipeIngredientRequirement(
            ingredientId: 'beans',
            ingredientName: 'Espresso Beans',
            quantity: 18.0,
            unit: 'g',
            temperature: 'both',
          ),
          RecipeIngredientRequirement(
            ingredientId: 'ice_cup',
            ingredientName: '16oz Iced Cup',
            quantity: 1.0,
            unit: 'pc',
            temperature: 'iced',
            itemType: 'packaging',
          ),
          RecipeIngredientRequirement(
            ingredientId: 'hot_cup',
            ingredientName: '12oz Hot Cup',
            quantity: 1.0,
            unit: 'pc',
            temperature: 'hot',
            itemType: 'packaging',
          ),
        ],
      );

      cartProvider.addToCart(
        product: icedCoffee,
        selectedTemperature: 'Iced',
        unitPrice: 120.0,
        quantity: 2,
      );

      final inventoryItems = [
        const InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Espresso Beans',
          category: 'Ingredient',
          availableQuantity: 100.0,
          unit: 'g',
          minStock: 10,
          branchId: 'br1',
        ),
        const InventoryItemModel(
          id: 'br_ice_cup',
          ingredientId: 'ice_cup',
          name: '16oz Iced Cup',
          category: 'Packaging',
          availableQuantity: 10.0,
          unit: 'pc',
          minStock: 10,
          branchId: 'br1',
        ),
        const InventoryItemModel(
          id: 'br_hot_cup',
          ingredientId: 'hot_cup',
          name: '12oz Hot Cup',
          category: 'Packaging',
          availableQuantity: 0.0, // 0 hot cups
          unit: 'pc',
          minStock: 10,
          branchId: 'br1',
        ),
      ];

      final result = cartProvider.validateCartStock(
        recipes: {'prod_biscoff_latte': recipe},
        inventoryItems: inventoryItems,
      );

      // Must be valid because hot cup is excluded!
      expect(result.isValid, isTrue);
      expect(result.deficits, isEmpty);
    });

    test('PosCartProvider.validateCartStock detects deficit when iced cup is insufficient', () {
      const icedCoffee = ProductModel(
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: 'Espresso with Lotus Biscoff spread',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: ProductPricing(icedPrice: 120.0),
      );

      final recipe = RecipeModel(
        recipeId: 'rec_biscoff',
        productId: 'prod_biscoff_latte',
        name: 'Biscoff Latte Recipe',
        ingredients: const [
          RecipeIngredientRequirement(
            ingredientId: 'ice_cup',
            ingredientName: '16oz Iced Cup',
            quantity: 1.0,
            unit: 'pc',
            temperature: 'iced',
            itemType: 'packaging',
          ),
        ],
      );

      cartProvider.addToCart(
        product: icedCoffee,
        selectedTemperature: 'Iced',
        unitPrice: 120.0,
        quantity: 5,
      );

      final inventoryItems = [
        const InventoryItemModel(
          id: 'br_ice_cup',
          ingredientId: 'ice_cup',
          name: '16oz Iced Cup',
          category: 'Packaging',
          availableQuantity: 2.0, // Only 2 in stock, need 5
          unit: 'pc',
          minStock: 10,
          branchId: 'br1',
        ),
      ];

      final result = cartProvider.validateCartStock(
        recipes: {'prod_biscoff_latte': recipe},
        inventoryItems: inventoryItems,
      );

      expect(result.isValid, isFalse);
      expect(result.deficits.length, 1);
      expect(result.deficits.first.ingredientId, 'ice_cup');
      expect(result.deficits.first.requiredAmount, 5.0);
      expect(result.deficits.first.availableAmount, 2.0);
    });
  });
}
