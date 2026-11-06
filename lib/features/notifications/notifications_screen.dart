import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/branch_session_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.restockApproved:
        return Icons.check_circle_rounded;
      case NotificationType.restockRejected:
        return Icons.cancel_rounded;
      case NotificationType.restockReceived:
        return Icons.archive_rounded;
      case NotificationType.announcement:
        return Icons.campaign_rounded;
      case NotificationType.system:
        return Icons.info_rounded;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.restockApproved:
        return AppColors.statusApproved;
      case NotificationType.restockRejected:
        return AppColors.statusRejected;
      case NotificationType.restockReceived:
        return AppColors.statusReceived;
      case NotificationType.announcement:
        return AppColors.caramelAccent;
      case NotificationType.system:
        return AppColors.caramelLight;
    }
  }

  void _showSubmitConcernDialog(BuildContext screenContext) {
    final controller = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;

    final session = screenContext.read<BranchSessionProvider>();
    final notifProv = screenContext.read<NotificationProvider>();
    final messenger = ScaffoldMessenger.of(screenContext);

    showDialog(
      context: screenContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.report_problem_rounded,
                    color: AppColors.caramelAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Submit Branch Concern',
                    style: AppTextStyles.dialogTitle(fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Describe your issue or request to the Owner (e.g. equipment issue, supply question):',
                    style: AppTextStyles.subtitle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    onChanged: (val) {
                      if (errorMessage != null && val.trim().isNotEmpty) {
                        setDialogState(() => errorMessage = null);
                      }
                    },
                    style: AppTextStyles.inputField(),
                    decoration: InputDecoration(
                      hintText: 'Type your concern here...',
                      hintStyle: AppTextStyles.inputHint(),
                      errorText: errorMessage,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.button(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            setDialogState(() {
                              errorMessage = 'Please enter your concern before submitting.';
                            });
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });
                          try {
                            final nav = Navigator.of(ctx);
                            final bName =
                                session.currentBranchName.endsWith('Branch')
                                ? session.currentBranchName
                                : '${session.currentBranchName} Branch';
                            await notifProv.submitStaffConcern(
                              branchId: session.branchId,
                              branchName: bName,
                              message: text,
                              staffId: session.currentUser?.uid,
                              staffName:
                                  session.currentUser?.displayName ??
                                  session.currentUser?.email ??
                                  'Store Staff',
                            );
                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Concern submitted to Owner Web successfully.',
                                ),
                                backgroundColor: AppColors.cardSurfaceLight,
                              ),
                            );
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() => isSubmitting = false);
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to submit concern: ${e.toString().replaceAll("Exception: ", "")}',
                                  style: AppTextStyles.caption(
                                    color: AppColors.surfaceWhite,
                                  ),
                                ),
                                backgroundColor: AppColors.mutedRed,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surfaceWhite,
                          ),
                        )
                      : Text(
                          'Submit Concern',
                          style: AppTextStyles.button(
                            color: AppColors.surfaceWhite,
                            fontSize: 13,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications & Announcements',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review_rounded),
            tooltip: 'Submit Concern',
            onPressed: () => _showSubmitConcernDialog(context),
          ),
          if (notifProvider.unreadCount > 0)
            TextButton(
              onPressed: () => notifProvider.markAllAsRead(),
              child: Text(
                'Mark Read',
                style: AppTextStyles.button(
                  color: AppColors.darkCoffee,
                  fontSize: 12,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(
                bottom: BorderSide(color: AppColors.latteBeige, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.forestGreen,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.forestGreen,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.navLabel(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AppTextStyles.navLabel(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Notifications (${notifProvider.notifications.length})',
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Announcements (${notifProvider.announcements.length})',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // --- TAB 1: NOTIFICATIONS LIST ---
            notifProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.darkCoffee,
                    ),
                  )
                : notifProvider.notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications found.',
                          style: AppTextStyles.cardTitle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Branch status updates from Owner Web will appear here.',
                          style: AppTextStyles.subtitle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifProvider.notifications[index];
                      final color = _getNotificationColor(item.type);
                      final icon = _getNotificationIcon(item.type);
                      final timeStr = DateFormat('MMM d, h:mm a')
                          .format(item.timestamp);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isRead
                                ? AppColors.latteBeige
                                : AppColors.darkCoffee,
                            width: item.isRead ? 1 : 1.5,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => notifProvider.markAsRead(item.id),
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(icon, color: color),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: AppTextStyles.cardTitle(
                                    fontSize: 15,
                                    color: AppColors.darkCoffee,
                                  ),
                                ),
                              ),
                              if (!item.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.darkCoffee,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                item.message,
                                style: AppTextStyles.bodySmall(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                timeStr,
                                style: AppTextStyles.caption(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // --- TAB 2: OWNER ANNOUNCEMENTS ---
            notifProvider.announcements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No owner announcements published.',
                          style: AppTextStyles.cardTitle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Announcements published by the Owner will appear here.',
                          style: AppTextStyles.subtitle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifProvider.announcements.length,
                    itemBuilder: (context, index) {
                      final anc = notifProvider.announcements[index];
                      final dateStr = DateFormat('MMMM d, yyyy • h:mm a')
                          .format(anc.createdAt);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.latteBeige,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.darkCoffee.withValues(
                                        alpha: 0.08,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.campaign_rounded,
                                      color: AppColors.darkCoffee,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          anc.title,
                                          style: AppTextStyles.cardTitle(
                                            fontSize: 16,
                                            color: AppColors.darkCoffee,
                                          ),
                                        ),
                                        Text(
                                          'Posted by ${anc.author}',
                                          style: AppTextStyles.caption(
                                            fontSize: 11,
                                            color: AppColors.darkCoffee,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                anc.message,
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const Divider(
                                height: 20,
                                color: AppColors.latteBeige,
                              ),
                              Text(
                                dateStr,
                                style: AppTextStyles.caption(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
