import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_grind_ph/main.dart';
import 'package:coffee_grind_ph/features/auth/branch_login_screen.dart';

void main() {
  testWidgets('App loads AuthGate and displays BranchLoginScreen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(BranchLoginScreen), findsOneWidget);
  });
}
