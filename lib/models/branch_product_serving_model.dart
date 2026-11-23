import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a branch-specific, product-specific manual serving quota
/// managed by Web Admin in Firestore: `branch_product_servings/{branchId}_{productId}`.
class BranchProductServingModel {
  final String branchId;
  final String productId;
  final int manualMaxServings;
  final int remainingServings;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BranchProductServingModel({
    required this.branchId,
    required this.productId,
    required this.manualMaxServings,
    required this.remainingServings,
    this.isEnabled = true,
    this.createdAt,
    this.updatedAt,
  }) {
    if (manualMaxServings < 0) {
      throw FormatException(
        'Invalid manualMaxServings: cannot be negative ($manualMaxServings)',
      );
    }
    if (remainingServings < 0) {
      throw FormatException(
        'Invalid remainingServings: cannot be negative ($remainingServings)',
      );
    }
  }

  /// Deterministic document ID format matching Web Admin: `{branchId}_{productId}`
  static String buildDocumentId(String branchId, String productId) {
    final bId = branchId.trim();
    final pId = productId.trim();
    if (bId.isEmpty) {
      throw ArgumentError('branchId cannot be empty when building document ID');
    }
    if (pId.isEmpty) {
      throw ArgumentError('productId cannot be empty when building document ID');
    }
    return '${bId}_$pId';
  }

  /// The document ID for this quota record
  String get documentId => buildDocumentId(branchId, productId);

  /// Whether manual quota is enabled AND has depleted (0 remaining).
  ///
  /// IMPORTANT: A disabled quota ([isEnabled] == false) is NOT considered out of stock.
  /// Missing or disabled quotas must allow physical recipe inventory fallback.
  bool get isOutOfStock => isEnabled && remainingServings <= 0;

  /// Explicit alias for manual quota depletion.
  bool get isDepleted => isEnabled && remainingServings <= 0;

  /// Whether manual quota permits sales:
  /// - When [isEnabled] is false, manual quota is bypassed (returns true, allowing physical inventory fallback).
  /// - When [isEnabled] is true, returns true only if [remainingServings] > 0.
  bool get isAvailable => !isEnabled || remainingServings > 0;

  /// Computes effective sellable servings by combining manual quota
  /// with the physical inventory capacity calculated from recipes:
  /// - If [isEnabled] is false, manual quota is bypassed and [physicalCapacity] is returned.
  /// - If [isEnabled] is true, the lower of [remainingServings] and [physicalCapacity] is returned.
  int computeEffectiveServings(int physicalCapacity) {
    if (!isEnabled) {
      return physicalCapacity;
    }
    return remainingServings < physicalCapacity ? remainingServings : physicalCapacity;
  }

  /// Safe parser for Firestore timestamps (Timestamp, ISO8601 String, or millis int)
  static DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val.trim());
    return null;
  }

  /// Parses Firestore document data into [BranchProductServingModel].
  ///
  /// Enforces strict validation:
  /// - `branchId` and `productId` must be non-empty and consistent.
  /// - `manualMaxServings` must be non-negative (rejects negative numbers with FormatException).
  /// - `remainingServings` must be non-negative (rejects negative numbers with FormatException).
  /// - Preserves valid zero values.
  /// - Matches Web Admin schema strictly (`branchId`, `productId`, `manualMaxServings`, `remainingServings`, `isEnabled`).
  /// - Supports `lastUpdated` as fallback for `updatedAt`.
  factory BranchProductServingModel.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    String bId = (data['branchId'] as String? ?? '').trim();
    String pId = (data['productId'] as String? ?? '').trim();

    // If missing from map, extract strictly from docId: {branchId}_{productId}
    if (bId.isEmpty || pId.isEmpty) {
      int separatorIndex = -1;
      if (docId.startsWith('br_')) {
        separatorIndex = docId.indexOf('_', 3);
      } else {
        separatorIndex = docId.indexOf('_');
      }

      if (separatorIndex > 0 && separatorIndex < docId.length - 1) {
        if (bId.isEmpty) {
          bId = docId.substring(0, separatorIndex).trim();
        }
        if (pId.isEmpty) {
          pId = docId.substring(separatorIndex + 1).trim();
        }
      }
    }

    if (bId.isEmpty) {
      throw const FormatException(
        'Invalid branch_product_servings document: missing branchId',
      );
    }
    if (pId.isEmpty) {
      throw const FormatException(
        'Invalid branch_product_servings document: missing productId',
      );
    }

    // Verify consistency if both docId and fields exist
    final expectedDocId = '${bId}_$pId';
    if (docId.isNotEmpty && docId.contains('_') && docId != expectedDocId) {
      throw FormatException(
        'Document ID "$docId" does not match internal fields "$expectedDocId"',
      );
    }

    // Strict numeric validation for manualMaxServings
    final rawMax = data['manualMaxServings'];
    if (rawMax == null || rawMax is! num) {
      throw const FormatException(
        'Invalid branch_product_servings document: missing or non-numeric manualMaxServings',
      );
    }
    final maxServings = rawMax.toInt();
    if (maxServings < 0) {
      throw FormatException(
        'Invalid branch_product_servings document: manualMaxServings cannot be negative ($maxServings)',
      );
    }

    // Strict numeric validation for remainingServings
    final rawRemaining = data['remainingServings'];
    if (rawRemaining == null || rawRemaining is! num) {
      throw const FormatException(
        'Invalid branch_product_servings document: missing or non-numeric remainingServings',
      );
    }
    final remaining = rawRemaining.toInt();
    if (remaining < 0) {
      throw FormatException(
        'Invalid branch_product_servings document: remainingServings cannot be negative ($remaining)',
      );
    }

    // Strict Web Admin schema: isEnabled is a boolean flag (defaults to true if null/absent)
    final rawEnabled = data['isEnabled'];
    final bool isEnabled = rawEnabled is bool ? rawEnabled : (rawEnabled != null ? rawEnabled == true : true);

    final createdAt = _parseTimestamp(data['createdAt']);
    final updatedAt = _parseTimestamp(data['updatedAt'] ?? data['lastUpdated']);

    return BranchProductServingModel(
      branchId: bId,
      productId: pId,
      manualMaxServings: maxServings,
      remainingServings: remaining,
      isEnabled: isEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Serializes model to Firestore map matching Web Admin schema
  Map<String, dynamic> toFirestore() {
    return {
      'branchId': branchId,
      'productId': productId,
      'manualMaxServings': manualMaxServings,
      'remainingServings': remainingServings,
      'isEnabled': isEnabled,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  BranchProductServingModel copyWith({
    String? branchId,
    String? productId,
    int? manualMaxServings,
    int? remainingServings,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BranchProductServingModel(
      branchId: branchId ?? this.branchId,
      productId: productId ?? this.productId,
      manualMaxServings: manualMaxServings ?? this.manualMaxServings,
      remainingServings: remainingServings ?? this.remainingServings,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchProductServingModel &&
          runtimeType == other.runtimeType &&
          branchId == other.branchId &&
          productId == other.productId &&
          manualMaxServings == other.manualMaxServings &&
          remainingServings == other.remainingServings &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode =>
      branchId.hashCode ^
      productId.hashCode ^
      manualMaxServings.hashCode ^
      remainingServings.hashCode ^
      isEnabled.hashCode;

  @override
  String toString() {
    return 'BranchProductServingModel(branchId: $branchId, productId: $productId, manualMaxServings: $manualMaxServings, remainingServings: $remainingServings, isEnabled: $isEnabled)';
  }
}
