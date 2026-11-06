import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_paths.dart';
import '../models/restock_request_model.dart';
import '../models/ingredient_model.dart';

class RestockProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot>? _restockSubscription;
  StreamSubscription<QuerySnapshot>? _ingredientsSubscription;

  List<RestockRequestModel> _requests = [];
  List<IngredientModel> _ingredients = [];
  bool _isLoading = true;
  bool _isLoadingIngredients = true;
  String? _requestsErrorMessage;
  String? _ingredientsErrorMessage;
  String? _currentBranchId;

  RestockProvider({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  List<RestockRequestModel> get requests => List.unmodifiable(_requests);
  List<IngredientModel> get ingredients => List.unmodifiable(_ingredients);
  List<RestockRequestModel> get activeRequests => _requests
      .where(
        (r) =>
            r.status == RestockStatus.pending ||
            r.status == RestockStatus.approved,
      )
      .toList();
  List<RestockRequestModel> get historyRequests => _requests
      .where(
        (r) =>
            r.status == RestockStatus.received ||
            r.status == RestockStatus.rejected,
      )
      .toList();
  int get pendingCount =>
      _requests.where((r) => r.status == RestockStatus.pending).length;
  bool get isLoading => _isLoading;
  bool get isLoadingIngredients => _isLoadingIngredients;
  String? get requestsErrorMessage => _requestsErrorMessage;
  String? get ingredientsErrorMessage => _ingredientsErrorMessage;
  bool get hasRequestsError => _requestsErrorMessage != null;
  bool get hasIngredientsError => _ingredientsErrorMessage != null;
  String? get currentBranchId => _currentBranchId;

  @visibleForTesting
  void setIngredientsForTesting(List<IngredientModel> testIngredients) {
    _ingredientsSubscription?.cancel();
    _ingredientsSubscription = null;
    _ingredients = testIngredients;
    _isLoadingIngredients = false;
    _ingredientsErrorMessage = null;
    notifyListeners();
  }

  @visibleForTesting
  void setRequestsForTesting(List<RestockRequestModel> testRequests) {
    _restockSubscription?.cancel();
    _restockSubscription = null;
    _requests = testRequests;
    _isLoading = false;
    _requestsErrorMessage = null;
    notifyListeners();
  }

  void bindToBranch(String branchId) {
    final cleanBranchId = branchId.trim();
    if (cleanBranchId.isEmpty) return;

    final isSameBranch = _currentBranchId == cleanBranchId;

    // Return early ONLY if already successfully subscribed to this branch without errors
    if (isSameBranch &&
        _restockSubscription != null &&
        _requestsErrorMessage == null &&
        _ingredientsSubscription != null &&
        _ingredientsErrorMessage == null &&
        _ingredients.isNotEmpty) {
      return;
    }

    if (!isSameBranch) {
      _restockSubscription?.cancel();
      _restockSubscription = null;
      _ingredientsSubscription?.cancel();
      _ingredientsSubscription = null;
      _currentBranchId = cleanBranchId;
      _requestsErrorMessage = null;
      _ingredientsErrorMessage = null;
    }

    if (_ingredientsSubscription == null || _ingredientsErrorMessage != null || _ingredients.isEmpty) {
      _listenToIngredients();
      if (_ingredients.isEmpty) {
        _loadIngredientsFromBranchInventory(cleanBranchId);
      }
    }

    if (_restockSubscription == null || _requestsErrorMessage != null) {
      _listenToRestockRequests(cleanBranchId);
    }
  }

  Future<void> retryLoadIngredients() async {
    _ingredientsSubscription?.cancel();
    _ingredientsSubscription = null;
    _isLoadingIngredients = true;
    _ingredientsErrorMessage = null;
    notifyListeners();

    _listenToIngredients();
    if (_ingredients.isEmpty && _currentBranchId != null && _currentBranchId!.isNotEmpty) {
      _loadIngredientsFromBranchInventory(_currentBranchId!);
    }
  }

  void _listenToIngredients() {
    _ingredientsSubscription?.cancel();
    _ingredientsSubscription = null;
    _isLoadingIngredients = true;
    _ingredientsErrorMessage = null;
    notifyListeners();

    try {
      _ingredientsSubscription = _firestore
          .collection(FirebasePaths.ingredients)
          .snapshots()
          .listen(
            (snapshot) {
              final activeIngs = snapshot.docs
                  .map((doc) => IngredientModel.fromMap(doc.id, doc.data()))
                  .where((item) => item.isActive)
                  .toList();
              if (activeIngs.isNotEmpty) {
                _ingredients = activeIngs;
                _isLoadingIngredients = false;
                _ingredientsErrorMessage = null;
                notifyListeners();
              } else if (_currentBranchId != null && _currentBranchId!.isNotEmpty) {
                // If master catalog has no items, fall back to branch inventory
                _loadIngredientsFromBranchInventory(_currentBranchId!);
              } else {
                _ingredients = [];
                _isLoadingIngredients = false;
                _ingredientsErrorMessage = null;
                notifyListeners();
              }
            },
            onError: (error) {
              // If reading /ingredients fails (e.g. security rules or timing),
              // fall back to reading items from the branch's /inventory collection
              if (_currentBranchId != null && _currentBranchId!.isNotEmpty) {
                _loadIngredientsFromBranchInventory(_currentBranchId!);
              } else {
                _isLoadingIngredients = false;
                _ingredientsErrorMessage = error.toString();
                notifyListeners();
              }
            },
          );
    } catch (e) {
      if (_currentBranchId != null && _currentBranchId!.isNotEmpty) {
        _loadIngredientsFromBranchInventory(_currentBranchId!);
      } else {
        _isLoadingIngredients = false;
        _ingredientsErrorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  void _loadIngredientsFromBranchInventory(String branchId) {
    try {
      _firestore
          .collection(FirebasePaths.inventory)
          .where('branchId', isEqualTo: branchId)
          .get()
          .then((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              _ingredients = snapshot.docs.map((doc) {
                final d = doc.data();
                final rawType =
                    (d['itemType'] as String? ??
                            d['category'] as String? ??
                            'ingredient')
                        .toLowerCase();
                final ingId = (d['ingredientId'] as String? ?? doc.id).trim();
                final isPkg =
                    rawType.contains('pack') ||
                    rawType.contains('suppl') ||
                    ingId.startsWith('pkg_');
                return IngredientModel(
                  ingredientId: ingId,
                  name:
                      d['ingredientName'] as String? ??
                      d['name'] as String? ??
                      ingId,
                  unit: d['unit'] as String? ?? 'pcs',
                  itemType: isPkg ? 'packaging' : 'ingredient',
                  status: 'active',
                );
              }).toList();
              _isLoadingIngredients = false;
              _ingredientsErrorMessage = null;
              notifyListeners();
            } else {
              _isLoadingIngredients = false;
              if (_ingredients.isEmpty) {
                _ingredientsErrorMessage = 'No ingredients found for this branch.';
              }
              notifyListeners();
            }
          })
          .catchError((err) {
            _isLoadingIngredients = false;
            _ingredientsErrorMessage = err.toString();
            notifyListeners();
          });
    } catch (_) {
      _isLoadingIngredients = false;
      _ingredientsErrorMessage = 'Unable to load branch inventory items.';
      notifyListeners();
    }
  }

  void _listenToRestockRequests(String branchId) {
    _restockSubscription?.cancel();
    _restockSubscription = null;
    _isLoading = true;
    _requestsErrorMessage = null;
    notifyListeners();

    try {
      final cleanBranchId = branchId.trim();
      if (cleanBranchId.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _restockSubscription = _firestore
          .collection(FirebasePaths.restockRequests)
          .where('branchId', isEqualTo: cleanBranchId)
          .snapshots()
          .listen(
            (snapshot) {
              final loaded = snapshot.docs.map((doc) {
                final data = doc.data();
                final statusStr = (data['status'] as String? ?? 'pending')
                    .toLowerCase();
                RestockStatus status = RestockStatus.pending;
                if (statusStr == 'approved') status = RestockStatus.approved;
                if (statusStr == 'rejected') status = RestockStatus.rejected;
                if (statusStr == 'received') status = RestockStatus.received;

                DateTime createdAt = DateTime.now();
                if (data['requestedAt'] is Timestamp) {
                  createdAt = (data['requestedAt'] as Timestamp).toDate();
                } else if (data['createdAt'] is Timestamp) {
                  createdAt = (data['createdAt'] as Timestamp).toDate();
                }

                final bName = data['branchName'] as String? ??
                    data['branch_name'] as String? ??
                    cleanBranchId;
                final ingName = data['ingredientName'] as String? ??
                    data['item_name'] as String? ??
                    data['itemType'] as String? ??
                    'Item';
                final cat = data['category'] as String? ??
                    data['itemType'] as String? ??
                    'Ingredients';

                return RestockRequestModel(
                  id: data['requestId'] as String? ?? doc.id,
                  category: cat,
                  itemType: ingName,
                  quantity: (data['quantity'] as num?)?.toInt() ?? 1,
                  unit: data['unit'] as String? ?? 'pcs',
                  note: data['note'] as String?,
                  status: status,
                  createdAt: createdAt,
                  branchName: bName,
                );
              }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              _requests = loaded;
              _isLoading = false;
              _requestsErrorMessage = null;
              notifyListeners();
            },
            onError: (error) {
              _isLoading = false;
              _requestsErrorMessage = error.toString();
              notifyListeners();
            },
          );
    } catch (e) {
      _isLoading = false;
      _requestsErrorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addRequest({
    required String branchId,
    required String branchName,
    required String category,
    required String itemType,
    required int quantity,
    String unit = 'pcs',
    String? note,
    String staffId = 'STAFF_DEVICE',
    String staffName = 'Store Staff',
    String? ingredientId,
    String? ingredientName,
  }) async {
    final docRef = _firestore.collection(FirebasePaths.restockRequests).doc();
    final cleanBranchId = branchId.trim();
    final cleanBranchName = branchName.trim();
    final cleanItemType = itemType.trim();
    final cleanIngId = (ingredientId ?? cleanItemType.toLowerCase().replaceAll(' ', '_')).trim();
    final cleanIngName = (ingredientName ?? cleanItemType).trim();

    final requestData = {
      'requestId': docRef.id,
      'branchId': cleanBranchId,
      'branch_id': cleanBranchId,
      'branchName': cleanBranchName,
      'branch_name': cleanBranchName,
      'ingredientId': cleanIngId,
      'ingredient_id': cleanIngId,
      'ingredientName': cleanIngName,
      'item_name': cleanIngName,
      'itemType': cleanItemType,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'note': note,
      'status': 'pending', // Initial status is pending for Owner Web approval (staff cannot self-approve)
      'requestedByStaffId': staffId,
      'requestedByStaffName': staffName,
      'requestedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(requestData);
  }

  @override
  void dispose() {
    _restockSubscription?.cancel();
    _ingredientsSubscription?.cancel();
    super.dispose();
  }
}
