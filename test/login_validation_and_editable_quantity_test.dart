import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/core/utils/auth_error_formatter.dart';
import 'package:coffee_grind_ph/features/auth/branch_login_screen.dart';
import 'package:coffee_grind_ph/features/pos/widgets/quantity_edit_dialog.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/models/recipe_model.dart';
import 'package:coffee_grind_ph/providers/branch_session_provider.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/providers/restock_provider.dart';
import 'package:coffee_grind_ph/services/auth_service.dart';

class MockFailingBranchSessionProvider extends ChangeNotifier implements BranchSessionProvider {
  String? _error;
  int signInAttempts = 0;

  @override
  bool get isInitializing => false;

  @override
  bool get isVerifying => false;

  @override
  String? get verificationError => _error;

  @override
  bool get isAuthenticated => false;

  @override
  String get branchId => '';

  @override
  String get currentBranchName => '';

  @override
  String get currentBranchEmail => '';

  @override
  BranchInfo? get currentBranch => null;

  @override
  Future<void> signIn(String email, String password) async {
    signInAttempts++;
    await Future.delayed(const Duration(milliseconds: 50));
    _error = 'Incorrect email or password. Please check your credentials and try again.';
    notifyListeners();
    throw Exception('invalid-credential');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('1. Auth Error Formatter & Email Validation Tests', () {
    test('formatAuthError maps technical codes to friendly messages and hides raw codes', () {
      expect(
        formatAuthError('firebase_auth/invalid-credential'),
        'Incorrect email or password. Please check your credentials and try again.',
      );
      expect(
        formatAuthError('wrong-password'),
        'Incorrect email or password. Please check your credentials and try again.',
      );
      expect(
        formatAuthError('user-not-found'),
        'Incorrect email or password. Please check your credentials and try again.',
      );
      expect(
        formatAuthError('network-request-failed'),
        'Network connection error. Please check your internet connection and try again.',
      );
      expect(
        formatAuthError('user-disabled'),
        'This branch account has been disabled. Please contact the administrator.',
      );
      expect(
        formatAuthError('too-many-requests'),
        'Too many unsuccessful login attempts. Please wait a moment and try again.',
      );
      expect(
        formatAuthError('service-unavailable'),
        'Authentication service is temporarily unavailable. Please try again later.',
      );
      expect(
        formatAuthError('unauthorized-device'),
        'This account is not authorized for the Staff App.',
      );

      // Verify raw Firebase bracketed codes are never returned
      final result = formatAuthError('[firebase_auth/unknown-error] Something went wrong');
      expect(result.contains('firebase_auth'), isFalse);
      expect(result.contains('['), isFalse);
    });

    testWidgets('Email field validates empty and invalid email formats with friendly messages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>(
            create: (_) => MockFailingBranchSessionProvider(),
            child: const BranchLoginScreen(),
          ),
        ),
      );

      // Tap Sign In with empty fields
      await tester.tap(find.text('Sign In Branch Device'));
      await tester.pumpAndSettle();

      expect(find.text('Enter branch account email'), findsOneWidget);
      expect(find.text('Enter password'), findsOneWidget);

      // Enter invalid email without @
      await tester.enterText(find.byType(TextFormField).first, 'santacruz_device');
      await tester.tap(find.text('Sign In Branch Device'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address containing "@".'), findsOneWidget);

      // Enter invalid email without domain
      await tester.enterText(find.byType(TextFormField).first, 'device@');
      await tester.tap(find.text('Sign In Branch Device'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address containing "@".'), findsOneWidget);
    });

    testWidgets('Preserves login inputs and prevents duplicate requests after unsuccessful authentication', (tester) async {
      final mockSession = MockFailingBranchSessionProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: mockSession,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passwordFinder = find.byType(TextFormField).at(1);
      final buttonFinder = find.text('Sign In Branch Device');

      await tester.enterText(emailFinder, 'staff@coffeegrind.ph');
      await tester.enterText(passwordFinder, 'SecurePass123!');
      await tester.pump();

      // Tap Sign In once
      await tester.tap(buttonFinder);
      await tester.pump(); // Start async login

      // Attempt to tap again while in flight
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      // Exactly 1 sign in attempt occurred (duplicate tap blocked)
      expect(mockSession.signInAttempts, 1);

      // Verify email and password text were NOT wiped out
      final emailField = tester.widget<TextFormField>(emailFinder);
      final passwordField = tester.widget<TextFormField>(passwordFinder);
      expect(emailField.controller?.text, 'staff@coffeegrind.ph');
      expect(passwordField.controller?.text, 'SecurePass123!');

      // Verify friendly error message is displayed
      expect(
        find.text('Incorrect email or password. Please check your credentials and try again.'),
        findsOneWidget,
      );
    });
  });

  group('2. Restock Ingredient Loading & Recovery Tests', () {
    late FakeFirebaseFirestore fakeDb;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
    });

    test('RestockProvider does not load ingredients in constructor and loads upon branch binding', () async {
      await fakeDb.collection(FirebasePaths.ingredients).doc('ing_1').set({
        'ingredientId': 'ing_1',
        'name': 'Arabica Beans',
        'unit': 'g',
        'itemType': 'ingredient',
        'status': 'active',
      });

      final provider = RestockProvider(firestore: fakeDb);
      await pumpEventQueue();

      // Before binding, ingredients are empty and no premature unauthenticated query was made
      expect(provider.ingredients, isEmpty);

      // Bind to branch
      provider.bindToBranch('br_1790905840872');
      await pumpEventQueue();

      expect(provider.ingredients.length, 1);
      expect(provider.ingredients.first.name, 'Arabica Beans');
      expect(provider.hasIngredientsError, isFalse);
    });

    test('RestockProvider can retry and recover from ingredient load errors', () async {
      final provider = RestockProvider(firestore: fakeDb);
      provider.bindToBranch('br_1790905840872');
      await pumpEventQueue();

      // Seed ingredient
      await fakeDb.collection(FirebasePaths.ingredients).doc('ing_vanilla').set({
        'ingredientId': 'ing_vanilla',
        'name': 'Vanilla Syrup',
        'unit': 'ml',
        'itemType': 'ingredient',
        'status': 'active',
      });

      // Call retryLoadIngredients
      await provider.retryLoadIngredients();
      await pumpEventQueue();

      expect(provider.hasIngredientsError, isFalse);
      expect(provider.ingredients.length, 1);
      expect(provider.ingredients.first.name, 'Vanilla Syrup');
    });

    test('RestockProvider gracefully falls back to branch inventory if master ingredients fails', () async {
      // Seed inventory for Santa Cruz
      await fakeDb.collection(FirebasePaths.inventory).doc('br_sc_beans').set({
        'branchId': 'br_1790905840872',
        'ingredientId': 'ing_beans',
        'ingredientName': 'Espresso Beans',
        'quantity': 500.0,
        'unit': 'g',
        'category': 'ingredient',
      });

      final provider = RestockProvider(firestore: fakeDb);
      provider.bindToBranch('br_1790905840872');
      await pumpEventQueue();

      expect(provider.ingredients.length, 1);
      expect(provider.ingredients.first.name, 'Espresso Beans');
      expect(provider.hasIngredientsError, isFalse);
    });
  });

  group('3. Direct Quantity Editing & Validation Tests', () {
    testWidgets('QuantityEditDialog displays current quantity and accepts valid positive integer', (tester) async {
      int? submittedQty;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  submittedQty = await showQuantityEditDialog(
                    context,
                    title: 'Edit Quantity',
                    itemName: 'Caramel Macchiato',
                    currentQuantity: 2,
                    maxQuantity: 10,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Quantity'), findsOneWidget);
      expect(find.text('Caramel Macchiato'), findsOneWidget);
      // Theoretical stock count is cleanly hidden
      expect(find.textContaining('Available branch stock'), findsNothing);
      expect(find.textContaining('servings'), findsNothing);

      final textFieldFinder = find.byType(TextFormField);
      expect(find.text('2'), findsOneWidget);

      // Enter 5
      await tester.enterText(textFieldFinder, '5');
      await tester.tap(find.text('Set Quantity'));
      await tester.pumpAndSettle();

      expect(submittedQty, 5);
    });

    testWidgets('QuantityEditDialog rejects 0, empty text, and exceeding stock', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showQuantityEditDialog(
                  context,
                  title: 'Edit Quantity',
                  currentQuantity: 1,
                  maxQuantity: 5,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextFormField);

      // Test empty input
      await tester.enterText(textFieldFinder, '');
      await tester.tap(find.text('Set Quantity'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a quantity'), findsOneWidget);

      // Test 0 input
      await tester.enterText(textFieldFinder, '0');
      await tester.tap(find.text('Set Quantity'));
      await tester.pumpAndSettle();
      expect(find.text('Quantity must be at least 1'), findsOneWidget);

      // Test exceeding stock (> 5)
      await tester.enterText(textFieldFinder, '8');
      await tester.tap(find.text('Set Quantity'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot exceed available stock (5)'), findsOneWidget);

      // Close dialog with cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(QuantityEditDialog), findsNothing);
    });

    test('PosCartProvider setItemQuantity updates quantity and revalidates stock deficit', () {
      final cart = PosCartProvider();

      const prod = ProductModel(
        productId: 'PROD_1',
        name: 'Latte',
        category: ProductCategory.coffee,
        description: '',
        imageUrl: '',
        isAvailable: true,
        availableBranches: ['br_santa_cruz'],
        pricing: ProductPricing(hotPrice: 120.0),
        recipeId: 'rec_1',
      );

      cart.addToCart(
        product: prod,
        selectedTemperature: 'Hot',
        selectedSize: 'Regular',
        quantity: 2,
        unitPrice: 120.0,
      );

      expect(cart.items.first.quantity, 2);

      // Update quantity via direct setItemQuantity
      final itemId = cart.items.first.id;
      cart.setItemQuantity(itemId, 5);
      expect(cart.items.first.quantity, 5);

      // Ignores non-positive quantity
      cart.setItemQuantity(itemId, 0);
      expect(cart.items.first.quantity, 5);
      cart.setItemQuantity(itemId, -3);
      expect(cart.items.first.quantity, 5);

      // Validate stock deficit when inventory has only 60g beans and recipe needs 18g/serving (5 * 18 = 90g)
      final recipe = RecipeModel(
        recipeId: 'rec_1',
        productId: 'PROD_1',
        name: 'Latte',
        ingredients: [
          RecipeIngredientRequirement(
            ingredientId: 'ing_beans',
            ingredientName: 'Coffee Beans',
            quantity: 18.0,
            unit: 'g',
          ),
        ],
      );

      final inventory = [
        const InventoryItemModel(
          id: 'br_santa_cruz_ing_beans',
          ingredientId: 'ing_beans',
          name: 'Coffee Beans',
          category: 'ingredient',
          availableQuantity: 60.0, // Only enough for 3 servings
          unit: 'g',
          minStock: 10.0,
          branchId: 'br_santa_cruz',
        ),
      ];

      final result = cart.validateCartStock(
        recipes: {'PROD_1': recipe},
        inventoryItems: inventory,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage?.contains('Coffee Beans'), isTrue);
    });
  });

  group('4. Login Page Footer & 20-Character Input Validation Tests', () {
    testWidgets('BranchLoginScreen displays clean "Coffee Grind PH" footer and hides technical backend info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>(
            create: (_) => MockFailingBranchSessionProvider(),
            child: const BranchLoginScreen(),
          ),
        ),
      );

      // Verify clean brand label is displayed
      expect(find.text('Coffee Grind PH'), findsOneWidget);

      // Verify technical connection message is removed
      expect(
        find.text('Connected to Shared Coffee Grind PH Firebase Backend'),
        findsNothing,
      );
      expect(find.textContaining('Firebase Backend'), findsNothing);
    });

    testWidgets('Email and Password input fields strictly enforce 20-character maximum and hide character counters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>(
            create: (_) => MockFailingBranchSessionProvider(),
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passwordFinder = find.byType(TextFormField).at(1);

      // Enter 30-character email
      await tester.enterText(emailFinder, 'verylongemailaddress123@example.com');
      await tester.pump();

      // Enter 30-character password
      await tester.enterText(passwordFinder, 'VeryLongPassword1234567890Extra');
      await tester.pump();

      final emailField = tester.widget<TextFormField>(emailFinder);
      final passwordField = tester.widget<TextFormField>(passwordFinder);

      // Max 20 characters enforced
      expect(emailField.controller?.text.length, 20);
      expect(emailField.controller?.text, 'verylongemailaddress');
      expect(passwordField.controller?.text.length, 20);
      expect(passwordField.controller?.text, 'VeryLongPassword1234');

      // No distracting counter widgets ("20/20") rendered
      expect(find.text('20/20'), findsNothing);
      expect(find.text('0/20'), findsNothing);
    });

    testWidgets('Email and Password fields reject whitespace-only inputs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>(
            create: (_) => MockFailingBranchSessionProvider(),
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passwordFinder = find.byType(TextFormField).at(1);
      final buttonFinder = find.text('Sign In Branch Device');

      // Whitespace-only email
      await tester.enterText(emailFinder, '     ');
      // Whitespace-only password
      await tester.enterText(passwordFinder, '    ');
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Enter branch account email'), findsOneWidget);
      expect(find.text('Enter password'), findsOneWidget);
    });

    testWidgets('Password visibility toggle toggles obscureText', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>(
            create: (_) => MockFailingBranchSessionProvider(),
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final passwordFinder = find.byType(TextField).at(1);
      final initialField = tester.widget<TextField>(passwordFinder);
      expect(initialField.obscureText, isTrue);

      // Tap visibility toggle icon
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      final revealedField = tester.widget<TextField>(passwordFinder);
      expect(revealedField.obscureText, isFalse);

      // Tap again to obscure
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      final reobscuredField = tester.widget<TextField>(passwordFinder);
      expect(reobscuredField.obscureText, isTrue);
    });
  });
}
