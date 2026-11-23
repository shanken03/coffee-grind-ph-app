import 'cart_item_model.dart';
import 'product_model.dart';
import 'transaction_model.dart';

/// Represents a POS order captured while offline, persisted locally until
/// internet connectivity returns and it is synced to Firebase.
class PendingOfflineOrder {
  final String clientSaleId;
  final String branchId;
  final String branchName;
  final List<CartItemModel> items;
  final double totalAmount;
  final String paymentMethod;
  final String? gcashReference;
  final String cashierId;
  final String cashierName;
  final int createdAtMillis;
  final String? syncError;

  const PendingOfflineOrder({
    required this.clientSaleId,
    required this.branchId,
    required this.branchName,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.gcashReference,
    required this.cashierId,
    required this.cashierName,
    required this.createdAtMillis,
    this.syncError,
  });

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMillis);

  PendingOfflineOrder copyWith({String? syncError}) {
    return PendingOfflineOrder(
      clientSaleId: clientSaleId,
      branchId: branchId,
      branchName: branchName,
      items: items,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      gcashReference: gcashReference,
      cashierId: cashierId,
      cashierName: cashierName,
      createdAtMillis: createdAtMillis,
      syncError: syncError,
    );
  }

  TransactionModel toTransactionModel() {
    return TransactionModel(
      transactionId: clientSaleId,
      timestamp: createdAt,
      branchName: branchName,
      items: items,
      totalAmount: totalAmount,
      status: 'Pending Sync',
      paymentMethod: paymentMethod,
      gcashReference: gcashReference,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientSaleId': clientSaleId,
      'branchId': branchId,
      'branchName': branchName,
      'items': items
          .map(
            (i) => {
              'id': i.id,
              'productId': i.product.productId,
              'productName': i.product.name,
              'category': i.product.category.label,
              'recipeId': i.product.recipeId,
              'fixedTemperature': i.product.fixedTemperature,
              'selectedTemperature': i.selectedTemperature,
              'selectedSize': i.selectedSize,
              'unitPrice': i.unitPrice,
              'quantity': i.quantity,
            },
          )
          .toList(),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'gcashReference': gcashReference,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'createdAtMillis': createdAtMillis,
      if (syncError != null) 'syncError': syncError,
    };
  }

  factory PendingOfflineOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List? ?? []);
    final parsedItems = rawItems.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final unitPrice = (m['unitPrice'] as num?)?.toDouble() ?? 0.0;
      return CartItemModel(
        id: m['id'] as String? ?? '',
        product: ProductModel(
          productId: m['productId'] as String? ?? '',
          name: m['productName'] as String? ?? '',
          category: ProductCategoryX.fromString(m['category'] as String? ?? ''),
          description: '',
          imageUrl: '',
          isActive: true,
          availableBranches: const [],
          pricing: ProductPricing(flatPrice: unitPrice),
          recipeId: m['recipeId'] as String?,
        ),
        selectedTemperature: m['selectedTemperature'] as String?,
        selectedSize: m['selectedSize'] as String?,
        unitPrice: unitPrice,
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    return PendingOfflineOrder(
      clientSaleId: json['clientSaleId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      branchName: json['branchName'] as String? ?? '',
      items: parsedItems,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
      gcashReference: json['gcashReference'] as String?,
      cashierId: json['cashierId'] as String? ?? 'STAFF_DEVICE',
      cashierName: json['cashierName'] as String? ?? 'Store Staff',
      createdAtMillis:
          (json['createdAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      syncError: json['syncError'] as String?,
    );
  }
}
