enum NotificationType { restockApproved, restockRejected, restockReceived, announcement, system }

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}

class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? expirationDate;
  final String author; // 'Owner'
  final String status;
  final String? targetBranch;
  final bool isRead;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.expirationDate,
    this.author = 'Owner',
    this.status = 'active',
    this.targetBranch,
    this.isRead = false,
  });

  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? createdAt,
    DateTime? expirationDate,
    String? author,
    String? status,
    String? targetBranch,
    bool? isRead,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      expirationDate: expirationDate ?? this.expirationDate,
      author: author ?? this.author,
      status: status ?? this.status,
      targetBranch: targetBranch ?? this.targetBranch,
      isRead: isRead ?? this.isRead,
    );
  }
}
