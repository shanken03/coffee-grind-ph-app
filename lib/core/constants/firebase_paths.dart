/// Firestore collection paths — centralized for shared Owner Web & Staff App integration.
class FirebasePaths {
  FirebasePaths._();

  static const String users = 'users';
  static const String branches = 'branches';
  static const String branchAccounts = 'branch_accounts';
  static const String quotas = 'quotas';
  static const String products = 'products';
  static const String recipes = 'recipes';
  static const String ingredients = 'ingredients';
  static const String inventoryItems = 'inventory_items';
  static const String inventory =
      'inventory'; // inventory/{branchId}_{ingredientId}
  @Deprecated('Replaced by recipe-based physical inventory')
  static const String branchProductStock = 'branch_product_stock'; // Deprecated - replaced by recipe-based inventory
  static const String sales = 'sales';
  static const String inventoryTransactions = 'inventory_transactions';
  static const String restockRequests = 'restock_requests';
  static const String attendance = 'attendance';
  static const String notifications = 'notifications';
  static const String announcements = 'announcements';
  static const String concerns = 'concerns';
  static const String branchPaymentSettings = 'branch_payment_settings';
}
