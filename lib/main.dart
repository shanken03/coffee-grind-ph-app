import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'core/widgets/app_animations.dart';
import 'providers/branch_session_provider.dart';
import 'providers/products_provider.dart';
import 'providers/pos_cart_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/restock_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_settings_provider.dart';
import 'features/auth/branch_login_screen.dart';
import 'features/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
  };
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('FIREBASE_INIT_FALLBACK: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BranchSessionProvider()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => PosCartProvider()),
        ChangeNotifierProvider(create: (_) => TransactionsProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => RestockProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PaymentSettingsProvider()),
      ],
      child: MaterialApp(
        title: 'Coffee Grind PH Staff',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BranchSessionProvider>();

    final Widget activeScreen;
    if (session.isInitializing) {
      activeScreen = const _AppOpeningSplash(
        key: ValueKey<String>('auth_initializing'),
      );
    } else if (session.isAuthenticated) {
      activeScreen = MainNavigationScreen(
        key: ValueKey<String>('authenticated_${session.branchId}'),
      );
    } else {
      activeScreen = const BranchLoginScreen(
        key: ValueKey<String>('unauthenticated_login'),
      );
    }

    return AnimatedSwitcher(
      duration: AppMotion.resolveDuration(
        context,
        const Duration(milliseconds: 520),
      ),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        if (AppMotion.reduceMotion(context)) {
          return child;
        }
        final scaleAnimation = Tween<double>(
          begin: 0.94,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
      child: activeScreen,
    );
  }
}

class _AppOpeningSplash extends StatelessWidget {
  const _AppOpeningSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: AppFadeSlideScale(
            duration: const Duration(milliseconds: 600),
            beginOffset: const Offset(0, 8),
            beginScale: 0.88,
            curve: Curves.easeOutBack,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1.4,
                    ),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Image.asset(
                    'assets/images/coffee_grind_logo.png',
                    height: 92,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 22),
                AppFadeSlideScale(
                  duration: const Duration(milliseconds: 520),
                  startInterval: 0.18,
                  beginOffset: const Offset(0, 6),
                  beginScale: 0.98,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Coffee Grind PH',
                        style: AppTextStyles.pageTitle(
                          fontSize: 22,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Preparing Branch POS...',
                        style: AppTextStyles.caption(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
