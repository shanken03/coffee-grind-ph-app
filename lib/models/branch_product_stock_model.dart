import 'package:cloud_firestore/cloud_firestore.dart';

/// Deprecated: Persistent product quota replaced by recipe-based physical inventory.
@Deprecated('Replaced by recipe-based physical inventory')
class BranchProductStockModel {
  final String branchId;
  final String productId;
  final int maxServings;
  final int remainingServings;
  final DateTime? updatedAt;
  final DateTime? lastReplenishedAt;

  const BranchProductStockModel({
    required this.branchId,
    required this.productId,
    this.maxServings = 50,
    required this.remainingServings,
    this.updatedAt,
    this.lastReplenishedAt,
  });

  /// Factory constructor to parse Firestore document.
  factory BranchProductStockModel.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    // Document ID convention: ${branchId}_${productId}
    String bId = (data['branchId'] as String? ?? '').trim();
    String pId = (data['productId'] as String? ?? '').trim();

    if (bId.isEmpty || pId.isEmpty) {
      final parts = docId.split('_');
      if (parts.length >= 2) {
        if (bId.isEmpty) bId = parts.first;
        if (pId.isEmpty) pId = parts.sublist(1).join('_');
      }
    }

    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    final maxS = (data['maxServings'] as num?)?.toInt() ?? 50;
    final remS =
        (data['remainingServings'] as num?)?.toInt() ??
        (data['availableServings'] as num?)?.toInt() ??
        (data['servings'] as num?)?.toInt() ??
        0;

    return BranchProductStockModel(
      branchId: bId,
      productId: pId,
      maxServings: maxS,
      remainingServings: remS,
      updatedAt: parseTimestamp(data['updatedAt'] ?? data['lastUpdated']),
      lastReplenishedAt: parseTimestamp(data['lastReplenishedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'productId': productId,
      'maxServings': maxServings,
      'remainingServings': remainingServings,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (lastReplenishedAt != null)
        'lastReplenishedAt': Timestamp.fromDate(lastReplenishedAt!),
    };
  }
}
