// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_grind_ph/services/inventory_resolver.dart';

class FakeDocumentReference implements DocumentReference {
  @override
  final String id;
  @override
  final String path;

  FakeDocumentReference(this.id, [String? path]) : path = path ?? 'inventory/$id';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeInventoryDocumentAdapter implements InventoryDocumentAdapter {
  @override
  final String id;
  @override
  final DocumentReference reference;
  @override
  final Map<String, dynamic>? data;
  @override
  final bool exists;

  FakeInventoryDocumentAdapter({
    required this.id,
    DocumentReference? reference,
    this.data,
    this.exists = true,
  }) : reference = reference ?? FakeDocumentReference(id);
}

void main() {
  group('InventoryDocumentResolver Document ID Consistency Tests', () {
    test('1. Canonical document ID exists: checkout resolution uses that exact document', () async {
      final docs = <String, InventoryDocumentAdapter>{
        'br_stacruz_beans': FakeInventoryDocumentAdapter(
          id: 'br_stacruz_beans',
          data: {
            'branchId': 'br_stacruz',
            'ingredientId': 'beans',
            'quantity': 500.0,
            'unit': 'g',
            'ingredientName': 'Coffee Beans',
          },
        ),
      };

      final resolver = InventoryDocumentResolver(
        docByIdLookup: (docId) async => docs[docId],
        fieldQueryLookup: (bId, iId) async => [],
      );

      final result = await resolver.resolve(
        branchId: 'br_stacruz',
        ingredientId: 'beans',
        ingredientName: 'Coffee Beans',
        branchName: 'Santa Cruz',
      );

      expect(result.id, 'br_stacruz_beans');
      expect(result.data?['quantity'], 500.0);
    });

    test('2. Canonical ID is missing but valid documented alternative prefix exists: resolution uses existing alternative document', () async {
      final docs = <String, InventoryDocumentAdapter>{
        // Canonical 'br_stacruz_beans' is missing; Owner Web alternative 'STACRUZ_beans' exists
        'STACRUZ_beans': FakeInventoryDocumentAdapter(
          id: 'STACRUZ_beans',
          data: {
            'branchId': 'STACRUZ',
            'ingredientId': 'beans',
            'quantity': 350.0,
            'unit': 'g',
            'ingredientName': 'Coffee Beans',
          },
        ),
      };

      final resolver = InventoryDocumentResolver(
        docByIdLookup: (docId) async => docs[docId],
        fieldQueryLookup: (bId, iId) async => [],
      );

      final result = await resolver.resolve(
        branchId: 'br_stacruz',
        ingredientId: 'beans',
        ingredientName: 'Coffee Beans',
        branchName: 'Santa Cruz',
      );

      expect(result.id, 'STACRUZ_beans');
      expect(result.data?['quantity'], 350.0);
    });

    test('3. Canonical ID and alternative are missing but exactly one valid field match exists: resolution uses that document', () async {
      final queryDatabase = <InventoryDocumentAdapter>[
        FakeInventoryDocumentAdapter(
          id: 'doc_auto_id_999',
          data: {
            'branchId': 'br_stacruz',
            'ingredientId': 'beans',
            'quantity': 200.0,
            'unit': 'g',
            'ingredientName': 'Coffee Beans',
          },
        ),
      ];

      final resolver = InventoryDocumentResolver(
        docByIdLookup: (docId) async => null, // No ID match
        fieldQueryLookup: (bId, iId) async {
          return queryDatabase
              .where((d) => d.data?['branchId'] == bId && d.data?['ingredientId'] == iId)
              .toList();
        },
      );

      final result = await resolver.resolve(
        branchId: 'br_stacruz',
        ingredientId: 'beans',
        ingredientName: 'Coffee Beans',
        branchName: 'Santa Cruz',
      );

      expect(result.id, 'doc_auto_id_999');
      expect(result.data?['quantity'], 200.0);
    });

    test('4. No matching document: checkout fails safely and does not create an inventory document', () async {
      final resolver = InventoryDocumentResolver(
        docByIdLookup: (docId) async => null,
        fieldQueryLookup: (bId, iId) async => [],
      );

      expect(
        () => resolver.resolve(
          branchId: 'br_stacruz',
          ingredientId: 'missing_ingredient',
          ingredientName: 'Secret Syrup',
          branchName: 'Santa Cruz',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Missing inventory record for ingredient "Secret Syrup" at branch "Santa Cruz"'),
          ),
        ),
      );
    });

    test('5. Multiple matching records: checkout fails safely rather than selecting an arbitrary record', () async {
      // Two duplicate documents with same branchId and ingredientId
      final duplicateDocs = <InventoryDocumentAdapter>[
        FakeInventoryDocumentAdapter(
          id: 'doc_dup_1',
          data: {'branchId': 'br_stacruz', 'ingredientId': 'beans', 'quantity': 100.0},
        ),
        FakeInventoryDocumentAdapter(
          id: 'doc_dup_2',
          data: {'branchId': 'br_stacruz', 'ingredientId': 'beans', 'quantity': 150.0},
        ),
      ];

      final resolver = InventoryDocumentResolver(
        docByIdLookup: (docId) async => null,
        fieldQueryLookup: (bId, iId) async => duplicateDocs,
      );

      expect(
        () => resolver.resolve(
          branchId: 'br_stacruz',
          ingredientId: 'beans',
          ingredientName: 'Coffee Beans',
          branchName: 'Santa Cruz',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Ambiguous inventory records (2 found) for ingredient "Coffee Beans" at branch "Santa Cruz". Checkout aborted for safety.'),
          ),
        ),
      );
    });

    test('6. Branch isolation: a matching ingredient record belonging to another branch is never selected', () async {
      final otherBranchDocs = <String, InventoryDocumentAdapter>{
        'br_quiapo_beans': FakeInventoryDocumentAdapter(
          id: 'br_quiapo_beans',
          data: {
            'branchId': 'br_quiapo',
            'ingredientId': 'beans',
            'quantity': 900.0,
          },
        ),
      };

      final resolver = InventoryDocumentResolver(
        docByIdLookup: (docId) async => otherBranchDocs[docId],
        fieldQueryLookup: (bId, iId) async {
          return otherBranchDocs.values
              .where((d) => d.data?['branchId'] == bId && d.data?['ingredientId'] == iId)
              .toList();
        },
      );

      expect(
        () => resolver.resolve(
          branchId: 'br_stacruz',
          ingredientId: 'beans',
          ingredientName: 'Coffee Beans',
          branchName: 'Santa Cruz',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Missing inventory record for ingredient "Coffee Beans" at branch "Santa Cruz"'),
          ),
        ),
      );
    });

