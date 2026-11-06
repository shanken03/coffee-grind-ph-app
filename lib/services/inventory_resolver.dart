import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firebase_paths.dart';

/// Abstract adapter representing an inventory document from Firestore or a test fixture.
abstract class InventoryDocumentAdapter {
  String get id;
  DocumentReference get reference;
  Map<String, dynamic>? get data;
  bool get exists;
}

/// Production implementation wrapping a real Firestore [DocumentSnapshot].
class FirestoreDocumentAdapter implements InventoryDocumentAdapter {
  final DocumentSnapshot snapshot;

  const FirestoreDocumentAdapter(this.snapshot);

  @override
  String get id => snapshot.id;

  @override
  DocumentReference get reference => snapshot.reference;

  @override
  Map<String, dynamic>? get data => snapshot.data() as Map<String, dynamic>?;

  @override
  bool get exists => snapshot.exists;
}

typedef DocByIdLookup = Future<InventoryDocumentAdapter?> Function(String docId);
typedef FieldQueryLookup = Future<List<InventoryDocumentAdapter>> Function(String branchId, String ingredientId);

/// Resolves the unique, existing Firestore inventory document for a given branch and ingredient.
///
/// Follows the documented resolution order:
/// 1. Canonical ID: `${branchId}_${ingredientId}`
/// 2. Alternative Branch Prefix: `${altBranchId}_${ingredientId}` (if branchId starts with 'br_')
/// 3. Query Fallback: `.where('branchId', isEqualTo: ...).where('ingredientId', isEqualTo: ...)`
///
/// Fails safely if:
/// - Multiple candidates are found (ambiguity check).
/// - No record exists.
/// - The document belongs to another branch.
class InventoryDocumentResolver {
  final FirebaseFirestore? firestore;
  final DocByIdLookup? docByIdLookup;
  final FieldQueryLookup? fieldQueryLookup;

  InventoryDocumentResolver({
    this.firestore,
    this.docByIdLookup,
    this.fieldQueryLookup,
  });

  /// Returns the documented alternative branch ID if [branchId] starts with 'br_'.
  ///
  /// Matches the exact convention used in [InventoryProvider] and [RestockProvider]:
  /// `branchId.startsWith('br_') ? branchId.replaceFirst('br_', '').toUpperCase() : branchId`
  static String? getAlternativeBranchId(String branchId) {
    final clean = branchId.trim();
    if (clean.startsWith('br_')) {
      final alt = clean.replaceFirst('br_', '').toUpperCase();
      if (alt.isNotEmpty && alt != clean) {
        return alt;
      }
    }
    return null;
  }

  Future<InventoryDocumentAdapter?> _lookupById(String docId) async {
    final lookup = docByIdLookup;
    if (lookup != null) {
      return lookup(docId);
    }
    final db = firestore ?? FirebaseFirestore.instance;
    final doc = await db.collection(FirebasePaths.inventory).doc(docId).get();
    return FirestoreDocumentAdapter(doc);
  }

  Future<List<InventoryDocumentAdapter>> _queryByFields(String branchId, String ingredientId) async {
    final query = fieldQueryLookup;
    if (query != null) {
      return query(branchId, ingredientId);
    }
    final db = firestore ?? FirebaseFirestore.instance;
    final snap = await db
        .collection(FirebasePaths.inventory)
        .where('branchId', isEqualTo: branchId)
        .where('ingredientId', isEqualTo: ingredientId)
        .limit(2)
        .get();
    return snap.docs.map((d) => FirestoreDocumentAdapter(d)).toList();
  }

  /// Resolves the inventory document or throws an explanatory [Exception] if missing or ambiguous.
  Future<InventoryDocumentAdapter> resolve({
    required String branchId,
    required String ingredientId,
    String? ingredientName,
    String? branchName,
  }) async {
    final cleanBranch = branchId.trim();
    final cleanIngredient = ingredientId.trim();
    final displayName = (ingredientName != null && ingredientName.trim().isNotEmpty)
        ? ingredientName.trim()
        : cleanIngredient;
    final displayBranch = (branchName != null && branchName.trim().isNotEmpty)
        ? branchName.trim()
        : cleanBranch;

    if (cleanBranch.isEmpty || cleanIngredient.isEmpty) {
      throw Exception(
        'Cannot complete sale: Invalid branch ID ("$branchId") or ingredient ID ("$ingredientId")',
      );
    }

    // Step 1: Canonical direct ID (${branchId}_${ingredientId})
    final canonicalId = '${cleanBranch}_$cleanIngredient';
    final canonicalDoc = await _lookupById(canonicalId);
    if (canonicalDoc != null && canonicalDoc.exists && canonicalDoc.data != null) {
      final docBranch = (canonicalDoc.data?['branchId'] as String? ?? '').trim().toLowerCase();
      if (docBranch.isEmpty || docBranch == cleanBranch.toLowerCase()) {
        return canonicalDoc;
      }
    }

    // Step 2: Documented alternative branch-prefix ID
    final altBranch = getAlternativeBranchId(cleanBranch);
    if (altBranch != null && altBranch.isNotEmpty && altBranch != cleanBranch) {
      final altId = '${altBranch}_$cleanIngredient';
      final altDoc = await _lookupById(altId);
      if (altDoc != null && altDoc.exists && altDoc.data != null) {
        final docBranch = (altDoc.data?['branchId'] as String? ?? '').trim().toLowerCase();
        if (docBranch.isEmpty ||
            docBranch == cleanBranch.toLowerCase() ||
            docBranch == altBranch.toLowerCase()) {
          return altDoc;
        }
      }
    }

    // Step 3: Firestore query fallback using branch and ingredient fields
    final candidates = await _queryByFields(cleanBranch, cleanIngredient);
    if (candidates.length == 1) {
      final match = candidates.first;
      if (match.exists && match.data != null) {
        return match;
      }
    } else if (candidates.length > 1) {
      throw Exception(
        'Cannot complete sale: Ambiguous inventory records (${candidates.length} found) '
        'for ingredient "$displayName" at branch "$displayBranch". Checkout aborted for safety.',
      );
    }

    // If still not found and altBranch exists, query by altBranch
    if (altBranch != null && altBranch.isNotEmpty && altBranch != cleanBranch) {
      final altCandidates = await _queryByFields(altBranch, cleanIngredient);
      if (altCandidates.length == 1) {
        final match = altCandidates.first;
        if (match.exists && match.data != null) {
          return match;
        }
      } else if (altCandidates.length > 1) {
        throw Exception(
          'Cannot complete sale: Ambiguous inventory records (${altCandidates.length} found) '
          'for ingredient "$displayName" at branch "$displayBranch". Checkout aborted for safety.',
        );
      }
    }

    // Step 4: Missing record -> fail safely
    throw Exception(
      'Cannot complete sale: Missing inventory record for ingredient "$displayName" at branch "$displayBranch"',
    );
  }
}
