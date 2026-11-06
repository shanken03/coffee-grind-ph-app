import 'product_model.dart';

class CartItemModel {
  final String id;
  final ProductModel product;
  final String? selectedTemperature; // 'Hot' | 'Iced' | null
  final String? selectedSize; // 'Small' | 'Medium' | 'Large' | null
  final double unitPrice;
  int quantity;

  CartItemModel({
    required this.id,
    required this.product,
    this.selectedTemperature,
    this.selectedSize,
    required this.unitPrice,
    this.quantity = 1,
  });

  double get subtotal => unitPrice * quantity;

  String get variantLabel {
    final parts = <String>[];
    if (selectedSize != null && selectedSize!.isNotEmpty) {
      parts.add(selectedSize!);
    }
    if (selectedTemperature != null && selectedTemperature!.isNotEmpty) {
      parts.add(selectedTemperature!);
    }
    if (parts.isNotEmpty) {
      return parts.join(' • ');
    }
    return 'Regular';
  }

  CartItemModel copyWith({
    int? quantity,
    double? unitPrice,
    String? selectedTemperature,
    String? selectedSize,
  }) {
    return CartItemModel(
      id: id,
      product: product,
      selectedTemperature: selectedTemperature ?? this.selectedTemperature,
      selectedSize: selectedSize ?? this.selectedSize,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}
