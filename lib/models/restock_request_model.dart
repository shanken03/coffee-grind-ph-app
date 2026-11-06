enum RestockStatus { pending, approved, rejected, received }

extension RestockStatusX on RestockStatus {
  String get label {
    switch (this) {
      case RestockStatus.pending:
        return 'Pending';
      case RestockStatus.approved:
        return 'Approved';
      case RestockStatus.rejected:
        return 'Rejected';
      case RestockStatus.received:
        return 'Received';
    }
  }
}

class RestockRequestModel {
  final String id;
  final String category; // 'Ingredients' | 'Packaging / Supplies'
  final String itemType;
  final int quantity;
  final String unit; // 'kg', 'pcs', 'packs', 'bottles', etc.
  final String? note;
  final RestockStatus status;
  final DateTime createdAt;
  final String branchName;

  const RestockRequestModel({
    required this.id,
    required this.category,
    required this.itemType,
    required this.quantity,
    this.unit = 'pcs',
    this.note,
    required this.status,
    required this.createdAt,
    required this.branchName,
  });

  bool get isActive => status == RestockStatus.pending || status == RestockStatus.approved;
}