    test('7. The same resolved document reference is used for reading and deduction', () async {
      final sharedReference = FakeDocumentReference('doc_target_456');
      final docs = <String, InventoryDocumentAdapter>{
        'doc_target_456': FakeInventoryDocumentAdapter(
          id: 'doc_target_456',
          reference: sharedReference,
          data: {
            'branchId': 'br_stacruz',
            'ingredientId': 'milk',
            'quantity': 1000.0,
            'unit': 'ml',
          },
        ),
      };

      final resolver = InventoryDocumentResolver(
        docByIdLookup: (docId) async => null,
        fieldQueryLookup: (bId, iId) async => [docs['doc_target_456']!],
      );

      final resolved = await resolver.resolve(
        branchId: 'br_stacruz',
        ingredientId: 'milk',
      );

      // Verify reference identity
      expect(identical(resolved.reference, sharedReference), isTrue);
      expect(resolved.reference.id, 'doc_target_456');
    });

    test('8. getAlternativeBranchId handles prefixes consistently with existing providers', () {
      expect(InventoryDocumentResolver.getAlternativeBranchId('br_1790905840872'), '1790905840872');
      expect(InventoryDocumentResolver.getAlternativeBranchId('br_stacruz'), 'STACRUZ');
      expect(InventoryDocumentResolver.getAlternativeBranchId('br_quiapo'), 'QUIAPO');
      expect(InventoryDocumentResolver.getAlternativeBranchId('santa_cruz'), isNull);
      expect(InventoryDocumentResolver.getAlternativeBranchId('LSPU'), isNull);
    });
  });
}
