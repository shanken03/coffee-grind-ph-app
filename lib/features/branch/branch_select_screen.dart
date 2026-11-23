import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/branch_session_provider.dart';
import '../auth/branch_login_screen.dart';

class BranchSelectScreen extends StatelessWidget {
  const BranchSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BranchSessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Branch Account Status',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.darkCoffee,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: AppColors.softShadow,
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
                        const SizedBox(height: 18),
                        Text(
                          session.currentBranchName,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.pageTitle(
                            fontSize: 22,
                            color: AppColors.darkCoffee,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warmCream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            'Branch ID: ${session.branchId}',
                            style: AppTextStyles.caption(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkCoffee,
                        foregroundColor: AppColors.surfaceWhite,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const BranchLoginScreen()),
                        );
                      },
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: Text(
                        'Switch Branch Account',
                        style: AppTextStyles.button(color: AppColors.surfaceWhite),
                      ),
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
}
