import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/models/branch_payment_settings_model.dart';
import 'package:coffee_grind_ph/models/cart_item_model.dart';
import 'package:coffee_grind_ph/models/product_model.dart';
import 'package:coffee_grind_ph/providers/branch_session_provider.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/payment_settings_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/providers/transactions_provider.dart';
import 'package:coffee_grind_ph/features/pos/widgets/checkout_screen.dart';
import 'package:coffee_grind_ph/features/pos/widgets/gcash_payment_dialog.dart';

class MockBranchSessionProvider extends ChangeNotifier implements BranchSessionProvider {
  @override
  final String branchId;

  @override
  final String currentBranchName;

  MockBranchSessionProvider({
    this.branchId = 'br_1790905840872',
    this.currentBranchName = 'Santa Cruz',
  });

  @override
  bool get isAuthenticated => true;

  @override
  bool get isBranchVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const santaCruzBranch = 'br_1790905840872';
  const lspuBranch = 'br_1790923872261';

  group('1. BranchPaymentSettingsModel Contract & Parsing Tests', () {
    test('Parses camelCase fields accurately', () {
      final now = DateTime.now();
      final data = {
        'branchId': santaCruzBranch,
        'branchName': 'Santa Cruz Branch',
        'cashEnabled': true,
        'gcashEnabled': true,
        'gcashQrImageUrl': 'https://res.cloudinary.com/q24gti7p/image/upload/v1/sc_qr.png',
        'gcashQrStoragePath': 'qr_codes/sc_qr.png',
        'accountName': 'Juan Dela Cruz',
        'accountNumber': '09171234567',
        'updatedAt': Timestamp.fromDate(now),
      };

      final model = BranchPaymentSettingsModel.fromFirestore(santaCruzBranch, data);
      expect(model.branchId, santaCruzBranch);
      expect(model.branchName, 'Santa Cruz Branch');
      expect(model.cashEnabled, isTrue);
      expect(model.gcashEnabled, isTrue);
      expect(model.gcashQrImageUrl, 'https://res.cloudinary.com/q24gti7p/image/upload/v1/sc_qr.png');
      expect(model.accountName, 'Juan Dela Cruz');
      expect(model.accountNumber, '09171234567');
      expect(model.hasValidQrUrl, isTrue);
      expect(model.isGcashAvailable, isTrue);
    });

    test('Parses snake_case fields accurately', () {
      final now = DateTime.now();
      final data = {
        'branch_id': lspuBranch,
        'branch_name': 'LSPU Branch',
        'cash_enabled': true,
        'gcash_enabled': true,
        'gcash_qr_image_url': 'https://firebasestorage.googleapis.com/v0/b/app/o/lspu_qr.png',
        'gcash_qr_storage_path': 'qr_codes/lspu_qr.png',
        'account_name': 'Maria Santos',
        'account_number': '09187654321',
        'updated_at': Timestamp.fromDate(now),
      };

      final model = BranchPaymentSettingsModel.fromFirestore(lspuBranch, data);
      expect(model.branchId, lspuBranch);
      expect(model.branchName, 'LSPU Branch');
      expect(model.cashEnabled, isTrue);
      expect(model.gcashEnabled, isTrue);
      expect(model.accountName, 'Maria Santos');
      expect(model.accountNumber, '09187654321');
      expect(model.hasValidQrUrl, isTrue);
      expect(model.isGcashAvailable, isTrue);
    });

    test('Parses legacy GCash account name and number aliases', () {
      final data = {
        'branchId': santaCruzBranch,
        'gcashEnabled': true,
        'gcashQrImageUrl': 'https://res.cloudinary.com/test/qr.png',
        'gcashAccountName': 'Legacy Store Account',
        'gcashAccountNumber': '09199998888',
      };

      final model = BranchPaymentSettingsModel.fromFirestore(santaCruzBranch, data);
      expect(model.accountName, 'Legacy Store Account');
      expect(model.accountNumber, '09199998888');
    });

    test('Missing settings defaults safely to Cash-only', () {
      final model = BranchPaymentSettingsModel.cashOnly(santaCruzBranch);
      expect(model.branchId, santaCruzBranch);
      expect(model.cashEnabled, isTrue);
      expect(model.gcashEnabled, isFalse);
      expect(model.isGcashAvailable, isFalse);
      expect(model.accountName, isEmpty);
      expect(model.accountNumber, isEmpty);
    });

    test('GCash enabled but missing or empty QR URL makes GCash unavailable', () {
      final data = {
        'branchId': santaCruzBranch,
        'gcashEnabled': true,
        'gcashQrImageUrl': '   ',
        'accountName': 'Store Owner',
      };

      final model = BranchPaymentSettingsModel.fromFirestore(santaCruzBranch, data);
      expect(model.gcashEnabled, isTrue);
      expect(model.hasValidQrUrl, isFalse);
      expect(model.isGcashAvailable, isFalse);
    });

    test('Invalid or non-HTTPS QR URL is rejected for safety', () {
      final insecureData = {
        'branchId': santaCruzBranch,
        'gcashEnabled': true,
        'gcashQrImageUrl': 'http://insecure-site.com/qr.png',
      };
      final insecureModel = BranchPaymentSettingsModel.fromFirestore(santaCruzBranch, insecureData);
      expect(insecureModel.hasValidQrUrl, isFalse);
      expect(insecureModel.isGcashAvailable, isFalse);

      final malformedData = {
        'branchId': santaCruzBranch,
        'gcashEnabled': true,
        'gcashQrImageUrl': 'not-a-url',
      };
      final malformedModel = BranchPaymentSettingsModel.fromFirestore(santaCruzBranch, malformedData);
      expect(malformedModel.hasValidQrUrl, isFalse);
      expect(malformedModel.isGcashAvailable, isFalse);
    });
  });

