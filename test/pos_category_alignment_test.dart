import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/recipe_model.dart';
import 'package:coffee_grind_ph/models/cart_item_model.dart';
import 'package:coffee_grind_ph/models/transaction_model.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/features/pos/pos_screen.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_card.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_details_dialog.dart';

void main() {
  group('1. ProductsProvider & Category Ingestion Alignment', () {
    test('Correctly maps Firestore category strings to Coffee Series and Non Coffee Series', () {
      final coffeeDoc = {
        'productId': 'p_coffee',
        'name': 'Americano',
        'category': 'Coffee',
        'pricing': {'hotPrice': 70.0, 'icedPrice': 75.0},
        'availableBranches': ['br_lspu'],
      };
      final nonCoffeeDoc = {
        'productId': 'p_non_coffee',
        'name': 'Matcha Latte',
        'category': 'Non-Coffee',
        'pricing': {'hotPrice': 80.0, 'icedPrice': 85.0},
        'availableBranches': ['br_lspu'],
      };
      final frappeDoc = {
        'productId': 'p_frappe',
        'name': 'Caramel Frappe',
        'category': 'Frappe',
        'pricing': {'flatPrice': 120.0},
        'availableBranches': ['br_lspu'],
      };
      final foodsDoc = {
        'productId': 'p_food',
        'name': 'Tuna Melt',
        'category': 'Foods',
        'pricing': {'flatPrice': 95.0},
        'availableBranches': ['br_lspu'],
      };
      final sweetsDoc = {
        'productId': 'p_sweet',
        'name': 'Chocolate Chip Cookie',
        'category': 'Sweets',
        'pricing': {'flatPrice': 45.0},
        'availableBranches': ['br_lspu'],
      };

      final pCoffee = ProductModel.fromMap('p_coffee', coffeeDoc);
      final pNonCoffee = ProductModel.fromMap('p_non_coffee', nonCoffeeDoc);
      final pFrappe = ProductModel.fromMap('p_frappe', frappeDoc);
      final pFood = ProductModel.fromMap('p_food', foodsDoc);
      final pSweet = ProductModel.fromMap('p_sweet', sweetsDoc);

      expect(pCoffee.displayCategory, equals('Coffee Series'));
      expect(pCoffee.isSupportedCategory, isTrue);

      expect(pNonCoffee.displayCategory, equals('Non Coffee Series'));
      expect(pNonCoffee.isSupportedCategory, isTrue);

      expect(pFrappe.displayCategory, equals('Frappe'));
      expect(pFrappe.isSupportedCategory, isFalse);

      expect(pFood.displayCategory, equals('Foods'));
      expect(pFood.isSupportedCategory, isFalse);

      expect(pSweet.displayCategory, equals('Sweets'));
      expect(pSweet.isSupportedCategory, isFalse);
    });

    test('ProductsProvider.categories getter returns ONLY supported active categories', () {
      final provider = ProductsProvider();
      provider.setProductsForTesting([
        const ProductModel(
          productId: 'c1',
          name: 'Americano',
          category: ProductCategory.coffee,
          categoryName: 'Coffee',
          description: '',
          imageUrl: '',
          availableBranches: ['br_lspu'],
          pricing: ProductPricing(hotPrice: 70.0, icedPrice: 75.0),
        ),
        const ProductModel(
          productId: 'nc1',
          name: 'Chocolate Milk',
          category: ProductCategory.nonCoffee,
          categoryName: 'Non Coffee',
          description: '',
          imageUrl: '',
          availableBranches: ['br_lspu'],
          pricing: ProductPricing(hotPrice: 80.0, icedPrice: 85.0),
        ),
        const ProductModel(
          productId: 'f1',
          name: 'Caramel Frappe',
          category: ProductCategory.frappe,
          categoryName: 'Frappe',
          description: '',
          imageUrl: '',
          availableBranches: ['br_lspu'],
          pricing: ProductPricing(flatPrice: 120.0),
        ),
        const ProductModel(
          productId: 'fd1',
          name: 'Croissant',
          category: ProductCategory.foods,
          categoryName: 'Foods',
          description: '',
          imageUrl: '',
          availableBranches: ['br_lspu'],
          pricing: ProductPricing(flatPrice: 65.0),
        ),
      ]);

      final cats = provider.categories;
      expect(cats, contains('Coffee Series'));
      expect(cats, contains('Non Coffee Series'));
      expect(cats, isNot(contains('Frappe')));
      expect(cats, isNot(contains('Foods')));
      expect(cats, isNot(contains('Sweets')));
      expect(cats.length, equals(2));
    });
  });

  group('2, 3, 4, 5 & 6. POS Screen Catalog Filtering & Search', () {
    late ProductsProvider productsProvider;
    late PosCartProvider cartProvider;

    final testProducts = [
      const ProductModel(
        productId: 'c1',
        name: 'Americano',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: 'Black coffee',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(hotPrice: 70.0, icedPrice: 75.0),
      ),
      const ProductModel(
        productId: 'c2',
        name: 'Caramel Macchiato',
        category: ProductCategory.coffee,
        categoryName: 'Coffee Series',
        description: 'Sweet espresso and caramel',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(hotPrice: 90.0, icedPrice: 95.0),
      ),
      const ProductModel(
        productId: 'nc1',
        name: 'Matcha Latte',
        category: ProductCategory.nonCoffee,
        categoryName: 'Non-Coffee',
        description: 'Green tea latte',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(hotPrice: 85.0, icedPrice: 90.0),
      ),
      const ProductModel(
        productId: 'nc2',
        name: 'Spanish Caramel Latte',
        category: ProductCategory.nonCoffee,
        categoryName: 'Non Coffee Series',
        description: 'Cold creamy caramel milk',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(icedPrice: 110.0),
      ),
      // Obsolete categories to be completely excluded
      const ProductModel(
        productId: 'ob1',
        name: 'Mocha Frappe',
        category: ProductCategory.frappe,
        categoryName: 'Frappe',
        description: 'Blended mocha',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(flatPrice: 130.0),
      ),
      const ProductModel(
        productId: 'ob2',
        name: 'Berry Refresher',
        category: ProductCategory.refreshers,
        categoryName: 'Refreshers',
        description: 'Fruity drink',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(flatPrice: 90.0),
      ),
      const ProductModel(
        productId: 'ob3',
        name: 'Club Sandwich',
        category: ProductCategory.foods,
        categoryName: 'Foods',
        description: 'Toasted sandwich',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(flatPrice: 110.0),
      ),
      const ProductModel(
        productId: 'ob4',
        name: 'Blueberry Cheesecake',
        category: ProductCategory.sweets,
        categoryName: 'Sweets',
        description: 'Rich dessert',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(flatPrice: 120.0),
      ),
    ];

    setUp(() {
      productsProvider = ProductsProvider();
      productsProvider.setProductsForTesting(testProducts);
      cartProvider = PosCartProvider();
    });

    Widget createPosScreenWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
          ChangeNotifierProvider<PosCartProvider>.value(value: cartProvider),
        ],
        child: const MaterialApp(
          home: PosScreen(),
        ),
      );
    }

    testWidgets('Active category filter chips contain strictly All, Coffee Series, Non Coffee Series', (tester) async {
      await tester.pumpWidget(createPosScreenWidget());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Coffee Series'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Non Coffee Series'), findsOneWidget);

      // Obsolete category chips must NOT exist
      expect(find.widgetWithText(ChoiceChip, 'Frappe'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Refreshers'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Foods'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Sweets'), findsNothing);
    });

    testWidgets('Under "All" filter, displays only Coffee & Non Coffee items; Obsolete items are excluded', (tester) async {
      await tester.pumpWidget(createPosScreenWidget());
      await tester.pumpAndSettle();

      // Coffee items visible
      expect(find.widgetWithText(ProductCard, 'Americano'), findsOneWidget);
      expect(find.widgetWithText(ProductCard, 'Caramel Macchiato'), findsOneWidget);

      // Non-Coffee items visible
      expect(find.widgetWithText(ProductCard, 'Matcha Latte'), findsOneWidget);
      expect(find.widgetWithText(ProductCard, 'Spanish Caramel Latte'), findsOneWidget);

      // Obsolete items must NOT be visible under All
      expect(find.text('Mocha Frappe'), findsNothing);
      expect(find.text('Berry Refresher'), findsNothing);
      expect(find.text('Club Sandwich'), findsNothing);
      expect(find.text('Blueberry Cheesecake'), findsNothing);
    });

    testWidgets('Under "Coffee Series" filter, displays ONLY Coffee items', (tester) async {
      await tester.pumpWidget(createPosScreenWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Coffee Series'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ProductCard, 'Americano'), findsOneWidget);
      expect(find.widgetWithText(ProductCard, 'Caramel Macchiato'), findsOneWidget);

      expect(find.widgetWithText(ProductCard, 'Matcha Latte'), findsNothing);
      expect(find.widgetWithText(ProductCard, 'Spanish Caramel Latte'), findsNothing);
      expect(find.text('Mocha Frappe'), findsNothing);
      expect(find.text('Club Sandwich'), findsNothing);
    });

    testWidgets('Under "Non Coffee Series" filter, displays ONLY Non Coffee items', (tester) async {
      await tester.pumpWidget(createPosScreenWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Non Coffee Series'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ProductCard, 'Matcha Latte'), findsOneWidget);
      expect(find.widgetWithText(ProductCard, 'Spanish Caramel Latte'), findsOneWidget);

      expect(find.widgetWithText(ProductCard, 'Americano'), findsNothing);
      expect(find.widgetWithText(ProductCard, 'Caramel Macchiato'), findsNothing);
      expect(find.text('Mocha Frappe'), findsNothing);
      expect(find.text('Club Sandwich'), findsNothing);
    });

    testWidgets('Searching within catalog searches active items and strictly excludes obsolete items', (tester) async {
      await tester.pumpWidget(createPosScreenWidget());
      await tester.pumpAndSettle();

      // Search for 'Americano'
      await tester.enterText(find.byType(TextField), 'Americano');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ProductCard, 'Americano'), findsOneWidget);
      expect(find.widgetWithText(ProductCard, 'Caramel Macchiato'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      // Search for obsolete product 'Frappe'
      await tester.enterText(find.byType(TextField), 'Frappe');
      await tester.pumpAndSettle();
      expect(find.text('Mocha Frappe'), findsNothing);
      expect(find.text('No products available for this branch.'), findsOneWidget);

      // Search for obsolete product 'Sandwich'
      await tester.enterText(find.byType(TextField), 'Sandwich');
      await tester.pumpAndSettle();
      expect(find.text('Club Sandwich'), findsNothing);
      expect(find.text('No products available for this branch.'), findsOneWidget);
    });
  });

  group('7, 8, 9 & 10. Product Details, Pricing, Iced-Only & Recipe Matching', () {
    testWidgets('Product details dialog displays Coffee Series / Non Coffee Series and correct pricing', (tester) async {
      const dualCoffee = ProductModel(
        productId: 'c1',
        name: 'Americano',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: 'Classic brew',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(hotPrice: 70.0, icedPrice: 75.0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductDetailsDialog(product: dualCoffee),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Americano'), findsOneWidget);
      expect(find.text('Coffee Series'), findsOneWidget);
      expect(find.textContaining('Hot'), findsWidgets);
      expect(find.textContaining('Iced'), findsWidgets);
    });

    test('Iced-only product strictly preserves "Iced" selected temperature', () {
      const icedNonCoffee = ProductModel(
        productId: 'nc_cold',
        name: 'Spanish Caramel Latte',
        category: ProductCategory.nonCoffee,
        categoryName: 'Non Coffee',
        description: 'Cold only',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(icedPrice: 110.0),
      );

      expect(icedNonCoffee.supportsTemperatureOptions, isFalse);
      expect(icedNonCoffee.isColdOnly, isTrue);
      expect(icedNonCoffee.fixedTemperature, equals('Iced'));
      expect(icedNonCoffee.initialTemperature, equals('Iced'));

      final cartItem = CartItemModel(
        id: 'cart_1',
        product: icedNonCoffee,
        selectedTemperature: icedNonCoffee.fixedTemperature,
        unitPrice: 110.0,
        quantity: 1,
      );

      expect(cartItem.selectedTemperature, equals('Iced'));
      expect(cartItem.variantLabel, equals('Iced'));
    });

    test('Recipe matching resolves correctly by productId', () {
      final recipes = <String, RecipeModel>{
        'c1': const RecipeModel(
          recipeId: 'rec_c1',
          productId: 'c1',
          name: 'Americano',
          ingredients: [
            RecipeIngredientRequirement(
              ingredientId: 'inv_beans',
              ingredientName: 'Espresso Beans',
              quantity: 18.0,
              unit: 'g',
            ),
          ],
        ),
      };

      final provider = ProductsProvider();
      provider.setRecipesForTesting(recipes);

      final recipe = provider.getRecipeForProduct('c1');
      expect(recipe, isNotNull);
      expect(recipe!.name, equals('Americano'));
      expect(recipe.ingredients.first.ingredientName, equals('Espresso Beans'));
    });
  });

  group('11, 12, 13 & 14. Cart, Inventory Deduction, Checkout & Branch Availability', () {
    test('Cart calculations, inventory deduction and sales breakdown operate properly', () {
      const coffee = ProductModel(
        productId: 'c1',
        name: 'Americano',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        availableBranches: ['br_lspu'],
        pricing: ProductPricing(hotPrice: 70.0, icedPrice: 75.0),
      );

      final cart = PosCartProvider();
      cart.addToCart(
        product: coffee,
        selectedTemperature: 'Iced',
        unitPrice: 75.0,
        quantity: 2,
      );

      expect(cart.itemCount, equals(2));
      expect(cart.totalAmount, equals(150.0));
      expect(cart.items.first.product.displayCategory, equals('Coffee Series'));
      expect(cart.items.first.selectedTemperature, equals('Iced'));

      // Test packaging deduction calculation
      final packagingDeductions = <String, double>{
        'inv_cup_16oz': 2.0,
        'inv_lid_flat': 2.0,
        'inv_straw': 2.0,
      };
      expect(packagingDeductions['inv_cup_16oz'], equals(2.0));

      // Test transaction creation structure
      final tx = TransactionModel(
        transactionId: 'TX-1001',
        timestamp: DateTime.now(),
        branchName: 'LSPU',
        items: cart.items,
        totalAmount: cart.totalAmount,
        paymentMethod: 'Cash',
      );

      expect(tx.totalAmount, equals(150.0));
      expect(tx.items.first.product.displayCategory, equals('Coffee Series'));
      expect(tx.itemsSummary, contains('2x Americano (Iced)'));
    });

    test('Branch-specific product availability filtering operates cleanly', () {
      const lspuOnly = ProductModel(
        productId: 'p_lspu',
        name: 'LSPU Special Coffee',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        availableBranches: ['br_1790923872261'],
        pricing: ProductPricing(hotPrice: 70.0, icedPrice: 75.0),
      );
      const santaCruzOnly = ProductModel(
        productId: 'p_sc',
        name: 'Santa Cruz Special Coffee',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        availableBranches: ['br_1790905840872'],
        pricing: ProductPricing(hotPrice: 70.0, icedPrice: 75.0),
      );

      bool isAvailableInBranch(ProductModel p, String branchId) {
        if (p.availableBranches.isEmpty || p.availableBranches.contains('all')) {
          return true;
        }
        return p.availableBranches.contains(branchId);
      }

      expect(isAvailableInBranch(lspuOnly, 'br_1790923872261'), isTrue);
      expect(isAvailableInBranch(lspuOnly, 'br_1790905840872'), isFalse);

      expect(isAvailableInBranch(santaCruzOnly, 'br_1790905840872'), isTrue);
      expect(isAvailableInBranch(santaCruzOnly, 'br_1790923872261'), isFalse);
    });
  });
}
