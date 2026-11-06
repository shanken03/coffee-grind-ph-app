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
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
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
      final accountType = (data['accountType'] as String? ?? '').toLowerCase();

      if (accountType != 'branch') {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'This account is not authorized for the Staff App.',
        );
      }

      final branchId = data['branchId'] as String? ?? '';
      if (branchId.isEmpty) {
        await signOutBranch();
        throw FirebaseAuthException(
          code: 'unauthorized-device',
          message: 'This account is not authorized for the Staff App.',
        );
      }

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

    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    final userCredential = await auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: cleanPassword,
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

  /// Sign out branch device
  Future<void> signOutBranch() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
  }
}
