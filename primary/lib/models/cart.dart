import '../models/product.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;
}

class Cart {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void addProduct(Product product) {
    final existingItemIndex = _items.indexWhere(
      (item) => item.id == product.id,
    );

    if (existingItemIndex >= 0) {
      _items[existingItemIndex].quantity++;
    } else {
      _items.add(
        CartItem(id: product.id, name: product.name, price: product.price),
      );
    }
  }

  void removeProduct(String productId) {
    _items.removeWhere((item) => item.id == productId);
  }

  void decreaseQuantity(String productId) {
    final existingItemIndex = _items.indexWhere((item) => item.id == productId);

    if (existingItemIndex >= 0) {
      if (_items[existingItemIndex].quantity > 1) {
        _items[existingItemIndex].quantity--;
      } else {
        _items.removeAt(existingItemIndex);
      }
    }
  }

  void clear() {
    _items.clear();
  }
}
