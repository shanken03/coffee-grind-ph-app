import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/pending_offline_order.dart';

/// Persistence contract for storing pending offline orders per branch.
abstract class OfflineOrderStorage {
  Future<List<PendingOfflineOrder>> load(String branchId);
  Future<void> save(String branchId, List<PendingOfflineOrder> orders);
}

/// Persists pending offline orders as JSON in the application's documents
/// directory, with an in-memory fallback when running on web or in unit tests
/// without platform channels.
class FileOfflineOrderStorage implements OfflineOrderStorage {
  final Map<String, List<PendingOfflineOrder>> _memoryFallback = {};

  Future<File?> _getQueueFile(String branchId) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeBranchId = branchId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      return File('${dir.path}/offline_orders_$safeBranchId.json');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<PendingOfflineOrder>> load(String branchId) async {
    if (branchId.trim().isEmpty) return [];
    final file = await _getQueueFile(branchId);
    if (file == null) {
      return List<PendingOfflineOrder>.from(_memoryFallback[branchId] ?? const []);
    }

    try {
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => PendingOfflineOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(String branchId, List<PendingOfflineOrder> orders) async {
    if (branchId.trim().isEmpty) return;
    _memoryFallback[branchId] = List<PendingOfflineOrder>.from(orders);

    final file = await _getQueueFile(branchId);
    if (file == null) return;

    try {
      final encoded = jsonEncode(orders.map((o) => o.toJson()).toList());
      await file.writeAsString(encoded, flush: true);
    } catch (_) {
      // Retain in-memory copy if filesystem write fails
    }
  }
}

/// In-memory storage implementation for deterministic unit and widget tests.
class InMemoryOfflineOrderStorage implements OfflineOrderStorage {
  final Map<String, List<PendingOfflineOrder>> _store = {};

  @override
  Future<List<PendingOfflineOrder>> load(String branchId) async {
    return List<PendingOfflineOrder>.from(_store[branchId] ?? const []);
  }

  @override
  Future<void> save(String branchId, List<PendingOfflineOrder> orders) async {
    _store[branchId] = List<PendingOfflineOrder>.from(orders);
  }
}