  group('2. PaymentSettingsProvider Branch Isolation & Lifecycle Tests', () {
    late FakeFirebaseFirestore fakeDb;

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();

      // Seed Santa Cruz settings
      await fakeDb.collection(FirebasePaths.branchPaymentSettings).doc(santaCruzBranch).set({
        'branchId': santaCruzBranch,
        'branchName': 'Santa Cruz',
        'cashEnabled': true,
        'gcashEnabled': true,
        'gcashQrImageUrl': 'https://res.cloudinary.com/coffee/sc_qr.png',
        'accountName': 'Santa Cruz Store',
        'accountNumber': '09170000001',
      });

      // Seed LSPU settings
      await fakeDb.collection(FirebasePaths.branchPaymentSettings).doc(lspuBranch).set({
        'branchId': lspuBranch,
        'branchName': 'LSPU Campus',
        'cashEnabled': true,
        'gcashEnabled': false, // GCash disabled for LSPU
        'gcashQrImageUrl': '',
        'accountName': 'LSPU Store',
        'accountNumber': '09170000002',
      });
    });

    test('Santa Cruz loads strictly its own payment settings', () async {
      final provider = PaymentSettingsProvider(firestore: fakeDb);
      provider.bindToBranch(santaCruzBranch);
      await pumpEventQueue();

      expect(provider.currentBranchId, santaCruzBranch);
      expect(provider.settings?.branchId, santaCruzBranch);
      expect(provider.settings?.accountName, 'Santa Cruz Store');
      expect(provider.isCashAvailable, isTrue);
      expect(provider.isGcashAvailable, isTrue);

      provider.dispose();
    });

    test('LSPU loads strictly its own payment settings (GCash disabled)', () async {
      final provider = PaymentSettingsProvider(firestore: fakeDb);
      provider.bindToBranch(lspuBranch);
      await pumpEventQueue();

      expect(provider.currentBranchId, lspuBranch);
      expect(provider.settings?.branchId, lspuBranch);
      expect(provider.settings?.accountName, 'LSPU Store');
      expect(provider.isCashAvailable, isTrue);
      expect(provider.isGcashAvailable, isFalse);

      provider.dispose();
    });

