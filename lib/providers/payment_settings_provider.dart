import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_paths.dart';
import '../models/branch_payment_settings_model.dart';

class PaymentSettingsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot>? _subscription;

  BranchPaymentSettingsModel? _settings;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPermissionDenied = false;
  String? _currentBranchId;

  PaymentSettingsProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  BranchPaymentSettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPermissionDenied => _isPermissionDenied;
  String? get currentBranchId => _currentBranchId;

  /// Cash remains always usable by default even during loading or missing settings
  bool get isCashAvailable => _settings?.cashEnabled ?? true;

  /// GCash is available only when verified branch settings are loaded,
  /// GCash is explicitly enabled, and a valid HTTPS QR URL is present.
  bool get isGcashAvailable => _settings?.isGcashAvailable ?? false;

  void bindToBranch(String branchId) {
    final cleanBranchId = branchId.trim();

    // If logging out or branchId is cleared, tear down listeners and reset state
    if (cleanBranchId.isEmpty) {
      _cancelSubscription();
      _currentBranchId = null;
      _settings = null;
      _isLoading = false;
      _errorMessage = null;
      _isPermissionDenied = false;
      notifyListeners();
      return;
    }

    // Prevent duplicate re-binding to the identical branch if already listening
    if (_currentBranchId == cleanBranchId && _subscription != null) {
      return;
    }

    // Cancel existing listener and clear old branch settings immediately
    // to prevent cross-branch leakage or stale data display.
    _cancelSubscription();
    _currentBranchId = cleanBranchId;
    _settings = null;
    _isLoading = true;
    _errorMessage = null;
    _isPermissionDenied = false;
    notifyListeners();

    try {
      final docRef = _firestore
          .collection(FirebasePaths.branchPaymentSettings)
          .doc(cleanBranchId);

      _subscription = docRef.snapshots().listen(
        (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            _settings = BranchPaymentSettingsModel.fromFirestore(
              snapshot.id,
              snapshot.data() as Map<String, dynamic>,
            );
            _errorMessage = null;
            _isPermissionDenied = false;
          } else {
            // Missing document defaults safely to Cash-only
            _settings = BranchPaymentSettingsModel.cashOnly(cleanBranchId);
            _errorMessage = null;
            _isPermissionDenied = false;
          }
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          final errStr = error.toString();
          _isLoading = false;
          _isPermissionDenied = errStr.contains('permission-denied') ||
              errStr.contains('PERMISSION_DENIED');
          _errorMessage = errStr;
          // Fall back gracefully to Cash-only so store operations never stall
          _settings = BranchPaymentSettingsModel.cashOnly(cleanBranchId);
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _settings = BranchPaymentSettingsModel.cashOnly(cleanBranchId);
      notifyListeners();
    }
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  @visibleForTesting
  void setSettingsForTesting(BranchPaymentSettingsModel? testSettings) {
    _settings = testSettings;
    _isLoading = false;
    _errorMessage = null;
    _isPermissionDenied = false;
    notifyListeners();
  }

  @visibleForTesting
  void setErrorForTesting(String error, {bool isPermissionDenied = false}) {
    _errorMessage = error;
    _isPermissionDenied = isPermissionDenied;
    _isLoading = false;
    _settings = _currentBranchId != null
        ? BranchPaymentSettingsModel.cashOnly(_currentBranchId!)
        : null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelSubscription();
    super.dispose();
  }
}

