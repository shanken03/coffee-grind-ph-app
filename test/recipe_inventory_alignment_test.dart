import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/recipe_model.dart';
import 'package:coffee_grind_ph/models/cart_item_model.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_card.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_details_dialog.dart';
import 'package:coffee_grind_ph/features/pos/widgets/cart_screen.dart';

void main() {
  group('UnitConverter Tests', () {
    test('Converts grams to kilograms and vice versa', () {
      expect(
        UnitConverter.convert(quantity: 1000, fromUnit: 'g', toUnit: 'kg'),
        1.0,
      );
      expect(
        UnitConverter.convert(quantity: 250, fromUnit: 'g', toUnit: 'kg'),
        0.25,
      );
      expect(
        UnitConverter.convert(quantity: 1.5, fromUnit: 'kg', toUnit: 'g'),
        1500.0,
      );
      expect(
        UnitConverter.convert(quantity: 18, fromUnit: 'grams', toUnit: 'kilo'),
        0.018,
      );
    });

    test('Converts milliliters to liters and vice versa', () {
      expect(
        UnitConverter.convert(quantity: 1000, fromUnit: 'ml', toUnit: 'l'),
        1.0,
      );
      expect(
        UnitConverter.convert(quantity: 200, fromUnit: 'ml', toUnit: 'l'),
        0.2,
      );
      expect(
        UnitConverter.convert(quantity: 2.0, fromUnit: 'l', toUnit: 'ml'),
        2000.0,
      );
    });

    test('Passes count/piece units directly', () {
      expect(
        UnitConverter.convert(quantity: 5, fromUnit: 'pc', toUnit: 'pcs'),
        5.0,
      );
      expect(
        UnitConverter.convert(quantity: 10, fromUnit: 'piece', toUnit: 'unit'),
        10.0,
      );
      expect(
        UnitConverter.convert(quantity: 1, fromUnit: 'cup', toUnit: 'cup'),
        1.0,
      );
    });

    test('Rejects incompatible units', () {
      // Mass to volume without density
      expect(
        UnitConverter.convert(quantity: 50, fromUnit: 'g', toUnit: 'ml'),
        isNull,
      );
      // Mass to count
      expect(
        UnitConverter.convert(quantity: 100, fromUnit: 'g', toUnit: 'pcs'),
        isNull,
      );
    });

    test('Normalizes case and whitespace', () {
      expect(
        UnitConverter.convert(quantity: 500, fromUnit: ' G ', toUnit: 'KG'),
        0.5,
      );
      expect(
        UnitConverter.convert(quantity: 1, fromUnit: 'Liter', toUnit: 'ML'),
        1000.0,
      );
    });
  });

  group('RecipeModel & Requirements Parsing Tests', () {
    test('Parses List format with temperature and unit costs', () {
      final doc = {
        'productId': 'prod_latte',
        'name': 'Caffe Latte Recipe',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'name': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'temperature': 'both',
            'unitCost': 1.2,
          },
          {
            'ingredientId': 'ing_milk',
            'name': 'Fresh Milk',
            'quantity': 180.0,
            'unit': 'ml',
            'temperature': 'both',
            'unitCost': 0.15,
          },
          {
            'ingredientId': 'pkg_ice_cup',
            'name': '16oz Iced Cup',
            'quantity': 1.0,
            'unit': 'pc',
            'temperature': 'iced',
            'itemType': 'packaging',
          },
          {
            'ingredientId': 'pkg_hot_cup',
            'name': '12oz Hot Cup',
            'quantity': 1.0,
            'unit': 'pc',
            'temperature': 'hot',
            'itemType': 'packaging',
          },
        ],
      };

      final recipe = RecipeModel.fromFirestore('recipe_latte', doc);
      expect(recipe.productId, 'prod_latte');
      expect(recipe.ingredients.length, 4);

      final hotReqs = recipe.getRequirementsForTemperature('hot');
      expect(hotReqs.any((r) => r.ingredientId == 'pkg_hot_cup'), isTrue);
      expect(hotReqs.any((r) => r.ingredientId == 'pkg_ice_cup'), isFalse);

      final icedReqs = recipe.getRequirementsForTemperature('iced');
      expect(icedReqs.any((r) => r.ingredientId == 'pkg_ice_cup'), isTrue);
      expect(icedReqs.any((r) => r.ingredientId == 'pkg_hot_cup'), isFalse);
    });

    test('Parses Map format ingredients', () {
      final doc = {
        'productId': 'prod_americano',
        'ingredients': {
          'ing_beans': {'amount': 20.0, 'unit': 'g', 'temperature': 'both'},
          'pkg_cup': 1.0,
        },
      };

      final recipe = RecipeModel.fromFirestore('recipe_americano', doc);
      expect(recipe.ingredients.length, 2);
      expect(
        recipe.ingredients.any(
          (r) => r.ingredientId == 'ing_beans' && r.quantity == 20.0,
        ),
        isTrue,
      );
      expect(
        recipe.ingredients.any(
          (r) => r.ingredientId == 'pkg_cup' && r.quantity == 1.0,
        ),
        isTrue,
      );
    });
  });

  group('Sellable Servings Calculation Tests', () {
    final sampleProduct = ProductModel(
      productId: 'p_latte',
      name: 'Latte',
      category: ProductCategory.coffee,
      categoryName: 'Coffee',
      description: '',
      imageUrl: '',
      availableBranches: ['all'],
      pricing: const ProductPricing(hotPrice: 90, icedPrice: 100),
      isAvailable: true,
    );

    final latteRecipe = RecipeModel(
      recipeId: 'rec_latte',
      productId: 'p_latte',
      name: 'Latte Recipe',
      ingredients: const [
        RecipeIngredientRequirement(
          ingredientId: 'beans',
          ingredientName: 'Coffee Beans',
          quantity: 20, // 20g per serving
          unit: 'g',
          temperature: 'both',
        ),
        RecipeIngredientRequirement(
          ingredientId: 'milk',
          ingredientName: 'Fresh Milk',
          quantity: 200, // 200ml per serving
          unit: 'ml',
          temperature: 'both',
        ),
      ],
    );

    test('Calculates servings based on limiting ingredient bottleneck', () {
      final provider = ProductsProvider();
      provider.setRecipesForTesting({'p_latte': latteRecipe});

      // Branch has 100g beans (5 servings: 100/20) and 2000ml milk (10 servings: 2000/200)
      // Beans is bottleneck -> 5 servings
      final inventory = [
        const InventoryItemModel(
          id: 'br1_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 100, // 100g
          unit: 'g',
          minStock: 10,
          branchId: 'br1',
        ),
        const InventoryItemModel(
          id: 'br1_milk',
          ingredientId: 'milk',
          name: 'Fresh Milk',
          category: 'Ingredient',
          availableQuantity: 2000, // 2000ml
          unit: 'ml',
          minStock: 10,
          branchId: 'br1',
        ),
      ];

      final result = provider.calculateSellableServings(
        product: sampleProduct,
        inventoryItems: inventory,
      );

      expect(result.servings, 5);
      expect(result.isAvailable, isTrue);
      expect(result.isOutOfStock, isFalse);
      expect(result.limitingIngredientName, 'Coffee Beans');
    });

    test('Reports 0 servings when an ingredient is out of stock', () {
      final provider = ProductsProvider();
      provider.setRecipesForTesting({'p_latte': latteRecipe});

      final inventory = [
        const InventoryItemModel(
          id: 'br1_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 0, // 0g beans
          unit: 'g',
          minStock: 10,
          branchId: 'br1',
        ),
        const InventoryItemModel(
          id: 'br1_milk',
          ingredientId: 'milk',
          name: 'Fresh Milk',
          category: 'Ingredient',
          availableQuantity: 2000,
          unit: 'ml',
          minStock: 10,
          branchId: 'br1',
        ),
      ];

      final result = provider.calculateSellableServings(
        product: sampleProduct,
        inventoryItems: inventory,
      );

      expect(result.servings, 0);
      expect(result.isAvailable, isFalse);
      expect(result.isOutOfStock, isTrue);
      expect(result.limitingIngredientName, 'Coffee Beans');
    });

    test('Reports 0 servings when recipe is missing and not loading', () {
      final provider = ProductsProvider();
      provider.setRecipesForTesting({}); // No recipes loaded

      final result = provider.calculateSellableServings(
        product: sampleProduct,
        inventoryItems: const [],
      );

      expect(result.servings, 0);
      expect(result.hasRecipe, isFalse);
      expect(result.isAvailable, isFalse);
      expect(result.errorReason, contains('Missing recipe'));
    });

    test(
      'Handles unit conversion during servings calculation (g to kg, ml to L)',
      () {
        final recipeReqs = [
          const RecipeIngredientRequirement(
            ingredientId: 'beans',
            ingredientName: 'Coffee Beans',
            quantity: 20, // 20g
            unit: 'g',
          ),
          const RecipeIngredientRequirement(
            ingredientId: 'milk',
            ingredientName: 'Fresh Milk',
            quantity: 200, // 200ml
            unit: 'ml',
          ),
        ];

        // Inventory stored in kg and L: 1kg beans (= 1000g / 20g = 50 servings), 1.0L milk (= 1000ml / 200ml = 5 servings)
        final inventory = [
          const InventoryItemModel(
            id: 'br1_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 1.0, // 1 kg
            unit: 'kg',
            minStock: 0.1,
            branchId: 'br1',
          ),
          const InventoryItemModel(
            id: 'br1_milk',
            ingredientId: 'milk',
            name: 'Fresh Milk',
            category: 'Ingredient',
            availableQuantity: 1.0, // 1 L
            unit: 'l',
            minStock: 0.5,
            branchId: 'br1',
          ),
        ];

        // Converted milk allows exactly 5 servings (1.0L / 0.2L)
        final beansConverted = UnitConverter.convert(
          quantity: recipeReqs[0].quantity,
          fromUnit: 'g',
          toUnit: 'kg',
        )!;
        expect(beansConverted, 0.02);
        expect((inventory[0].availableQuantity / beansConverted).floor(), 50);

        final milkConverted = UnitConverter.convert(
          quantity: recipeReqs[1].quantity,
          fromUnit: 'ml',
          toUnit: 'l',
        )!;
        expect(milkConverted, 0.2);
        expect((inventory[1].availableQuantity / milkConverted).floor(), 5);
      },
    );
  });

  group('PosCartProvider Shared-Ingredient Cumulative Validation Tests', () {
    final prod1 = ProductModel(
      productId: 'p1',
      name: 'Latte',
      category: ProductCategory.coffee,
      categoryName: 'Coffee',
      description: '',
      imageUrl: '',
      availableBranches: ['all'],
      pricing: const ProductPricing(flatPrice: 100),
      isAvailable: true,
    );

    final prod2 = ProductModel(
      productId: 'p2',
      name: 'Cappuccino',
      category: ProductCategory.coffee,
      categoryName: 'Coffee',
      description: '',
      imageUrl: '',
      availableBranches: ['all'],
      pricing: const ProductPricing(flatPrice: 110),
      isAvailable: true,
    );

    final recipes = {
      'p1': const RecipeModel(
        recipeId: 'rec_p1',
        productId: 'p1',
        ingredients: [
          RecipeIngredientRequirement(
            ingredientId: 'beans',
            ingredientName: 'Coffee Beans',
            quantity: 20,
            unit: 'g',
          ),
          RecipeIngredientRequirement(
            ingredientId: 'milk',
            ingredientName: 'Fresh Milk',
            quantity: 150,
            unit: 'ml',
          ),
        ],
      ),
      'p2': const RecipeModel(
        recipeId: 'rec_p2',
        productId: 'p2',
        ingredients: [
          RecipeIngredientRequirement(
            ingredientId: 'beans',
            ingredientName: 'Coffee Beans',
            quantity: 20,
            unit: 'g',
          ),
          RecipeIngredientRequirement(
            ingredientId: 'milk',
            ingredientName: 'Fresh Milk',
            quantity: 100,
            unit: 'ml',
          ),
        ],
      ),
    };

    test('Validates cart when cumulative demand is within stock', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: prod1,
        unitPrice: 100,
        quantity: 2,
      ); // 40g beans, 300ml milk
      cart.addToCart(
        product: prod2,
        unitPrice: 110,
        quantity: 1,
      ); // 20g beans, 100ml milk
      // Total needed: 60g beans, 400ml milk

      final inventory = [
        const InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 100, // 100g > 60g
          unit: 'g',
          minStock: 10,
          branchId: 'br1',
        ),
        const InventoryItemModel(
          id: 'br_milk',
          ingredientId: 'milk',
          name: 'Fresh Milk',
          category: 'Ingredient',
          availableQuantity: 500, // 500ml > 400ml
          unit: 'ml',
          minStock: 50,
          branchId: 'br1',
        ),
      ];

      final result = cart.validateCartStock(
        recipes: recipes,
        inventoryItems: inventory,
      );
      expect(result.isValid, isTrue);
      expect(result.deficits, isEmpty);
    });

    test(
      'Detects deficit when shared ingredient cumulative demand exceeds stock',
      () {
        final cart = PosCartProvider();
        cart.addToCart(
          product: prod1,
          unitPrice: 100,
          quantity: 2,
        ); // 40g beans
        cart.addToCart(
          product: prod2,
          unitPrice: 110,
          quantity: 2,
        ); // 40g beans
        // Total needed: 80g beans. But stock is only 50g!
        // (Even though individually each item needed 40g <= 50g)

        final inventory = [
          const InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 50, // Only 50g available!
            unit: 'g',
            minStock: 10,
            branchId: 'br1',
          ),
          const InventoryItemModel(
            id: 'br_milk',
            ingredientId: 'milk',
            name: 'Fresh Milk',
            category: 'Ingredient',
            availableQuantity: 1000,
            unit: 'ml',
            minStock: 50,
            branchId: 'br1',
          ),
        ];

        final result = cart.validateCartStock(
          recipes: recipes,
          inventoryItems: inventory,
        );
        expect(result.isValid, isFalse);
        expect(result.deficits.length, 1);
        expect(result.deficits.first.ingredientId, 'beans');
        expect(result.deficits.first.requiredAmount, 80.0);
        expect(result.deficits.first.availableAmount, 50.0);
        expect(result.errorMessage, contains('Insufficient branch inventory'));
      },
    );

    test('Detects missing recipe configuration', () {
      final cart = PosCartProvider();
      final prodNoRecipe = ProductModel(
        productId: 'p_unknown',
        name: 'Mystery Drink',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 150),
        isAvailable: true,
      );

      cart.addToCart(product: prodNoRecipe, unitPrice: 150, quantity: 1);

      final result = cart.validateCartStock(
        recipes: recipes, // missing p_unknown
        inventoryItems: const [],
        allowMissingRecipes: false,
      );

      expect(result.isValid, isFalse);
      expect(result.missingRecipes, contains('Mystery Drink'));
      expect(
        result.errorMessage,
        contains('Products missing recipe configuration'),
      );
    });

    test('Detects missing inventory record for recipe requirement', () {
      final cart = PosCartProvider();
      cart.addToCart(product: prod1, unitPrice: 100, quantity: 1);

      // Inventory only has milk, missing beans completely
      final inventory = [
        const InventoryItemModel(
          id: 'br_milk',
          ingredientId: 'milk',
          name: 'Fresh Milk',
          category: 'Ingredient',
          availableQuantity: 1000,
          unit: 'ml',
          minStock: 50,
          branchId: 'br1',
        ),
      ];

      final result = cart.validateCartStock(
        recipes: recipes,
        inventoryItems: inventory,
      );
      expect(result.isValid, isFalse);
      expect(result.missingInventory, contains('Coffee Beans'));
      expect(result.errorMessage, contains('Missing inventory records'));
    });

    test('Detects incompatible units between recipe and inventory', () {
      final cart = PosCartProvider();
      cart.addToCart(product: prod1, unitPrice: 100, quantity: 1);

      // Inventory has beans in 'pieces' but recipe uses 'g'
      final inventory = [
        const InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 100,
          unit: 'pcs', // Incompatible with g!
          minStock: 10,
          branchId: 'br1',
        ),
        const InventoryItemModel(
          id: 'br_milk',
          ingredientId: 'milk',
          name: 'Fresh Milk',
          category: 'Ingredient',
          availableQuantity: 1000,
          unit: 'ml',
          minStock: 50,
          branchId: 'br1',
        ),
      ];

      final result = cart.validateCartStock(
        recipes: recipes,
        inventoryItems: inventory,
      );
      expect(result.isValid, isFalse);
      expect(result.incompatibleUnits, isNotEmpty);
      expect(result.errorMessage, contains('Incompatible unit configurations'));
    });
  });

  group('PosCartProvider Branch Product Live Stock Validation Tests', () {
    final prodAmericano = ProductModel(
      productId: 'prod_americano',
      name: 'Americano',
      category: ProductCategory.coffee,
      categoryName: 'Coffee',
      description: 'Espresso diluted with water',
      imageUrl: '',
      availableBranches: const ['all'],
      pricing: const ProductPricing(hotPrice: 100, icedPrice: 110),
      isAvailable: true,
      recipeId: 'rec_americano',
    );

    final americanoRecipe = RecipeModel(
      recipeId: 'rec_americano',
      productId: 'prod_americano',
      ingredients: const [
        RecipeIngredientRequirement(
          ingredientId: 'beans',
          quantity: 18,
          unit: 'g',
          temperature: 'both',
        ),
        RecipeIngredientRequirement(
          ingredientId: 'hot_cup',
          quantity: 1,
          unit: 'pcs',
          temperature: 'hot',
        ),
        RecipeIngredientRequirement(
          ingredientId: 'iced_cup',
          quantity: 1,
          unit: 'pcs',
          temperature: 'iced',
        ),
      ],
    );

    final recipes = {'prod_americano': americanoRecipe};

    test(
      'Requested quantity = 3 but available physical inventory = 2: blocked',
      () {
        final cart = PosCartProvider();
        cart.addToCart(
          product: prodAmericano,
          selectedTemperature: 'Hot',
          unitPrice: 100,
          quantity: 3,
        );

        final limitedInventory = [
          const InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 1800,
            unit: 'g',
            minStock: 10,
            branchId: 'br_1790905840872',
          ),
          const InventoryItemModel(
            id: 'br_hot_cup',
            ingredientId: 'hot_cup',
            name: 'Hot Cup',
            category: 'Packaging',
            availableQuantity: 2, // Only 2 cups
            unit: 'pcs',
            minStock: 10,
            branchId: 'br_1790905840872',
          ),
        ];

        final result = cart.validateCartStock(
          recipes: recipes,
          inventoryItems: limitedInventory,
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Insufficient branch inventory'));
        expect(result.deficits.any((d) => d.ingredientId == 'hot_cup'), isTrue);
      },
    );

    test('Requested quantity = 2 and available physical inventory = 2: allowed if recipe ingredients and packaging suffice', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100,
        quantity: 2,
      );

      final exactInventory = [
        const InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 1800,
          unit: 'g',
          minStock: 10,
          branchId: 'br_1790905840872',
        ),
        const InventoryItemModel(
          id: 'br_hot_cup',
          ingredientId: 'hot_cup',
          name: 'Hot Cup',
          category: 'Packaging',
          availableQuantity: 2, // Exactly 2 cups
          unit: 'pcs',
          minStock: 10,
          branchId: 'br_1790905840872',
        ),
      ];

      final result = cart.validateCartStock(
        recipes: recipes,
        inventoryItems: exactInventory,
      );

      expect(result.isValid, isTrue);
      expect(result.deficits, isEmpty);
    });

    test('Packaging insufficient: blocked with deficits information', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100,
        quantity: 2,
      );

      // Inventory only has 1 hot cup, but cart requires 2
      final lowInventory = [
        const InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 1800,
          unit: 'g',
          minStock: 10,
          branchId: 'br_1790905840872',
        ),
        const InventoryItemModel(
          id: 'br_hot_cup',
          ingredientId: 'hot_cup',
          name: 'Hot Cup',
          category: 'Packaging',
          availableQuantity: 1, // Only 1 cup!
          unit: 'pcs',
          minStock: 10,
          branchId: 'br_1790905840872',
        ),
      ];

      final result = cart.validateCartStock(
        recipes: recipes,
        inventoryItems: lowInventory,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Insufficient branch inventory'));
      expect(result.deficits.any((d) => d.ingredientId == 'hot_cup'), isTrue);
    });

    test('Santa Cruz physical inventory is not used for LSPU, and vice versa (Branch Isolation)', () {
      final cart = PosCartProvider();
      cart.addToCart(
        product: prodAmericano,
        selectedTemperature: 'Hot',
        unitPrice: 100,
        quantity: 2,
      );

      const santaCruzBranch = 'br_1790905840872';
      const lspuBranch = 'br_1790923872261';

      // Santa Cruz inventory has 10 cups
      final scInventory = [
        const InventoryItemModel(
          id: 'br_sc_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 1800,
          unit: 'g',
          minStock: 10,
          branchId: santaCruzBranch,
        ),
        const InventoryItemModel(
          id: 'br_sc_hot_cup',
          ingredientId: 'hot_cup',
          name: 'Hot Cup',
          category: 'Packaging',
          availableQuantity: 10,
          unit: 'pcs',
          minStock: 10,
          branchId: santaCruzBranch,
        ),
      ];

      // LSPU inventory has 0 cups
      final lspuInventory = [
        const InventoryItemModel(
          id: 'br_lspu_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 1800,
          unit: 'g',
          minStock: 10,
          branchId: lspuBranch,
        ),
        const InventoryItemModel(
          id: 'br_lspu_hot_cup',
          ingredientId: 'hot_cup',
          name: 'Hot Cup',
          category: 'Packaging',
          availableQuantity: 0,
          unit: 'pcs',
          minStock: 10,
          branchId: lspuBranch,
        ),
      ];

      // Validating against Santa Cruz inventory succeeds
      final scResult = cart.validateCartStock(
        recipes: recipes,
        inventoryItems: scInventory,
      );
      expect(scResult.isValid, isTrue);

      // Validating against LSPU inventory fails
      final lspuResult = cart.validateCartStock(
        recipes: recipes,
        inventoryItems: lspuInventory,
      );
      expect(lspuResult.isValid, isFalse);
      expect(
        lspuResult.errorMessage,
        contains('Insufficient branch inventory'),
      );
    });

    test(
      'Existing hot/iced validation remains correct with physical inventory',
      () {
        final cart = PosCartProvider();
        cart.addToCart(
          product: prodAmericano,
          selectedTemperature: 'Iced',
          unitPrice: 110,
          quantity: 2,
        );

        // Inventory only has iced cups (0 hot cups)
        final icedOnlyInventory = [
          const InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 1800,
            unit: 'g',
            minStock: 10,
            branchId: 'br_1790905840872',
          ),
          const InventoryItemModel(
            id: 'br_hot_cup',
            ingredientId: 'hot_cup',
            name: 'Hot Cup',
            category: 'Packaging',
            availableQuantity: 0, // 0 hot cups should be ignored for iced
            unit: 'pcs',
            minStock: 10,
            branchId: 'br_1790905840872',
          ),
          const InventoryItemModel(
            id: 'br_iced_cup',
            ingredientId: 'iced_cup',
            name: 'Iced Cup',
            category: 'Packaging',
            availableQuantity: 10,
            unit: 'pcs',
            minStock: 10,
            branchId: 'br_1790905840872',
          ),
        ];

        final result = cart.validateCartStock(
          recipes: recipes,
          inventoryItems: icedOnlyInventory,
        );

        expect(result.isValid, isTrue);
      },
    );
  });

  group('Item Variant Preservation in Cart & Transaction Items', () {
    test(
      'CartItemModel preserves temperature and size across serialization',
      () {
        final product = ProductModel(
          productId: 'prod_matcha',
          name: 'Matcha Latte',
          category: ProductCategory.nonCoffee,
          categoryName: 'Non Coffee',
          description: '',
          imageUrl: '',
          availableBranches: ['all'],
          pricing: const ProductPricing(hotPrice: 95, icedPrice: 110),
          isAvailable: true,
        );

        final hotItem = CartItemModel(
          id: 'hot_1',
          product: product,
          selectedTemperature: 'Hot',
          selectedSize: null,
          unitPrice: 95,
          quantity: 2,
        );

        expect(hotItem.variantLabel, 'Hot');
        expect(hotItem.subtotal, 190.0);

        final icedItem = CartItemModel(
          id: 'iced_1',
          product: product,
          selectedTemperature: 'Iced',
          selectedSize: null,
          unitPrice: 110,
          quantity: 3,
        );

        expect(icedItem.variantLabel, 'Iced');
        expect(icedItem.subtotal, 330.0);
      },
    );
  });

  group('ProductCard Recipe-Based Stock UI Tests', () {
    testWidgets(
      'Displays OUT OF STOCK and disabled Add button when recipe ingredients have 0 stock',
      (tester) async {
        final productsProvider = ProductsProvider();
        final inventoryProvider = InventoryProvider();

        final latte = ProductModel(
          productId: 'prod_latte_test',
          name: 'Latte Test',
          category: ProductCategory.coffee,
          categoryName: 'Coffee',
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: ['all'],
          pricing: const ProductPricing(flatPrice: 100),
        );

        final latteRecipe = RecipeModel(
          recipeId: 'rec_latte_test',
          productId: 'prod_latte_test',
          ingredients: const [
            RecipeIngredientRequirement(
              ingredientId: 'beans',
              quantity: 20,
              unit: 'g',
            ),
          ],
        );

        productsProvider.setRecipesForTesting({'prod_latte_test': latteRecipe});
        // 0 stock in inventory
        inventoryProvider.setItemsForTesting([
          const InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 0,
            unit: 'g',
            minStock: 10,
            branchId: 'br1',
          ),
        ]);

        bool addTapped = false;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: productsProvider),
              ChangeNotifierProvider.value(value: inventoryProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 280,
                  child: ProductCard(
                    product: latte,
                    onTap: () {},
                    onAdd: () {
                      addTapped = true;
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('OUT OF STOCK'), findsOneWidget);
        expect(find.text('Out of Stock'), findsWidgets);
        expect(find.byIcon(Icons.block_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.block_rounded));
        await tester.pump();
        expect(addTapped, isFalse);
      },
    );

    testWidgets('Does not display misleading stock count when stock is available', (
      tester,
    ) async {
      final productsProvider = ProductsProvider();
      final inventoryProvider = InventoryProvider();

      final latte = ProductModel(
        productId: 'prod_latte_5',
        name: 'Latte Test 5',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 100),
      );

      final latteRecipe = RecipeModel(
        recipeId: 'rec_latte_5',
        productId: 'prod_latte_5',
        ingredients: const [
          RecipeIngredientRequirement(
            ingredientId: 'beans',
            quantity: 20,
            unit: 'g',
          ),
        ],
      );

      productsProvider.setRecipesForTesting({'prod_latte_5': latteRecipe});
      // 100g beans / 20g = 5 servings
      inventoryProvider.setItemsForTesting([
        const InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 100,
          unit: 'g',
          minStock: 10,
          branchId: 'br1',
        ),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: productsProvider),
            ChangeNotifierProvider.value(value: inventoryProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 280,
                child: ProductCard(product: latte, onTap: () {}, onAdd: () {}),
              ),
            ),
          ),
        ),
      );

      // Verify exact computed low-stock servings badge is displayed
      expect(find.textContaining('left'), findsNothing);
      expect(find.text('LOW STOCK — 5 servings'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Latte Test 5'), findsOneWidget);
      expect(find.text('₱100'), findsOneWidget);
    });

    testWidgets(
      'ProductCard does not display misleading estimated stock count when calculated sellable servings exceed 50',
      (tester) async {
        final productsProvider = ProductsProvider();
        final inventoryProvider = InventoryProvider();

        final latte = ProductModel(
          productId: 'prod_latte_high_stock',
          name: 'Latte High Stock',
          category: ProductCategory.coffee,
          categoryName: 'Coffee',
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: ['all'],
          pricing: const ProductPricing(flatPrice: 100),
        );

        final latteRecipe = RecipeModel(
          recipeId: 'rec_latte_high_stock',
          productId: 'prod_latte_high_stock',
          ingredients: const [
            RecipeIngredientRequirement(
              ingredientId: 'beans',
              quantity: 20,
              unit: 'g',
            ),
          ],
        );

        productsProvider.setRecipesForTesting({
          'prod_latte_high_stock': latteRecipe,
        });
        // 2000g beans / 20g = 100 servings (> 50)
        inventoryProvider.setItemsForTesting([
          const InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 2000,
            unit: 'g',
            minStock: 10,
            branchId: 'br1',
          ),
        ]);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: productsProvider),
              ChangeNotifierProvider.value(value: inventoryProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 280,
                  child: ProductCard(
                    product: latte,
                    onTap: () {},
                    onAdd: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        // Verify exact computed available servings badge is displayed (not capped at 50)
        expect(find.textContaining('left'), findsNothing);
        expect(find.text('AVAILABLE — 100 servings'), findsOneWidget);
        expect(find.text('Add'), findsOneWidget);
        expect(find.text('Latte High Stock'), findsOneWidget);
        expect(find.text('₱100'), findsOneWidget);
      },
    );
  });

  group('ProductDetailsDialog Stock Limit Tests', () {
    testWidgets('Stepper does not increment past available servings', (
      tester,
    ) async {
      final productsProvider = ProductsProvider();
      final inventoryProvider = InventoryProvider();
      final cartProvider = PosCartProvider();

      final latte = ProductModel(
        productId: 'prod_latte_dialog',
        name: 'Latte Dialog',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 100),
      );

      final latteRecipe = RecipeModel(
        recipeId: 'rec_latte_dialog',
        productId: 'prod_latte_dialog',
        ingredients: const [
          RecipeIngredientRequirement(
            ingredientId: 'beans',
            quantity: 20,
            unit: 'g',
          ),
        ],
      );

      productsProvider.setRecipesForTesting({'prod_latte_dialog': latteRecipe});
      productsProvider.setProductsForTesting([latte]);
      // 40g beans / 20g = 2 servings
      inventoryProvider.setItemsForTesting([
        const InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 40,
          unit: 'g',
          minStock: 10,
          branchId: 'br1',
        ),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: productsProvider),
            ChangeNotifierProvider.value(value: inventoryProvider),
            ChangeNotifierProvider.value(value: cartProvider),
          ],
          child: MaterialApp(
            home: Scaffold(body: ProductDetailsDialog(product: latte)),
          ),
        ),
      );

      // Verify exact computed servings chip is displayed
      expect(find.textContaining('in stock'), findsNothing);
      expect(find.text('LOW STOCK — 2 servings'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Increment to 2
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      // Attempt to increment past 2 (should remain 2 because button is disabled)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('CartScreen Stock Deficit UI Tests', () {
    testWidgets(
      'Displays Stock Deficit Detected and disables checkout when cart exceeds inventory',
      (tester) async {
        final productsProvider = ProductsProvider();
        final inventoryProvider = InventoryProvider();
        final cartProvider = PosCartProvider();

        final latte = ProductModel(
          productId: 'prod_cart_test',
          name: 'Cart Latte',
          category: ProductCategory.coffee,
          categoryName: 'Coffee',
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: ['all'],
          pricing: const ProductPricing(flatPrice: 100),
        );

        final latteRecipe = RecipeModel(
          recipeId: 'rec_cart_test',
          productId: 'prod_cart_test',
          ingredients: const [
            RecipeIngredientRequirement(
              ingredientId: 'beans',
              quantity: 20,
              unit: 'g',
            ),
          ],
        );

        productsProvider.setRecipesForTesting({'prod_cart_test': latteRecipe});
        // 20g in stock (allows 1 serving)
        inventoryProvider.setItemsForTesting([
          const InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 20,
            unit: 'g',
            minStock: 10,
            branchId: 'br1',
          ),
        ]);

        // Add 2 items to cart (needs 40g > 20g stock)
        cartProvider.addToCart(product: latte, unitPrice: 100, quantity: 2);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: productsProvider),
              ChangeNotifierProvider.value(value: inventoryProvider),
              ChangeNotifierProvider.value(value: cartProvider),
            ],
            child: const MaterialApp(home: CartScreen()),
          ),
        );

        expect(find.text('Stock Deficit Detected'), findsOneWidget);
        expect(find.text('Stock Exceeded — Adjust Cart'), findsOneWidget);

        // Decrement quantity in cart to 1 (needs 20g <= 20g stock)
        await tester.tap(find.byIcon(Icons.remove_circle_outline));
        await tester.pump();

        // Warning disappears, Proceed to Checkout is restored!
        expect(find.text('Stock Deficit Detected'), findsNothing);
        expect(find.text('Proceed to Checkout'), findsOneWidget);
      },
    );

    testWidgets(
      'CartScreen stepper cannot increment past branch product stock quota',
      (tester) async {
        final productsProvider = ProductsProvider();
        final inventoryProvider = InventoryProvider();
        final cartProvider = PosCartProvider();

        final americano = ProductModel(
          productId: 'prod_americano_ui',
          name: 'Americano UI',
          category: ProductCategory.coffee,
          categoryName: 'Coffee',
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: const ['all'],
          pricing: const ProductPricing(hotPrice: 100),
          recipeId: 'rec_americano_ui',
        );

        final americanoRecipe = RecipeModel(
          recipeId: 'rec_americano_ui',
          productId: 'prod_americano_ui',
          ingredients: const [
            RecipeIngredientRequirement(
              ingredientId: 'beans',
              quantity: 18,
              unit: 'g',
            ),
            RecipeIngredientRequirement(
              ingredientId: 'cup',
              quantity: 1,
              unit: 'pcs',
            ),
          ],
        );

        productsProvider.setRecipesForTesting({
          'prod_americano_ui': americanoRecipe,
        });
        productsProvider.setProductsForTesting([americano]);

        // 1000g beans and 2 cups (physical inventory limit is 2 servings)
        inventoryProvider.setItemsForTesting([
          const InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 1000,
            unit: 'g',
            minStock: 10,
            branchId: 'br_sc',
          ),
          const InventoryItemModel(
            id: 'br_cup',
            ingredientId: 'cup',
            name: 'Cup',
            category: 'Packaging',
            availableQuantity: 2, // Physical inventory limit is 2!
            unit: 'pcs',
            minStock: 10,
            branchId: 'br_sc',
          ),
        ]);

        // Add 1 item to cart initially
        cartProvider.addToCart(
          product: americano,
          selectedTemperature: 'Hot',
          unitPrice: 100,
          quantity: 1,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: productsProvider),
              ChangeNotifierProvider.value(value: inventoryProvider),
              ChangeNotifierProvider.value(value: cartProvider),
            ],
            child: const MaterialApp(home: CartScreen()),
          ),
        );

        expect(find.text('1'), findsOneWidget);

        // Increment to 2 (allowed since quota = 2)
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pump();
        expect(find.text('2'), findsOneWidget);

        // At quantity 2, the increment button must be disabled
        final addIconButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.add_circle_outline),
        );
        expect(addIconButton.onPressed, isNull);

        // Tapping disabled button should not increment past 2
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pump();
        expect(find.text('2'), findsOneWidget);

        // Decrementing to 1 re-enables the increment button
        await tester.tap(find.byIcon(Icons.remove_circle_outline));
        await tester.pump();
        expect(find.text('1'), findsOneWidget);
        final reEnabledButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.add_circle_outline),
        );
        expect(reEnabledButton.onPressed, isNotNull);
      },
    );
  });

  group('Phase 2 Dual-Temperature Fallback & Shared-Ingredient Cart Stock Tests', () {
    test('Dual-temperature fallback defaults to Iced and never returns Hot + Iced packaging together', () {
      const dualRecipe = RecipeModel(
        recipeId: 'rec_americano_dual',
        productId: 'prod_americano_dual',
        name: 'Americano',
        ingredients: [
          RecipeIngredientRequirement(
            ingredientId: 'beans',
            ingredientName: 'Espresso Beans',
            quantity: 18,
            unit: 'g',
            temperature: 'both',
          ),
          RecipeIngredientRequirement(
            ingredientId: 'cup_hot_8oz',
            ingredientName: '8oz Hot Cup',
            quantity: 1,
            unit: 'pcs',
            temperature: 'hot',
            itemType: 'packaging',
          ),
          RecipeIngredientRequirement(
            ingredientId: 'cup_iced_890ml',
            ingredientName: '890ml Iced Cup',
            quantity: 1,
            unit: 'pcs',
            temperature: 'iced',
            itemType: 'packaging',
          ),
        ],
      );

      // Even if null is passed directly, dual-temp recipe selects Iced only.
      final nullReqs = dualRecipe.getRequirementsForTemperature(null);
      expect(nullReqs.map((r) => r.ingredientId).toSet(), {'beans', 'cup_iced_890ml'});
      expect(nullReqs.any((r) => r.temperature == 'hot'), isFalse);

      // Explicit Hot returns Hot packaging only.
      final hotReqs = dualRecipe.getRequirementsForTemperature('Hot');
      expect(hotReqs.map((r) => r.ingredientId).toSet(), {'beans', 'cup_hot_8oz'});

      // Cart addition without explicit selectedTemperature falls back to initialTemperature ('Iced').
      final dualProduct = ProductModel(
        productId: 'prod_americano_dual',
        name: 'Americano',
        category: ProductCategory.coffee,
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: const ['all'],
        pricing: const ProductPricing(hotPrice: 90, icedPrice: 110),
        recipeId: 'rec_americano_dual',
      );
      expect(dualProduct.initialTemperature, 'Iced');

      final cart = PosCartProvider();
      cart.addToCart(
        product: dualProduct,
        selectedTemperature: null,
        unitPrice: 110,
        quantity: 1,
      );
      expect(cart.items.single.selectedTemperature, 'Iced');
    });

    test('Missing recipe or missing inventory fails safely (0 servings, never unlimited)', () {
      final productsProvider = ProductsProvider();
      productsProvider.setRecipesForTesting({});

      final prod = ProductModel(
        productId: 'prod_no_recipe',
        name: 'Mystery Drink',
        category: ProductCategory.coffee,
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: const ['all'],
        pricing: const ProductPricing(hotPrice: 100),
      );

      final missingRecipeRes = productsProvider.calculateSellableServings(
        product: prod,
        inventoryItems: const [
          InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Beans',
            category: 'Ingredient',
            availableQuantity: 1000,
            unit: 'g',
            minStock: 10,
            branchId: 'br_sc',
          ),
        ],
      );
      expect(missingRecipeRes.isOutOfStock, isTrue);
      expect(missingRecipeRes.servings, 0);

      // Web-Admin style recipe ID matching (rec_<normalized_name>)
      productsProvider.setRecipesForTesting({
        'rec_mystery_drink': const RecipeModel(
          recipeId: 'rec_mystery_drink',
          productId: 'different_id',
          name: 'Mystery Drink',
          ingredients: [
            RecipeIngredientRequirement(
              ingredientId: 'missing_syrup',
              ingredientName: 'Secret Syrup',
              quantity: 20,
              unit: 'ml',
            ),
          ],
        ),
      });

      final missingInvRes = productsProvider.calculateSellableServings(
        product: prod,
        inventoryItems: const [],
      );
      expect(missingInvRes.hasRecipe, isTrue);
      expect(missingInvRes.isOutOfStock, isTrue);
      expect(missingInvRes.servings, 0);
    });

    testWidgets('Multiple cart items sharing beans update ProductCard and cap CartScreen stepper', (tester) async {
      final productsProvider = ProductsProvider();
      final inventoryProvider = InventoryProvider();
      final cartProvider = PosCartProvider();

      final espresso = ProductModel(
        productId: 'prod_espresso',
        name: 'Espresso',
        category: ProductCategory.coffee,
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: const ['all'],
        pricing: const ProductPricing(hotPrice: 80),
        recipeId: 'rec_espresso',
      );
      final americano = ProductModel(
        productId: 'prod_americano',
        name: 'Americano',
        category: ProductCategory.coffee,
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: const ['all'],
        pricing: const ProductPricing(hotPrice: 100),
        recipeId: 'rec_americano',
      );

      productsProvider.setRecipesForTesting({
        'rec_espresso': const RecipeModel(
          recipeId: 'rec_espresso',
          productId: 'prod_espresso',
          name: 'Espresso',
          ingredients: [
            RecipeIngredientRequirement(ingredientId: 'beans', quantity: 18, unit: 'g'),
          ],
        ),
        'rec_americano': const RecipeModel(
          recipeId: 'rec_americano',
          productId: 'prod_americano',
          name: 'Americano',
          ingredients: [
            RecipeIngredientRequirement(ingredientId: 'beans', quantity: 18, unit: 'g'),
          ],
        ),
      });
      productsProvider.setProductsForTesting([espresso, americano]);

      // 36g beans = 2 total shots across both drinks
      inventoryProvider.setItemsForTesting(const [
        InventoryItemModel(
          id: 'br_beans',
          ingredientId: 'beans',
          name: 'Coffee Beans',
          category: 'Ingredient',
          availableQuantity: 36,
          unit: 'g',
          minStock: 10,
          branchId: 'br_sc',
        ),
      ]);

      // Put 1 Espresso and 1 Americano into cart (consuming all 36g beans)
      cartProvider.addToCart(
        product: espresso,
        selectedTemperature: 'Hot',
        unitPrice: 80,
        quantity: 1,
      );
      cartProvider.addToCart(
        product: americano,
        selectedTemperature: 'Hot',
        unitPrice: 100,
        quantity: 1,
      );

      // Verify remaining inventory helper reduces beans to 0
      final remaining = cartProvider.getRemainingInventory(
        inventoryItems: inventoryProvider.items,
        recipes: productsProvider.recipes,
      );
      expect(remaining.single.availableQuantity, 0.0);

      // ProductCard for Americano now reflects OUT OF STOCK once all beans are in cart
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: productsProvider),
            ChangeNotifierProvider.value(value: inventoryProvider),
            ChangeNotifierProvider.value(value: cartProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 220,
                height: 320,
                child: ProductCard(
                  product: americano,
                  onTap: () {},
                  onAdd: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('OUT OF STOCK'), findsOneWidget);

      // CartScreen disables both items' '+' steppers because shared 36g beans are exhausted
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: productsProvider),
            ChangeNotifierProvider.value(value: inventoryProvider),
            ChangeNotifierProvider.value(value: cartProvider),
          ],
          child: const MaterialApp(home: CartScreen()),
        ),
      );

      final plusButtons = tester
          .widgetList<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add_circle_outline),
          )
          .toList();
      expect(plusButtons.length, 2);
      expect(plusButtons.every((b) => b.onPressed == null), isTrue);
    });
  });

  group('Phase 2B Exact Available Servings UI Tests', () {
    testWidgets(
      'ProductCard displays AVAILABLE, LOW STOCK, and OUT OF STOCK exact servings (including missing recipe)',
      (tester) async {
        final productsProvider = ProductsProvider();
        final inventoryProvider = InventoryProvider();
        final cartProvider = PosCartProvider();

        final espresso = ProductModel(
          productId: 'prod_esp_b',
          name: 'Espresso B',
          category: ProductCategory.coffee,
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: const ['all'],
          pricing: const ProductPricing(hotPrice: 80),
          recipeId: 'rec_esp_b',
        );

        final missingRecipeProd = ProductModel(
          productId: 'prod_missing_b',
          name: 'Unconfigured Drink',
          category: ProductCategory.coffee,
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: const ['all'],
          pricing: const ProductPricing(flatPrice: 90),
        );

        productsProvider.setRecipesForTesting({
          'rec_esp_b': const RecipeModel(
            recipeId: 'rec_esp_b',
            productId: 'prod_esp_b',
            name: 'Espresso B',
            ingredients: [
              RecipeIngredientRequirement(
                ingredientId: 'beans',
                quantity: 18,
                unit: 'g',
              ),
            ],
          ),
        });
        productsProvider.setProductsForTesting([espresso, missingRecipeProd]);

        // 180g beans -> 10 servings (AVAILABLE — 10 servings)
        inventoryProvider.setItemsForTesting(const [
          InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Beans',
            category: 'Ingredient',
            availableQuantity: 180,
            unit: 'g',
            minStock: 10,
            branchId: 'br_sc',
          ),
        ]);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: productsProvider),
              ChangeNotifierProvider.value(value: inventoryProvider),
              ChangeNotifierProvider.value(value: cartProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Row(
                  children: [
                    SizedBox(
                      width: 210,
                      height: 300,
                      child: ProductCard(
                        product: espresso,
                        onTap: () {},
                        onAdd: () {},
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      height: 300,
                      child: ProductCard(
                        product: missingRecipeProd,
                        onTap: () {},
                        onAdd: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('AVAILABLE — 10 servings'), findsOneWidget);
        expect(find.text('OUT OF STOCK — 0 servings'), findsOneWidget);

        // Drop inventory to 72g beans -> 4 servings (LOW STOCK — 4 servings)
        inventoryProvider.setItemsForTesting(const [
          InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Beans',
            category: 'Ingredient',
            availableQuantity: 72,
            unit: 'g',
            minStock: 10,
            branchId: 'br_sc',
          ),
        ]);
        await tester.pump();
        expect(find.text('LOW STOCK — 4 servings'), findsOneWidget);

        // Drop inventory to 0g beans -> OUT OF STOCK — 0 servings for both cards
        inventoryProvider.setItemsForTesting(const [
          InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Beans',
            category: 'Ingredient',
            availableQuantity: 0,
            unit: 'g',
            minStock: 10,
            branchId: 'br_sc',
          ),
        ]);
        await tester.pump();
        expect(find.text('OUT OF STOCK — 0 servings'), findsNWidgets(2));
      },
    );

    testWidgets(
      'Hot/Iced variant availability updates live in ProductDetailsDialog',
      (tester) async {
        final productsProvider = ProductsProvider();
        final inventoryProvider = InventoryProvider();
        final cartProvider = PosCartProvider();

        final americano = ProductModel(
          productId: 'prod_am_hot_iced',
          name: 'Americano Variant',
          category: ProductCategory.coffee,
          categoryName: 'Coffee',
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: const ['all'],
          pricing: const ProductPricing(hotPrice: 90, icedPrice: 105),
          recipeId: 'rec_am_hot_iced',
        );

        productsProvider.setRecipesForTesting({
          'rec_am_hot_iced': const RecipeModel(
            recipeId: 'rec_am_hot_iced',
            productId: 'prod_am_hot_iced',
            name: 'Americano Variant',
            ingredients: [
              RecipeIngredientRequirement(
                ingredientId: 'beans',
                quantity: 18,
                unit: 'g',
                temperature: 'both',
              ),
              RecipeIngredientRequirement(
                ingredientId: 'cup_hot',
                quantity: 1,
                unit: 'pcs',
                temperature: 'hot',
                itemType: 'packaging',
              ),
              RecipeIngredientRequirement(
                ingredientId: 'cup_iced',
                quantity: 1,
                unit: 'pcs',
                temperature: 'iced',
                itemType: 'packaging',
              ),
            ],
          ),
        });
        productsProvider.setProductsForTesting([americano]);

        // Enough beans for 20 drinks, 8 Iced cups, 3 Hot cups
        inventoryProvider.setItemsForTesting(const [
          InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Beans',
            category: 'Ingredient',
            availableQuantity: 360,
            unit: 'g',
            minStock: 10,
            branchId: 'br_sc',
          ),
          InventoryItemModel(
            id: 'br_cup_iced',
            ingredientId: 'cup_iced',
            name: 'Iced Cup',
            category: 'Packaging',
            availableQuantity: 8,
            unit: 'pcs',
            minStock: 5,
            branchId: 'br_sc',
          ),
          InventoryItemModel(
            id: 'br_cup_hot',
            ingredientId: 'cup_hot',
            name: 'Hot Cup',
            category: 'Packaging',
            availableQuantity: 3,
            unit: 'pcs',
            minStock: 5,
            branchId: 'br_sc',
          ),
        ]);

        // ProductCard defaults to Iced variant (8 servings)
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: productsProvider),
              ChangeNotifierProvider.value(value: inventoryProvider),
              ChangeNotifierProvider.value(value: cartProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 210,
                  height: 300,
                  child: ProductCard(
                    product: americano,
                    onTap: () {},
                    onAdd: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('AVAILABLE — 8 servings'), findsOneWidget);

        // Open ProductDetailsDialog -> defaults to Iced (8 servings)
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: productsProvider),
              ChangeNotifierProvider.value(value: inventoryProvider),
              ChangeNotifierProvider.value(value: cartProvider),
            ],
            child: MaterialApp(
              home: Scaffold(body: ProductDetailsDialog(product: americano)),
            ),
          ),
        );
        expect(find.text('AVAILABLE — 8 servings'), findsOneWidget);

        // Switch to Hot -> shows Hot variant exact stock (LOW STOCK — 3 servings)
        await tester.tap(find.text('Hot (₱90)'));
        await tester.pump();
        expect(find.text('LOW STOCK — 3 servings'), findsOneWidget);
      },
    );

    testWidgets(
      'CartScreen and ProductCard update remaining available servings live as shared-ingredient cart quantities change',
      (tester) async {
        final productsProvider = ProductsProvider();
        final inventoryProvider = InventoryProvider();
        final cartProvider = PosCartProvider();

        final espresso = ProductModel(
          productId: 'prod_esp_live',
          name: 'Espresso Live',
          category: ProductCategory.coffee,
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: const ['all'],
          pricing: const ProductPricing(hotPrice: 80),
          recipeId: 'rec_esp_live',
        );
        final americano = ProductModel(
          productId: 'prod_am_live',
          name: 'Americano Live',
          category: ProductCategory.coffee,
          description: '',
          imageUrl: '',
          isAvailable: true,
          availableBranches: const ['all'],
          pricing: const ProductPricing(hotPrice: 100),
          recipeId: 'rec_am_live',
        );

        productsProvider.setRecipesForTesting({
          'rec_esp_live': const RecipeModel(
            recipeId: 'rec_esp_live',
            productId: 'prod_esp_live',
            name: 'Espresso Live',
            ingredients: [
              RecipeIngredientRequirement(
                ingredientId: 'beans',
                quantity: 18,
                unit: 'g',
              ),
            ],
          ),
          'rec_am_live': const RecipeModel(
            recipeId: 'rec_am_live',
            productId: 'prod_am_live',
            name: 'Americano Live',
            ingredients: [
              RecipeIngredientRequirement(
                ingredientId: 'beans',
                quantity: 18,
                unit: 'g',
              ),
            ],
          ),
        });
        productsProvider.setProductsForTesting([espresso, americano]);

        // 180g beans -> 10 shared servings total
        inventoryProvider.setItemsForTesting(const [
          InventoryItemModel(
            id: 'br_beans',
            ingredientId: 'beans',
            name: 'Coffee Beans',
            category: 'Ingredient',
            availableQuantity: 180,
            unit: 'g',
            minStock: 10,
            branchId: 'br_sc',
          ),
        ]);

        // Add 2 Espresso + 1 Americano (uses 3 of 10 shared shots -> 7 remaining)
        cartProvider.addToCart(
          product: espresso,
          selectedTemperature: 'Hot',
          unitPrice: 80,
          quantity: 2,
        );
        cartProvider.addToCart(
          product: americano,
          selectedTemperature: 'Hot',
          unitPrice: 100,
          quantity: 1,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: productsProvider),
              ChangeNotifierProvider.value(value: inventoryProvider),
              ChangeNotifierProvider.value(value: cartProvider),
            ],
            child: const MaterialApp(home: CartScreen()),
          ),
        );

        // Both cart items share the remaining 7 shots
        expect(find.text('AVAILABLE — 7 servings'), findsNWidgets(2));

        // Increase Espresso qty twice (+ -> 3, then + -> 4 -> 5 total in cart, 5 remaining)
        await tester.tap(find.byIcon(Icons.add_circle_outline).first);
        await tester.pump();
        expect(find.text('AVAILABLE — 6 servings'), findsNWidgets(2));

        await tester.tap(find.byIcon(Icons.add_circle_outline).first);
        await tester.pump();
        expect(find.text('LOW STOCK — 5 servings'), findsNWidgets(2));

        // Decrease Espresso qty (- -> 3 -> 6 remaining)
        await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
        await tester.pump();
        expect(find.text('AVAILABLE — 6 servings'), findsNWidgets(2));

        // Remove Espresso (qty 3 -> freed back to inventory, leaving 1 Americano -> 9 remaining)
        await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
        await tester.pump();
        expect(find.text('AVAILABLE — 9 servings'), findsOneWidget);
      },
    );
  });
}
