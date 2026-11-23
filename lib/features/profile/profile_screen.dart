import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/branch_session_provider.dart';
import '../../providers/notification_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const String appVersion = '1.0.0+1';

  void _confirmLogout(BuildContext context, BranchSessionProvider session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          'Log out?',
          style: AppTextStyles.dialogTitle(color: AppColors.darkCoffee),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.button(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mutedRed,
              foregroundColor: AppColors.surfaceWhite,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await session.signOut();
            },
            child: Text(
              'Log Out',
              style: AppTextStyles.button(color: AppColors.surfaceWhite, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportProblemDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;

    final session = context.read<BranchSessionProvider>();
    NotificationProvider? notifProv;
    try {
      notifProv = context.read<NotificationProvider>();
    } catch (_) {}
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
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
                    'Report a Problem',
                    style: AppTextStyles.dialogTitle(fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Describe your issue or technical concern directly to the Owner (e.g. equipment malfunction, supply discrepancy, POS bug):',
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
                      hintText: 'Type your problem or issue here...',
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
                            final bName = session.currentBranchName.endsWith('Branch')
                                ? session.currentBranchName
                                : '${session.currentBranchName} Branch';

                            if (notifProv != null) {
                              await notifProv.submitStaffConcern(
                                branchId: session.branchId,
                                branchName: bName,
                                message: text,
                                staffId: session.currentUser?.uid,
                                staffName: session.currentUser?.displayName ??
                                    session.currentUser?.email ??
                                    'Store Staff',
                              );
                            }
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
                          'Submit Report',
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

  void _showInfoModal(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warmCream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.darkCoffee, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.dialogTitle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: AppTextStyles.button(color: AppColors.darkCoffee, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BranchSessionProvider>();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          'Branch Device Profile',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.darkCoffee,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch Device Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle, width: 1),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warmCream,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderSubtle, width: 2),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/coffee_grind_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${session.currentBranchName} Branch Device',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.pageTitle(
                            fontSize: 22,
                            color: AppColors.darkCoffee,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.currentBranchEmail,
                          style: AppTextStyles.subtitle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.forestGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.forestGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, color: AppColors.forestGreen, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Authenticated Branch Device',
                                style: AppTextStyles.badge(
                                  fontSize: 12,
                                  color: AppColors.forestGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Branch Configured Daily Quota
                  Material(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle, width: 1),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warmCream,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.flag_rounded, color: AppColors.darkCoffee, size: 20),
                      ),
                      title: Text(
                        'Configured Daily Quota',
                        style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      subtitle: Text(
                        '₱${session.dailyQuota.toStringAsFixed(2)}',
                        style: AppTextStyles.statNumber(
                          fontSize: 16,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ),
                  ),
                ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // SECTION 1: APP INFORMATION
                  // ==========================================
                  Text(
                    'App Information',
                    style: AppTextStyles.sectionHeading(
                      fontSize: 16,
                      color: AppColors.darkCoffee,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Material(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle, width: 1),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                      children: [
                        // 1. App Version
                        ListTile(
                          leading: _buildMenuIcon(Icons.info_outline_rounded),
                          title: Text(
                            'App Version',
                            style: AppTextStyles.body(color: AppColors.darkCoffee, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'v$appVersion (Stable Release)',
                            style: AppTextStyles.caption(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warmCream,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Text(
                              'v$appVersion',
                              style: AppTextStyles.badge(color: AppColors.darkCoffee, fontSize: 11),
                            ),
                          ),
                          onTap: () {
                            _showInfoModal(
                              context,
                              title: 'App Version Information',
                              icon: Icons.info_outline_rounded,
                              children: [
                                _buildInfoItem('Application', 'Coffee Grind PH Staff App'),
                                _buildInfoItem('Version', '1.0.0'),
                                _buildInfoItem('Build Number', '1'),
                                _buildInfoItem('Environment', 'Production (Firebase Realtime & Cloud Firestore)'),
                                _buildInfoItem('Platform', 'Flutter / Multiplatform Staff Client'),
                                _buildInfoItem('Backend Project', 'coffee-grind-ph-dce9c'),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 1, color: AppColors.borderSubtle),

                        // 2. Terms and Conditions
                        ListTile(
                          leading: _buildMenuIcon(Icons.description_outlined),
                          title: Text(
                            'Terms and Conditions',
                            style: AppTextStyles.body(color: AppColors.darkCoffee, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Staff POS terminal and operating policies',
                            style: AppTextStyles.caption(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onTap: () {
                            _showInfoModal(
                              context,
                              title: 'Terms & Conditions',
                              icon: Icons.description_outlined,
                              children: [
                                Text(
                                  'Coffee Grind PH Staff POS Terminal Operating Guidelines',
                                  style: AppTextStyles.cardTitle(fontSize: 14, color: AppColors.darkCoffee),
                                ),
                                const SizedBox(height: 10),
                                _buildPolicyParagraph('1. Terminal Usage: This application is intended solely for authorized Coffee Grind PH staff to process sales transactions, manage recipe-based inventory deductions, and coordinate restocking requests.'),
                                _buildPolicyParagraph('2. Cashier Accountability: Each cashier is responsible for all sales recorded under their branch terminal session, ensuring all cash payments and GCash reference numbers match customer receipts.'),
                                _buildPolicyParagraph('3. Inventory Integrity: Physical stock discrepancies must be promptly reported to the Owner via Restock Requests or Problem Reports to prevent checkout interruption.'),
                                _buildPolicyParagraph('4. Operating Hours: Terminals must complete daily sales synchronization and report drawer reconciliation at the close of every shift.'),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 1, color: AppColors.borderSubtle),

                        // 3. Privacy Policy
                        ListTile(
                          leading: _buildMenuIcon(Icons.privacy_tip_outlined),
                          title: Text(
                            'Privacy Policy',
                            style: AppTextStyles.body(color: AppColors.darkCoffee, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Store transaction logging & customer data security',
                            style: AppTextStyles.caption(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onTap: () {
                            _showInfoModal(
                              context,
                              title: 'Privacy Policy',
                              icon: Icons.privacy_tip_outlined,
                              children: [
                                Text(
                                  'Data Protection & Security Statement',
                                  style: AppTextStyles.cardTitle(fontSize: 14, color: AppColors.darkCoffee),
                                ),
                                const SizedBox(height: 10),
                                _buildPolicyParagraph('1. Transaction Data: Transaction records (item quantities, timestamps, totals, and payment methods) are securely saved to Firebase Realtime Database for branch accounting.'),
                                _buildPolicyParagraph('2. Customer Privacy: Coffee Grind PH Staff App does NOT collect, store, or transmit customer bank credentials or sensitive payment details. GCash transactions only record cashier-verified reference numbers.'),
                                _buildPolicyParagraph('3. Device Isolation: Security rules enforce strict branch boundary checks ensuring this terminal can only access its own branch payment settings and stock quotas.'),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 1, color: AppColors.borderSubtle),

                        // 4. Help and Support
                        ListTile(
                          leading: _buildMenuIcon(Icons.support_agent_rounded),
                          title: Text(
                            'Help and Support',
                            style: AppTextStyles.body(color: AppColors.darkCoffee, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Operating procedures, supervisor escalation & troubleshooting',
                            style: AppTextStyles.caption(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onTap: () {
                            _showInfoModal(
                              context,
                              title: 'Help and Support',
                              icon: Icons.support_agent_rounded,
                              children: [
                                Text(
                                  'Staff POS Assistance & Escalation Channels',
                                  style: AppTextStyles.cardTitle(fontSize: 14, color: AppColors.darkCoffee),
                                ),
                                const SizedBox(height: 10),
                                _buildInfoItem('On-Duty Shift Supervisor', 'Contact your branch supervisor for register balance or offline cash drawer assistance.'),
                                _buildInfoItem('Owner Web Administration', 'Product catalog changes, daily quotas, and master ingredient supplies are administered via the Owner Web portal.'),
                                _buildInfoItem('Direct Concern Channel', 'Use "Report a Problem" below to send real-time alerts directly to the management dashboard.'),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 1, color: AppColors.borderSubtle),

                        // 5. Report a Problem
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.report_problem_rounded, color: AppColors.amber, size: 20),
                          ),
                          title: Text(
                            'Report a Problem',
                            style: AppTextStyles.body(color: AppColors.darkCoffee, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Submit operational or technical concerns to Owner Web',
                            style: AppTextStyles.caption(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onTap: () => _showReportProblemDialog(context),
                        ),
                        const Divider(height: 1, color: AppColors.borderSubtle),

                        // 6. About Coffee Grind PH
                        ListTile(
                          leading: _buildMenuIcon(Icons.coffee_rounded),
                          title: Text(
                            'About Coffee Grind PH',
                            style: AppTextStyles.body(color: AppColors.darkCoffee, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Brand identity, craft coffee vision & system overview',
                            style: AppTextStyles.caption(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onTap: () {
                            _showInfoModal(
                              context,
                              title: 'About Coffee Grind PH',
                              icon: Icons.coffee_rounded,
                              children: [
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.warmCream,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                                    ),
                                    child: Image.asset(
                                      'assets/images/coffee_grind_logo.png',
                                      height: 72,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'Artisanal Coffee & Handcrafted Beverages',
                                    style: AppTextStyles.caption(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildPolicyParagraph(
                                  'Coffee Grind PH delivers handcrafted espresso beverages, iced refresheners, and cafe specialties across university and urban locations. This Staff POS App is specifically crafted for high-speed counter ordering, real-time recipe-based physical inventory tracking, and synchronized branch daily sales.',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                  const SizedBox(height: 24),

                  // Sign Out Action
                  Material(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle, width: 1),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.mutedRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, color: AppColors.mutedRed, size: 20),
                      ),
                      title: Text(
                        'Sign Out Branch Device',
                        style: AppTextStyles.body(
                          color: AppColors.mutedRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'End terminal session on this branch device',
                        style: AppTextStyles.caption(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.mutedRed,
                      ),
                      onTap: () => _confirmLogout(context, session),
                    ),
                  ),
                ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildMenuIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.warmCream,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.darkCoffee, size: 20),
    );
  }

  static Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodySmall(
              color: AppColors.darkCoffee,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPolicyParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: AppTextStyles.bodySmall(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }
}
