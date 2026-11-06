import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/branch_session_provider.dart';
import '../providers/products_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/restock_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/payment_settings_provider.dart';
import 'home/home_screen.dart';
import 'pos/pos_screen.dart';
import 'restock/restock_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindProvidersToBranch();
    _checkLoginSuccessToast();
  }

  void _bindProvidersToBranch() {
    final session = context.watch<BranchSessionProvider>();
    final branchId = session.branchId;
    if (branchId.isEmpty) {
      context.read<PaymentSettingsProvider>().bindToBranch('');
      return;
    }

    context.read<ProductsProvider>().bindToBranch(branchId);
    context.read<TransactionsProvider>().bindToBranch(branchId);
    context.read<InventoryProvider>().bindToBranch(branchId);
    context.read<RestockProvider>().bindToBranch(branchId);
    context.read<NotificationProvider>().bindToBranch(
      branchId,
      branchName: session.currentBranchName,
    );
    context.read<PaymentSettingsProvider>().bindToBranch(branchId);
  }

  void _checkLoginSuccessToast() {
    final session = context.read<BranchSessionProvider>();
    if (session.consumeLoginSuccessToast()) {
      final branchName = session.currentBranchName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Welcome back!\nYou're now signed in to the $branchName branch.",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              duration: const Duration(milliseconds: 1500),
              backgroundColor: AppColors.surfaceWhite,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  void switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateToTab: switchTab),
      const PosScreen(),
      const RestockScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];

    final unreadNotifications = context.watch<NotificationProvider>().unreadCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;

        if (isTablet) {
          return Scaffold(
            body: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceWhite,
                    border: Border(right: BorderSide(color: AppColors.latteBeige, width: 1)),
                  ),
                  child: NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) => setState(() => _currentIndex = index),
                    backgroundColor: AppColors.surfaceWhite,
                    indicatorColor: AppColors.forestGreen.withValues(alpha: 0.12),
                    selectedIconTheme: const IconThemeData(color: AppColors.forestGreen),
                    unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.darkCoffee.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.coffee_rounded, color: AppColors.darkCoffee, size: 28),
                      ),
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Home'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.point_of_sale_outlined),
                        selectedIcon: Icon(Icons.point_of_sale_rounded),
                        label: Text('POS'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2_rounded),
                        label: Text('Restock'),
                      ),
                      NavigationRailDestination(
                        icon: Badge(
                          isLabelVisible: unreadNotifications > 0,
                          label: Text('$unreadNotifications'),
                          backgroundColor: AppColors.forestGreen,
                          child: const Icon(Icons.notifications_outlined),
                        ),
                        selectedIcon: Badge(
                          isLabelVisible: unreadNotifications > 0,
                          label: Text('$unreadNotifications'),
                          backgroundColor: AppColors.forestGreen,
                          child: const Icon(Icons.notifications_rounded),
                        ),
                        label: const Text('Notifications'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: Text('Profile'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(top: BorderSide(color: AppColors.latteBeige, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.surfaceWhite,
              selectedItemColor: AppColors.forestGreen,
              unselectedItemColor: AppColors.textSecondary,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.3),
              elevation: 0,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded, color: AppColors.forestGreen),
                  label: 'HOME',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.point_of_sale_outlined),
                  activeIcon: Icon(Icons.point_of_sale_rounded, color: AppColors.forestGreen),
                  label: 'POS',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  activeIcon: Icon(Icons.inventory_2_rounded, color: AppColors.forestGreen),
                  label: 'RESTOCK',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: unreadNotifications > 0,
                    label: Text(
                      '$unreadNotifications',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: AppColors.forestGreen,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: unreadNotifications > 0,
                    label: Text(
                      '$unreadNotifications',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: AppColors.forestGreen,
                    child: const Icon(Icons.notifications_rounded, color: AppColors.forestGreen),
                  ),
                  label: 'NOTIFICATIONS',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person_rounded, color: AppColors.forestGreen),
                  label: 'PROFILE',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
