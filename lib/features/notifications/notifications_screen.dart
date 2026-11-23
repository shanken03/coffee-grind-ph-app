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
              backgroundColor: AppColors.surfaceWhite,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.report_problem_rounded,
                      color: AppColors.amber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
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
                  const SizedBox(height: 14),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCoffee,
                    foregroundColor: AppColors.surfaceWhite,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          'Notifications & Announcements',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.darkCoffee,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review_rounded, color: AppColors.darkCoffee),
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
          if (notifProvider.notifications.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColors.mutedRed,
              ),
              tooltip: 'Clear All',
              onPressed: () => notifProvider.clearAllNotifications(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.darkCoffee,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.darkCoffee,
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
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Swipe right to mark read, left to delete',
                                style: AppTextStyles.caption(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  notifProvider.clearAllNotifications(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.mutedRed,
                                backgroundColor:
                                    AppColors.mutedRed.withValues(alpha: 0.08),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_sweep_rounded,
                                size: 15,
                                color: AppColors.mutedRed,
                              ),
                              label: Text(
                                'Clear All',
                                style: AppTextStyles.buttonSmall(
                                  color: AppColors.mutedRed,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          itemCount: notifProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifProvider.notifications[index];
                      final color = _getNotificationColor(item.type);
                      final icon = _getNotificationIcon(item.type);
                      final timeStr = DateFormat('MMM d, h:mm a')
                          .format(item.timestamp);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.done_all_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Checked',
                                  style: AppTextStyles.button(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppColors.mutedRed,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Remove',
                                  style: AppTextStyles.button(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              notifProvider.markAsRead(item.id);
                              return false;
                            }
                            return true;
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart) {
                              notifProvider.removeNotification(item.id);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: item.isRead
                                    ? AppColors.borderSubtle
                                    : AppColors.darkCoffee,
                                width: item.isRead ? 1 : 1.5,
                              ),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                              onTap: () => notifProvider.markAsRead(item.id),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                child: Icon(icon, color: color, size: 20),
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
                          ),
                          ),
                        ),
                      );
                    },
                        ),
                      ),
                    ],
                  ),

            // --- TAB 2: OWNER ANNOUNCEMENTS ---
            notifProvider.announcements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Icon(
                            Icons.campaign_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Swipe right to mark read, left to delete',
                                style: AppTextStyles.caption(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  notifProvider.clearAllAnnouncements(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.mutedRed,
                                backgroundColor:
                                    AppColors.mutedRed.withValues(alpha: 0.08),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_sweep_rounded,
                                size: 15,
                                color: AppColors.mutedRed,
                              ),
                              label: Text(
                                'Clear All',
                                style: AppTextStyles.buttonSmall(
                                  color: AppColors.mutedRed,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          itemCount: notifProvider.announcements.length,
                          itemBuilder: (context, index) {
                            final anc = notifProvider.announcements[index];
                            final dateStr = DateFormat('MMMM d, yyyy • h:mm a')
                                .format(anc.createdAt);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Dismissible(
                                key: ValueKey('announcement_${anc.id}'),
                                direction: DismissDirection.horizontal,
                                background: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.forestGreen,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.done_all_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Mark Read',
                                        style: AppTextStyles.button(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                secondaryBackground: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.mutedRed,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Delete',
                                        style: AppTextStyles.button(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.startToEnd) {
                                    notifProvider.markAnnouncementAsRead(anc.id);
                                    return false; // Snaps back, now marked as read
                                  }
                                  return true; // Dismisses/deletes
                                },
                                onDismissed: (direction) {
                                  if (direction == DismissDirection.endToStart) {
                                    notifProvider.removeAnnouncement(anc.id);
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceWhite,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: anc.isRead
                                          ? AppColors.borderSubtle
                                          : AppColors.darkCoffee,
                                      width: anc.isRead ? 1 : 1.5,
                                    ),
                                    boxShadow: AppColors.cardShadow,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => notifProvider.markAnnouncementAsRead(anc.id),
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
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              anc.title,
                                                              style: AppTextStyles.cardTitle(
                                                                fontSize: 16,
                                                                color: AppColors.darkCoffee,
                                                              ),
                                                            ),
                                                          ),
                                                          if (!anc.isRead) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              width: 8,
                                                              height: 8,
                                                              decoration: const BoxDecoration(
                                                                color: AppColors.darkCoffee,
                                                                shape: BoxShape.circle,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      Text(
                                                        'Posted by ${anc.author}',
                                                        style: AppTextStyles.caption(
                                                          fontSize: 11,
                                                          color: AppColors.textSecondary,
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
                                              color: AppColors.borderSubtle,
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    dateStr,
                                                    style: AppTextStyles.caption(
                                                      fontSize: 11,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (anc.targetBranch != null &&
                                                    anc.targetBranch!.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.darkCoffee
                                                          .withValues(alpha: 0.06),
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      anc.targetBranch!,
                                                      style: AppTextStyles.caption(
                                                        fontSize: 10,
                                                        color: AppColors.darkCoffee,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
