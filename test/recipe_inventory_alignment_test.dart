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

      // Verify no misleading estimated stock count is displayed
      expect(find.textContaining('left'), findsNothing);
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

        // Verify no misleading estimated count is displayed
        expect(find.textContaining('left'), findsNothing);
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

      // Verify no misleading 'in stock' count is displayed, but Available chip is shown
      expect(find.textContaining('in stock'), findsNothing);
      expect(find.text('Available'), findsOneWidget);
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
}
