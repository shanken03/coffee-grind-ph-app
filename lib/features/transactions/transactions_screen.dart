import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/transactions_provider.dart';
import '../../models/transaction_model.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _searchQuery = '';
  String _dateFilter = 'All';

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> all) {
    final now = DateTime.now();

    return all.where((t) {
      final matchesSearch = _searchQuery.isEmpty ||
          t.transactionId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.itemsSummary.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesDate = true;
      if (_dateFilter == 'Today') {
        matchesDate = t.timestamp.year == now.year &&
            t.timestamp.month == now.month &&
            t.timestamp.day == now.day;
      } else if (_dateFilter == 'This Week') {
        matchesDate = now.difference(t.timestamp).inDays <= 7;
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionsProvider>();
    final filtered = _getFilteredTransactions(txProvider.transactions);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales & Transactions',
          style: AppTextStyles.pageTitle(
            color: AppColors.darkCoffee,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Filter & Search Bar
            Container(
              color: AppColors.surfaceWhite,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: AppTextStyles.inputField(),
                    decoration: InputDecoration(
                      hintText: 'Search transaction ID or item...',
                      hintStyle: AppTextStyles.inputHint(),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.darkCoffee),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Filter Date: ',
                        style: AppTextStyles.caption(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Today', 'This Week'].map((f) {
                              final isSelected = _dateFilter == f;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text(
                                    f,
                                    style: AppTextStyles.badge(
                                      color: isSelected ? AppColors.surfaceWhite : AppColors.textSecondary,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.forestGreen,
                                  backgroundColor: AppColors.surfaceWhite,
                                  side: BorderSide(color: isSelected ? AppColors.forestGreen : AppColors.latteBeige),
                                  onSelected: (selected) {
                                    if (selected) setState(() => _dateFilter = f);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.latteBeige),

            // Transactions List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions found.',
                            style: AppTextStyles.cardTitle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        final timeStr = DateFormat('MMM d, yyyy • h:mm a').format(tx.timestamp);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.latteBeige, width: 1),
                          ),
                          child: InkWell(
                            onTap: () => _showTransactionDetails(tx),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.receipt_rounded,
                                            color: AppColors.darkCoffee,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            tx.transactionId,
                                            style: AppTextStyles.cardTitle(
                                              fontSize: 15,
                                              color: AppColors.darkCoffee,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.forestGreen.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tx.status,
                                          style: AppTextStyles.badge(
                                            fontSize: 11,
                                            color: AppColors.forestGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    tx.itemsSummary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Divider(height: 20, color: AppColors.latteBeige),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: AppTextStyles.caption(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '₱${tx.totalAmount.toStringAsFixed(2)}',
                                        style: AppTextStyles.statNumber(
                                          fontSize: 16,
                                          color: AppColors.darkCoffee,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(TransactionModel tx) {
    final timeStr = DateFormat('MMMM d, yyyy • h:mm a').format(tx.timestamp);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.latteBeige),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tx.transactionId,
                style: AppTextStyles.dialogTitle(fontSize: 18, color: AppColors.darkCoffee),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tx.status,
                  style: AppTextStyles.badge(
                    fontSize: 11,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Date: $timeStr',
                  style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  'Branch: ${tx.branchName}',
                  style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  'Payment: ${tx.paymentMethod}',
                  style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (tx.gcashReference != null && tx.gcashReference!.isNotEmpty)
                  Text(
                    'GCash Ref: ${tx.gcashReference}',
                    style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Items Purchased:',
                  style: AppTextStyles.cardTitle(fontSize: 14, color: AppColors.darkCoffee),
                ),
                const SizedBox(height: 8),
                ...tx.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.product.name} (${item.variantLabel})',
                            style: AppTextStyles.bodySmall(fontSize: 13, color: AppColors.darkCoffee),
                          ),
                        ),
                        Text(
                          '₱${item.subtotal.toStringAsFixed(2)}',
                          style: AppTextStyles.tableCell(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkCoffee),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24, color: AppColors.latteBeige),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Paid:',
                      style: AppTextStyles.cardTitle(fontSize: 16, color: AppColors.darkCoffee),
                    ),
                    Text(
                      '₱${tx.totalAmount.toStringAsFixed(2)}',
                      style: AppTextStyles.statNumber(
                        fontSize: 18,
                        color: AppColors.darkCoffee,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: AppTextStyles.button(color: AppColors.darkCoffee, fontSize: 13)),
            ),
          ],
        );
      },
    );
  }
}