    test('Switching branches cancels previous listener and prevents stale settings display', () async {
      final provider = PaymentSettingsProvider(firestore: fakeDb);

      // Start on Santa Cruz
      provider.bindToBranch(santaCruzBranch);
      await pumpEventQueue();
      expect(provider.settings?.accountName, 'Santa Cruz Store');

      // Switch to LSPU
      provider.bindToBranch(lspuBranch);
      // Immediately after bindToBranch, previous settings are cleared
      expect(provider.currentBranchId, lspuBranch);
      await pumpEventQueue();

      expect(provider.settings?.branchId, lspuBranch);
      expect(provider.settings?.accountName, 'LSPU Store');
      expect(provider.isGcashAvailable, isFalse);

      // Clearing branchId on logout cancels listener and clears settings
      provider.bindToBranch('');
      expect(provider.currentBranchId, isNull);
      expect(provider.settings, isNull);

      provider.dispose();
    });

    test('Missing branch document defaults to Cash-only safely', () async {
      final provider = PaymentSettingsProvider(firestore: fakeDb);
      provider.bindToBranch('br_unconfigured_999');
      await pumpEventQueue();

      expect(provider.settings?.branchId, 'br_unconfigured_999');
      expect(provider.isCashAvailable, isTrue);
      expect(provider.isGcashAvailable, isFalse);

      provider.dispose();
    });

