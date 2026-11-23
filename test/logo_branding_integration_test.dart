import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffee_grind_ph/features/auth/branch_login_screen.dart';
import 'package:coffee_grind_ph/features/profile/profile_screen.dart';
import 'package:coffee_grind_ph/providers/branch_session_provider.dart';

class MockSession extends ChangeNotifier implements BranchSessionProvider {
  @override
  String get currentBranchName => 'LSPU';

  @override
  String get currentBranchEmail => 'lspu@gmail.com';

  @override
  String get branchId => 'lspu';

  @override
  bool get isAuthenticated => true;

  @override
  bool get isSigningIn => false;

  @override
  bool get isSigningOut => false;

  @override
  String? get verificationError => null;

  @override
  double get dailyQuota => 10000.0;

  @override
  bool consumeLoginSuccessToast() => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('Coffee Grind PH Official Logo & Android Launcher Icon Verification', () {
    test('Official brand logo asset exists in assets/images/', () {
      final logoFile = File('assets/images/coffee_grind_logo.png');
      expect(logoFile.existsSync(), isTrue, reason: 'assets/images/coffee_grind_logo.png must exist');
      expect(logoFile.lengthSync(), greaterThan(1000), reason: 'Logo image must be a valid non-empty PNG');

      final logoCreamFile = File('assets/images/coffee_grind_logo_cream.png');
      expect(logoCreamFile.existsSync(), isTrue, reason: 'assets/images/coffee_grind_logo_cream.png must exist');
    });

    test('pubspec.yaml declares assets/images/ directory', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('assets/images/'), isTrue, reason: 'pubspec.yaml must include assets/images/');
    });

    test('Android launcher icons and adaptive icons exist for all densities', () {
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final launcher = File('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect(launcher.existsSync(), isTrue, reason: 'mipmap-$density/ic_launcher.png must exist');
        expect(launcher.lengthSync(), greaterThan(100));

        final foreground = File('android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png');
        expect(foreground.existsSync(), isTrue, reason: 'mipmap-$density/ic_launcher_foreground.png must exist');
        expect(foreground.lengthSync(), greaterThan(100));
      }

      final adaptiveXml = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(adaptiveXml.existsSync(), isTrue, reason: 'Adaptive icon XML must exist');
      final xmlContent = adaptiveXml.readAsStringSync();
      expect(xmlContent.contains('adaptive-icon'), isTrue);
      expect(xmlContent.contains('ic_launcher_background'), isTrue);
      expect(xmlContent.contains('ic_launcher_foreground'), isTrue);

      final colorsXml = File('android/app/src/main/res/values/colors.xml');
      expect(colorsXml.existsSync(), isTrue, reason: 'values/colors.xml must exist');
      final colorsContent = colorsXml.readAsStringSync();
      expect(colorsContent.contains('#F9F6F0'), isTrue, reason: 'Background must be warm cream #F9F6F0');
    });

    testWidgets('BranchLoginScreen contains official Coffee Grind PH logo image', (tester) async {
      final sessionProvider = MockSession();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: sessionProvider,
            child: const BranchLoginScreen(),
          ),
        ),
      );

      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/coffee_grind_logo.png',
      );
      expect(imageFinder, findsOneWidget, reason: 'Login screen must display official logo asset');
    });

    testWidgets('ProfileScreen contains official Coffee Grind PH logo image', (tester) async {
      final sessionProvider = MockSession();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BranchSessionProvider>.value(
            value: sessionProvider,
            child: const Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/coffee_grind_logo.png',
      );
      expect(imageFinder, findsWidgets, reason: 'Profile screen must display official logo asset');
    });
  });
}
