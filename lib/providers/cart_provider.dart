import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'],
    name: json['name'],
    price: json['price'].toDouble(),
    quantity: json['quantity'],
  );
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isInitialized = false;

  CartProvider() {
    _loadCartFromLocalStorage();
  }

  List<CartItem> get items => [..._items];

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  int get itemCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  Future<void> addItem(String productId, String name, double price) async {
    final existingItemIndex = _items.indexWhere((item) => item.id == productId);

    if (existingItemIndex >= 0) {
      _items[existingItemIndex].quantity++;
    } else {
      _items.add(CartItem(id: productId, name: name, price: price));
    }

    await _saveCartToLocalStorage();
    notifyListeners();
  }

  Future<void> removeItem(String productId) async {
    _items.removeWhere((item) => item.id == productId);
    await _saveCartToLocalStorage();
    notifyListeners();
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    final itemIndex = _items.indexWhere((item) => item.id == productId);
    if (itemIndex >= 0) {
      if (quantity <= 0) {
        await removeItem(productId);
      } else {
        _items[itemIndex].quantity = quantity;
        await _saveCartToLocalStorage();
        notifyListeners();
      }
    }
  }

  Future<void> clear() async {
    _items.clear();
    await _saveCartToLocalStorage();
    notifyListeners();
  }

  // Save cart to local storage using shared preferences
  Future<void> _saveCartToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('cart', cartData);
    } catch (error) {
      debugPrint('Error saving cart to local storage: $error');
    }
  }

  // Load cart from local storage
  Future<void> _loadCartFromLocalStorage() async {
    try {
      if (_isInitialized) return;
      _isInitialized = true;

      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('cart');

      if (cartData != null && cartData.isNotEmpty) {
        final List<dynamic> itemsJson = jsonDecode(cartData);
        _items.clear();
        _items.addAll(
          itemsJson.map((item) => CartItem.fromJson(item)).toList(),
        );
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Error loading cart from local storage: $error');
    }
  }

  bool isInCart(String productId) {
    return _items.any((item) => item.id == productId);
  }

  int getQuantity(String productId) {
    final item = _items.firstWhere(
      (item) => item.id == productId,
      orElse: () => CartItem(id: productId, name: '', price: 0, quantity: 0),
    );
    return item.quantity;
  }
}
