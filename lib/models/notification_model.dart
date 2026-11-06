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

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.expirationDate,
    this.author = 'Owner',
    this.status = 'active',
    this.targetBranch,
  });
}
