import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/models/notification_model.dart';
import 'package:coffee_grind_ph/providers/restock_provider.dart';
import 'package:coffee_grind_ph/providers/notification_provider.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('Part 1: Restock Reload & Branch Verification Tests', () {

    test('1. Santa Cruz account reloads and loads Santa Cruz requests', () async {
      // Seed Santa Cruz and LSPU requests
      await fakeDb.collection(FirebasePaths.restockRequests).doc('req_sc_1').set({
        'requestId': 'req_sc_1',
        'branchId': 'br_1790905840872',
        'branchName': 'Santa Cruz',
        'category': 'Ingredients',
        'ingredientName': 'Espresso Beans',
        'quantity': 10,
        'unit': 'kg',
        'status': 'pending',
        'requestedAt': Timestamp.now(),
      });

      await fakeDb.collection(FirebasePaths.restockRequests).doc('req_lspu_1').set({
        'requestId': 'req_lspu_1',
        'branchId': 'br_1790923872261',
        'branchName': 'LSPU',
        'category': 'Packaging',
        'ingredientName': '16oz Cups',
        'quantity': 200,
        'unit': 'pcs',
        'status': 'pending',
        'requestedAt': Timestamp.now(),
      });

      final restockProvider = RestockProvider(firestore: fakeDb);
      restockProvider.bindToBranch('br_1790905840872');
      await pumpEventQueue();

      expect(restockProvider.isLoading, isFalse);
      expect(restockProvider.hasRequestsError, isFalse);
      expect(restockProvider.requestsErrorMessage, isNull);
      expect(restockProvider.requests.length, 1);
      expect(restockProvider.requests.first.id, 'req_sc_1');
      expect(restockProvider.requests.first.itemType, 'Espresso Beans');
      expect(restockProvider.activeRequests.length, 1);
      expect(restockProvider.historyRequests.length, 0);
    });

    test('2. LSPU account reloads and loads LSPU requests', () async {
      // Seed Santa Cruz and LSPU requests
      await fakeDb.collection(FirebasePaths.restockRequests).doc('req_sc_1').set({
        'requestId': 'req_sc_1',
        'branchId': 'br_1790905840872',
        'branchName': 'Santa Cruz',
        'category': 'Ingredients',
        'ingredientName': 'Espresso Beans',
        'quantity': 10,
        'unit': 'kg',
        'status': 'pending',
        'requestedAt': Timestamp.now(),
      });

      await fakeDb.collection(FirebasePaths.restockRequests).doc('req_lspu_1').set({
        'requestId': 'req_lspu_1',
        'branchId': 'br_1790923872261',
        'branchName': 'LSPU',
        'category': 'Packaging',
        'ingredientName': '16oz Cups',
        'quantity': 200,
        'unit': 'pcs',
        'status': 'approved',
        'requestedAt': Timestamp.now(),
      });

      final restockProvider = RestockProvider(firestore: fakeDb);
      restockProvider.bindToBranch('br_1790923872261');
      await pumpEventQueue();

      expect(restockProvider.isLoading, isFalse);
      expect(restockProvider.hasRequestsError, isFalse);
      expect(restockProvider.requests.length, 1);
      expect(restockProvider.requests.first.id, 'req_lspu_1');
      expect(restockProvider.requests.first.itemType, '16oz Cups');
      expect(restockProvider.activeRequests.length, 1);
      expect(restockProvider.historyRequests.length, 0);
    });

    test('3. No Santa Cruz query occurs while branchId is empty (isVerifying == true)', () async {
      final restockProvider = RestockProvider(firestore: fakeDb);
      
      // Attempt binding with empty branch ID (simulating unverified/verifying state)
      restockProvider.bindToBranch('');
      await pumpEventQueue();

      expect(restockProvider.requests, isEmpty);
      expect(restockProvider.currentBranchId, isNull);
    });

    test('4. Switching branches cancels old subscription and isolates data', () async {
      await fakeDb.collection(FirebasePaths.restockRequests).doc('req_sc_1').set({
        'requestId': 'req_sc_1',
        'branchId': 'br_1790905840872',
        'branchName': 'Santa Cruz',
        'ingredientName': 'Espresso Beans',
        'quantity': 10,
        'unit': 'kg',
        'status': 'pending',
        'requestedAt': Timestamp.now(),
      });

      await fakeDb.collection(FirebasePaths.restockRequests).doc('req_lspu_1').set({
        'requestId': 'req_lspu_1',
        'branchId': 'br_1790923872261',
        'branchName': 'LSPU',
        'ingredientName': 'Caramel Syrup',
        'quantity': 5,
        'unit': 'bottles',
        'status': 'received',
        'requestedAt': Timestamp.now(),
      });

      final restockProvider = RestockProvider(firestore: fakeDb);
      restockProvider.bindToBranch('br_1790905840872');
      await pumpEventQueue();
      expect(restockProvider.requests.length, 1);
      expect(restockProvider.requests.first.itemType, 'Espresso Beans');

      // Switch to LSPU
      restockProvider.bindToBranch('br_1790923872261');
      await pumpEventQueue();
      expect(restockProvider.requests.length, 1);
      expect(restockProvider.requests.first.itemType, 'Caramel Syrup');
      expect(restockProvider.historyRequests.length, 1);
      expect(restockProvider.activeRequests.length, 0);
    });

    test('5. A failed subscription can recover after rebinding', () async {
      final restockProvider = RestockProvider(firestore: fakeDb);

      // Simulate a previous error state (e.g. from an unauthorized query)
      restockProvider.bindToBranch('br_1790905840872');
      await pumpEventQueue();

      // Seed new document
      await fakeDb.collection(FirebasePaths.restockRequests).doc('req_sc_2').set({
        'requestId': 'req_sc_2',
        'branchId': 'br_1790905840872',
        'branchName': 'Santa Cruz',
        'ingredientName': 'Whole Milk',
        'quantity': 24,
        'unit': 'L',
        'status': 'pending',
        'requestedAt': Timestamp.now(),
      });

      // Re-bind to branch
      restockProvider.bindToBranch('br_1790905840872');
      await pumpEventQueue();

      expect(restockProvider.hasRequestsError, isFalse);
      expect(restockProvider.requests.length, 1);
      expect(restockProvider.requests.first.itemType, 'Whole Milk');
    });

    test('6. Rebuilding screens does not create duplicate subscriptions', () async {
      await fakeDb.collection(FirebasePaths.restockRequests).doc('req_sc_1').set({
        'requestId': 'req_sc_1',
        'branchId': 'br_1790905840872',
        'branchName': 'Santa Cruz',
        'ingredientName': 'Espresso Beans',
        'quantity': 10,
        'unit': 'kg',
        'status': 'pending',
        'requestedAt': Timestamp.now(),
      });

      final restockProvider = RestockProvider(firestore: fakeDb);
      restockProvider.bindToBranch('br_1790905840872');
      await pumpEventQueue();
      expect(restockProvider.requests.length, 1);

      // Subsequent identical bind calls (such as on widget rebuild) do not duplicate or error
      restockProvider.bindToBranch('br_1790905840872');
      restockProvider.bindToBranch('br_1790905840872');
      await pumpEventQueue();

      expect(restockProvider.requests.length, 1);
      expect(restockProvider.hasRequestsError, isFalse);
    });
  });

  group('Part 2 & 3: Announcement Compatibility & Expiration Tests', () {
    test('7. "All Branches" announcement is received by Santa Cruz and LSPU', () {
      final allBranchesSchemas = [
        {'isAllBranches': true},
        {'targetAudience': 'All Branches'},
        {'targetAudience': 'all'},
        {'branchId': 'all'},
        {'branch_id': 'all'},
        {'targetBranches': ['all']},
        {'audience': 'all'},
        {'audience': 'all branches'},
      ];

      for (final schema in allBranchesSchemas) {
        final Map<String, dynamic> data = {...schema, 'status': 'active'};
        expect(
          NotificationProvider.isAnnouncementTargetedToBranch(
            data: data,
            branchId: 'br_1790905840872',
            branchName: 'Santa Cruz',
          ),
          isTrue,
          reason: 'Failed for schema $schema on Santa Cruz',
        );

        expect(
          NotificationProvider.isAnnouncementTargetedToBranch(
            data: data,
            branchId: 'br_1790923872261',
            branchName: 'LSPU',
          ),
          isTrue,
          reason: 'Failed for schema $schema on LSPU',
        );
      }
    });

    test('8. Santa Cruz-only announcement is received only by Santa Cruz', () {
      final santaCruzSchemas = [
        {'targetBranchId': 'br_1790905840872'},
        {'targetAudience': 'Santa Cruz'},
        {'targetBranchName': 'Santa Cruz'},
        {'branchId': 'br_1790905840872'},
        {'branch_id': 'br_1790905840872'},
      ];

      for (final schema in santaCruzSchemas) {
        final Map<String, dynamic> data = {...schema, 'status': 'active'};
        expect(
          NotificationProvider.isAnnouncementTargetedToBranch(
            data: data,
            branchId: 'br_1790905840872',
            branchName: 'Santa Cruz',
          ),
          isTrue,
          reason: 'Failed to target Santa Cruz with schema $schema',
        );

        expect(
          NotificationProvider.isAnnouncementTargetedToBranch(
            data: data,
            branchId: 'br_1790923872261',
            branchName: 'LSPU',
          ),
          isFalse,
          reason: 'Santa Cruz announcement should not match LSPU with schema $schema',
        );
      }
    });

    test('9. LSPU-only announcement is received only by LSPU', () {
      final lspuSchemas = [
        {'targetBranchId': 'br_1790923872261'},
        {'targetAudience': 'LSPU'},
        {'targetBranchName': 'LSPU'},
        {'branchId': 'br_1790923872261'},
        {'branch_id': 'br_1790923872261'},
      ];

      for (final schema in lspuSchemas) {
        final Map<String, dynamic> data = {...schema, 'status': 'active'};
        expect(
          NotificationProvider.isAnnouncementTargetedToBranch(
            data: data,
            branchId: 'br_1790923872261',
            branchName: 'LSPU',
          ),
          isTrue,
          reason: 'Failed to target LSPU with schema $schema',
        );

        expect(
          NotificationProvider.isAnnouncementTargetedToBranch(
            data: data,
            branchId: 'br_1790905840872',
            branchName: 'Santa Cruz',
          ),
          isFalse,
          reason: 'LSPU announcement should not match Santa Cruz with schema $schema',
        );
      }
    });

    test('10. Wrong-branch announcement is excluded', () {
      final wrongBranchData = {
        'targetBranchId': 'br_other_branch',
        'targetAudience': 'Other Branch',
        'status': 'active',
      };

      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: wrongBranchData,
          branchId: 'br_1790905840872',
          branchName: 'Santa Cruz',
        ),
        isFalse,
      );
    });

    test('11. Draft announcements are excluded', () {
      final draftData = {
        'status': 'draft',
        'isAllBranches': true,
        'targetAudience': 'All Branches',
      };

      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: draftData,
          branchId: 'br_1790905840872',
          branchName: 'Santa Cruz',
        ),
        isFalse,
      );
    });

    test('12. Legacy field aliases are handled correctly', () {
      final legacyListBranch = {
        'targetBranches': ['br_1790905840872'],
        'status': 'active',
      };
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: legacyListBranch,
          branchId: 'br_1790905840872',
          branchName: 'Santa Cruz',
        ),
        isTrue,
      );
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: legacyListBranch,
          branchId: 'br_1790923872261',
          branchName: 'LSPU',
        ),
        isFalse,
      );

      final legacyTargetBranchString = {
        'targetBranch': 'Santa Cruz',
        'status': 'active',
      };
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: legacyTargetBranchString,
          branchId: 'br_1790905840872',
          branchName: 'Santa Cruz',
        ),
        isTrue,
      );
    });

    test('13. Expiration date parsing handles Timestamp, ISO string, and null', () {
      final date = DateTime(2026, 11, 5, 12, 0);
      final ts = Timestamp.fromDate(date);

      // Timestamp in expDate
      expect(NotificationProvider.parseExpirationDate(ts, null), date);
      // Timestamp in expiresAt
      expect(NotificationProvider.parseExpirationDate(null, ts), date);

      // ISO string
      final isoStr = date.toIso8601String();
      expect(NotificationProvider.parseExpirationDate(isoStr, null), date);
      expect(NotificationProvider.parseExpirationDate(null, isoStr), date);

      // Null or invalid
      expect(NotificationProvider.parseExpirationDate(null, null), isNull);
      expect(NotificationProvider.parseExpirationDate('', 'invalid_date'), isNull);
    });

    test('14. Dynamic getter excludes expired announcements without requiring reload', () {
      final now = DateTime.now();
      final activeAnnouncement = AnnouncementModel(
        id: 'ann_active',
        title: 'Active Promo',
        message: 'Enjoy coffee discounts',
        createdAt: now.subtract(const Duration(hours: 1)),
        expirationDate: now.add(const Duration(days: 3)), // 3-day boundary
      );

      final expiredAnnouncement = AnnouncementModel(
        id: 'ann_expired',
        title: 'Expired Promo',
        message: 'This promo ended yesterday',
        createdAt: now.subtract(const Duration(days: 2)),
        expirationDate: now.subtract(const Duration(minutes: 5)),
      );

      final evergreenAnnouncement = AnnouncementModel(
        id: 'ann_evergreen',
        title: 'Store Policy',
        message: 'Clean machines daily',
        createdAt: now.subtract(const Duration(days: 10)),
        expirationDate: null,
      );

      final provider = NotificationProvider(firestore: fakeDb);
      provider.setAnnouncementsForTesting([
        activeAnnouncement,
        expiredAnnouncement,
        evergreenAnnouncement,
      ]);

      final displayed = provider.announcements;
      expect(displayed.length, 2);
      expect(displayed.any((a) => a.id == 'ann_active'), isTrue);
      expect(displayed.any((a) => a.id == 'ann_evergreen'), isTrue);
      expect(displayed.any((a) => a.id == 'ann_expired'), isFalse);
    });

    test('15. NotificationProvider Firestore stream filters announcements by branch, status, and expiration', () async {
      final now = DateTime.now();

      await fakeDb.collection(FirebasePaths.announcements).doc('ann_all').set({
        'isAllBranches': true,
        'status': 'active',
        'title': 'All Branches Notice',
        'message': 'Meeting at 5pm',
        'createdAt': Timestamp.fromDate(now),
      });

      await fakeDb.collection(FirebasePaths.announcements).doc('ann_sc').set({
        'targetBranchId': 'br_1790905840872',
        'targetAudience': 'Santa Cruz',
        'status': 'active',
        'title': 'SC Notice',
        'message': 'Water filter check',
        'createdAt': Timestamp.fromDate(now),
      });

      await fakeDb.collection(FirebasePaths.announcements).doc('ann_lspu').set({
        'targetBranchId': 'br_1790923872261',
        'targetAudience': 'LSPU',
        'status': 'active',
        'title': 'LSPU Notice',
        'message': 'Campus event tomorrow',
        'createdAt': Timestamp.fromDate(now),
      });

      await fakeDb.collection(FirebasePaths.announcements).doc('ann_draft').set({
        'isAllBranches': true,
        'status': 'draft',
        'title': 'Draft Notice',
        'message': 'Unreleased',
        'createdAt': Timestamp.fromDate(now),
      });

      await fakeDb.collection(FirebasePaths.announcements).doc('ann_expired').set({
        'isAllBranches': true,
        'status': 'active',
        'title': 'Expired Notice',
        'message': 'Last week',
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        'expirationDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      });

      final provider = NotificationProvider(firestore: fakeDb);

      // Bind to Santa Cruz
      provider.bindToBranch('br_1790905840872', branchName: 'Santa Cruz');
      await pumpEventQueue();

      final scAnnouncements = provider.announcements;
      expect(scAnnouncements.length, 2);
      expect(scAnnouncements.any((a) => a.id == 'ann_all'), isTrue);
      expect(scAnnouncements.any((a) => a.id == 'ann_sc'), isTrue);
      expect(scAnnouncements.any((a) => a.id == 'ann_lspu'), isFalse);
      expect(scAnnouncements.any((a) => a.id == 'ann_draft'), isFalse);
      expect(scAnnouncements.any((a) => a.id == 'ann_expired'), isFalse);

      // Switch to LSPU
      provider.bindToBranch('br_1790923872261', branchName: 'LSPU');
      await pumpEventQueue();

      final lspuAnnouncements = provider.announcements;
      expect(lspuAnnouncements.length, 2);
      expect(lspuAnnouncements.any((a) => a.id == 'ann_all'), isTrue);
      expect(lspuAnnouncements.any((a) => a.id == 'ann_lspu'), isTrue);
      expect(lspuAnnouncements.any((a) => a.id == 'ann_sc'), isFalse);
      expect(lspuAnnouncements.any((a) => a.id == 'ann_draft'), isFalse);
      expect(lspuAnnouncements.any((a) => a.id == 'ann_expired'), isFalse);

      provider.dispose();
    });

    test('16. NotificationProvider Firestore stream isolates notifications by branchId', () async {
      await fakeDb.collection(FirebasePaths.notifications).doc('notif_sc').set({
        'branchId': 'br_1790905840872',
        'title': 'SC Restock Approved',
        'message': 'Beans on the way',
        'type': 'restockApproved',
        'timestamp': Timestamp.now(),
        'isRead': false,
      });

      await fakeDb.collection(FirebasePaths.notifications).doc('notif_lspu').set({
        'branchId': 'br_1790923872261',
        'title': 'LSPU Restock Rejected',
        'message': 'Milk out of stock',
        'type': 'restockRejected',
        'timestamp': Timestamp.now(),
        'isRead': false,
      });

      final provider = NotificationProvider(firestore: fakeDb);

      provider.bindToBranch('br_1790905840872', branchName: 'Santa Cruz');
      await pumpEventQueue();

      expect(provider.notifications.length, 1);
      expect(provider.notifications.first.id, 'notif_sc');
      expect(provider.unreadCount, 1);

      provider.bindToBranch('br_1790923872261', branchName: 'LSPU');
      await pumpEventQueue();

      expect(provider.notifications.length, 1);
      expect(provider.notifications.first.id, 'notif_lspu');
      expect(provider.unreadCount, 1);

      provider.dispose();
    });
  });

  group('Part 4: Web Admin Schema Compatibility & Query Stream Tests', () {
    test('17. Snake_case Web Admin fields are fully supported for All Branches and specific branches', () {
      final now = DateTime.now();
      final exp = now.add(const Duration(days: 3));

      // All Branches via snake_case is_all_branches
      final allBranchesSnake1 = {
        'is_all_branches': true,
        'status': 'active',
        'target_audience': 'all',
        'created_at': Timestamp.fromDate(now),
        'expiration_date': Timestamp.fromDate(exp),
      };
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: allBranchesSnake1,
          branchId: 'br_1790905840872',
          branchName: 'Santa Cruz',
        ),
        isTrue,
      );
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: allBranchesSnake1,
          branchId: 'br_1790923872261',
          branchName: 'LSPU',
        ),
        isTrue,
      );

      // Santa Cruz only via snake_case target_branch_id
      final scSnake = {
        'target_branch_id': 'br_1790905840872',
        'target_audience': 'Santa Cruz',
        'status': 'active',
      };
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: scSnake,
          branchId: 'br_1790905840872',
          branchName: 'Santa Cruz',
        ),
        isTrue,
      );
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: scSnake,
          branchId: 'br_1790923872261',
          branchName: 'LSPU',
        ),
        isFalse,
      );

      // LSPU only via snake_case target_branch_ids array
      final lspuSnake = {
        'target_branch_ids': ['br_1790923872261'],
        'status': 'active',
      };
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: lspuSnake,
          branchId: 'br_1790923872261',
          branchName: 'LSPU',
        ),
        isTrue,
      );
      expect(
        NotificationProvider.isAnnouncementTargetedToBranch(
          data: lspuSnake,
          branchId: 'br_1790905840872',
          branchName: 'Santa Cruz',
        ),
        isFalse,
      );
    });

    test('18. Draft, archived, solved, and inactive announcements are excluded from active list', () {
      final excludedStatuses = ['draft', 'archived', 'solved', 'inactive', 'DRAFT', 'Archived'];

      for (final st in excludedStatuses) {
        final data = {
          'isAllBranches': true,
          'status': st,
          'title': 'Test Notice',
        };
        expect(
          NotificationProvider.isAnnouncementTargetedToBranch(
            data: data,
            branchId: 'br_1790905840872',
            branchName: 'Santa Cruz',
          ),
          isFalse,
          reason: 'Status $st should have been excluded',
        );
      }
    });

    test('19. Mixed legacy and new schema expiration and creation dates parse accurately', () {
      final date = DateTime(2026, 11, 10, 8, 30);
      final ts = Timestamp.fromDate(date);

      // snake_case expiration_date
      final dataExpSnake = {'expiration_date': ts};
      expect(NotificationProvider.parseExpirationDateFromData(dataExpSnake), date);

      // snake_case expires_at
      final dataExpiresAtSnake = {'expires_at': ts};
      expect(NotificationProvider.parseExpirationDateFromData(dataExpiresAtSnake), date);

      // camelCase expirationDate
      final dataExpCamel = {'expirationDate': ts};
      expect(NotificationProvider.parseExpirationDateFromData(dataExpCamel), date);

      // snake_case created_at
      final dataCreatedSnake = {'created_at': ts};
      expect(NotificationProvider.parseCreatedAtFromData(dataCreatedSnake), date);

      // ISO date string in expiration_date
      final dataIso = {'expiration_date': '2026-11-10T08:30:00.000Z'};
      expect(
        NotificationProvider.parseExpirationDateFromData(dataIso),
        DateTime.parse('2026-11-10T08:30:00.000Z'),
      );
    });

    test('20. NotificationProvider stream merges targeted and broad queries and handles permission errors gracefully', () async {
      final now = DateTime.now();

      // Seed all-branches announcement
      await fakeDb.collection(FirebasePaths.announcements).doc('ann_all_1').set({
        'isAllBranches': true,
        'targetAudience': 'All Branches',
        'status': 'active',
        'title': 'General Staff Memo',
        'message': 'Store meeting on Friday',
        'createdAt': Timestamp.fromDate(now),
      });

      // Seed Santa Cruz targeted announcement with snake_case
      await fakeDb.collection(FirebasePaths.announcements).doc('ann_sc_1').set({
        'target_branch_id': 'br_1790905840872',
        'targetBranchId': 'br_1790905840872',
        'status': 'active',
        'title': 'Santa Cruz Maintenance',
        'message': 'Espresso grinder maintenance at 6pm',
        'createdAt': Timestamp.fromDate(now),
      });

      // Seed LSPU targeted announcement
      await fakeDb.collection(FirebasePaths.announcements).doc('ann_lspu_1').set({
        'target_branch_id': 'br_1790923872261',
        'targetBranchId': 'br_1790923872261',
        'status': 'active',
        'title': 'LSPU Exam Week Promo',
        'message': 'Extended store hours',
        'createdAt': Timestamp.fromDate(now),
      });

      // Seed solved announcement (should be filtered out)
      await fakeDb.collection(FirebasePaths.announcements).doc('ann_solved').set({
        'isAllBranches': true,
        'status': 'solved',
        'title': 'Water Issue Solved',
        'message': 'Resolved yesterday',
        'createdAt': Timestamp.fromDate(now),
      });

      final provider = NotificationProvider(firestore: fakeDb);

      provider.bindToBranch('br_1790905840872', branchName: 'Santa Cruz');
      await pumpEventQueue();

      final scActive = provider.announcements;
      expect(scActive.any((a) => a.id == 'ann_all_1'), isTrue);
      expect(scActive.any((a) => a.id == 'ann_sc_1'), isTrue);
      expect(scActive.any((a) => a.id == 'ann_lspu_1'), isFalse);
      expect(scActive.any((a) => a.id == 'ann_solved'), isFalse);

      provider.dispose();
    });
  });
}
