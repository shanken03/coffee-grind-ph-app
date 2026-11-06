import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_paths.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  StreamSubscription<QuerySnapshot>? _announcementSubscription;
  final List<StreamSubscription<QuerySnapshot>> _targetedAnnouncementSubscriptions = [];
  final Map<String, AnnouncementModel> _announcementsMap = {};
  Timer? _expirationTimer;

  List<NotificationModel> _notifications = [];
  List<AnnouncementModel> _rawAnnouncements = [];
  bool _isLoading = true;
  String? _currentBranchId;
  String? _currentBranchName;
  String? _announcementsErrorMessage;

  NotificationProvider({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  /// Dynamically excludes expired, draft, archived, and solved announcements so
  /// that active announcements update automatically while the app remains open
  /// and after reload.
  List<AnnouncementModel> get announcements {
    final now = DateTime.now();
    return _rawAnnouncements.where((a) {
      final st = a.status.toLowerCase().trim();
      if (st == 'draft' ||
          st == 'archived' ||
          st == 'solved' ||
          st == 'inactive') {
        return false;
      }
      if (a.expirationDate == null) return true;
      return a.expirationDate!.isAfter(now);
    }).toList();
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;
  String? get announcementsErrorMessage => _announcementsErrorMessage;

  @visibleForTesting
  void setLoadingForTesting(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @visibleForTesting
  void setAnnouncementsForTesting(List<AnnouncementModel> testAnnouncements) {
    _rawAnnouncements = testAnnouncements;
    notifyListeners();
  }

  void bindToBranch(String branchId, {String? branchName}) {
    final cleanBranchId = branchId.trim();
    final cleanBranchName = (branchName ?? _currentBranchName ?? '').trim();
    if (cleanBranchId.isEmpty) return;

    if (_currentBranchId == cleanBranchId &&
        _currentBranchName == cleanBranchName &&
        _notifSubscription != null &&
        (_announcementSubscription != null ||
            _targetedAnnouncementSubscriptions.isNotEmpty)) {
      return;
    }

    _currentBranchId = cleanBranchId;
    _currentBranchName = cleanBranchName;
    _listenToNotifications(cleanBranchId);
    _listenToAnnouncements(branchId: cleanBranchId, branchName: cleanBranchName);
  }

  void _listenToNotifications(String branchId) {
    _notifSubscription?.cancel();
    _notifSubscription = null;
    final cleanBranchId = branchId.trim();
    if (cleanBranchId.isEmpty) return;

    try {
      // Query filtered strictly by branchId to conform to Firestore security rules
      _notifSubscription = _firestore
          .collection(FirebasePaths.notifications)
          .where('branchId', isEqualTo: cleanBranchId)
          .snapshots()
          .listen(
            (snapshot) {
              final loaded = snapshot.docs.map((doc) {
                final data = doc.data();
                DateTime ts = DateTime.now();
                if (data['timestamp'] is Timestamp) {
                  ts = (data['timestamp'] as Timestamp).toDate();
                } else if (data['createdAt'] is Timestamp) {
                  ts = (data['createdAt'] as Timestamp).toDate();
                }

                return NotificationModel(
                  id: doc.id,
                  title: data['title'] as String? ?? 'Notification',
                  message: data['message'] as String? ?? '',
                  type: _parseType(data['type'] as String?),
                  timestamp: ts,
                  isRead: data['isRead'] as bool? ?? false,
                );
              }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              _notifications = loaded;
              _isLoading = false;
              notifyListeners();
            },
            onError: (_) {
              _isLoading = false;
              notifyListeners();
            },
          );
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startExpirationTimer() {
    _expirationTimer?.cancel();
    // Lightweight timer to notify listeners when an announcement expires while the app stays open
    _expirationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final hasExpiring = _rawAnnouncements.any((a) => a.expirationDate != null);
      if (hasExpiring) {
        notifyListeners();
      }
    });
  }

  static DateTime? parseExpirationDate(
    dynamic expDateRaw,
    dynamic expiresAtRaw, [
    dynamic expDateSnake,
    dynamic expiresAtSnake,
  ]) {
    final candidates = [expDateRaw, expiresAtRaw, expDateSnake, expiresAtSnake];
    for (final c in candidates) {
      if (c is Timestamp) return c.toDate();
      if (c is DateTime) return c;
      if (c is String && c.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(c.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? parseExpirationDateFromData(Map<String, dynamic> data) {
    return parseExpirationDate(
      data['expirationDate'],
      data['expiresAt'],
      data['expiration_date'],
      data['expires_at'],
    );
  }

  static DateTime parseCreatedAtFromData(Map<String, dynamic> data) {
    final raw = data['createdAt'] ?? data['created_at'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static bool isAnnouncementTargetedToBranch({
    required Map<String, dynamic> data,
    required String branchId,
    String? branchName,
  }) {
    // Exclude draft, archived, solved, and inactive announcements
    final status = (data['status'] as String? ?? 'active').toLowerCase().trim();
    if (status == 'draft' ||
        status == 'archived' ||
        status == 'solved' ||
        status == 'inactive') {
      return false;
    }

    // 1. All-Branches checks (Web schema: isAllBranches, is_all_branches, targetAudience: 'All Branches', branchId: 'all')
    if (data['isAllBranches'] == true || data['is_all_branches'] == true) {
      return true;
    }

    final targetAudience = (data['targetAudience'] as String? ??
            data['target_audience'] as String? ??
            '')
        .trim()
        .toLowerCase();
    if (targetAudience == 'all branches' || targetAudience == 'all') {
      return true;
    }

    final bId = (data['branchId'] as String? ??
            data['branch_id'] as String? ??
            '')
        .trim()
        .toLowerCase();
    if (bId == 'all') return true;

    final rawTargetBranches = [
      ...(data['targetBranchIds'] as List? ?? []),
      ...(data['target_branch_ids'] as List? ?? []),
      ...(data['targetBranches'] as List? ?? []),
    ].map((e) => e.toString().trim().toLowerCase()).toList();

    if (rawTargetBranches.contains('all')) return true;

    final legacyAudience = (data['audience'] as String? ??
            data['targetBranch'] as String? ??
            '')
        .trim()
        .toLowerCase();
    if (legacyAudience == 'all' || legacyAudience == 'all branches') {
      return true;
    }

    // 2. Specific Branch checks
    final cleanBranchId = branchId.trim().toLowerCase();
    final cleanBranchName = (branchName ?? '').trim().toLowerCase();

    // Check targetBranchId / target_branch_id
    final targetBranchId = (data['targetBranchId'] as String? ??
            data['target_branch_id'] as String? ??
            '')
        .trim()
        .toLowerCase();
    if (targetBranchId.isNotEmpty) {
      return targetBranchId == cleanBranchId;
    }

    // Check branchId / branch_id if explicit and specific
    if (bId.isNotEmpty && bId != 'all') {
      if (bId == cleanBranchId) return true;
      if (bId.startsWith('br_')) return false;
    }

    // Check targetBranchIds / target_branch_ids / targetBranches list
    if (rawTargetBranches.isNotEmpty) {
      if (rawTargetBranches.contains(cleanBranchId)) return true;
      if (cleanBranchName.isNotEmpty && rawTargetBranches.contains(cleanBranchName)) return true;
      if (cleanBranchId == 'br_1790905840872' && rawTargetBranches.any((t) => t.contains('santa'))) return true;
      if (cleanBranchId == 'br_1790923872261' && rawTargetBranches.any((t) => t.contains('lspu'))) return true;
      return false;
    }

    // Check targetBranchName / target_branch_name
    final targetBranchName = (data['targetBranchName'] as String? ??
            data['target_branch_name'] as String? ??
            '')
        .trim()
        .toLowerCase();
    if (targetBranchName.isNotEmpty) {
      if (cleanBranchName.isNotEmpty && targetBranchName == cleanBranchName) return true;
      if (cleanBranchId == 'br_1790905840872' && targetBranchName.contains('santa')) return true;
      if (cleanBranchId == 'br_1790923872261' && targetBranchName.contains('lspu')) return true;
      return false;
    }

    // Check targetAudience / target_audience against branch name or branch ID
    if (targetAudience.isNotEmpty && targetAudience != 'all branches' && targetAudience != 'all') {
      if (cleanBranchName.isNotEmpty && targetAudience == cleanBranchName) return true;
      if (cleanBranchId == 'br_1790905840872' && targetAudience.contains('santa')) return true;
      if (cleanBranchId == 'br_1790923872261' && targetAudience.contains('lspu')) return true;
      if (targetAudience == cleanBranchId) return true;
      return false;
    }

    // Check legacy audience / targetBranch
    if (legacyAudience.isNotEmpty) {
      if (legacyAudience == cleanBranchId) return true;
      if (cleanBranchName.isNotEmpty && legacyAudience == cleanBranchName) return true;
      if (cleanBranchId == 'br_1790905840872' && legacyAudience.contains('santa')) return true;
      if (cleanBranchId == 'br_1790923872261' && legacyAudience.contains('lspu')) return true;
      return false;
    }

    return false;
  }

  void _cancelAnnouncementSubscriptions() {
    for (final sub in _targetedAnnouncementSubscriptions) {
      sub.cancel();
    }
    _targetedAnnouncementSubscriptions.clear();
    _announcementSubscription?.cancel();
    _announcementSubscription = null;
    _announcementsMap.clear();
  }

  void _listenToAnnouncements({required String branchId, String? branchName}) {
    _cancelAnnouncementSubscriptions();
    _startExpirationTimer();

    final cleanBranch = branchId.trim();
    if (cleanBranch.isEmpty) return;

    void processSnapshot(QuerySnapshot snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        if (isAnnouncementTargetedToBranch(
          data: data,
          branchId: cleanBranch,
          branchName: branchName,
        )) {
          final expDate = parseExpirationDateFromData(data);
          final created = parseCreatedAtFromData(data);
          final st = (data['status'] as String? ?? 'active').trim();
          final bName = (data['targetBranchName'] as String? ??
                  data['target_branch_name'] as String? ??
                  data['targetBranch'] as String? ??
                  data['targetAudience'] as String? ??
                  data['target_audience'] as String? ??
                  'All Branches')
              .trim();

          _announcementsMap[doc.id] = AnnouncementModel(
            id: doc.id,
            title: data['title'] as String? ?? 'Announcement',
            message: data['message'] as String? ?? '',
            createdAt: created,
            expirationDate: expDate,
            author: data['author'] as String? ?? 'Store Owner',
            status: st,
            targetBranch: bName,
          );
        } else {
          _announcementsMap.remove(doc.id);
        }
      }

      final sorted = _announcementsMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _rawAnnouncements = sorted;
      _announcementsErrorMessage = null;
      notifyListeners();
    }

    void handleStreamError(dynamic error) {
      _announcementsErrorMessage = error.toString();
      notifyListeners();
    }

    // 1. Primary Targeted Queries for Branch and All-Branches
    // Strategy: Listen to scoped queries that guarantee branch or all-branches ownership
    final targetedQueries = [
      // All Branches queries
      _firestore.collection(FirebasePaths.announcements).where('isAllBranches', isEqualTo: true),
      _firestore.collection(FirebasePaths.announcements).where('targetAudience', isEqualTo: 'All Branches'),
      // Branch-specific queries for current authenticated branch
      _firestore.collection(FirebasePaths.announcements).where('targetBranchId', isEqualTo: cleanBranch),
      _firestore.collection(FirebasePaths.announcements).where('branchId', isEqualTo: cleanBranch),
    ];

    for (final q in targetedQueries) {
      try {
        final sub = q.snapshots().listen(processSnapshot, onError: handleStreamError);
        _targetedAnnouncementSubscriptions.add(sub);
      } catch (e) {
        handleStreamError(e);
      }
    }

    // 2. Fallback General Collection Listener (handles documents using snake_case/legacy fields)
    try {
      _announcementSubscription = _firestore
          .collection(FirebasePaths.announcements)
          .snapshots()
          .listen(processSnapshot, onError: (err) {
            // If the broad query receives PERMISSION_DENIED because of other branches' documents
            // or rules-as-constraints evaluation, catch it gracefully so the targeted queries continue serving data.
            handleStreamError(err);
          });
    } catch (e) {
      handleStreamError(e);
    }
  }

  NotificationType _parseType(String? raw) {
    if (raw == null) return NotificationType.system;
    switch (raw.toLowerCase()) {
      case 'restockapproved':
        return NotificationType.restockApproved;
      case 'restockrejected':
        return NotificationType.restockRejected;
      case 'restockreceived':
        return NotificationType.restockReceived;
      case 'announcement':
        return NotificationType.announcement;
      default:
        return NotificationType.system;
    }
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  /// Submit a branch staff concern/request to the Owner
  Future<void> submitStaffConcern({
    required String branchId,
    required String branchName,
    required String message,
    String? staffId,
    String? staffName,
  }) async {
    final cleanBranchId = branchId.trim();
    final cleanBranchName = branchName.trim();
    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      throw Exception('Concern message cannot be empty.');
    }
    if (cleanBranchId.isEmpty) {
      throw Exception('Branch ID is required to submit a concern.');
    }

    final docRef = _firestore.collection(FirebasePaths.concerns).doc();
    await docRef.set({
      'concernId': docRef.id,
      'branchId': cleanBranchId,
      'branchName': cleanBranchName,
      'message': cleanMessage,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'submittedByStaffId': staffId ?? 'STAFF_DEVICE',
      'submittedByStaffName': staffName ?? 'Store Staff',
    });
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _notifSubscription?.cancel();
    _cancelAnnouncementSubscriptions();
    super.dispose();
  }
}
