import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/core/utils/auth_error_formatter.dart';
import 'package:coffee_grind_ph/features/auth/branch_login_screen.dart';
import 'package:coffee_grind_ph/features/main_navigation_screen.dart';
import 'package:coffee_grind_ph/main.dart';
import 'package:coffee_grind_ph/providers/branch_session_provider.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/notification_provider.dart';
import 'package:coffee_grind_ph/providers/payment_settings_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/providers/restock_provider.dart';
import 'package:coffee_grind_ph/providers/transactions_provider.dart';
import 'package:coffee_grind_ph/services/auth_service.dart';

// Mock user for testing
class MockTestUser implements User {
  final String _uid;
  final String? _email;

  MockTestUser(this._uid, [this._email]);

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test harness session provider recording calls
class MockRecordingBranchSessionProvider extends ChangeNotifier implements BranchSessionProvider {
  String? submittedEmail;
  String? submittedPassword;
  String? submittedResetEmail;
  int signInCalls = 0;
  int resetCalls = 0;
  bool _authenticated = false;
  bool _initializing = false;
  bool _showLoginToast = false;
  BranchInfo? _branch;
  User? _user;

  @override
  bool get isInitializing => _initializing;

  void setInitializing(bool val) {
    _initializing = val;
    notifyListeners();
  }

  @override
  bool get isVerifying => false;

  @override
  String? get verificationError => null;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  bool get isBranchVerified => _authenticated;

  @override
  BranchInfo? get currentBranch => _branch;

  @override
  User? get currentUser => _user;

  @override
  String get branchId => _branch?.branchId ?? '';

  @override
  String get currentBranchName => _branch?.name ?? '';

  @override
  String get currentBranchEmail => _branch?.email ?? '';

  @override
  double get dailyQuota => 0.0;

  @override
  bool get isLoadingQuota => false;

  @override
  bool consumeLoginSuccessToast() {
    if (_showLoginToast) {
      _showLoginToast = false;
      return true;
    }
    return false;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    submittedEmail = email;
    submittedPassword = password;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetCalls++;
    submittedResetEmail = email;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> signOut({bool preserveError = false}) async {
    _authenticated = false;
    _branch = null;
    _user = null;
    notifyListeners();
  }

  void setAuthenticatedBranch(
    String bId,
    String name,
    String email, {
    bool showToast = false,
  }) {
    _authenticated = true;
    _showLoginToast = showToast;
    _branch = BranchInfo(branchId: bId, name: name, email: email);
    _user = MockTestUser('test_uid', email);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('1. Branch Login Screen Input Tests', () {
    testWidgets('Full Santa Cruz Gmail address (26 chars) is accepted without truncation', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: mock,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      const scEmail = 'sukunaryoumen154@gmail.com';
      await tester.enterText(emailFinder, scEmail);
      await tester.pump();

      final emailField = tester.widget<TextFormField>(emailFinder);
      expect(emailField.controller?.text, scEmail);
      expect(emailField.controller?.text.length, 26);
    });

    testWidgets('Full LSPU Gmail address (28 chars) is accepted without truncation', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: mock,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      const lspuEmail = 'malabananshanken03@gmail.com';
      await tester.enterText(emailFinder, lspuEmail);
      await tester.pump();

      final emailField = tester.widget<TextFormField>(emailFinder);
      expect(emailField.controller?.text, lspuEmail);
      expect(emailField.controller?.text.length, 28);
    });

    testWidgets('Email whitespace is trimmed and lowercased while password is kept verbatim', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: mock,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passwordFinder = find.byType(TextFormField).at(1);
      final buttonFinder = find.text('Sign In Branch Device');

      // Enter untrimmed mixed-case email and password with deliberate space
      await tester.enterText(emailFinder, '  SukunarYoumen154@Gmail.com  ');
      await tester.enterText(passwordFinder, ' Secret Password With Spaces! ');
      await tester.pump();

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Email was trimmed and lowercased
      expect(mock.submittedEmail, 'sukunaryoumen154@gmail.com');
      // Password was preserved verbatim without trimming or lowercasing
      expect(mock.submittedPassword, ' Secret Password With Spaces! ');
    });

    testWidgets('Invalid email formats are rejected by validator', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: mock,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      final passwordFinder = find.byType(TextFormField).at(1);
      final buttonFinder = find.text('Sign In Branch Device');

      await tester.enterText(passwordFinder, 'ValidPassword123');

      // Test empty email
      await tester.enterText(emailFinder, '');
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(find.text('Enter branch account email'), findsOneWidget);

      // Test missing @ shows validation error live
      await tester.enterText(emailFinder, 'santacruzgmail.com');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address containing "@".'), findsOneWidget);

      // Typing @ immediately clears the "@" error live
      await tester.enterText(emailFinder, 'santacruz@');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address containing "@".'), findsNothing);
    });

