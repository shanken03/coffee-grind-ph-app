import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkCoffee,
        foregroundColor: AppColors.surfaceWhite,
        elevation: 0,
        title: Text(
          'Privacy Policy',
          style: AppTextStyles.pageTitle(
            color: AppColors.surfaceWhite,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.darkCoffee, AppColors.espressoDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.latteBeige.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Official Staff Point of Sale',
                      style: AppTextStyles.subtitle(
                        color: AppColors.latteBeige,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Coffee Grind PH — Privacy Policy',
                    style: AppTextStyles.displayTitle(
                      color: AppColors.surfaceWhite,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Package: ph.coffeegrind.officialpos • Version 1.0.1',
                    style: AppTextStyles.subtitle(
                      color: AppColors.latteBeige.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last Updated: November 2026',
                    style: AppTextStyles.subtitle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionCard(
              title: '1. Purpose of the Application',
              icon: Icons.storefront_rounded,
              content:
                  'Coffee Grind PH Mobile POS is a dedicated internal commercial Point of Sale and inventory tracking application designed specifically for authorized cafe staff, cashiers, and supervisors operating across Coffee Grind PH branches (including Santa Cruz, LSPU, and expanding branches).',
            ),

            _buildSectionCard(
              title: '2. Data We Collect',
              icon: Icons.security_rounded,
              content:
                  'To operate cafe checkout, authenticate branch terminals, and maintain accurate inventory balances, the app collects and processes:\n\n'
                  '• Branch Account Credentials: Authorized branch email addresses, user IDs, and login session tokens.\n\n'
                  '• Transaction Records: Items sold, recipe variations (Hot/Iced), quantities, total sales amounts, cash tender, exact change, and optional GCash electronic reference numbers for receipt verification.\n\n'
                  '• Inventory & Servings Quotas: Real-time ingredient usage, daily drink quota counters, and restock replenishment requests.\n\n'
                  '• Offline Queue Records: Pending sales orders stored encrypted locally on the device until internet connectivity synchronizes with Cloud Firestore.',
            ),

            _buildSectionCard(
              title: '3. How Data is Used',
              icon: Icons.checklist_rounded,
              content:
                  'Information processed by this application is strictly used for:\n\n'
                  '• Customer order checkout and instant receipt computation.\n'
                  '• Real-time stock deductions and serving quota ledger updates.\n'
                  '• Branch restocking request coordination with management.\n'
                  '• Broadcasting branch announcements and operational alerts.\n\n'
                  'We NEVER sell, rent, or trade any transaction, staff, or customer data to third-party advertisers or data brokers.',
            ),

            _buildSectionCard(
              title: '4. Data Security & Encryption',
              icon: Icons.lock_outline_rounded,
              content:
                  'All data transmitted between this mobile application and Google Cloud Firebase infrastructure is protected using industry-standard TLS/HTTPS encryption.\n\n'
                  'Cloud Firestore Security Rules strictly enforce multi-owner authorization, branch session boundaries, and prevent unauthorized cross-branch data access.',
            ),

            _buildSectionCard(
              title: '5. Permissions & Device Access',
              icon: Icons.perm_device_information_rounded,
              content:
                  '• Internet Access: Communicates securely with Cloud Firestore backend.\n\n'
                  '• Network State Monitoring: Detects offline/online transitions to queue sales locally without interrupting customer service.',
            ),

            _buildSectionCard(
              title: '6. Data Deletion & Contact Inquiries',
              icon: Icons.mail_outline_rounded,
              content:
                  'Commercial transaction records are archived for internal store accounting, inventory audits, and tax compliance.\n\n'
                  'For privacy inquiries or account data deletion requests, contact store administration at:\n'
                  'Email: malabananshanken03@gmail.com\n'
                  'Website: https://coffeegrindph.web.app',
            ),

            const SizedBox(height: 16),

            // Live Web Policy Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.latteBeige.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.latteBeige,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.public_rounded,
                    color: AppColors.darkCoffee,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Public Web Policy Hosted At:',
                          style: AppTextStyles.body(
                            color: AppColors.darkCoffee,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'https://coffeegrindph.web.app/privacy-policy.html',
                          style: AppTextStyles.subtitle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.espressoDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.espressoDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.cardTitle(
                    fontSize: 15,
                    color: AppColors.darkCoffee,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
