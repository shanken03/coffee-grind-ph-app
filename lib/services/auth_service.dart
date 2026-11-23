import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firebase_paths.dart';

class BranchInfo {
  final String branchId;
  final String name;
  final String email;

  const BranchInfo({
    required this.branchId,
    required this.name,
    required this.email,
  });
}

class AuthService {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _customAuth = auth,
        _customFirestore = firestore;

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth?.authStateChanges() ?? const Stream.empty();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Verify authenticated user's UID against branch_accounts/{uid} in Firestore
  Future<BranchInfo?> verifyAndGetBranchInfo(User? user) async {
    if (user == null) return null;
    final firestore = _firestore;
    if (firestore == null) return null;

    try {
      final doc = await firestore
          .collection(FirebasePaths.branchAccounts)
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'This account is not authorized for the Staff App.',
        );
      }

      final data = doc.data()!;

      // 1. Account type and role validation
      final hasRole = data.containsKey('role') && data['role'] != null;
      final hasAccountType = data.containsKey('accountType') && data['accountType'] != null;

      if (!hasRole && !hasAccountType) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'This account is not authorized for the Staff App.',
        );
      }

      final roleVal = hasRole ? (data['role'] as String? ?? '').trim().toLowerCase() : null;
      final accountTypeVal = hasAccountType ? (data['accountType'] as String? ?? '').trim().toLowerCase() : null;

      const authorizedRoles = {'branch', 'staff'};

      if (hasRole && !authorizedRoles.contains(roleVal)) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'This account is not authorized for the Staff App.',
        );
      }

      if (hasAccountType && !authorizedRoles.contains(accountTypeVal)) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'This account is not authorized for the Staff App.',
        );
      }

      // If both fields exist and conflict, reject session
      if (hasRole && hasAccountType && roleVal != accountTypeVal) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'Account role configuration conflict.',
        );
      }

      // 2. Active account validation
      final hasActive = data.containsKey('active') && data['active'] != null;
      final hasIsActive = data.containsKey('isActive') && data['isActive'] != null;
      final hasStatus = data.containsKey('status') && data['status'] != null;

      if (!hasActive && !hasIsActive && !hasStatus) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'Account active status is missing or ambiguous.',
        );
      }

      bool? boolActive;
      if (hasActive && hasIsActive) {
        final a = data['active'] == true;
        final ia = data['isActive'] == true;
        if (a != ia) {
          await signOutBranch();
          throw FirebaseAuthException(
            code: 'user-disabled',
            message: 'This branch account has been disabled. Please contact the administrator.',
          );
        }
        boolActive = a;
      } else if (hasActive) {
        boolActive = data['active'] == true;
      } else if (hasIsActive) {
        boolActive = data['isActive'] == true;
      }

      bool? statusActive;
      if (hasStatus) {
        final statusStr = (data['status'] as String? ?? '').trim().toLowerCase();
        if (statusStr == 'active' || statusStr == 'open') {
          statusActive = true;
        } else {
          statusActive = false;
        }
      }

      // Reject if boolean flag and status string contradict each other
      if (boolActive != null && statusActive != null && boolActive != statusActive) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'This branch account has been disabled. Please contact the administrator.',
        );
      }

      final isAccountActive = (boolActive ?? statusActive) == true;
      if (!isAccountActive) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'This branch account has been disabled. Please contact the administrator.',
        );
      }

      // 3. Branch ID validation
      final hasBranchId = data.containsKey('branchId') && data['branchId'] != null;
      final hasSnakeBranchId = data.containsKey('branch_id') && data['branch_id'] != null;

      final branchIdVal = hasBranchId ? (data['branchId'] as String? ?? '').trim() : '';
      final snakeBranchIdVal = hasSnakeBranchId ? (data['branch_id'] as String? ?? '').trim() : '';

      if (branchIdVal.isEmpty && snakeBranchIdVal.isEmpty) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'This account has no valid branch assignment.',
        );
      }

      if (branchIdVal.isNotEmpty && snakeBranchIdVal.isNotEmpty && branchIdVal != snakeBranchIdVal) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'Branch assignment conflict detected.',
        );
      }

      final branchId = branchIdVal.isNotEmpty ? branchIdVal : snakeBranchIdVal;

      String branchName = data['branchName'] as String? ?? data['name'] as String? ?? '';

      if (branchName.isEmpty) {
        try {
          final branchDoc = await firestore.collection(FirebasePaths.branches).doc(branchId).get();
          if (branchDoc.exists && branchDoc.data() != null) {
            final bData = branchDoc.data()!;
            branchName = bData['name'] as String? ?? bData['branchName'] as String? ?? '';
          }
        } catch (_) {}
      }

      if (branchName.isEmpty) {
        if (branchId == 'br_1790905840872') {
          branchName = 'Santa Cruz';
        } else if (branchId == 'br_1790923872261') {
          branchName = 'LSPU';
        } else {
          branchName = branchId;
        }
      }

      return BranchInfo(
        branchId: branchId,
        name: branchName,
        email: user.email ?? '',
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        rethrow;
      }
      await signOutBranch();
      throw FirebaseAuthException(
        code: 'unauthorized-device',
        message: 'This account is not authorized for the Staff App.',
      );
    }
  }

  /// Sign in using branch email and password via Firebase Authentication
  /// and verify UID against branch_accounts/{uid} in Firestore.
  Future<BranchInfo?> signInBranch({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw FirebaseAuthException(
        code: 'app-not-initialized',
        message: 'Firebase is not initialized.',
      );
    }

    final cleanEmail = email.trim().toLowerCase();
    // Password is NEVER trimmed, lowercased, or modified

    final userCredential = await auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Authentication failed.',
      );
    }

    return await verifyAndGetBranchInfo(user);
  }

  /// Send password reset email using Firebase Authentication
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw FirebaseAuthException(
        code: 'app-not-initialized',
        message: 'Firebase is not initialized.',
      );
    }

    final cleanEmail = email.trim().toLowerCase();
    await auth.sendPasswordResetEmail(email: cleanEmail);
  }

  /// Sign out branch device
  Future<void> signOutBranch() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
  }
}
