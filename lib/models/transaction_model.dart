import 'cart_item_model.dart';

class SalesBreakdown {
  final double totalSales;
  final double? cogs; // Cost of Goods Sold
  final double? grossProfit; // totalSales - cogs
  final double? otherExpenses; // Applicable recorded expenses
  final double? netProfit; // grossProfit - otherExpenses

  const SalesBreakdown({
    required this.totalSales,
    this.cogs,
    this.grossProfit,
    this.otherExpenses,
    this.netProfit,
  });

  bool get hasCogs => cogs != null;
  bool get hasGrossProfit => grossProfit != null;
  bool get hasOtherExpenses => otherExpenses != null;
  bool get hasNetProfit => netProfit != null;
}

class TransactionModel {
  final String transactionId;
  final DateTime timestamp;
  final String branchName;
  final List<CartItemModel> items;
  final double totalAmount;
  final String status; // 'Completed'
  final String paymentMethod; // 'Cash' | 'GCash'
  final String? gcashReference;
  final double? cogs;
  final double? grossProfit;
  final double? otherExpenses;
  final double? netProfit;

  const TransactionModel({
    required this.transactionId,
    required this.timestamp,
    required this.branchName,
    required this.items,
    required this.totalAmount,
    this.status = 'Completed',
    this.paymentMethod = 'Cash',
    this.gcashReference,
    this.cogs,
    this.grossProfit,
    this.otherExpenses,
    this.netProfit,
  });

  int get totalItemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  String get itemsSummary => items.map((i) => '${i.quantity}x ${i.product.name} (${i.variantLabel})').join(', ');

  SalesBreakdown get salesBreakdown => SalesBreakdown(
        totalSales: totalAmount,
        cogs: cogs,
        grossProfit: grossProfit ?? (cogs != null ? totalAmount - cogs! : null),
        otherExpenses: otherExpenses,
        netProfit: netProfit ??
            (cogs != null
                ? (totalAmount - cogs! - (otherExpenses ?? 0.0))
                : null),
      );
}
