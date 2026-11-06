import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
                    padding: const EdgeInsets.all(22.0),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border(
                        bottom: BorderSide(color: AppColors.latteBeige, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkCoffee.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.latteBeige,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.coffee_rounded,
                                    color: AppColors.darkCoffee,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'COFFEE GRIND PH',
                                      style: AppTextStyles.displayTitle(
                                        fontSize: 16,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      '${branchSession.currentBranchName} Branch',
                                      style: AppTextStyles.caption(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Logged-in Branch Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.forestGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.forestGreen.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.forestGreen, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ONLINE',
                                    style: AppTextStyles.badge(
                                      color: AppColors.forestGreen,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.latteBeige, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.flag_rounded, color: AppColors.darkCoffee, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Daily Branch Quota',
                                    style: AppTextStyles.cardTitle(
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$progressPct%',
                                style: AppTextStyles.statNumber(
                                  fontSize: 14,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: AppColors.warmCream,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                            _buildOverviewCard(
                              title: "Today's Sales",
                              value: '₱${todaySales.toStringAsFixed(2)}',
                              icon: Icons.payments_rounded,
                              accentColor: AppColors.darkCoffee,
                            ),
                            _buildOverviewCard(
                              title: 'Transactions',
                              value: '${txProvider.todayTransactionCount}',
                              icon: Icons.receipt_long_rounded,
                              accentColor: AppColors.darkCoffee,
                            ),
                            _buildOverviewCard(
                              title: 'Pending Restock',
                              value: '${restockProvider.pendingCount}',
                              icon: Icons.inventory_rounded,
                              accentColor: AppColors.amber,
                            ),
                            _buildOverviewCard(
                              title: 'Notifications',
                              value: '${notifProvider.unreadCount} Unread',
                              icon: Icons.notifications_active_rounded,
                              accentColor: AppColors.forestGreen,
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
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  'No published announcements from the Owner.',
                                  style: AppTextStyles.body(color: AppColors.textSecondary),
                                ),
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

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.campaign_rounded, color: AppColors.caramelAccent, size: 20),
                                          const SizedBox(width: 8),
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
                                      const SizedBox(height: 6),
                                      Text(
                                        anc.message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        dateStr,
                                        style: AppTextStyles.caption(color: AppColors.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.latteBeige, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.subtitle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, color: accentColor, size: 18),
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
