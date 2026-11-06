import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_details_dialog.dart';

void main() {
  group('ProductDetailsDialog Size Selection Removal & Pricing Tests', () {
    late PosCartProvider cartProvider;

    setUp(() {
      cartProvider = PosCartProvider();
    });

    final singlePriceProduct = ProductModel(
      productId: 'prod_choco_lava',
      name: 'Choco Lava',
      category: ProductCategory.nonCoffee,
      categoryName: 'Non Coffee',
      description: 'Rich decadent chocolate drink',
      imageUrl: '',
      isActive: true,
      availableBranches: ['all'],
      pricing: const ProductPricing(
        flatPrice: 105.0,
        sizePrices: {'small': 105.0, 'medium': 105.0, 'large': 105.0},
      ),
    );

    final hotIcedCoffeeProduct = ProductModel(
      productId: 'prod_americano',
      name: 'Americano',
      category: ProductCategory.coffee,
      categoryName: 'Coffee',
      description: 'Espresso with water',
      imageUrl: '',
      isActive: true,
      availableBranches: ['all'],
      pricing: const ProductPricing(
        flatPrice: 70.0,
        hotPrice: 70.0,
        icedPrice: 75.0,
        sizePrices: {'small': 70.0, 'medium': 70.0, 'large': 70.0},
      ),
    );

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

    testWidgets('Dialog DOES NOT display Small, Medium, or Large size chips', (WidgetTester tester) async {
      await tester.pumpWidget(createDialogApp(singlePriceProduct));

      // Verify no size chips appear anywhere in the dialog
      expect(find.text('Size'), findsNothing);
      expect(find.text('Small'), findsNothing);
      expect(find.text('Medium'), findsNothing);
      expect(find.text('Large'), findsNothing);
    });

    testWidgets('Single-price product displays base price and adds to cart without requiring size selection', (WidgetTester tester) async {
      await tester.pumpWidget(createDialogApp(singlePriceProduct));

      // Verify product name and single price
      expect(find.text('Choco Lava'), findsOneWidget);
      expect(find.text('₱105'), findsWidgets);

      // Verify no temperature chips for single-price product
      expect(find.text('Temperature'), findsNothing);

      // Tap 'Add to Cart'
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      // Verify added to cart with exact base price ₱105 and no selected size
      expect(cartProvider.items.length, 1);
      final item = cartProvider.items.first;
      expect(item.product.name, 'Choco Lava');
      expect(item.unitPrice, 105.0);
      expect(item.selectedSize, isNull);
      expect(item.selectedTemperature, isNull);
      expect(cartProvider.totalAmount, 105.0);
    });

    testWidgets('Hot/Iced beverage displays temperature options, defaults to Iced, and adds with correct price', (WidgetTester tester) async {
      await tester.pumpWidget(createDialogApp(hotIcedCoffeeProduct));

      // Verify temperature controls exist
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Hot (₱70)'), findsOneWidget);
      expect(find.text('Iced (₱75)'), findsOneWidget);

      // Verify no size controls exist
      expect(find.text('Size'), findsNothing);
      expect(find.text('Small'), findsNothing);
      expect(find.text('Medium'), findsNothing);
      expect(find.text('Large'), findsNothing);

      // Default is Iced (₱75)
      expect(find.text('₱75'), findsWidgets);

      // Tap 'Add to Cart' with Iced
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      expect(cartProvider.items.length, 1);
      final icedItem = cartProvider.items.first;
      expect(icedItem.product.name, 'Americano');
      expect(icedItem.unitPrice, 75.0);
      expect(icedItem.selectedTemperature, 'Iced');
      expect(icedItem.selectedSize, isNull);
      expect(icedItem.variantLabel, 'Iced');
      expect(cartProvider.totalAmount, 75.0);
    });

    testWidgets('Switching temperature to Hot updates unit price and adds Hot variant', (WidgetTester tester) async {
      await tester.pumpWidget(createDialogApp(hotIcedCoffeeProduct));

      // Tap 'Hot (₱70)'
      await tester.tap(find.text('Hot (₱70)'));
      await tester.pumpAndSettle();

      // Total price should reflect ₱70
      expect(find.text('₱70'), findsWidgets);

      // Tap 'Add to Cart'
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      expect(cartProvider.items.length, 1);
      final hotItem = cartProvider.items.first;
      expect(hotItem.unitPrice, 70.0);
      expect(hotItem.selectedTemperature, 'Hot');
      expect(hotItem.selectedSize, isNull);
      expect(hotItem.variantLabel, 'Hot');
      expect(cartProvider.totalAmount, 70.0);
    });

    testWidgets('Quantity increments correctly and multiplies total amount', (WidgetTester tester) async {
      await tester.pumpWidget(createDialogApp(singlePriceProduct));

      // Tap '+' to increment quantity to 3
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('₱315'), findsOneWidget); // 105 * 3 = 315

      // Add to cart
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      expect(cartProvider.items.length, 1);
      expect(cartProvider.items.first.quantity, 3);
      expect(cartProvider.totalAmount, 315.0);
    });
  });
}

