import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/app_animations.dart';
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

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _previousIndex = widget.initialIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<BranchSessionProvider>();
    final branchId = session.branchId;
    final branchName = session.currentBranchName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bindProvidersToBranch(branchId, branchName: branchName);
    });
    _checkLoginSuccessToast();
  }

  void _bindProvidersToBranch(String branchId, {required String branchName}) {
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
      branchName: branchName,
    );
    context.read<PaymentSettingsProvider>().bindToBranch(branchId);
  }

  void _checkLoginSuccessToast() {
    final session = context.read<BranchSessionProvider>();
    if (session.consumeLoginSuccessToast()) {
      final branchName = session.currentBranchName.trim();
      final greeting = branchName.isNotEmpty
          ? 'Welcome back, $branchName!'
          : 'Welcome back to Coffee Grind PH!';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) return;
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.darkCoffee,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.coffee_rounded,
                  color: AppColors.warmCream,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    greeting,
                    style: AppTextStyles.buttonSmall(
                      color: AppColors.surfaceWhite,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });
    }
  }

  /// Smooth Fade & Directional Slide Transition between tabs
  Widget _buildAnimatedBody(List<Widget> screens) {
    final bool isForward = _currentIndex >= _previousIndex;
    final double beginX = isForward ? 44.0 : -44.0;

    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(_currentIndex),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: AppMotion.resolveDuration(
        context,
        const Duration(milliseconds: 280),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        if (AppMotion.reduceMotion(context)) {
          return child!;
        }
        return Opacity(
          opacity: animValue.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(beginX * (1.0 - animValue), 0.0),
            child: Transform.scale(
              scale: 0.988 + (0.012 * animValue),
              child: child,
            ),
          ),
        );
      },
      child: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }

  void switchTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _previousIndex = _currentIndex;
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
          final session = context.watch<BranchSessionProvider>();

          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      Container(
                        width: 100,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceWhite,
                          border: Border(right: BorderSide(color: AppColors.borderSubtle, width: 1.2)),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: NavigationRail(
                                selectedIndex: _currentIndex,
                                onDestinationSelected: switchTab,
                                backgroundColor: AppColors.surfaceWhite,
                                indicatorColor: AppColors.darkCoffee.withValues(alpha: 0.08),
                                indicatorShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                selectedIconTheme: const IconThemeData(color: AppColors.darkCoffee, size: 24),
                                unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),
                                selectedLabelTextStyle: const TextStyle(
                                  color: AppColors.darkCoffee,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                                unselectedLabelTextStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                                labelType: NavigationRailLabelType.all,
                                leading: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.warmCream,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                                      boxShadow: AppColors.cardShadow,
                                    ),
                                    child: Image.asset(
                                      'assets/images/coffee_grind_logo.png',
                                      fit: BoxFit.contain,
                                    ),
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
                            // Branch Badge at bottom of Rail
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Tooltip(
                                message: session.currentBranchName,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.forestGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.forestGreen.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.forestGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'ONLINE',
                                        style: AppTextStyles.badge(
                                          color: AppColors.forestGreen,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildAnimatedBody(screens),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: _buildAnimatedBody(screens),
          bottomNavigationBar: _CustomBottomNavBar(
            currentIndex: _currentIndex,
            onTabSelected: switchTab,
            unreadNotifications: unreadNotifications,
          ),
        );
      },
    );
  }
}

// ===============================================================
// CUSTOM SPRING BOUNCE & SCALE-POP LOWER NAVIGATION BAR
// ===============================================================

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

class _CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final int unreadNotifications;

  const _CustomBottomNavBar({
    required this.currentIndex,
    required this.onTabSelected,
    required this.unreadNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      const _NavItemData(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'HOME',
      ),
      const _NavItemData(
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale_rounded,
        label: 'POS',
      ),
      const _NavItemData(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        label: 'RESTOCK',
      ),
      _NavItemData(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications_rounded,
        label: 'NOTIFICATIONS',
        badgeCount: unreadNotifications,
      ),
      const _NavItemData(
        icon: Icons.person_outline,
        activeIcon: Icons.person_rounded,
        label: 'PROFILE',
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D2E1C14),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top gliding indicator line
            SizedBox(
              height: 3,
              child: AnimatedAlign(
                alignment: Alignment(-1.0 + (currentIndex * 0.5), 0.0),
                duration: AppMotion.resolveDuration(
                  context,
                  const Duration(milliseconds: 280),
                ),
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 0.2,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.darkCoffee,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Navigation Items Row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final isSelected = index == currentIndex;

                  return Expanded(
                    child: _SpringNavBarItem(
                      data: item,
                      isSelected: isSelected,
                      onTap: () => onTabSelected(index),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpringNavBarItem extends StatefulWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpringNavBarItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SpringNavBarItem> createState() => _SpringNavBarItemState();
}

class _SpringNavBarItemState extends State<_SpringNavBarItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 55,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(covariant _SpringNavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      if (!AppMotion.reduceMotion(context)) {
        _bounceController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (!AppMotion.reduceMotion(context)) {
      _bounceController.forward(from: 0.0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final data = widget.data;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isSelected ? _scaleAnimation.value : 1.0,
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with pill highlight and optional badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.darkCoffee.withValues(alpha: 0.09)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildIconWithBadge(data, isSelected),
              ),
              const SizedBox(height: 3),
              // Label text
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.darkCoffee
                      : AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconWithBadge(_NavItemData data, bool isSelected) {
    final iconWidget = Icon(
      isSelected ? data.activeIcon : data.icon,
      color: isSelected ? AppColors.darkCoffee : AppColors.textSecondary,
      size: 22,
    );

    if (data.badgeCount == null || data.badgeCount! <= 0) {
      return iconWidget;
    }

    return Badge(
      label: Text(
        '${data.badgeCount}',
        style: const TextStyle(
          fontSize: 9.5,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppColors.forestGreen,
      child: iconWidget,
    );
  }
}
