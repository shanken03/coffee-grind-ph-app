import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firebase_paths.dart';
import '../core/utils/auth_error_formatter.dart';
import '../services/auth_service.dart';

class BranchSessionProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _quotaSubscription;

  User? _currentUser;
  BranchInfo? _currentBranch;

  bool _isInitializing = true;
  bool _isVerifying = false;
  String? _verificationError;

  double _dailyQuota = 0.0;
  bool _isLoadingQuota = false;
  bool _showLoginSuccessToast = false;

  BranchSessionProvider() {
    _initAuthListener();
  }

  User? get currentUser => _currentUser;
  bool get isInitializing => _isInitializing;
  bool get isVerifying => _isVerifying;
  String? get verificationError => _verificationError;
  bool get isBranchVerified =>
      _currentUser != null &&
      _currentBranch != null &&
      _currentBranch!.branchId.isNotEmpty;
  bool get isAuthenticated => isBranchVerified;

  BranchInfo? get currentBranch => _currentBranch;
  String get branchId => _currentBranch?.branchId ?? '';
  String get currentBranchName => _currentBranch?.name ?? '';
  String get currentBranchEmail => _currentBranch?.email ?? '';
  double get dailyQuota => _dailyQuota;
  bool get isLoadingQuota => _isLoadingQuota;

  bool consumeLoginSuccessToast() {
    if (_showLoginSuccessToast) {
      _showLoginSuccessToast = false;
      return true;
    }
    return false;
  }

  void _initAuthListener() {
    try {
      final cachedUser = _authService.currentUser;
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _isInitializing = true;
        _isVerifying = true;
        _verifyAndSetBranchInfo(cachedUser);
      } else {
        _currentUser = null;
        _currentBranch = null;
        _isInitializing = false;
        _isVerifying = false;
        notifyListeners();
      }

      _authSubscription = _authService.authStateChanges.listen((user) async {
        if (user != null) {
          _currentUser = user;
          _isVerifying = true;
          notifyListeners();
          await _verifyAndSetBranchInfo(user);
        } else {
          _currentUser = null;
          _currentBranch = null;
          _isInitializing = false;
          _isVerifying = false;
          _quotaSubscription?.cancel();
          _quotaSubscription = null;
          notifyListeners();
        }
      });
    } catch (_) {
      _isInitializing = false;
      _isVerifying = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndSetBranchInfo(User user) async {
    try {
      final info = await _authService.verifyAndGetBranchInfo(user);
      if (info != null && info.branchId.isNotEmpty) {
        _currentUser = user;
        _currentBranch = info;
        _isInitializing = false;
        _isVerifying = false;
        _verificationError = null;
        _listenToBranchQuota();
        notifyListeners();
      } else {
        _currentBranch = null;
        _isInitializing = false;
        _isVerifying = false;
        _verificationError = 'This account has no valid branch assignment.';
        await signOut();
      }
    } catch (e) {
      _currentBranch = null;
      _isInitializing = false;
      _isVerifying = false;
      _verificationError = formatAuthError(e);
      await signOut();
    }
  }

  void _listenToBranchQuota() {
    _quotaSubscription?.cancel();
    _isLoadingQuota = true;
    notifyListeners();

    try {
      if (branchId.isEmpty) {
        _isLoadingQuota = false;
        return;
      }
      // Primary source: branches/{branchId} dailyQuota field
      final docRef = FirebaseFirestore.instance.collection(FirebasePaths.branches).doc(branchId);
      _quotaSubscription = docRef.snapshots().listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          final target = (data['dailyQuota'] as num?)?.toDouble() ??
              (data['quota'] as num?)?.toDouble() ??
              (data['salesTarget'] as num?)?.toDouble() ??
              0.0;
          _dailyQuota = target;
        } else {
          _dailyQuota = 0.0;
        }
        _isLoadingQuota = false;
        notifyListeners();
      }, onError: (_) {
        _isLoadingQuota = false;
        notifyListeners();
      });
    } catch (_) {
      _isLoadingQuota = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isVerifying = true;
    _verificationError = null;
    notifyListeners();

    try {
      final info = await _authService.signInBranch(email: email, password: password);
      if (info != null && info.branchId.isNotEmpty) {
        _currentUser = _authService.currentUser;
        _currentBranch = info;
        _isInitializing = false;
        _isVerifying = false;
        _showLoginSuccessToast = true;
        _listenToBranchQuota();
        notifyListeners();
      } else {
        _isInitializing = false;
        _isVerifying = false;
        _verificationError = 'This account is not authorized for the Staff App.';
        notifyListeners();
      }
    } catch (e) {
      _isInitializing = false;
      _isVerifying = false;
      _verificationError = formatAuthError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _authService.signOutBranch();
    _currentUser = null;
    _currentBranch = null;
    _isInitializing = false;
    _isVerifying = false;
    _quotaSubscription?.cancel();
    _quotaSubscription = null;
    notifyListeners();
  }

  @visibleForTesting
  void setSessionForTesting({
    User? user,
    BranchInfo? branch,
    bool isInitializing = false,
    bool isVerifying = false,
    String? verificationError,
  }) {
    _currentUser = user;
    _currentBranch = branch;
    _isInitializing = isInitializing;
    _isVerifying = isVerifying;
    _verificationError = verificationError;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _quotaSubscription?.cancel();
    super.dispose();
  }
}
