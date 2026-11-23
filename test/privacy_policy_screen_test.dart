import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/features/profile/privacy_policy_screen.dart';
import 'package:coffee_grind_ph/features/auth/branch_login_screen.dart';
import 'package:coffee_grind_ph/providers/branch_session_provider.dart';

void main() {
  group('Privacy Policy Screen Tests', () {
    testWidgets('1. PrivacyPolicyScreen renders all header elements and policy sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsAtLeast(1));
      expect(find.text('Coffee Grind PH — Privacy Policy'), findsOneWidget);
      expect(find.textContaining('com.shanken.coffeegrindph'), findsOneWidget);
      expect(find.text('1. Purpose of the Application'), findsOneWidget);
      expect(find.text('2. Data We Collect'), findsOneWidget);
      expect(find.text('3. How Data is Used'), findsOneWidget);
      expect(find.text('4. Data Security & Encryption'), findsOneWidget);
      expect(find.text('5. Permissions & Device Access'), findsOneWidget);
      expect(find.text('6. Data Deletion & Contact Inquiries'), findsOneWidget);
      expect(find.textContaining('https://coffeegrindph.web.app/privacy-policy.html'), findsOneWidget);
    });

    testWidgets('2. BranchLoginScreen shows Privacy Policy link and navigates on tap', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => BranchSessionProvider(),
          child: const MaterialApp(
            home: BranchLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final linkFinder = find.widgetWithText(GestureDetector, 'Privacy Policy');
      expect(linkFinder, findsOneWidget);

      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.text('1. Purpose of the Application'), findsOneWidget);
    });
  });
}
