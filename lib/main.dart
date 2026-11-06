import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
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
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase initialization fallback if already initialized or in test environment
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

    if (session.isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.warmCream,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.darkCoffee,
          ),
        ),
      );
    }

    if (session.isAuthenticated) {
      return const MainNavigationScreen();
    }
    return const BranchLoginScreen();
  }
}
