import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_card.dart';
import 'package:coffee_grind_ph/features/pos/widgets/product_details_dialog.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';

void main() {
  group('ProductCard & ProductDetailsDialog Image Rendering Tests', () {
    final sampleCoffeeWithImage = ProductModel(
      productId: 'prod_1',
      name: 'Spanish Caramel Latte',
      category: ProductCategory.coffee,
      categoryName: 'Coffee',
      description: 'Sweet creamy espresso drink',
      imageUrl: 'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=500',
      isActive: true,
      availableBranches: ['all'],
      pricing: const ProductPricing(hotPrice: 80, icedPrice: 95),
    );

    final sampleCoffeeNoImage = ProductModel(
      productId: 'prod_2',
      name: 'Mocha',
      category: ProductCategory.coffee,
      categoryName: 'Coffee',
      description: 'Rich chocolate and espresso',
      imageUrl: '',
      isActive: true,
      availableBranches: ['all'],
      pricing: const ProductPricing(hotPrice: 70, icedPrice: 85),
    );

    testWidgets('ProductCard displays category icon fallback when imageUrl is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250,
              child: ProductCard(
                product: sampleCoffeeNoImage,
                onTap: () {},
                onAdd: () {},
              ),
            ),
          ),
        ),
      );

      // Verify coffee icon is present
      expect(find.byIcon(Icons.coffee_rounded), findsOneWidget);
      expect(find.text('Mocha'), findsOneWidget);
      expect(find.text('₱70 / ₱85'), findsOneWidget);
    });

    testWidgets('ProductCard builds without throwing when imageUrl is present', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250,
              child: ProductCard(
                product: sampleCoffeeWithImage,
                onTap: () {},
                onAdd: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Spanish Caramel Latte'), findsOneWidget);
      expect(find.text('₱80 / ₱95'), findsOneWidget);
    });

    testWidgets('ProductDetailsDialog renders properly for products with and without images', (WidgetTester tester) async {
      final cartProvider = PosCartProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cartProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ProductDetailsDialog(product: sampleCoffeeNoImage),
            ),
          ),
        ),
      );

      expect(find.text('Mocha'), findsOneWidget);
      expect(find.byIcon(Icons.coffee_rounded), findsOneWidget);
    });
  });
}

