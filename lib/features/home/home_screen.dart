import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_animations.dart';
import '../../providers/branch_session_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../providers/restock_provider.dart';
import '../../providers/notification_provider.dart';

class HomeScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  String _getGreeting(String branchName) {
    final hour = DateTime.now().hour;
    final prefix = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return '$prefix, $branchName';
  }

  @override
  Widget build(BuildContext context) {
    final branchSession = context.watch<BranchSessionProvider>();
    final txProvider = context.watch<TransactionsProvider>();
    final restockProvider = context.watch<RestockProvider>();
    final notifProvider = context.watch<NotificationProvider>();

    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());

    final todaySales = txProvider.todaySales;
    final dailyQuota = branchSession.dailyQuota;
    final progress = dailyQuota > 0 ? (todaySales / dailyQuota).clamp(0.0, 1.0) : 0.0;
    final progressPct = (progress * 100).toStringAsFixed(1);

    final screenWidth = MediaQuery.of(context).size.width;
    final overviewCrossAxisCount = screenWidth >= 600 ? 4 : 2;
    final overviewAspectRatio = screenWidth >= 600 ? 1.6 : 1.45;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER CONTAINER ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                      border: const Border(
                        bottom: BorderSide(color: AppColors.borderSubtle, width: 1.2),
                      ),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceWhite,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.borderSubtle,
                                      ),
                                      boxShadow: AppColors.softShadow,
                                    ),
                                    child: Image.asset(
                                      'assets/images/coffee_grind_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'COFFEE GRIND PH',
                                          style: AppTextStyles.displayTitle(
                                            fontSize: 16,
                                            letterSpacing: 1.4,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${branchSession.currentBranchName} Branch',
                                          style: AppTextStyles.caption(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Logged-in Branch Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.forestGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.forestGreen.withValues(alpha: 0.25)),
                              ),
                              child: Row(
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
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          _getGreeting(branchSession.currentBranchName),
                          style: AppTextStyles.pageTitle(
                            fontSize: 24,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: AppTextStyles.subtitle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // --- BRANCH QUOTA & PROGRESS CARD ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: AppColors.darkCoffee.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.flag_rounded, color: AppColors.darkCoffee, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Daily Branch Quota',
                                        style: AppTextStyles.cardTitle(
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.forestGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$progressPct%',
                                  style: AppTextStyles.statNumber(
                                    fontSize: 14,
                                    color: AppColors.forestGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppAnimatedProgressBar(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: AppColors.containerMuted,
                              valueColor: AppColors.forestGreen,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Today: ₱${todaySales.toStringAsFixed(2)}',
                                style: AppTextStyles.cardTitle(
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Target: ₱${dailyQuota.toStringAsFixed(2)}',
                                style: AppTextStyles.subtitle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // --- TODAY'S OVERVIEW ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Overview",
                          style: AppTextStyles.sectionHeading(
                            fontSize: 17,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: overviewCrossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: overviewAspectRatio,
                          children: [
                            AppFadeSlideScale(
                              startInterval: 0.05,
                              beginOffset: const Offset(0, 14),
                              child: _buildOverviewCard(
                                title: "Today's Sales",
                                value: '₱${todaySales.toStringAsFixed(2)}',
                                icon: Icons.payments_rounded,
                                accentColor: AppColors.darkCoffee,
                              ),
                            ),
                            AppFadeSlideScale(
                              startInterval: 0.12,
                              beginOffset: const Offset(0, 14),
                              child: _buildOverviewCard(
                                title: 'Transactions',
                                value: '${txProvider.todayTransactionCount}',
                                icon: Icons.receipt_long_rounded,
                                accentColor: AppColors.darkCoffee,
                              ),
                            ),
                            AppFadeSlideScale(
                              startInterval: 0.19,
                              beginOffset: const Offset(0, 14),
                              child: _buildOverviewCard(
                                title: 'Pending Restock',
                                value: '${restockProvider.pendingCount}',
                                icon: Icons.inventory_rounded,
                                accentColor: AppColors.amber,
                              ),
                            ),
                            AppFadeSlideScale(
                              startInterval: 0.26,
                              beginOffset: const Offset(0, 14),
                              child: _buildOverviewCard(
                                title: 'Notifications',
                                value: '${notifProvider.unreadCount} Unread',
                                icon: Icons.notifications_active_rounded,
                                accentColor: AppColors.forestGreen,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        // --- OWNER ANNOUNCEMENTS ---
                        Text(
                          'Owner Announcements',
                          style: AppTextStyles.sectionHeading(
                            fontSize: 17,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (notifProvider.announcements.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.campaign_outlined,
                                    size: 32,
                                    color: AppColors.textMuted.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No published announcements from the Owner.',
                                    style: AppTextStyles.body(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: notifProvider.announcements.take(2).length,
                            itemBuilder: (context, index) {
                              final anc = notifProvider.announcements[index];
                              final dateStr = DateFormat('MMM d, h:mm a').format(anc.createdAt);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                                  boxShadow: AppColors.cardShadow,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.warmBronze.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.campaign_rounded, color: AppColors.warmBronze, size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            anc.title,
                                            style: AppTextStyles.cardTitle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      anc.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySmall(color: AppColors.textSecondary, height: 1.35),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          dateStr,
                                          style: AppTextStyles.caption(color: AppColors.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: AppTextStyles.statNumber(
              fontSize: 18,
              color: accentColor == AppColors.darkCoffee ? AppColors.darkCoffee : accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
