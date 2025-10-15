import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart.dart';
import '../providers/cart_provider.dart';
import 'dart:async';

class ProductService extends ChangeNotifier {
  final List<Category> _categories = [];
  final List<Product> _products = [];
  final Cart _cart = Cart();
  final _searchController = StreamController<List<Product>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  CartProvider? _cartProvider;

  // Cache for category products
  final Map<String, List<Product>> _categoryProductsCache = {};

  // Getters
  List<Category> get categories => List.unmodifiable(_categories);
  List<Product> get products => List.unmodifiable(_products);
  Cart get cart => _cart;
  Stream<List<Product>> get searchResults => _searchController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Update constructor to allow passing CartProvider
  ProductService({CartProvider? cartProvider}) : _cartProvider = cartProvider {
    _loadData();
  }

  // Method to set CartProvider later (useful for provider pattern)
  void setCartProvider(CartProvider cartProvider) {
    _cartProvider = cartProvider;
  }

  @override
  void dispose() {
    _searchController.close();
    _errorController.close();
    super.dispose();
  }

  void _handleError(String error) {
    _errorController.add(error);
    debugPrint(error);
  }

  Future<void> _loadData() async {
    try {
      // Load categories
      _categories.addAll([
        Category(
          id: 'cat1',
          name: 'Reading & Recognition Devices',
          description: 'Devices that help with reading and recognizing objects',
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/ReaderPen.jpg',
        ),
        Category(
          id: 'cat2',
          name: 'Daily Living Tools',
          description: 'Tools that assist with everyday tasks',
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/SonnetTalkingClock.jpg',
        ),
        Category(
          id: 'cat3',
          name: 'Navigation Aids',
          description: 'Devices that help with navigation and mobility',
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/WewalkCane.jpg',
        ),
      ]);

      // Load products
      _products.addAll([
        Product(
          id: 'prod1',
          name: 'C-Pen Text to Speech Reader Pen 2',
          description:
              'An electronic smart digital scanner that defines and reads aloud words. Includes an audio boost for better hearing. Suitable for all age groups.',
          price: 4544.99,
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/ReaderPen.jpg',
          category: 'cat1',
        ),
        Product(
          id: 'prod2',
          name: 'OrCam MyEye Pro',
          description:
              'A wearable assistive device that attaches to eyeglasses and offers smart reading, face recognition, and color/product identification.',
          price: 6799.99,
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/OrCamMyEye.jpg',
          category: 'cat1',
        ),
        Product(
          id: 'prod3',
          name: 'Sonnet Talking Alarm Clock',
          description:
              'A clock with hourly voice notifications, large display, temperature reading, and blue backlight.',
          price: 249.99,
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/SonnetTalkingClock.jpg',
          category: 'cat2',
        ),
        Product(
          id: 'prod4',
          name: 'Reizen RL-350 Braille Labeler',
          description:
              'A handheld Braille labeler with a comfortable grip and simple tape loading. Comes with one free roll of vinyl tape.',
          price: 369.99,
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/ReizenBrailleLabeler.jpg',
          category: 'cat2',
        ),
        Product(
          id: 'prod5',
          name: 'Liquid Level Beeping Indicator',
          description:
              'Easily attaches to glasses and cups. Emits audible alerts to indicate liquid levels and prevent spills.',
          price: 169.99,
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/LiquidLevelIndicator.jpg',
          category: 'cat2',
        ),
        Product(
          id: 'prod6',
          name: 'WeWalk Smart Cane',
          description:
              'Detects head/chest-level obstacles using sensors. Vibration and audio alerts. Turn-by-turn voice navigation. Real-time public transit information. Built-in GPT-powered voice assistant. Touchpad control. Water-resistant. Bluetooth audio support.',
          price: 3579.99,
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/WewalkCane.jpg',
          category: 'cat3',
          features: [
            'Detects head/chest-level obstacles using sensors',
            'Vibration and audio alerts',
            'Turn-by-turn voice navigation',
            'Real-time public transit information',
            'Built-in GPT-powered voice assistant',
            'Touchpad control',
            'Water-resistant',
            'Bluetooth audio support',
          ],
        ),
        Product(
          id: 'prod7',
          name: 'Sunu Band Premium',
          description:
              'Helps with navigation by detecting obstacles up to 16 feet away using echolocation. Provides haptic feedback for distance, detects obstacles from knees to head, and features gesture controls for hands-free use. Includes GPS, haptic compass, and place-finder app. Complements a cane or guide dog.',
          price: 2459.99,
          imageUrl:
              'https://qahmiqcrdigumpugeavt.supabase.co/storage/v1/object/public/products/primary/SunuSmartBand.jpg',
          category: 'cat3',
        ),
      ]);

      notifyListeners();
    } catch (e) {
      _handleError('Failed to load data: $e');
    }
  }

  List<Product> getProductsByCategory(String categoryId) {
    // Check cache first
    if (_categoryProductsCache.containsKey(categoryId)) {
      return _categoryProductsCache[categoryId]!;
    }

    // If not in cache, filter and cache the results
    final products =
        _products.where((product) => product.category == categoryId).toList();
    _categoryProductsCache[categoryId] = products;
    return products;
  }

  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) {
      _searchController.add([]);
      return [];
    }

    try {
      final lowerQuery = query.toLowerCase();
      final results =
          _products
              .where(
                (product) =>
                    product.name.toLowerCase().contains(lowerQuery) ||
                    product.description.toLowerCase().contains(lowerQuery),
              )
              .toList();

      _searchController.add(results);
      return results;
    } catch (e) {
      _handleError('Failed to search products: $e');
      _searchController.add([]);
      return [];
    }
  }

  Product? findProductByName(String name) {
    try {
      final lowerName = name.toLowerCase();
      return _products.firstWhere(
        (product) => product.name.toLowerCase().contains(lowerName),
        orElse: () => throw Exception('Product not found'),
      );
    } catch (e) {
      _handleError('Failed to find product: $e');
      return null;
    }
  }

  void addToCart(Product product) {
    try {
      // Use CartProvider if available
      if (_cartProvider != null) {
        _cartProvider!.addItem(product.id, product.name, product.price);
      } else {
        // Fallback to internal cart for backward compatibility
        _cart.addProduct(product);
      }
      notifyListeners();
    } catch (e) {
      _handleError('Failed to add product to cart: $e');
    }
  }

  void removeFromCart(String productId) {
    try {
      _cart.removeProduct(productId);
      notifyListeners();
    } catch (e) {
      _handleError('Failed to remove product from cart: $e');
    }
  }

  void decreaseCartItemQuantity(String productId) {
    try {
      _cart.decreaseQuantity(productId);
      notifyListeners();
    } catch (e) {
      _handleError('Failed to decrease cart item quantity: $e');
    }
  }

  void clearCart() {
    try {
      _cart.clear();
      notifyListeners();
    } catch (e) {
      _handleError('Failed to clear cart: $e');
    }
  }

  void clearCategoryCache() {
    _categoryProductsCache.clear();
  }
}
