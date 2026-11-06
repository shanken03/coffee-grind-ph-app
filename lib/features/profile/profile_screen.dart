import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/branch_session_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _confirmLogout(BuildContext context, BranchSessionProvider session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.latteBeige),
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
            child: Text('Cancel', style: AppTextStyles.button(color: AppColors.textSecondary, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mutedRed,
              foregroundColor: AppColors.surfaceWhite,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await session.signOut();
            },
            child: Text('Log Out', style: AppTextStyles.button(color: AppColors.surfaceWhite, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BranchSessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Branch Device Profile',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Branch Device Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.latteBeige, width: 1),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.darkCoffee.withValues(alpha: 0.1),
                      child: const CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.surfaceWhite,
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 44,
                          color: AppColors.darkCoffee,
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
                        border: Border.all(color: AppColors.forestGreen.withValues(alpha: 0.4)),
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Branch Account Info Details
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.latteBeige, width: 1),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.numbers_rounded, color: AppColors.darkCoffee),
                      title: Text(
                        'Branch ID',
                        style: AppTextStyles.caption(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      subtitle: Text(
                        session.branchId,
                        style: AppTextStyles.statNumber(
                          fontSize: 16,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.latteBeige),
                    ListTile(
                      leading: const Icon(Icons.flag_rounded, color: AppColors.darkCoffee),
                      title: Text(
                        'Configured Daily Quota',
                        style: AppTextStyles.caption(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      subtitle: Text(
                        '₱${session.dailyQuota.toStringAsFixed(2)}',
                        style: AppTextStyles.statNumber(
                          fontSize: 16,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.latteBeige),
                    ListTile(
                      leading: const Icon(Icons.cloud_done_rounded, color: AppColors.darkCoffee),
                      title: Text(
                        'Firebase Integration',
                        style: AppTextStyles.caption(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      subtitle: Text(
                        'Shared Owner Web Backend (coffee-grind-ph-dce9c)',
                        style: AppTextStyles.cardTitle(
                          fontSize: 13,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Branch Device Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mutedRed,
                    side: const BorderSide(color: AppColors.mutedRed, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    _confirmLogout(context, session);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(
                    'Sign Out Branch Device',
                    style: AppTextStyles.button(color: AppColors.mutedRed),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // App Version Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.latteBeige),
                ),
                child: Column(
                  children: [
                    Text(
                      'Coffee Grind PH Staff App',
                      style: AppTextStyles.cardTitle(
                        fontSize: 14,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0 (Branch Shared Firebase Integration)',
                      style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
