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
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          'Sales & Transactions',
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
        child: Column(
          children: [
            // Top Filter & Search Bar
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: AppTextStyles.inputField(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search transaction ID or item...',
                      hintStyle: AppTextStyles.inputHint(fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.darkCoffee, size: 20),
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
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    f,
                                    style: AppTextStyles.badge(
                                      color: isSelected ? AppColors.surfaceWhite : AppColors.darkCoffee,
                                      fontSize: 12,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.darkCoffee,
                                  backgroundColor: AppColors.warmCream,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.darkCoffee : AppColors.borderSubtle,
                                  ),
                                  showCheckmark: false,
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

            // Transactions List
            Expanded(
              child: filtered.isEmpty
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
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
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
                        final isGCash = tx.paymentMethod.toLowerCase().contains('gcash');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSubtle, width: 1),
                            boxShadow: AppColors.cardShadow,
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
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.warmCream,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.receipt_rounded,
                                              color: AppColors.darkCoffee,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tx.transactionId,
                                                style: AppTextStyles.cardTitle(
                                                  fontSize: 15,
                                                  color: AppColors.darkCoffee,
                                                ),
                                              ),
                                              Text(
                                                timeStr,
                                                style: AppTextStyles.caption(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isGCash
                                                  ? Colors.blue.withValues(alpha: 0.12)
                                                  : AppColors.forestGreen.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              tx.paymentMethod,
                                              style: AppTextStyles.badge(
                                                fontSize: 10,
                                                color: isGCash ? Colors.blue.shade800 : AppColors.forestGreen,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
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
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    tx.itemsSummary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.only(top: 10),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: AppColors.borderSubtle, width: 1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${tx.items.length} ${tx.items.length == 1 ? 'item' : 'items'}',
                                          style: AppTextStyles.caption(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          '₱${tx.totalAmount.toStringAsFixed(2)}',
                                          style: AppTextStyles.statNumber(
                                            fontSize: 17,
                                            color: AppColors.darkCoffee,
                                          ),
                                        ),
                                      ],
                                    ),
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
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tx.transactionId,
                  style: AppTextStyles.dialogTitle(fontSize: 17, color: AppColors.darkCoffee),
                  overflow: TextOverflow.ellipsis,
                ),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warmCream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      _buildReceiptRow('Date', timeStr),
                      const SizedBox(height: 6),
                      _buildReceiptRow('Branch', tx.branchName),
                      const SizedBox(height: 6),
                      _buildReceiptRow('Payment', tx.paymentMethod),
                      if (tx.gcashReference != null && tx.gcashReference!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildReceiptRow('GCash Ref', tx.gcashReference!),
                      ],
                    ],
                  ),
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
                const Divider(height: 24, color: AppColors.borderSubtle),
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('Close', style: AppTextStyles.button(color: AppColors.darkCoffee, fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.tableCell(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.darkCoffee,
            ),
          ),
        ),
      ],
    );
  }
}
