import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';
import 'package:coffee_grind_ph/models/branch_product_serving_model.dart';

void main() {
  group('BranchProductServingModel Schema & Validation Tests', () {
    const santaCruzBranch = 'br_1790905840872';
    const lspuBranch = 'br_1790923872261';
    const testProductId = 'spanish_latte';

    test('FirebasePaths includes branchProductServings constant', () {
      expect(FirebasePaths.branchProductServings, 'branch_product_servings');
    });

    test('buildDocumentId formats {branchId}_{productId} correctly', () {
      final docId = BranchProductServingModel.buildDocumentId(santaCruzBranch, testProductId);
      expect(docId, '${santaCruzBranch}_$testProductId');

      final lspuDocId = BranchProductServingModel.buildDocumentId(lspuBranch, 'americano');
      expect(lspuDocId, '${lspuBranch}_americano');
    });

    test('buildDocumentId rejects empty branchId or productId', () {
      expect(
        () => BranchProductServingModel.buildDocumentId('', testProductId),
        throwsArgumentError,
      );
      expect(
        () => BranchProductServingModel.buildDocumentId(santaCruzBranch, '  '),
        throwsArgumentError,
      );
    });

    test('Parses valid Web Admin document format with exact fields and Timestamps', () {
      final now = DateTime.now();
      final data = {
        'branchId': santaCruzBranch,
        'productId': testProductId,
        'manualMaxServings': 50,
        'remainingServings': 35,
        'isEnabled': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final model = BranchProductServingModel.fromFirestore(
        '${santaCruzBranch}_$testProductId',
        data,
      );

      expect(model.branchId, santaCruzBranch);
      expect(model.productId, testProductId);
      expect(model.manualMaxServings, 50);
      expect(model.remainingServings, 35);
      expect(model.isEnabled, isTrue);
      expect(model.isAvailable, isTrue);
      expect(model.isOutOfStock, isFalse);
      expect(model.isDepleted, isFalse);
      expect(model.documentId, '${santaCruzBranch}_$testProductId');
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
    });

    test('Preserves valid zero values for manualMaxServings and remainingServings', () {
      final data = {
        'branchId': santaCruzBranch,
        'productId': testProductId,
        'manualMaxServings': 0,
        'remainingServings': 0,
        'isEnabled': true,
      };

      final model = BranchProductServingModel.fromFirestore(
        '${santaCruzBranch}_$testProductId',
        data,
      );

      expect(model.manualMaxServings, 0);
      expect(model.remainingServings, 0);
      expect(model.isDepleted, isTrue);
      expect(model.isOutOfStock, isTrue);
    });

    test('Negative manualMaxServings throws FormatException', () {
      final data = {
        'branchId': santaCruzBranch,
        'productId': testProductId,
        'manualMaxServings': -10,
        'remainingServings': 20,
        'isEnabled': true,
      };

      expect(
        () => BranchProductServingModel.fromFirestore(
          '${santaCruzBranch}_$testProductId',
          data,
        ),
        throwsFormatException,
      );

      expect(
        () => BranchProductServingModel(
          branchId: santaCruzBranch,
          productId: testProductId,
          manualMaxServings: -5,
          remainingServings: 20,
        ),
        throwsFormatException,
      );
    });

    test('Negative remainingServings throws FormatException', () {
      final data = {
        'branchId': santaCruzBranch,
        'productId': testProductId,
        'manualMaxServings': 50,
        'remainingServings': -1,
        'isEnabled': true,
      };

      expect(
        () => BranchProductServingModel.fromFirestore(
          '${santaCruzBranch}_$testProductId',
          data,
        ),
        throwsFormatException,
      );

      expect(
        () => BranchProductServingModel(
          branchId: santaCruzBranch,
          productId: testProductId,
          manualMaxServings: 50,
          remainingServings: -1,
        ),
        throwsFormatException,
      );
    });

    test('Enabled zero remaining is considered depleted and out of stock', () {
      final data = {
        'branchId': santaCruzBranch,
        'productId': testProductId,
        'manualMaxServings': 50,
        'remainingServings': 0,
        'isEnabled': true,
      };

      final model = BranchProductServingModel.fromFirestore(
        '${santaCruzBranch}_$testProductId',
        data,
      );

      expect(model.isDepleted, isTrue);
      expect(model.isOutOfStock, isTrue);
      expect(model.isAvailable, isFalse);
      // Depleted quota restricts effective sellable servings to 0 regardless of physical stock
      expect(model.computeEffectiveServings(30), 0);
    });

    test('Disabled quota is NOT considered depleted or out of stock', () {
      final data = {
        'branchId': santaCruzBranch,
        'productId': testProductId,
        'manualMaxServings': 50,
        'remainingServings': 0,
        'isEnabled': false,
      };

      final model = BranchProductServingModel.fromFirestore(
        '${santaCruzBranch}_$testProductId',
        data,
      );

      expect(model.isEnabled, isFalse);
      expect(model.isOutOfStock, isFalse, reason: 'Disabled quota must NOT mean out of stock');
      expect(model.isDepleted, isFalse, reason: 'Disabled quota is not considered depleted');
      expect(model.isAvailable, isTrue, reason: 'Disabled quota must permit physical inventory fallback');
    });

    test('Disabled quota uses physical inventory fallback in computeEffectiveServings', () {
      // Even if remainingServings is 0, disabled quota bypasses manual restriction
      final disabledModelZeroRemaining = BranchProductServingModel(
        branchId: santaCruzBranch,
        productId: testProductId,
        manualMaxServings: 50,
        remainingServings: 0,
        isEnabled: false,
      );
      expect(disabledModelZeroRemaining.computeEffectiveServings(25), 25);

      // Even if remainingServings is 5 and physical is 40, disabled quota returns 40
      final disabledModelLowRemaining = BranchProductServingModel(
        branchId: santaCruzBranch,
        productId: testProductId,
        manualMaxServings: 50,
        remainingServings: 5,
        isEnabled: false,
      );
      expect(disabledModelLowRemaining.computeEffectiveServings(40), 40);
    });

    test('Enabled quota returns the lower of remaining manual servings and physical stock', () {
      final enabledModel = BranchProductServingModel(
        branchId: santaCruzBranch,
        productId: testProductId,
        manualMaxServings: 50,
        remainingServings: 12,
        isEnabled: true,
      );

      // When manual is lower (12 < 30), return 12
      expect(enabledModel.computeEffectiveServings(30), 12);

      // When physical is lower (8 < 12), return 8
      expect(enabledModel.computeEffectiveServings(8), 8);
    });

    test('Actual Web Admin field compatibility: handles missing optional timestamps and lastUpdated', () {
      final updatedTime = DateTime(2026, 11, 18, 5, 0);
      final dataWithLastUpdated = {
        'branchId': santaCruzBranch,
        'productId': 'americano',
        'manualMaxServings': 30,
        'remainingServings': 12,
        'isEnabled': true,
        'lastUpdated': Timestamp.fromDate(updatedTime),
      };

      final model = BranchProductServingModel.fromFirestore(
        '${santaCruzBranch}_americano',
        dataWithLastUpdated,
      );

      expect(model.updatedAt, updatedTime);
      expect(model.createdAt, isNull);

      // Serializes back to Firestore map matching Web Admin schema
      final map = model.toFirestore();
      expect(map['branchId'], santaCruzBranch);
      expect(map['productId'], 'americano');
      expect(map['manualMaxServings'], 30);
      expect(map['remainingServings'], 12);
      expect(map['isEnabled'], isTrue);
      expect(map['updatedAt'], isA<Timestamp>());
      expect(map.containsKey('createdAt'), isFalse);
    });

    test('Extracts branchId and productId from docId if missing in map (including br_ prefix)', () {
      final data = {
        'manualMaxServings': 40,
        'remainingServings': 15,
        'isEnabled': true,
      };

      final model = BranchProductServingModel.fromFirestore(
        '${lspuBranch}_mocha',
        data,
      );

      expect(model.branchId, lspuBranch);
      expect(model.productId, 'mocha');
    });

    test('Throws FormatException if document ID contradicts internal branchId or productId', () {
      final data = {
        'branchId': santaCruzBranch,
        'productId': 'spanish_latte',
        'manualMaxServings': 50,
        'remainingServings': 20,
        'isEnabled': true,
      };

      expect(
        () => BranchProductServingModel.fromFirestore(
          '${lspuBranch}_spanish_latte',
          data,
        ),
        throwsFormatException,
      );
    });
  });
}
