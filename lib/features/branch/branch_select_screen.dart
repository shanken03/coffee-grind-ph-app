import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/branch_session_provider.dart';
import '../auth/branch_login_screen.dart';

class BranchSelectScreen extends StatelessWidget {
  const BranchSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BranchSessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Account Status'),
        centerTitle: true,
      ),
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.latteBeige),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 48, color: AppColors.darkCoffee),
                    const SizedBox(height: 12),
                    Text(
                      session.currentBranchName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkCoffee),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Branch ID: ${session.branchId}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkCoffee,
                  foregroundColor: AppColors.surfaceWhite,
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const BranchLoginScreen()),
                  );
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Switch Branch Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