    test('Permission-denied error falls back gracefully to Cash-only without crashing', () {
      final provider = PaymentSettingsProvider(firestore: fakeDb);
      provider.bindToBranch(santaCruzBranch);

      provider.setErrorForTesting(
        '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
        isPermissionDenied: true,
      );

      expect(provider.isPermissionDenied, isTrue);
      expect(provider.isCashAvailable, isTrue);
      expect(provider.isGcashAvailable, isFalse);

      provider.dispose();
    });
  });

  group('3. TransactionsProvider GCash Persistence & Idempotency Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late TransactionsProvider transactionsProvider;

    final latteProduct = ProductModel(
      productId: 'PROD_LATTE',
      name: 'Café Latte',
      category: ProductCategory.coffee,
      description: 'Espresso with steamed milk',
      imageUrl: '',
      isAvailable: true,
      availableBranches: const [santaCruzBranch],
      pricing: const ProductPricing(hotPrice: 120.0),
      recipeId: 'rec_latte',
    );

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      transactionsProvider = TransactionsProvider(firestore: fakeDb);

      // Seed recipe
      await fakeDb.collection(FirebasePaths.recipes).doc('rec_latte').set({
        'recipeId': 'rec_latte',
        'productId': 'PROD_LATTE',
        'name': 'Café Latte',
        'ingredients': [
          {
            'ingredientId': 'ing_beans',
            'ingredientName': 'Espresso Beans',
            'quantity': 18.0,
            'unit': 'g',
            'temperature': 'Hot',
          },
        ],
      });

      // Seed Santa Cruz inventory
      await fakeDb.collection(FirebasePaths.inventory).doc('${santaCruzBranch}_ing_beans').set({
        'branchId': santaCruzBranch,
        'ingredientId': 'ing_beans',
        'ingredientName': 'Espresso Beans',
        'quantity': 500.0,
        'unit': 'g',
      });
    });

    test('Cash transaction does NOT store gcashReference and records Cash paymentMethod', () async {
      final cartItem = CartItemModel(
        id: 'cart_1',
        product: latteProduct,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 1,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz Branch',
        items: [cartItem],
        totalAmount: 120.0,
        paymentMethod: 'Cash',
        clientSaleId: 'SALE_CASH_001',
      );

      expect(tx.paymentMethod, 'Cash');
      expect(tx.gcashReference, isNull);

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_CASH_001').get();
      expect(saleDoc.exists, isTrue);
      final saleData = saleDoc.data()!;
      expect(saleData['paymentMethod'], 'Cash');
      expect(saleData.containsKey('gcashReference'), isFalse);

      // Inventory deducted by 18g: 500 - 18 = 482g
      final invDoc = await fakeDb.collection(FirebasePaths.inventory).doc('${santaCruzBranch}_ing_beans').get();
      expect(invDoc.data()!['quantity'], 482.0);
    });

    test('GCash transaction stores validated gcashReference in Firestore', () async {
      final cartItem = CartItemModel(
        id: 'cart_2',
        product: latteProduct,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 2,
      );

      final tx = await transactionsProvider.addTransaction(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz Branch',
        items: [cartItem],
        totalAmount: 240.0,
        paymentMethod: 'GCash',
        gcashReference: '100293847589',
        clientSaleId: 'SALE_GCASH_001',
      );

      expect(tx.paymentMethod, 'GCash');
      expect(tx.gcashReference, '100293847589');

      final saleDoc = await fakeDb.collection(FirebasePaths.sales).doc('SALE_GCASH_001').get();
      expect(saleDoc.exists, isTrue);
      final saleData = saleDoc.data()!;
      expect(saleData['paymentMethod'], 'GCash');
      expect(saleData['gcashReference'], '100293847589');
      expect(saleData['gcash_reference'], '100293847589');

      // Inventory deducted: 2 * 18 = 36g. 500 - 36 = 464g
      final invDoc = await fakeDb.collection(FirebasePaths.inventory).doc('${santaCruzBranch}_ing_beans').get();
      expect(invDoc.data()!['quantity'], 464.0);
    });

    test('Idempotency prevents duplicate sale creation and double inventory deduction', () async {
      final cartItem = CartItemModel(
        id: 'cart_3',
        product: latteProduct,
        selectedTemperature: 'Hot',
        unitPrice: 120.0,
        quantity: 1,
      );

      // Attempt 1
      final tx1 = await transactionsProvider.addTransaction(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz Branch',
        items: [cartItem],
        totalAmount: 120.0,
        paymentMethod: 'GCash',
        gcashReference: '9988776655',
        clientSaleId: 'SALE_IDEMPOTENT_001',
      );

      // Attempt 2 with exact same clientSaleId
      final tx2 = await transactionsProvider.addTransaction(
        branchId: santaCruzBranch,
        branchName: 'Santa Cruz Branch',
        items: [cartItem],
        totalAmount: 120.0,
        paymentMethod: 'GCash',
        gcashReference: '9988776655',
        clientSaleId: 'SALE_IDEMPOTENT_001',
      );

      expect(tx1.transactionId, tx2.transactionId);

      // Inventory only deducted ONCE (500 - 18 = 482)
      final invDoc = await fakeDb.collection(FirebasePaths.inventory).doc('${santaCruzBranch}_ing_beans').get();
      expect(invDoc.data()!['quantity'], 482.0);
    });
  });

  group('4. Static QR Payment Dialog Widget Tests', () {
    final validSettings = BranchPaymentSettingsModel(
      branchId: santaCruzBranch,
      branchName: 'Santa Cruz Branch',
      cashEnabled: true,
      gcashEnabled: true,
      gcashQrImageUrl: 'https://res.cloudinary.com/coffee/qr.png',
      accountName: 'Juan Dela Cruz',
      accountNumber: '0917-123-4567',
    );

    testWidgets('Displays exact total, account details, and validates required reference number', (tester) async {
      String? submittedRef;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  submittedRef = await showGcashPaymentDialog(
                    ctx,
                    settings: validSettings,
                    totalAmount: 350.0,
                  );
                },
                child: const Text('Open QR Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open QR Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify UI elements
      expect(find.text('GCash QR Payment'), findsOneWidget);
      expect(find.text('Santa Cruz Branch'), findsOneWidget);
      expect(find.text('₱350.00'), findsOneWidget);
      expect(find.text('Account: Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Number: 0917-123-4567'), findsOneWidget);
      expect(find.textContaining('Cashier verification required'), findsOneWidget);

      // Attempt submit with empty reference number
      await tester.tap(find.text('Confirm Payment'));
      await tester.pump();

      expect(find.text('Enter GCash reference number'), findsOneWidget);
      expect(submittedRef, isNull);

      // Enter valid reference number and confirm
      await tester.enterText(find.byType(TextFormField), '100234567890');
      await tester.pump();
      await tester.tap(find.text('Confirm Payment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(submittedRef, '100234567890');
      expect(find.byType(GcashPaymentDialog), findsNothing);
    });

    testWidgets('Tapping Cancel closes dialog and returns null without performing payment', (tester) async {
      String? submittedRef = 'PREVIOUS_VALUE';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  submittedRef = await showGcashPaymentDialog(
                    ctx,
                    settings: validSettings,
                    totalAmount: 200.0,
                  );
                },
                child: const Text('Open QR Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open QR Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(submittedRef, isNull);
      expect(find.byType(GcashPaymentDialog), findsNothing);
    });
  });

  group('5. CheckoutScreen Payment Method & GCash Integration Tests', () {
    testWidgets('CheckoutScreen disables GCash when branch settings have GCash unavailable', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      final mockSession = MockBranchSessionProvider();
      final paymentSettingsProvider = PaymentSettingsProvider(firestore: fakeDb);
      // GCash disabled
      paymentSettingsProvider.setSettingsForTesting(
        BranchPaymentSettingsModel.cashOnly(santaCruzBranch),
      );

      final cartProvider = PosCartProvider();
      final productsProvider = ProductsProvider(firestore: fakeDb);
      final inventoryProvider = InventoryProvider(firestore: fakeDb);
      final transactionsProvider = TransactionsProvider(firestore: fakeDb);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BranchSessionProvider>.value(value: mockSession),
            ChangeNotifierProvider<PaymentSettingsProvider>.value(value: paymentSettingsProvider),
            ChangeNotifierProvider<PosCartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
            ChangeNotifierProvider<InventoryProvider>.value(value: inventoryProvider),
            ChangeNotifierProvider<TransactionsProvider>.value(value: transactionsProvider),
          ],
          child: const MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Cash is active and GCash indicates unavailable
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('GCash (Unavailable)'), findsOneWidget);
      expect(find.textContaining('GCash static QR is not configured'), findsOneWidget);
    });

    testWidgets('CheckoutScreen enables GCash selection when branch settings has valid QR URL', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      final mockSession = MockBranchSessionProvider();
      final paymentSettingsProvider = PaymentSettingsProvider(firestore: fakeDb);
      // GCash enabled with valid Cloudinary HTTPS URL
      paymentSettingsProvider.setSettingsForTesting(
        const BranchPaymentSettingsModel(
          branchId: santaCruzBranch,
          branchName: 'Santa Cruz Branch',
          cashEnabled: true,
          gcashEnabled: true,
          gcashQrImageUrl: 'https://res.cloudinary.com/coffee/sc_qr.png',
          accountName: 'Juan Store',
          accountNumber: '09170001111',
        ),
      );

      final cartProvider = PosCartProvider();
      final productsProvider = ProductsProvider(firestore: fakeDb);
      final inventoryProvider = InventoryProvider(firestore: fakeDb);
      final transactionsProvider = TransactionsProvider(firestore: fakeDb);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BranchSessionProvider>.value(value: mockSession),
            ChangeNotifierProvider<PaymentSettingsProvider>.value(value: paymentSettingsProvider),
            ChangeNotifierProvider<PosCartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
            ChangeNotifierProvider<InventoryProvider>.value(value: inventoryProvider),
            ChangeNotifierProvider<TransactionsProvider>.value(value: transactionsProvider),
          ],
          child: const MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify both Cash and GCash are active and selectable
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('GCash'), findsOneWidget);
      expect(find.text('GCash (Unavailable)'), findsNothing);

      // Tap GCash chip
      await tester.tap(find.text('GCash'));
      await tester.pump();

      // ChoiceChip for GCash is now selected
      final gcashChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('GCash'), matching: find.byType(ChoiceChip)),
      );
      expect(gcashChip.selected, isTrue);
    });
  });
}
