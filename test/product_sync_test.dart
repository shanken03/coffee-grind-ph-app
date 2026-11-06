import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/cart_item_model.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';

void main() {
  group('ProductModel & ProductPricing Firestore Parsing Tests', () {
    test('Parses real Firestore coffee document with hot/iced prices, sizes map, and image_url', () {
      final firestoreDoc = {
        'productId': 'PROD-0721373',
        'name': 'Americano',
        'category': 'Coffee',
        'description': 'Espresso diluted with hot or cold filtered water for a clean coffee profile.',
        'image_url': 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=500&q=80',
        'imageUrl': 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=500&q=80',
        'active': true,
        'status': 'active',
        'price': 70,
        'hotPrice': 70,
        'icedPrice': 75,
        'prices': {
          'small': 70,
          'medium': 70,
          'large': 70,
        },
        'availableBranches': ['all'],
      };

      final product = ProductModel.fromMap('PROD-0721373', firestoreDoc);

      expect(product.productId, 'PROD-0721373');
      expect(product.name, 'Americano');
      expect(product.category, ProductCategory.coffee);
      expect(product.displayCategory, 'Coffee Series');
      expect(product.imageUrl, 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=500&q=80');
      expect(product.isActive, isTrue);
      expect(product.pricing.hotPrice, 70.0);
      expect(product.pricing.icedPrice, 75.0);
      expect(product.pricing.availableSizes, ['Small', 'Medium', 'Large']);
      expect(product.pricing.sizePrices?['small'], 70.0);
      expect(product.pricing.sizePrices?['medium'], 70.0);
      expect(product.pricing.sizePrices?['large'], 70.0);
    });

    test('Parses Non Coffee product with Cloudinary image and sizes map', () {
      final firestoreDoc = {
        'productId': 'PROD-0754994',
        'name': 'Brewed Latte',
        'category': 'Coffee',
        'description': '',
        'imageUrl': 'https://res.cloudinary.com/q24gti7p/image/upload/v1791866581/coffee-grind-products/prod_PROD-0754994_1791866579988.jpg',
        'image_url': 'https://res.cloudinary.com/q24gti7p/image/upload/v1791866581/coffee-grind-products/prod_PROD-0754994_1791866579988.jpg',
        'active': true,
        'status': 'active',
        'price': 85,
        'hotPrice': 85,
        'icedPrice': 90,
        'prices': {
          'small': 85.0,
          'medium': 85.0,
          'large': 85.0,
        },
        'availableBranches': ['all'],
      };

      final product = ProductModel.fromMap('PROD-0754994', firestoreDoc);

      expect(product.name, 'Brewed Latte');
      expect(product.imageUrl.contains('cloudinary.com'), isTrue);
      expect(product.pricing.hotPrice, 85.0);
      expect(product.pricing.icedPrice, 90.0);
      expect(product.pricing.availableSizes, containsAll(['Small', 'Medium', 'Large']));
    });

    test('Parses Non Coffee category correctly and maps to Non Coffee Series', () {
      final firestoreDoc = {
        'productId': 'prod_choco_lava',
        'name': 'Choco Lava',
        'category': 'Non Coffee',
        'description': 'Rich decadent chocolate drink',
        'image_url': 'https://images.unsplash.com/photo-1542990253-0d0f5be5f0ed?auto=format&fit=crop&w=500&q=80',
        'active': true,
        'status': 'active',
        'price': 105,
        'prices': {
          'small': 105,
          'medium': 105,
          'large': 105,
        },
        'availableBranches': ['all'],
      };

      final product = ProductModel.fromMap('prod_choco_lava', firestoreDoc);

      expect(product.category, ProductCategory.nonCoffee);
      expect(product.displayCategory, 'Non Coffee Series');
      expect(product.pricing.flatPrice, 105.0);
      expect(product.pricing.hotPrice, isNull);
      expect(product.pricing.icedPrice, isNull);
    });

    test('Parses inactive products correctly when active: false', () {
      final firestoreDoc = {
        'productId': 'prod_seasonal',
        'name': 'Seasonal Drink',
        'category': 'Coffee',
        'active': false,
        'status': 'inactive',
      };

      final product = ProductModel.fromMap('prod_seasonal', firestoreDoc);
      expect(product.isActive, isFalse);
    });
  });

  group('CartItemModel & PosCartProvider with Sizes and Temperatures', () {
    test('CartItemModel variantLabel combines size and temperature', () {
      final product = ProductModel(
        productId: 'p1',
        name: 'Latte',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        isActive: true,
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 85.0),
      );

      final itemWithSizeAndTemp = CartItemModel(
        id: 'p1_hot_medium',
        product: product,
        selectedTemperature: 'Hot',
        selectedSize: 'Medium',
        unitPrice: 85.0,
      );
      expect(itemWithSizeAndTemp.variantLabel, 'Medium • Hot');

      final itemWithSizeOnly = CartItemModel(
        id: 'p1_none_large',
        product: product,
        selectedSize: 'Large',
        unitPrice: 105.0,
      );
      expect(itemWithSizeOnly.variantLabel, 'Large');

      final itemWithTempOnly = CartItemModel(
        id: 'p1_iced_none',
        product: product,
        selectedTemperature: 'Iced',
        unitPrice: 90.0,
      );
      expect(itemWithTempOnly.variantLabel, 'Iced');

      final itemRegular = CartItemModel(
        id: 'p1_none_none',
        product: product,
        unitPrice: 85.0,
      );
      expect(itemRegular.variantLabel, 'Regular');
    });

    test('PosCartProvider differentiates items with different sizes or temperatures', () {
      final cart = PosCartProvider();
      final product = ProductModel(
        productId: 'prod_americano',
        name: 'Americano',
        category: ProductCategory.coffee,
        categoryName: 'Coffee',
        description: '',
        imageUrl: '',
        isActive: true,
        availableBranches: ['all'],
        pricing: const ProductPricing(flatPrice: 70.0),
      );

      // Add Small Hot
      cart.addToCart(
        product: product,
        selectedTemperature: 'Hot',
        selectedSize: 'Small',
        unitPrice: 70.0,
        quantity: 1,
      );

      // Add Medium Iced
      cart.addToCart(
        product: product,
        selectedTemperature: 'Iced',
        selectedSize: 'Medium',
        unitPrice: 75.0,
        quantity: 2,
      );

      expect(cart.items.length, 2);
      expect(cart.itemCount, 3);
      expect(cart.totalAmount, 70.0 * 1 + 75.0 * 2);

      // Add another Small Hot (should increment quantity of existing item)
      cart.addToCart(
        product: product,
        selectedTemperature: 'Hot',
        selectedSize: 'Small',
        unitPrice: 70.0,
        quantity: 1,
      );

      expect(cart.items.length, 2);
      expect(cart.itemCount, 4);
    });
  });
}

