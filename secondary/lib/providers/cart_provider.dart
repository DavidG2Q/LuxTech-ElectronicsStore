import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';

class CartProvider with ChangeNotifier {
  // Cart items list
  final Map<String, CartItem> _items = {};
  final ProductProvider _productProvider;
  static const String _cartKey = 'cart_items';
  bool _isInitialized = false;

  CartProvider(this._productProvider) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!_isInitialized) {
      await _loadCartItems();
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Load cart items from local storage
  Future<void> _loadCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString(_cartKey);
      
      if (cartData != null) {
        final Map<String, dynamic> decodedData = json.decode(cartData);
        _items.clear();
        decodedData.forEach((key, value) {
          final cartItem = CartItem.fromJson(value);
          // Verify product exists and has stock before adding to cart
          if (_productProvider.findById(cartItem.productId) != null &&
              _productProvider.getProductQuantity(cartItem.productId) > 0) {
            _items[key] = cartItem;
          }
        });
        print('Successfully loaded ${_items.length} cart items from SharedPreferences');
      }
    } catch (e) {
      print('Error loading cart items: $e');
    }
  }

  // Save cart items to local storage
  Future<void> _saveCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = json.encode(_items.map((key, value) => MapEntry(key, value.toJson())));
      await prefs.setString(_cartKey, cartData);
      print('Successfully saved ${_items.length} cart items to SharedPreferences');
    } catch (e) {
      print('Error saving cart items: $e');
    }
  }

  // Get all cart items
  Map<String, CartItem> get items {
    if (!_isInitialized) {
      _initialize();
    }
    return {..._items};
  }

  // Number of items in the cart
  int get itemCount {
    if (!_isInitialized) {
      _initialize();
    }
    return _items.length;
  }

  // Total amount in the cart
  double get totalAmount {
    if (!_isInitialized) {
      _initialize();
    }
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  // Add product to cart
  Future<void> addItem(
    Product product,
    String selectedColor,
    String selectedSize,
    double selectedPrice,
  ) async {
    if (!_isInitialized) {
      await _initialize();
    }
    
    // Check available stock
    int availableStock = _productProvider.getProductQuantity(product.id);
    
    // Create unique ID for the product with selected color and size
    final cartItemId = '${product.id}_${selectedColor}_${selectedSize}';
    
    if (_items.containsKey(cartItemId)) {
      // Check if we can add more of this product
      final currentQuantity = _items[cartItemId]!.quantity;
      if (currentQuantity >= availableStock) {
        // Cannot add more than available stock
        return;
      }
      
      // Increase quantity if product already exists
      _items.update(
        cartItemId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          productId: existingCartItem.productId,
          name: existingCartItem.name,
          price: existingCartItem.price,
          quantity: existingCartItem.quantity + 1,
          imageUrl: existingCartItem.imageUrl,
          color: existingCartItem.color,
          size: existingCartItem.size,
        ),
      );
    } else {
      // Check if product is available
      if (availableStock <= 0) {
        return;
      }
      
      // Add new product to cart
      _items.putIfAbsent(
        cartItemId,
        () => CartItem(
          id: cartItemId,
          productId: product.id,
          name: product.name,
          price: selectedPrice,
          quantity: 1,
          imageUrl: product.imageUrl,
          color: selectedColor,
          size: selectedSize,
        ),
      );
    }
    
    await _saveCartItems();
    notifyListeners();
  }

  // Update quantity of a product in the cart
  void updateQuantity(String id, int quantity) async {
    if (!_items.containsKey(id)) {
      return;
    }
    
    // Get product ID from cart item ID
    final productId = _items[id]!.productId;
    
    // Check available stock
    int availableStock = _productProvider.getProductQuantity(productId);
    
    if (quantity <= 0) {
      // Remove item if quantity is 0 or less
      _items.remove(id);
    } else if (quantity <= availableStock) {
      // Update quantity if within available stock
      _items.update(
        id,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          productId: existingCartItem.productId,
          name: existingCartItem.name,
          price: existingCartItem.price,
          quantity: quantity,
          imageUrl: existingCartItem.imageUrl,
          color: existingCartItem.color,
          size: existingCartItem.size,
        ),
      );
    }
    
    await _saveCartItems();
    notifyListeners();
  }

  // Remove product from cart
  void removeItem(String id) async {
    _items.remove(id);
    await _saveCartItems();
    notifyListeners();
  }

  // Clear the cart
  void clear() async {
    _items.clear();
    await _saveCartItems();
    notifyListeners();
  }
  
  // Process order and update stock
  Future<void> processOrder() async {
    // Update product quantities
    _items.forEach((key, cartItem) {
      final productId = cartItem.productId;
      final quantity = cartItem.quantity;
      
      // Get current stock
      final currentStock = _productProvider.getProductQuantity(productId);
      
      // Update stock
      _productProvider.updateProductQuantity(productId, currentStock - quantity);
    });
    
    // Clear cart
    clear();
  }
  
  // Check if a product is available in the requested quantity
  bool isProductAvailable(String productId, int requestedQuantity) {
    final availableStock = _productProvider.getProductQuantity(productId);
    return requestedQuantity <= availableStock;
  }
  
  // Get available stock for a product
  int getAvailableStock(String productId) {
    return _productProvider.getProductQuantity(productId);
  }
}