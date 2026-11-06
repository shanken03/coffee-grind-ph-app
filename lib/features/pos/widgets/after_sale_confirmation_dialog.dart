import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/transaction_model.dart';

class AfterSaleConfirmationDialog extends StatefulWidget {
  final TransactionModel transaction;
  final VoidCallback onNewSale;
  final VoidCallback onBackToDashboard;

  const AfterSaleConfirmationDialog({
    super.key,
    required this.transaction,
    required this.onNewSale,
    required this.onBackToDashboard,
  });

  @override
  State<AfterSaleConfirmationDialog> createState() => _AfterSaleConfirmationDialogState();
}

class _AfterSaleConfirmationDialogState extends State<AfterSaleConfirmationDialog> {
  bool _showItems = false;

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final breakdown = tx.salesBreakdown;

    final cogsDisplay = breakdown.hasCogs
        ? '₱${breakdown.cogs!.toStringAsFixed(2)}'
        : 'Not Available';
    final grossProfitDisplay = breakdown.hasGrossProfit
        ? '₱${breakdown.grossProfit!.toStringAsFixed(2)}'
        : 'Not Available';
    final otherExpensesDisplay = breakdown.hasOtherExpenses
        ? '₱${breakdown.otherExpenses!.toStringAsFixed(2)}'
        : '₱0.00';
    final netProfitDisplay = breakdown.hasNetProfit
        ? '₱${breakdown.netProfit!.toStringAsFixed(2)}'
        : 'Not Available';

    final formattedDate = DateFormat('MMM d, yyyy h:mm a').format(tx.timestamp);
    final refId = tx.transactionId.length > 12 ? tx.transactionId.substring(0, 12) : tx.transactionId;

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.latteBeige, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Header Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.forestGreen,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Sale Completed Successfully',
                textAlign: TextAlign.center,
                style: AppTextStyles.pageTitle(
                  fontSize: 20,
                  color: AppColors.darkCoffee,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recorded to Firebase Real-time Database',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 18),

              // Transaction Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warmCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.latteBeige),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Branch', tx.branchName),
                    const SizedBox(height: 6),
                    _buildInfoRow('Ref / Sale ID', refId),
                    const SizedBox(height: 6),
                    _buildInfoRow('Date & Time', formattedDate),
                    const SizedBox(height: 6),
                    _buildInfoRow('Payment Method', tx.paymentMethod),
                    if (tx.gcashReference != null && tx.gcashReference!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow('GCash Ref', tx.gcashReference!),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),
              Text(
                'Sales & Profit Breakdown',
                style: AppTextStyles.sectionHeading(
                  fontSize: 15,
                  color: AppColors.darkCoffee,
                ),
              ),
              const SizedBox(height: 10),

              // Breakdown Table Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.latteBeige),
                ),
                child: Column(
                  children: [
                    _buildBreakdownRow('Total Sales', '₱${tx.totalAmount.toStringAsFixed(2)}', isBold: true),
                    const Divider(height: 16, color: AppColors.latteBeige),
                    _buildBreakdownRow('Cost of Goods Sold (COGS)', cogsDisplay, isSubtle: cogsDisplay == 'Not Available'),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Gross Profit', grossProfitDisplay, isSubtle: grossProfitDisplay == 'Not Available', isProfit: grossProfitDisplay != 'Not Available'),
                    const SizedBox(height: 8),
                    _buildBreakdownRow('Other Expenses', otherExpensesDisplay),
                    const Divider(height: 16, color: AppColors.latteBeige),
                    _buildBreakdownRow('Net Profit', netProfitDisplay, isBold: true, isProfit: netProfitDisplay != 'Not Available'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // View Transaction Details Toggle / Expandable Section
              TextButton.icon(
                onPressed: () {
                  setState(() => _showItems = !_showItems);
                },
                icon: Icon(
                  _showItems ? Icons.keyboard_arrow_up_rounded : Icons.receipt_long_rounded,
                  color: AppColors.darkCoffee,
                  size: 18,
                ),
                label: Text(
                  _showItems ? 'Hide Items Summary' : 'View Transaction Details',
                  style: AppTextStyles.button(
                    color: AppColors.darkCoffee,
                    fontSize: 13,
                  ),
                ),
              ),

              if (_showItems) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warmCream.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.latteBeige),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ordered Items:',
                        style: AppTextStyles.cardTitle(
                          fontSize: 13,
                          color: AppColors.darkCoffee,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...tx.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.product.name} (${item.variantLabel})',
                                    style: AppTextStyles.bodySmall(color: AppColors.darkCoffee, fontSize: 12),
                                  ),
                                ),
                                Text(
                                  '₱${item.subtotal.toStringAsFixed(2)}',
                                  style: AppTextStyles.tableCell(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkCoffee,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.darkCoffee),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.onBackToDashboard,
                      child: Text(
                        'Dashboard',
                        style: AppTextStyles.button(
                          color: AppColors.darkCoffee,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkCoffee,
                        foregroundColor: AppColors.surfaceWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.onNewSale,
                      child: Text(
                        'New Sale',
                        style: AppTextStyles.button(color: AppColors.surfaceWhite),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppTextStyles.tableCell(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.darkCoffee,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    bool isBold = false,
    bool isSubtle = false,
    bool isProfit = false,
  }) {
    Color valueColor = AppColors.darkCoffee;
    if (isSubtle) {
      valueColor = AppColors.textSecondary;
    } else if (isProfit) {
      valueColor = AppColors.forestGreen;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.tableCell(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? AppColors.darkCoffee : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.statNumber(
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
