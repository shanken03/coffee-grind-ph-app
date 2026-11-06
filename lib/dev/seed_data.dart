import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_grind_ph/core/constants/firebase_paths.dart';

/// DEV-ONLY seed script. Run once via the button on FirebaseTestScreen,
/// then this whole file (and the button) gets deleted once the Owner Web
/// is managing this data for real. Never ship this to production.
class SeedData {
  static Future<void> seedEverything() async {
    final firestore = FirebaseFirestore.instance;
    await _seedBranches(firestore);
    await _seedProducts(firestore);
  }

  static Future<void> _seedBranches(FirebaseFirestore db) async {
    const branches = [
      'LSPU',
      'Santa Cruz',
      'Magdalena',
      'Bay',
      'Pila',
      'Cabuyao',
      'Calamba City',
    ];

    for (final name in branches) {
      final branchId = name.toLowerCase().replaceAll(' ', '_');
      await db.collection(FirebasePaths.branches).doc(branchId).set({
        'name': name,
        'address': '',
        'isActive': true,
      });

      await db.collection(FirebasePaths.quotas).doc(branchId).set({
        'daily': {'salesTarget': null, 'transactionTarget': null},
        'weekly': {'salesTarget': null, 'transactionTarget': null},
        'monthly': {'salesTarget': null, 'transactionTarget': null},
      });
    }
  }

  static Future<void> _seedProducts(FirebaseFirestore db) async {
    final batch = db.batch();
    final col = db.collection(FirebasePaths.products);

    void addCoffee(String name, double hotPrice, double icedPrice) {
      final doc = col.doc();
      batch.set(doc, {
        'name': name,
        'category': 'coffee',
        'description': '',
        'imageUrl': '',
        'isActive': true,
        'availableBranches': <String>[],
        'pricing': {
          'flatPrice': null,
          'sizePrices': null,
          'hotPrice': hotPrice,
          'icedPrice': icedPrice,
          'hotSizePrices': null,
          'icedSizePrices': null,
        },
        'recipeId': null,
      });
    }

    void addFlat(String name, String category, double? price) {
      final doc = col.doc();
      batch.set(doc, {
        'name': name,
        'category': category,
        'description': '',
        'imageUrl': '',
        'isActive': true,
        'availableBranches': <String>[],
        'pricing': {
          'flatPrice': price,
          'sizePrices': null,
          'hotPrice': null,
          'icedPrice': null,
          'hotSizePrices': null,
          'icedSizePrices': null,
        },
        'recipeId': null,
      });
    }

    void addNonCoffee(String name, double knownPrice) {
      final doc = col.doc();
      batch.set(doc, {
        'name': name,
        'category': 'nonCoffee',
        'description': '',
        'imageUrl': '',
        'isActive': true,
        'availableBranches': <String>[],
        'pricing': {
          'flatPrice': knownPrice,
          'sizePrices': {'small': null, 'medium': null, 'large': null},
          'hotPrice': null,
          'icedPrice': null,
          'hotSizePrices': null,
          'icedSizePrices': null,
        },
        'recipeId': null,
      });
    }

    addCoffee('Americano', 50, 60);
    addCoffee('Brewed Latte', 60, 75);
    addCoffee('Brown Sugar Latte', 60, 75);
    addCoffee('Cappuccino', 60, 75);
    addCoffee('Vanilla Latte', 60, 75);
    addCoffee('Caramel Macchiato', 65, 80);
    addCoffee("Barista's Choice", 65, 80);
    addCoffee('Spanish Latte', 65, 80);
    addCoffee('Spanish Mocha', 65, 80);
    addCoffee('Spanish White Choco', 65, 80);

    addNonCoffee('Choco Lava', 85);
    addNonCoffee('Dark Choco', 85);
    addNonCoffee('Matcha', 85);
    addNonCoffee('Strawberry', 85);

    addFlat('Double Chocolate', 'frappe', 110);
    addFlat('Caramel Drizzled', 'frappe', 100);
    addFlat('Cookies and Cream', 'frappe', 100);
    addFlat('Matcha Oreo', 'frappe', 100);
    addFlat('Strawberry Oreo', 'frappe', 100);

    addFlat('Lycheeberry', 'refreshers', 80);
    addFlat('Orangeberry', 'refreshers', 80);
    addFlat('Appleberry', 'refreshers', 80);

    addFlat('Chicken Rice Meal', 'foods', 89);
    addFlat('Hungarian Rice Meal', 'foods', 89);
    addFlat('Tonkatsu Rice Meal', 'foods', 89);
    addFlat('Carbonara', 'foods', 120);
    addFlat('Tuna Pesto', 'foods', 120);
    addFlat('Flavored Fries', 'foods', 70);
    addFlat('Chic and Fries', 'foods', 120);
    addFlat('Fries Overload', 'foods', 150);
    addFlat('Mojos', 'foods', 110);
    addFlat('Nachos', 'foods', 110);
    addFlat('V Salad', 'foods', 80);

    addFlat('Classic Cookie', 'sweets', 70);
    addFlat('Double Choco Cookie', 'sweets', 75);
    addFlat('Walnut Cookie', 'sweets', 80);
    addFlat('Matcha Cookie', 'sweets', 80);
    addFlat('Biscoff Cookie', 'sweets', 95);
    addFlat('Banana Muffin', 'sweets', 55);
    addFlat('Chocolate Banana Muffin', 'sweets', 65);
    addFlat('Blueberry Cheesecake', 'sweets', 125);
    addFlat('Oreo Cheesecake', 'sweets', 125);

    await batch.commit();
  }
}