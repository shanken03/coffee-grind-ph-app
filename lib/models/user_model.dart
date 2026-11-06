class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String role; // 'OWNER' | 'STAFF'
  final String status; // 'pending' | 'approved' | 'denied'
  final String? branchId;
  final String? branchName;
  final String? rfidUid;
  final bool active;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.role,
    required this.status,
    this.branchId,
    this.branchName,
    this.rfidUid,
    required this.active,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';
  bool get isOwner => role == 'OWNER';

  bool get hasBranchAssigned => branchId != null && branchId!.isNotEmpty;
  bool get hasRfidAssigned => rfidUid != null && rfidUid!.isNotEmpty;

  /// True once Owner has approved AND assigned both branch and RFID —
  /// only then does this staff member reach the "attendance required" gate.
  bool get isFullySetUp =>
      isApproved && active && hasBranchAssigned && hasRfidAssigned;

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      role: map['role'] as String? ?? 'STAFF',
      status: map['status'] as String? ?? 'pending',
      branchId: map['branchId'] as String?,
      branchName: map['branchName'] as String?,
      rfidUid: map['rfidUid'] as String?,
      active: map['active'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'status': status,
      'branchId': branchId,
      'branchName': branchName,
      'rfidUid': rfidUid,
      'active': active,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}