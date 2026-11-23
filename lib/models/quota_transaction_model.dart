import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an immutable audit log record in `quota_transactions/{saleId}_{productId}`
/// documenting every manual product servings deduction or offline overdraft.
class QuotaTransactionModel {
  final String transactionId;
  final String saleId;
  final String clientSaleId;
  final String branchId;
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int deductedQuantity;
  final int overdraftQuantity;
  final int previousRemaining;
  final int newRemaining;
  final bool isOfflineSync;
  final String? cashierId;
  final String? cashierName;
  final DateTime? timestamp;
  final DateTime? createdAt;

  const QuotaTransactionModel({
    required this.transactionId,
    required this.saleId,
    required this.clientSaleId,
    required this.branchId,
    required this.productId,
    this.productName = '',
    required this.requestedQuantity,
    required this.deductedQuantity,
    this.overdraftQuantity = 0,
    required this.previousRemaining,
    required this.newRemaining,
    this.isOfflineSync = false,
    this.cashierId,
    this.cashierName,
    this.timestamp,
    this.createdAt,
  });

  /// Deterministic document ID format: `{saleId}_{productId}`
  static String buildTransactionId(String saleId, String productId) {
    return '${saleId.trim()}_${productId.trim()}';
  }

  Map<String, dynamic> toMap({bool useServerTimestamp = true}) {
    return {
      'transactionId': transactionId,
      'saleId': saleId,
      'clientSaleId': clientSaleId,
      'branchId': branchId,
      'productId': productId,
      if (productName.isNotEmpty) 'productName': productName,
      'requestedQuantity': requestedQuantity,
      'deductedQuantity': deductedQuantity,
      'overdraftQuantity': overdraftQuantity,
      'previousRemaining': previousRemaining,
      'newRemaining': newRemaining,
      'isOfflineSync': isOfflineSync,
      if (cashierId != null && cashierId!.isNotEmpty) 'cashierId': cashierId,
      if (cashierName != null && cashierName!.isNotEmpty) 'cashierName': cashierName,
      'timestamp': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : (timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp()),
      'createdAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : (createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp()),
    };
  }

  factory QuotaTransactionModel.fromMap(String docId, Map<String, dynamic> data) {
    DateTime? parseTs(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return QuotaTransactionModel(
      transactionId: data['transactionId'] as String? ?? docId,
      saleId: data['saleId'] as String? ?? '',
      clientSaleId: data['clientSaleId'] as String? ?? '',
      branchId: data['branchId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      requestedQuantity: (data['requestedQuantity'] as num?)?.toInt() ?? 0,
      deductedQuantity: (data['deductedQuantity'] as num?)?.toInt() ?? 0,
      overdraftQuantity: (data['overdraftQuantity'] as num?)?.toInt() ?? 0,
      previousRemaining: (data['previousRemaining'] as num?)?.toInt() ?? 0,
      newRemaining: (data['newRemaining'] as num?)?.toInt() ?? 0,
      isOfflineSync: data['isOfflineSync'] as bool? ?? false,
      cashierId: data['cashierId'] as String?,
      cashierName: data['cashierName'] as String?,
      timestamp: parseTs(data['timestamp']),
      createdAt: parseTs(data['createdAt']),
    );
  }
}
