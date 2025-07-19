import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'product_provider.dart';
import 'dart:convert';

class WishlistProvider with ChangeNotifier {
  final ProductProvider productProvider;
  List<String> _wishlistItems = [];
  bool _isInitialized = false;

  WishlistProvider(this.productProvider) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!_isInitialized) {
      await _loadWishlistFromPrefs();
      _isInitialized = true;
      notifyListeners();
    }
  }

  List<String> get wishlistItems {
    if (!_isInitialized) {
      _initialize();
    }
    return [..._wishlistItems];
  }

  List<Product> get wishlistProducts {
    if (!_isInitialized) {
      _initialize();
    }
    return _wishlistItems
        .map((productId) => productProvider.findById(productId))
        .whereType<Product>()
        .toList();
  }

  bool isInWishlist(String productId) {
    if (!_isInitialized) {
      _initialize();
    }
    return _wishlistItems.contains(productId);
  }

  Future<void> toggleWishlistItem(String productId) async {
    if (!_isInitialized) {
      await _initialize();
    }
    if (_wishlistItems.contains(productId)) {
      _wishlistItems.remove(productId);
    } else {
      _wishlistItems.add(productId);
    }
    notifyListeners();
    await _saveWishlistToPrefs();
  }

  Future<void> removeFromWishlist(String productId) async {
    if (!_isInitialized) {
      await _initialize();
    }
    _wishlistItems.remove(productId);
    notifyListeners();
    await _saveWishlistToPrefs();
  }

  Future<void> _saveWishlistToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistData = json.encode(_wishlistItems);
      await prefs.setString('wishlist', wishlistData);
      print('Successfully saved ${_wishlistItems.length} wishlist items to SharedPreferences');
    } catch (e) {
      print('Error saving wishlist items: $e');
    }
  }

  Future<void> _loadWishlistFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('wishlist')) {
        final wishlistData = prefs.getString('wishlist');
        if (wishlistData != null) {
          _wishlistItems = List<String>.from(json.decode(wishlistData));
          print('Successfully loaded ${_wishlistItems.length} wishlist items from SharedPreferences');
        }
      }
    } catch (e) {
      print('Error loading wishlist items: $e');
    }
  }

  int get itemCount {
    if (!_isInitialized) {
      _initialize();
    }
    return _wishlistItems.length;
  }
}
