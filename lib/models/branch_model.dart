class BranchModel {
  final String branchId;
  final String name;
  final String address;
  final bool isActive;

  const BranchModel({
    required this.branchId,
    required this.name,
    required this.address,
    required this.isActive,
  });

  factory BranchModel.fromMap(String id, Map<String, dynamic> map) {
    return BranchModel(
      branchId: id,
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'isActive': isActive,
    };
  }
}