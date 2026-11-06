import 'package:cloud_firestore/cloud_firestore.dart';

class BranchPaymentSettingsModel {
  final String branchId;
  final String branchName;
  final bool cashEnabled;
  final bool gcashEnabled;
  final String gcashQrImageUrl;
  final String gcashQrStoragePath;
  final String accountName;
  final String accountNumber;
  final DateTime? updatedAt;

  const BranchPaymentSettingsModel({
    required this.branchId,
    this.branchName = '',
    this.cashEnabled = true,
    this.gcashEnabled = false,
    this.gcashQrImageUrl = '',
    this.gcashQrStoragePath = '',
    this.accountName = '',
    this.accountNumber = '',
    this.updatedAt,
  });

  /// Cash-only fallback when settings document is missing, loading, or unconfigured
  factory BranchPaymentSettingsModel.cashOnly(String branchId) {
    return BranchPaymentSettingsModel(
      branchId: branchId.trim(),
      cashEnabled: true,
      gcashEnabled: false,
    );
  }

  /// Parses Firestore data supporting both camelCase and snake_case schemas
  /// as well as Web Admin legacy field aliases.
  factory BranchPaymentSettingsModel.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final bId = (data['branchId'] as String? ??
            data['branch_id'] as String? ??
            docId)
        .trim();

    final bName = (data['branchName'] as String? ??
            data['branch_name'] as String? ??
            '')
        .trim();

    final cEnabled = (data['cashEnabled'] as bool?) ??
        (data['cash_enabled'] as bool?) ??
        true;

    final gEnabled = (data['gcashEnabled'] as bool?) ??
        (data['gcash_enabled'] as bool?) ??
        false;

    final qrUrl = (data['gcashQrImageUrl'] as String? ??
            data['gcash_qr_image_url'] as String? ??
            '')
        .trim();

    final qrPath = (data['gcashQrStoragePath'] as String? ??
            data['gcash_qr_storage_path'] as String? ??
            '')
        .trim();

    // Account name: checks primary fields then legacy aliases
    final accName = (data['accountName'] as String? ??
            data['account_name'] as String? ??
            data['gcashAccountName'] as String? ??
            data['gcash_account_name'] as String? ??
            '')
        .trim();

    // Account number: checks primary fields then legacy aliases
    final accNum = (data['accountNumber'] as String? ??
            data['account_number'] as String? ??
            data['gcashAccountNumber'] as String? ??
            data['gcash_account_number'] as String? ??
            '')
        .trim();

    final updated = _parseDateTime(data['updatedAt'] ?? data['updated_at']);

    return BranchPaymentSettingsModel(
      branchId: bId,
      branchName: bName,
      cashEnabled: cEnabled,
      gcashEnabled: gEnabled,
      gcashQrImageUrl: qrUrl,
      gcashQrStoragePath: qrPath,
      accountName: accName,
      accountNumber: accNum,
      updatedAt: updated,
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String && val.trim().isNotEmpty) {
      return DateTime.tryParse(val.trim());
    }
    return null;
  }

  /// Validates that QR URL is non-empty and strictly uses the HTTPS scheme.
  bool get hasValidQrUrl {
    final trimmed = gcashQrImageUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.hasScheme && uri.scheme.toLowerCase() == 'https';
  }

  /// GCash is available only when explicitly enabled AND accompanied by a valid HTTPS QR URL.
  bool get isGcashAvailable => gcashEnabled && hasValidQrUrl;

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'branchName': branchName,
      'cashEnabled': cashEnabled,
      'gcashEnabled': gcashEnabled,
      'gcashQrImageUrl': gcashQrImageUrl,
      'gcashQrStoragePath': gcashQrStoragePath,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

