import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/providers/notification_provider.dart';
import 'package:coffee_grind_ph/providers/branch_session_provider.dart';
import 'package:coffee_grind_ph/services/auth_service.dart';
import 'package:coffee_grind_ph/features/notifications/notifications_screen.dart';

class FakeBranchSessionProvider extends ChangeNotifier
    implements BranchSessionProvider {
  @override
  String get branchId => 'br_1790905840872';

  @override
  String get currentBranchName => 'Santa Cruz';

  @override
  String get currentBranchEmail => 'santacruz@gmail.com';

  @override
  BranchInfo get currentBranch => const BranchInfo(
    branchId: 'br_1790905840872',
    name: 'Santa Cruz',
    email: 'santacruz@gmail.com',
  );

  @override
  bool get isAuthenticated => true;

  @override
  User? get currentUser => null;

  @override
  bool consumeLoginSuccessToast() => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Concern Submission Flow Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late NotificationProvider notifProvider;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      notifProvider = NotificationProvider(firestore: fakeDb);
    });

    test('1. Successful concern submission saves to concerns collection with pending status', () async {
      await notifProvider.submitStaffConcern(
        branchId: 'br_1790905840872',
        branchName: 'Santa Cruz Branch',
        message: 'The grinder burrs need calibration.',
        staffId: 'STAFF_001',
        staffName: 'Barista Juan',
      );

      final snapshot = await fakeDb.collection(FirebasePaths.concerns).get();
      expect(snapshot.docs.length, 1);

      final data = snapshot.docs.first.data();
      expect(data['branchId'], 'br_1790905840872');
      expect(data['branchName'], 'Santa Cruz Branch');
      expect(data['message'], 'The grinder burrs need calibration.');
      expect(data['status'], 'pending');
      expect(data['submittedByStaffId'], 'STAFF_001');
      expect(data['submittedByStaffName'], 'Barista Juan');
      expect(data['concernId'], isNotEmpty);
      expect(data['concernId'], snapshot.docs.first.id);
    });

    test(
      '2. Concern submission isolates branch ID (Santa Cruz vs LSPU)',
      () async {
        await notifProvider.submitStaffConcern(
          branchId: 'br_1790923872261',
          branchName: 'LSPU Branch',
          message: 'Water filter replacement required.',
        );

        final snapshot = await fakeDb
            .collection(FirebasePaths.concerns)
            .where('branchId', isEqualTo: 'br_1790923872261')
            .get();

        expect(snapshot.docs.length, 1);
        final data = snapshot.docs.first.data();
        expect(data['branchName'], 'LSPU Branch');
        expect(data['message'], 'Water filter replacement required.');
      },
    );

    test('3. Rejects empty concern message', () async {
      expect(
        () => notifProvider.submitStaffConcern(
          branchId: 'br_1790905840872',
          branchName: 'Santa Cruz Branch',
          message: '   ',
        ),
        throwsA(isA<Exception>()),
      );

      final snapshot = await fakeDb.collection(FirebasePaths.concerns).get();
      expect(snapshot.docs.length, 0);
    });

    test('4. Rejects empty branchId', () async {
      expect(
        () => notifProvider.submitStaffConcern(
          branchId: '   ',
          branchName: 'Unknown Branch',
          message: 'Valid message',
        ),
        throwsA(isA<Exception>()),
      );

      final snapshot = await fakeDb.collection(FirebasePaths.concerns).get();
      expect(snapshot.docs.length, 0);
    });

    testWidgets(
      '5. Submit concern dialog validates empty input before submission',
      (tester) async {
        final fakeSession = FakeBranchSessionProvider();
        notifProvider.setLoadingForTesting(false);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<NotificationProvider>.value(
                  value: notifProvider,
                ),
                ChangeNotifierProvider<BranchSessionProvider>.value(
                  value: fakeSession,
                ),
              ],
              child: const Scaffold(body: NotificationsScreen()),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the action button to open the concern dialog
        final openButton = find.byTooltip('Submit Concern');
        expect(openButton, findsOneWidget);
        await tester.tap(openButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Submit Branch Concern'), findsOneWidget);

        // Tap submit with empty text field
        final submitButton = find.text('Submit Concern');
        expect(submitButton, findsOneWidget);
        await tester.tap(submitButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Inline validation error should appear and dialog should NOT close
        expect(
          find.text('Please enter your concern before submitting.'),
          findsOneWidget,
        );
        expect(find.text('Submit Branch Concern'), findsOneWidget);

        // Enter text and submit
        await tester.enterText(
          find.byType(TextField),
          'AC temperature too low.',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Error message disappears on typing
        expect(
          find.text('Please enter your concern before submitting.'),
          findsNothing,
        );

        await tester.tap(submitButton);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final snap = await fakeDb.collection(FirebasePaths.concerns).get();

        // Dialog is dismissed
        expect(find.text('Submit Branch Concern'), findsNothing);
        expect(snap.docs.length, 1);
        expect(snap.docs.first.data()['message'], 'AC temperature too low.');
        expect(snap.docs.first.data()['branchId'], 'br_1790905840872');
      },
    );
  });
}
