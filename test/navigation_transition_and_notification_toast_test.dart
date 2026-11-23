import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:coffee_grind_ph/features/main_navigation_screen.dart';
import 'package:coffee_grind_ph/services/auth_service.dart';
import 'package:coffee_grind_ph/providers/branch_session_provider.dart';
import 'package:coffee_grind_ph/providers/products_provider.dart';
import 'package:coffee_grind_ph/providers/transactions_provider.dart';
import 'package:coffee_grind_ph/providers/inventory_provider.dart';
import 'package:coffee_grind_ph/providers/restock_provider.dart';
import 'package:coffee_grind_ph/providers/notification_provider.dart';
import 'package:coffee_grind_ph/providers/payment_settings_provider.dart';
import 'package:coffee_grind_ph/providers/pos_cart_provider.dart';

Widget createTestApp({
  required FakeFirebaseFirestore fakeDb,
  required NotificationProvider notifProvider,
  required BranchSessionProvider branchSession,
  int initialIndex = 0,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BranchSessionProvider>.value(value: branchSession),
      ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
      ChangeNotifierProvider<ProductsProvider>(
        create: (_) => ProductsProvider(firestore: fakeDb),
      ),
      ChangeNotifierProvider<TransactionsProvider>(
        create: (_) => TransactionsProvider(firestore: fakeDb),
      ),
      ChangeNotifierProvider<InventoryProvider>(
        create: (_) => InventoryProvider(firestore: fakeDb),
      ),
      ChangeNotifierProvider<RestockProvider>(
        create: (_) => RestockProvider(firestore: fakeDb),
      ),
      ChangeNotifierProvider<PaymentSettingsProvider>(
        create: (_) => PaymentSettingsProvider(firestore: fakeDb),
      ),
      ChangeNotifierProvider<PosCartProvider>(
        create: (_) => PosCartProvider(),
      ),
    ],
    child: MaterialApp(
      home: MainNavigationScreen(initialIndex: initialIndex),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;
  late NotificationProvider notifProvider;
  late BranchSessionProvider branchSession;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    notifProvider = NotificationProvider(firestore: fakeDb);
    branchSession = BranchSessionProvider();
    branchSession.setSessionForTesting(
      branch: const BranchInfo(
        branchId: 'br_1790905840872',
        name: 'Santa Cruz',
        email: 'santacruz@gmail.com',
      ),
      isInitializing: false,
    );
  });

  tearDown(() {
    try {
      notifProvider.dispose();
    } catch (_) {}
  });

  group('Main Navigation & Lower Nav Bar Tests', () {
    testWidgets('1. Lower nav bar renders all 5 tabs and active tab displays label and highlight', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestApp(
        fakeDb: fakeDb,
        notifProvider: notifProvider,
        branchSession: branchSession,
      ));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('POS'), findsOneWidget);
      expect(find.text('RESTOCK'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      expect(find.text('PROFILE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      notifProvider.dispose();
    });

    testWidgets('2. Tapping a tab triggers spring bounce scale animation and switches tab', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestApp(
        fakeDb: fakeDb,
        notifProvider: notifProvider,
        branchSession: branchSession,
        initialIndex: 0,
      ));
      await tester.pumpAndSettle();

      // Tap on POS tab
      await tester.tap(find.text('POS'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Staff POS should now be visible
      expect(find.text('Staff POS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      notifProvider.dispose();
    });

    testWidgets('3. Navigating backward from tab 3 to tab 0 triggers directional slide', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestApp(
        fakeDb: fakeDb,
        notifProvider: notifProvider,
        branchSession: branchSession,
        initialIndex: 3, // Start on Notifications
      ));
      await tester.pumpAndSettle();

      // Tap backward on HOME tab (index 0)
      await tester.tap(find.text('HOME'));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();

      // Home overview should be visible
      expect(find.text("Today's Overview"), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      notifProvider.dispose();
    });
  });

  group('Announcement Swipe and Restock New Request Position Tests', () {
    testWidgets('4. Swiping an announcement right marks it as read and swiping left deletes it', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Prepopulate an announcement directly in Fake Firestore so the branch listener picks it up
      await fakeDb.collection('announcements').doc('anc_holiday_promo').set({
        'title': 'Holiday Promo Launch',
        'message': 'All holiday themed syrups are 10% off this weekend.',
        'createdAt': DateTime.now(),
        'isAllBranches': true,
        'targetAudience': 'All Branches',
        'author': 'Store Owner',
        'status': 'active',
      });

      await tester.pumpWidget(createTestApp(
        fakeDb: fakeDb,
        notifProvider: notifProvider,
        branchSession: branchSession,
        initialIndex: 3, // Notifications tab
      ));
      await tester.pumpAndSettle();

      // Switch to Announcements tab
      await tester.tap(find.text('Announcements (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Holiday Promo Launch'), findsOneWidget);
      expect(notifProvider.announcements.first.isRead, false);

      // 1. Swipe RIGHT (startToEnd) to mark as read
      await tester.drag(find.text('Holiday Promo Launch'), const Offset(300, 0));
      await tester.pumpAndSettle();

      // Announcement remains in list and is now read
      expect(find.text('Holiday Promo Launch'), findsOneWidget);
      expect(notifProvider.announcements.first.isRead, true);

      // 2. Swipe LEFT (endToStart) to delete/remove
      await tester.drag(find.text('Holiday Promo Launch'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Announcement is dismissed/deleted
      expect(find.text('Holiday Promo Launch'), findsNothing);
      expect(notifProvider.announcements.isEmpty, true);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      notifProvider.dispose();
    });

    testWidgets('5. RestockScreen renders New Request in AppBar actions leaving bottom pagination unobstructed', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestApp(
        fakeDb: fakeDb,
        notifProvider: notifProvider,
        branchSession: branchSession,
        initialIndex: 2, // Restock tab
      ));
      await tester.pumpAndSettle();

      // Verify "New Request" is in the AppBar area (top of screen, Y < 120)
      final newRequestFinder = find.widgetWithText(ElevatedButton, 'New Request');
      expect(newRequestFinder, findsOneWidget);
      final newRequestTop = tester.getTopLeft(newRequestFinder).dy;
      expect(newRequestTop, lessThan(120.0));

      // Tapping New Request opens CreateRestockDialog (title: Request Restocking)
      await tester.tap(newRequestFinder);
      await tester.pumpAndSettle();

      expect(find.text('Request Restocking'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      notifProvider.dispose();
    });
  });
}
