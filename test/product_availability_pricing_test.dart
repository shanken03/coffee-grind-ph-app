import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_card.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_details_dialog.dart';

void main() {
  group('Product Availability Parsing & Fallbacks', () {
    test('Defaults to available (true) when availability fields are missing', () {
      final doc = {
        'name': 'Classic Brew',
        'price': 80,
      };
      final product = ProductModel.fromMap('p1', doc);
      expect(product.isAvailable, isTrue);
      expect(product.isActive, isTrue);
    });

    test('Parses isAvailable boolean', () {
      final doc1 = {'name': 'Item', 'isAvailable': true};
      final doc2 = {'name': 'Item', 'isAvailable': false};
      expect(ProductModel.fromMap('p1', doc1).isAvailable, isTrue);
      expect(ProductModel.fromMap('p2', doc2).isAvailable, isFalse);
    });

    test('Parses available boolean', () {
      final doc1 = {'name': 'Item', 'available': true};
      final doc2 = {'name': 'Item', 'available': false};
      expect(ProductModel.fromMap('p1', doc1).isAvailable, isTrue);
      expect(ProductModel.fromMap('p2', doc2).isAvailable, isFalse);
    });

    test('Parses active / isActive boolean', () {
      final doc1 = {'name': 'Item', 'active': true};
      final doc2 = {'name': 'Item', 'active': false};
      final doc3 = {'name': 'Item', 'isActive': false};
      expect(ProductModel.fromMap('p1', doc1).isAvailable, isTrue);
      expect(ProductModel.fromMap('p2', doc2).isAvailable, isFalse);
      expect(ProductModel.fromMap('p3', doc3).isAvailable, isFalse);
    });

    test('Parses status string values', () {
      expect(ProductModel.fromMap('p1', {'status': 'active'}).isAvailable, isTrue);
      expect(ProductModel.fromMap('p2', {'status': 'unavailable'}).isAvailable, isFalse);
      expect(ProductModel.fromMap('p3', {'status': 'inactive'}).isAvailable, isFalse);
      expect(ProductModel.fromMap('p4', {'status': 'disabled'}).isAvailable, isFalse);
      expect(ProductModel.fromMap('p5', {'status': 'archived'}).isAvailable, isFalse);
      expect(ProductModel.fromMap('p6', {'status': 'out_of_stock'}).isAvailable, isFalse);
      expect(ProductModel.fromMap('p7', {'status': 'in_stock'}).isAvailable, isTrue);
      expect(ProductModel.fromMap('p8', {'status': 'published'}).isAvailable, isTrue);
    });
  });

  group('Category-Based Pricing & Temperature Options', () {
    test('Coffee supports temperature options ONLY when both hotPrice and icedPrice are > 0', () {
      final coffeeDual = ProductModel(
        productId: 'c1',
        name: 'Caramel Macchiato',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(hotPrice: 85, icedPrice: 95),
      );
      expect(coffeeDual.supportsTemperatureOptions, isTrue);

      final coffeeHotOnly = ProductModel(
        productId: 'c2',
        name: 'Espresso',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(hotPrice: 60),
      );
      expect(coffeeHotOnly.supportsTemperatureOptions, isFalse);
      expect(coffeeHotOnly.pricing.regularPrice, 60.0);
    });

    test('Non-Coffee supports temperature options only if explicit hot and iced prices exist', () {
      final nonCoffeeSingle = ProductModel(
        productId: 'nc1',
        name: 'Matcha Latte',
        category: ProductCategory.nonCoffee,
        categoryName: 'Non Coffee',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 110),
      );
      expect(nonCoffeeSingle.supportsTemperatureOptions, isFalse);
      expect(nonCoffeeSingle.pricing.regularPrice, 110.0);

      final nonCoffeeDual = ProductModel(
        productId: 'nc2',
        name: 'Chocolate',
        category: ProductCategory.nonCoffee,
        categoryName: 'Non Coffee',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(hotPrice: 90, icedPrice: 100),
      );
      expect(nonCoffeeDual.supportsTemperatureOptions, isTrue);
    });

    test('Frappe, Refreshers, Foods, and Sweets NEVER support temperature options', () {
      final frappe = ProductModel(
        productId: 'f1',
        name: 'Java Chip Frappe',
        category: ProductCategory.frappe,
        categoryName: 'Frappe',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 130, hotPrice: 130, icedPrice: 130),
      );
      expect(frappe.supportsTemperatureOptions, isFalse);
      expect(frappe.pricing.regularPrice, 130.0);

      final refresher = ProductModel(
        productId: 'r1',
        name: 'Strawberry Lemonade',
        category: ProductCategory.refreshers,
        categoryName: 'Refreshers',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 95),
      );
      expect(refresher.supportsTemperatureOptions, isFalse);

      final food = ProductModel(
        productId: 'fd1',
        name: 'French Fries',
        category: ProductCategory.foods,
        categoryName: 'Foods',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 85),
      );
      expect(food.supportsTemperatureOptions, isFalse);

      final sweet = ProductModel(
        productId: 'sw1',
        name: 'Chocolate Muffin',
        category: ProductCategory.sweets,
        categoryName: 'Sweets',
        description: '',
        imageUrl: '',
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 75),
      );
      expect(sweet.supportsTemperatureOptions, isFalse);
    });

    test('ProductPricing.fromFirestore parses various price field names and types', () {
      final doc1 = {'price': 120};
      expect(ProductPricing.fromFirestore(doc1).regularPrice, 120.0);

      final doc2 = {'regularPrice': 115.5};
      expect(ProductPricing.fromFirestore(doc2).regularPrice, 115.5);

      final doc3 = {'flatPrice': '100'};
      expect(ProductPricing.fromFirestore(doc3).regularPrice, 100.0);

      final doc4 = {'pricing': {'price': 90}};
      expect(ProductPricing.fromFirestore(doc4).regularPrice, 90.0);
    });
  });

  group('Cart Availability Guard', () {
    test('PosCartProvider prevents adding unavailable product to cart', () {
      final cart = PosCartProvider();
      final unavailableProduct = ProductModel(
        productId: 'p_unavail',
        name: 'Unavailable Coffee',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        isAvailable: false,
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 100),
      );

      cart.addToCart(
        product: unavailableProduct,
        unitPrice: 100,
        quantity: 1,
      );

      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
    });

    test('PosCartProvider allows adding available product to cart', () {
      final cart = PosCartProvider();
      final availableProduct = ProductModel(
        productId: 'p_avail',
        name: 'Available Coffee',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 100),
      );

      cart.addToCart(
        product: availableProduct,
        unitPrice: 100,
        quantity: 2,
      );

      expect(cart.isEmpty, isFalse);
      expect(cart.itemCount, 2);
    });
  });

  group('ProductCard Availability UI Tests', () {
    testWidgets('Displays NOT AVAILABLE overlay and disabled Add button when product is unavailable',
        (WidgetTester tester) async {
      bool addTapped = false;
      final unavailableProduct = ProductModel(
        productId: 'p_unavail',
        name: 'Sold Out Pastry',
        category: ProductCategory.sweets,
        categoryName: 'Sweets',
        description: '',
        imageUrl: '',
        isAvailable: false,
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 85),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 280,
              child: ProductCard(
                product: unavailableProduct,
                onTap: () {},
                onAdd: () {
                  addTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify NOT AVAILABLE overlay
      expect(find.text('NOT AVAILABLE'), findsOneWidget);
      expect(find.text('Unavailable'), findsWidgets);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);

      // Tap on Add button (which is disabled)
      await tester.tap(find.byIcon(Icons.block_rounded));
      await tester.pump();

      expect(addTapped, isFalse);
    });

    testWidgets('Displays active Add button and price when product is available', (WidgetTester tester) async {
      bool addTapped = false;
      final availableProduct = ProductModel(
        productId: 'p_avail',
        name: 'Strawberry Frappe',
        category: ProductCategory.frappe,
        categoryName: 'Frappe',
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 140),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 280,
              child: ProductCard(
                product: availableProduct,
                onTap: () {},
                onAdd: () {
                  addTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('NOT AVAILABLE'), findsNothing);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('₱140'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(addTapped, isTrue);
    });
  });

  group('ProductDetailsDialog Availability UI Tests', () {
    testWidgets('Displays NOT AVAILABLE overlay and disabled button when unavailable', (WidgetTester tester) async {
      final cart = PosCartProvider();
      final unavailableProduct = ProductModel(
        productId: 'p_unavail_dialog',
        name: 'Out of Stock Coffee',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: 'Sold out',
        imageUrl: '',
        isAvailable: false,
        availableBranches: ['all'],
        pricing: const ProductPricing(hotPrice: 80, icedPrice: 90),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp(
            home: Scaffold(
              body: ProductDetailsDialog(product: unavailableProduct),
            ),
          ),
        ),
      );

      expect(find.text('NOT AVAILABLE'), findsOneWidget);
      expect(find.text('Unavailable'), findsWidgets);

      // Verify button is disabled
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });
}