    testWidgets('Password visibility toggle toggles password obscuring', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: mock,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final passwordFieldFinder = find.byType(TextField).at(1);
      var field = tester.widget<TextField>(passwordFieldFinder);
      expect(field.obscureText, isTrue);

      // Tap show password
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      field = tester.widget<TextField>(passwordFieldFinder);
      expect(field.obscureText, isFalse);

      // Tap hide password
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      field = tester.widget<TextField>(passwordFieldFinder);
      expect(field.obscureText, isTrue);
    });
  });

  group('2. AuthService UID-to-Branch Verification Tests (Firestore)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AuthService authService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      authService = AuthService(firestore: fakeFirestore);
    });

    test('Santa Cruz UID resolves to Santa Cruz branch info', () async {
      const scUid = 'VbbTKsNnSwMQ7rnDU8fsYM7dod12';
      const scBranchId = 'br_1790905840872';

      await fakeFirestore.collection(FirebasePaths.branchAccounts).doc(scUid).set({
        'branchId': scBranchId,
        'branchName': 'Santa Cruz',
        'accountType': 'branch',
        'status': 'active',
        'active': true,
      });

      final user = MockTestUser(scUid, 'sukunaryoumen154@gmail.com');
      final info = await authService.verifyAndGetBranchInfo(user);

      expect(info, isNotNull);
      expect(info!.branchId, scBranchId);
      expect(info.name, 'Santa Cruz');
      expect(info.email, 'sukunaryoumen154@gmail.com');
    });

    test('LSPU UID resolves to LSPU branch info', () async {
      const lspuUid = 'uGOP7Jd3K1RMttlZDI6WqrhwRLd2';
      const lspuBranchId = 'br_1790923872261';

      await fakeFirestore.collection(FirebasePaths.branchAccounts).doc(lspuUid).set({
        'branchId': lspuBranchId,
        'branchName': 'LSPU',
        'role': 'branch',
        'isActive': true,
      });

      final user = MockTestUser(lspuUid, 'malabananshanken03@gmail.com');
      final info = await authService.verifyAndGetBranchInfo(user);

      expect(info, isNotNull);
      expect(info!.branchId, lspuBranchId);
      expect(info.name, 'LSPU');
      expect(info.email, 'malabananshanken03@gmail.com');
    });

    test('Missing branch_accounts document throws unauthorized-device', () async {
      final user = MockTestUser('unregistered_uid', 'stranger@gmail.com');

      expect(
        () => authService.verifyAndGetBranchInfo(user),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'unauthorized-device')),
      );
    });

    test('Inactive account throws user-disabled', () async {
      const uid = 'inactive_uid';
      await fakeFirestore.collection(FirebasePaths.branchAccounts).doc(uid).set({
        'branchId': 'br_test',
        'branchName': 'Test Branch',
        'accountType': 'branch',
        'status': 'inactive',
        'active': false,
      });

      final user = MockTestUser(uid, 'inactive@gmail.com');
      expect(
        () => authService.verifyAndGetBranchInfo(user),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'user-disabled')),
      );
    });

    test('Owner or Admin role throws unauthorized-device', () async {
      const uid = 'owner_uid';
      await fakeFirestore.collection(FirebasePaths.branchAccounts).doc(uid).set({
        'branchId': 'br_test',
        'branchName': 'Test Branch',
        'role': 'owner',
        'active': true,
      });

      final user = MockTestUser(uid, 'iankakilala@gmail.com');
      expect(
        () => authService.verifyAndGetBranchInfo(user),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'unauthorized-device')),
      );
    });

    test('Conflicting role fields throw unauthorized-device', () async {
      const uid = 'conflict_uid';
      await fakeFirestore.collection(FirebasePaths.branchAccounts).doc(uid).set({
        'branchId': 'br_test',
        'branchName': 'Test Branch',
        'role': 'branch',
        'accountType': 'owner', // Conflict
        'active': true,
      });

      final user = MockTestUser(uid, 'conflict@gmail.com');
      expect(
        () => authService.verifyAndGetBranchInfo(user),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'unauthorized-device')),
      );
    });

    test('Conflicting branchId and branch_id throw unauthorized-device', () async {
      const uid = 'branch_conflict_uid';
      await fakeFirestore.collection(FirebasePaths.branchAccounts).doc(uid).set({
        'branchId': 'br_sc',
        'branch_id': 'br_lspu', // Conflict
        'accountType': 'branch',
        'active': true,
      });

      final user = MockTestUser(uid, 'test@gmail.com');
      expect(
        () => authService.verifyAndGetBranchInfo(user),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'unauthorized-device')),
      );
    });

    test('Missing branchId throws unauthorized-device', () async {
      const uid = 'nobranch_uid';
      await fakeFirestore.collection(FirebasePaths.branchAccounts).doc(uid).set({
        'accountType': 'branch',
        'active': true,
      });

      final user = MockTestUser(uid, 'test@gmail.com');
      expect(
        () => authService.verifyAndGetBranchInfo(user),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'unauthorized-device')),
      );
    });
  });

  group('3. Forgot Password Workflow Tests', () {
    testWidgets('Forgot Password button opens dialog with prefilled email', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: mock,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final emailFinder = find.byType(TextFormField).at(0);
      await tester.enterText(emailFinder, 'sukunaryoumen154@gmail.com');
      await tester.pump();

      // Tap Forgot Password?
      final forgotBtn = find.text('Forgot Password?');
      expect(forgotBtn, findsOneWidget);
      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);

      // Email prefilled
      expect(find.text('sukunaryoumen154@gmail.com'), findsNWidgets(2)); // in login field & dialog field
    });

    testWidgets('Submitting valid email triggers sendPasswordReset and displays privacy-safe success message with cooldown', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: mock,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      // Open Forgot Password dialog
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      // Enter email in dialog field
      final dialogEmailFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dialogEmailFinder, '  MalabananShanKen03@Gmail.com  ');
      await tester.pump();

      // Tap Send Reset Link
      final sendBtn = find.text('Send Reset Link');
      await tester.tap(sendBtn);
      await tester.pump(); // Start async

      // While in flight
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Verified provider was called with trimmed and lowercased email
      expect(mock.resetCalls, 1);
      expect(mock.submittedResetEmail, 'malabananshanken03@gmail.com');

      // Privacy-safe success message displayed
      expect(
        find.text(
          'If an account is associated with this email, a password reset link has been requested. Please check your inbox and spam folder.',
        ),
        findsOneWidget,
      );

      // Cooldown timer displayed
      expect(find.textContaining('Resend ('), findsOneWidget);
    });

    test('formatPasswordResetError handles error mappings properly', () {
      expect(
        formatPasswordResetError('firebase_auth/too-many-requests'),
        'Too many password reset attempts. Please wait a moment and try again.',
      );
      expect(
        formatPasswordResetError('invalid-email'),
        'Enter a valid email address containing "@".',
      );
      expect(
        formatPasswordResetError('user-disabled'),
        'This branch account has been disabled. Please contact the administrator.',
      );
      expect(
        formatPasswordResetError('network-request-failed'),
        'Network connection error. Please check your internet connection and try again.',
      );
      expect(
        formatPasswordResetError('unknown-error'),
        'Unable to request password reset. Please try again later.',
      );
    });
  });

  group('4. Branch Session & AuthGate Navigation Tests', () {
    testWidgets('Unauthenticated session displays BranchLoginScreen', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<BranchSessionProvider>.value(
          value: mock,
          child: const MaterialApp(
            home: AuthGate(),
          ),
        ),
      );

      expect(find.byType(BranchLoginScreen), findsOneWidget);
    });

    testWidgets('Initializing session displays warm cream loading indicator in AuthGate', (tester) async {
      final mock = MockRecordingBranchSessionProvider();
      mock.setInitializing(true);

      await tester.pumpWidget(
        ChangeNotifierProvider<BranchSessionProvider>.value(
          value: mock,
          child: const MaterialApp(
            home: AuthGate(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('BranchSessionProvider sets verified branch and clears completely on signOut', () async {
      final mock = MockRecordingBranchSessionProvider();
      expect(mock.isAuthenticated, isFalse);
      expect(mock.branchId, isEmpty);

      // Authenticate with Santa Cruz
      mock.setAuthenticatedBranch('br_1790905840872', 'Santa Cruz', 'sukunaryoumen154@gmail.com');
      expect(mock.isAuthenticated, isTrue);
      expect(mock.branchId, 'br_1790905840872');
      expect(mock.currentBranchName, 'Santa Cruz');
      expect(mock.currentBranchEmail, 'sukunaryoumen154@gmail.com');

      // Sign out
      await mock.signOut();
      expect(mock.isAuthenticated, isFalse);
      expect(mock.branchId, isEmpty);
      expect(mock.currentBranch, isNull);
      expect(mock.currentUser, isNull);
    });

    testWidgets(
      'Opening splash animates into BranchLoginScreen and authenticates smoothly into MainNavigationScreen with welcome toast',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final fakeDb = FakeFirebaseFirestore();
        final mock = MockRecordingBranchSessionProvider();
        mock.setInitializing(true);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BranchSessionProvider>.value(value: mock),
              ChangeNotifierProvider(create: (_) => ProductsProvider(firestore: fakeDb)),
              ChangeNotifierProvider(create: (_) => PosCartProvider()),
              ChangeNotifierProvider(
                create: (_) => TransactionsProvider(
                  firestore: fakeDb,
                  checkIsOnline: () async => true,
                ),
              ),
              ChangeNotifierProvider(create: (_) => InventoryProvider(firestore: fakeDb)),
              ChangeNotifierProvider(create: (_) => RestockProvider(firestore: fakeDb)),
              ChangeNotifierProvider(create: (_) => NotificationProvider(firestore: fakeDb)),
              ChangeNotifierProvider(create: (_) => PaymentSettingsProvider(firestore: fakeDb)),
            ],
            child: const MaterialApp(home: AuthGate()),
          ),
        );

        // Opening splash appears with logo, title, subtitle, and loading indicator
        expect(find.text('Coffee Grind PH'), findsOneWidget);
        expect(find.text('Preparing Branch POS...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Finish initialization -> transitions smoothly to BranchLoginScreen
        mock.setInitializing(false);
        await tester.pumpAndSettle();
        expect(find.byType(BranchLoginScreen), findsOneWidget);
        expect(find.text('Branch Device Sign In'), findsOneWidget);

        // Sign in -> transitions smoothly to MainNavigationScreen and shows welcome toast
        mock.setAuthenticatedBranch(
          'br_1790905840872',
          'Santa Cruz',
          'sukunaryoumen154@gmail.com',
          showToast: true,
        );
        await tester.pumpAndSettle();

        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.text('Welcome back, Santa Cruz!'), findsOneWidget);
      },
    );
  });
}
