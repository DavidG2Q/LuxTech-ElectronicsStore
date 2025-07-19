import 'package:flutter/material.dart';
import '../models/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'hardcoded_products.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProductProvider with ChangeNotifier, WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _productsChannel;
  bool _isRealtimeSubscribed = false;
  int _realtimeRetryCount = 0;
  static const int _maxRealtimeRetries = 5;

  // Map to store product quantities (will be updated during runtime)
  final Map<String, int> _productQuantities = {};

  // Static category lookup map
  static const Map<String, Map<String, String?>> categoryLookup = {
    '00000000-0000-0000-0000-00000000C001': {'category': 'Smartphones', 'subcategory': 'Iphone'},
    '00000000-0000-0000-0000-00000000C002': {'category': 'Smartphones', 'subcategory': 'Samsung'},
    '00000000-0000-0000-0000-00000000C003': {'category': 'Laptops', 'subcategory': 'Business Laptops'},
    '00000000-0000-0000-0000-00000000C004': {'category': 'Laptops', 'subcategory': 'Gaming Laptops'},
    '00000000-0000-0000-0000-00000000C005': {'category': 'iPad', 'subcategory': null},
    '00000000-0000-0000-0000-00000000C006': {'category': 'Watch', 'subcategory': 'Apple Watch'},
    '00000000-0000-0000-0000-00000000C007': {'category': 'AirPods', 'subcategory': 'AirPods Pro'},
    '00000000-0000-0000-0000-00000000C008': {'category': 'AirPods', 'subcategory': 'AirPods Max'},
    '00000000-0000-0000-0000-00000000C009': {'category': 'TV', 'subcategory': 'Apple TV'},
    '00000000-0000-0000-0000-00000000C010': {'category': 'TV', 'subcategory': 'Smart TV'},
    '00000000-0000-0000-0000-00000000C011': {'category': 'TV', 'subcategory': 'Samsung TV'},
    '00000000-0000-0000-0000-00000000C012': {'category': 'Watch', 'subcategory': 'Samsung Watch'},
    '00000000-0000-0000-0000-00000000C013': {'category': 'iPad', 'subcategory': 'iPad Pro'},
    '00000000-0000-0000-0000-00000000C014': {'category': 'iPad', 'subcategory': 'iPad Air'},
    '00000000-0000-0000-0000-00000000C015': {'category': 'iPad', 'subcategory': 'iPad Mini'},
  };

  // Helper to get categoryId by category/subcategory
  static String? getCategoryId(String category, String? subcategory) {
    return categoryLookup.entries.firstWhere(
      (e) => e.value['category'] == category && e.value['subcategory'] == subcategory,
      orElse: () => MapEntry('', {}),
    ).key;
  }

  // Hardcoded fallback products (imported from hardcoded_products.dart)
  final List<Product> _hardcodedProducts = hardcodedProducts;

  ProductProvider() {
    print('Initializing ProductProvider...');
    WidgetsBinding.instance.addObserver(this);
    _initializeProducts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-subscribe to real-time updates when app resumes
      print('[ProductProvider] App resumed, re-subscribing to Supabase real-time.');
      _setupRealtimeSubscription();
      // Optionally, force a refresh from Supabase
      ensureFreshData();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _initializeProducts() async {
    // 0. Instantly show hardcoded values as placeholder
    _products = List<Product>.from(_hardcodedProducts);
    notifyListeners();
    debugPrintProducts();

    try {
      // 1. Always try to fetch from Supabase first (async, update if fresher data found)
      final isOnline = await _isDeviceOnline();
      bool loadedFromSupabase = false;
      if (isOnline) {
        try {
          await _loadProducts(); // Always try Supabase
          if (_products.isNotEmpty && !_isHardcodedList(_products)) {
            print('[ProductProvider] Loaded products from Supabase.');
            debugPrintProducts();
            notifyListeners();
            loadedFromSupabase = true;
          }
        } catch (e) {
          print('[ProductProvider] Supabase fetch failed: $e');
        }
      } else {
        print('[ProductProvider] Device is offline, skipping Supabase fetch.');
      }

      // 2. If Supabase failed or returned empty/hardcoded, try cache
      if (!loadedFromSupabase) {
        try {
          await _loadFromSharedPreferences();
          if (_products.isNotEmpty && !_isHardcodedList(_products)) {
            print('[ProductProvider] Loaded products from cache.');
            debugPrintProducts();
            notifyListeners();
          } else {
            print('[ProductProvider] Cache is empty or hardcoded. Using hardcoded as last resort.');
            _products = List<Product>.from(_hardcodedProducts);
            notifyListeners();
          }
        } catch (e) {
          print('[ProductProvider] Cache load failed: $e');
          _products = List<Product>.from(_hardcodedProducts);
          notifyListeners();
        }
      }
      // 3. If both fail, keep hardcoded (already set)
      // 4. Always set up real-time subscription
      _setupRealtimeSubscription();
    } catch (e) {
      print('[ProductProvider] Error during initialization: $e');
      _products = List<Product>.from(_hardcodedProducts);
      debugPrintProducts();
      notifyListeners();
      _setupRealtimeSubscription();
    }
  }

  // Helper to check if a list is the hardcoded list
  bool _isHardcodedList(List<Product> list) {
    if (list.length != _hardcodedProducts.length) return false;
    for (int i = 0; i < list.length; i++) {
      if (list[i].id != _hardcodedProducts[i].id) return false;
    }
    return true;
  }

  // Method to ensure fresh data on app startup
  Future<void> ensureFreshData() async {
    print('[ProductProvider] Ensuring fresh data...');
    try {
      final isOnline = await _isDeviceOnline();
      if (isOnline) {
        // Clear cache and force reload from Supabase
        await forceRefreshFromSupabase();
      } else {
        print('[ProductProvider] Device offline, keeping current data');
      }
    } catch (e) {
      print('[ProductProvider] Error ensuring fresh data: $e');
    }
  }

  // Main categories list
  final List<String> _categories = [
    'Smartphones',
    'Laptops',
    'iPad',
    'Watch',
    'AirPods',
    'TV',
  ];

  // Subcategories list
  final Map<String, List<String>> _subcategories = {
    'Smartphones': ['Iphone', 'Samsung'],
    'Laptops': ['Gaming Laptops', 'Business Laptops'],
    'iPad': ['iPad Pro', 'iPad Air', 'iPad Mini'],
    'Watch': ['Apple Watch', 'Samsung Watch'],
    'AirPods': ['AirPods Pro', 'AirPods Max', 'AirPods'],
    'TV': ['Smart TV', 'Apple TV', 'Samsung TV'],
  };

  // Get all products
  List<Product> get products => [..._products];

  // Force refresh products from Supabase
  Future<void> refreshProducts() async {
    await forceRefreshFromSupabase();
  }

  // Force clear cache and reload from Supabase
  Future<void> forceRefreshFromSupabase() async {
    print('[ProductProvider] Force refreshing from Supabase...');
    try {
      // Clear local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_products');
      await prefs.remove('product_quantities');
      print('[ProductProvider] Cleared local cache');
      
      // Clear current products
      _products.clear();
      notifyListeners();
      
      // Reload from Supabase
      await _loadProducts();
    } catch (e) {
      print('[ProductProvider] Error during force refresh: $e');
      // Fallback to hardcoded values
      _products = List<Product>.from(_hardcodedProducts);
      notifyListeners();
    }
  }

  // Get all categories
  List<String> get categories => [..._categories];

  // Get subcategories for a specific category
  List<String> getSubcategories(String category) {
    return _subcategories[category] ?? [];
  }

  // Get featured products
  List<Product> get featuredProducts {
    return _products.where((product) => product.isFeatured).toList();
  }

  // Get new products
  List<Product> get newProducts {
    return _products.where((product) => product.isNew).toList();
  }

  // Get product by ID
  Product? findById(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (_) {
      // Fallback to hardcoded products if not found in Supabase
      try {
        return _hardcodedProducts.firstWhere((product) => product.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  // Get products by category (should include all subcategories)
  List<Product> getProductsByCategory(String category) {
    // Find all categoryIds for this category (including all subcategories)
    final ids = categoryLookup.entries
        .where((e) => (e.value['category'] ?? '').trim().toLowerCase() == category.trim().toLowerCase())
        .map((e) => e.key.trim().toLowerCase())
        .toSet();
    return _products.where((product) => ids.contains(product.categoryId.trim().toLowerCase())).toList();
  }

  // Get products by subcategory (should only include that subcategory)
  List<Product> getProductsBySubcategory(String subcategory) {
    final normalizedSubcategory = subcategory.trim().toLowerCase();
    // Find all categoryIds for this subcategory only, case-insensitive
    final ids = categoryLookup.entries
        .where((e) => ((e.value['subcategory'] ?? '').trim().toLowerCase() == normalizedSubcategory))
        .map((e) => e.key.trim().toLowerCase())
        .toSet();
    return _products.where((product) => ids.contains(product.categoryId.trim().toLowerCase())).toList();
  }

  // Get category display name
  String getCategoryDisplayName(String category) {
    return category;
  }

  // Get subcategory display name
  String getSubcategoryDisplayName(String subcategory) {
    return subcategory;
  }

  // Search products with priority order: Supabase -> Local -> Hardcoded
  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) return [];
    final lowercaseQuery = query.toLowerCase();
    
    // Search in local products first
    final localResults = _products.where((product) {
      return product.name.toLowerCase().contains(lowercaseQuery) ||
          product.description.toLowerCase().contains(lowercaseQuery) ||
          product.categoryId.toLowerCase().contains(lowercaseQuery) ||
          product.categoryId.toLowerCase().contains(lowercaseQuery);
    }).toList();
    
    if (localResults.isNotEmpty) {
      return localResults;
    }
    
    // If no local results, try Supabase
    try {
      final response = await _supabase
          .from('products')
          .select()
          .or('name.ilike.%$query%,description.ilike.%$query%,categoryId.ilike.%$query%');
      
      if (response != null && response.isNotEmpty) {
        final List<dynamic> productsData = response;
        final supabaseResults = productsData.map((data) => Product.fromSupabaseMap(data)).toList();
        
        // Add new products from Supabase to local storage
        for (final product in supabaseResults) {
          if (!_products.any((p) => p.id == product.id)) {
            _products.add(product);
          }
        }
        
        // Save updated products to local storage
        await _saveToSharedPreferences();
        
        return supabaseResults;
      }
    } catch (e) {
      print('Error searching in Supabase: $e');
    }
    
    // If no results anywhere, return empty list
    return [];
  }

  // Get product quantity (modified to handle sizes)
  int getProductQuantity(String productId) {
    final product = findById(productId);
    if (product != null) {
      return product.sizes.fold(0, (sum, size) => sum + (size.quantity ?? 0));
    }
    return _productQuantities[productId] ?? 0;
  }

  // Modify the getProducts method to set quantities
  Future<void> getProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.from('products').select();
      if (response != null) {
        _products = (response as List)
            .map((json) => Product.fromJson(json))
            .toList();
      } else {
        // Use hardcoded products with quantities from _productQuantities
        _products = _hardcodedProducts.map((product) {
          return product.copyWith(
            sizes: product.sizes.map((size) => size.copyWith(quantity: _productQuantities[product.id] ?? 0)).toList(),
          );
        }).toList();
      }
      // ENFORCE: iPad Pro always has correct subcategory ID
      for (var i = 0; i < _products.length; i++) {
        if (_products[i].name.trim().toLowerCase() == 'Ipad Pro') {
          _products[i] = _products[i].copyWith(
            categoryId: '00000000-0000-0000-0000-00000000C013',
          );
        }
      }
    } catch (e) {
      _error = e.toString();
      // Use hardcoded products with quantities from _productQuantities
      _products = _hardcodedProducts.map((product) {
        return product.copyWith(
          sizes: product.sizes.map((size) => size.copyWith(quantity: _productQuantities[product.id] ?? 0)).toList(),
        );
      }).toList();
      // ENFORCE: iPad Pro always has correct subcategory ID
      for (var i = 0; i < _products.length; i++) {
        if (_products[i].name.trim().toLowerCase() == 'ipad pro') {
          _products[i] = _products[i].copyWith(
            categoryId: '00000000-0000-0000-0000-00000000C013',
          );
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProductImage(String productId, String newImageUrl) async {
    final productIndex = _products.indexWhere((product) => product.id == productId);
    if (productIndex >= 0) {
      final product = _products[productIndex];
      try {
        // Update local state immediately
        _products[productIndex] = product.copyWith(imageUrl: newImageUrl);
        notifyListeners();

        // Save to local storage
        await _saveToSharedPreferences();

        // Try to update Supabase if online
        try {
          await _supabase.from('products').update({
            'image_url': newImageUrl,
          }).eq('id', productId);
          print('Successfully updated product image in Supabase');
        } catch (e) {
          print('Could not update Supabase (might be offline): $e');
          // Continue execution even if Supabase update fails
        }
      } catch (e) {
        print('Error updating product image: $e');
        // Revert local state if something goes wrong
        _products[productIndex] = product;
        notifyListeners();
        throw e;
      }
    }
  }

  Future<void> updateProductPrice(String productId, double basePrice, List<ProductSize> updatedSizes) async {
    final productIndex = _products.indexWhere((product) => product.id == productId);
    if (productIndex >= 0) {
      final product = _products[productIndex];
      final updatedProduct = product.copyWith(
        price: basePrice,
        sizes: updatedSizes,
      );
      try {
        // Update local state immediately
        _products[productIndex] = updatedProduct;
        notifyListeners();

        // Save to local storage
        await _saveToSharedPreferences();

        // Try to update Supabase if online
        try {
          await _supabase.from('products').update({
            'price': basePrice, // Update base price to match first variant
            'variants': updatedSizes.map((s) => {
              'name': s.name,
              'price': s.price,
              'quantity': s.quantity ?? 1,
            }).toList(),
          }).eq('id', productId);
          print('Successfully updated product price and quantity in Supabase');
        } catch (e) {
          print('Could not update Supabase (might be offline): $e');
          // Continue execution even if Supabase update fails
        }
      } catch (e) {
        print('Error updating price: $e');
        // Revert local state if something goes wrong
        _products[productIndex] = product;
        notifyListeners();
        throw e;
      }
    }
  }

  /// Updates the quantity for a product's variant.
  /// Returns a message indicating which variant was updated.
  Future<String> updateProductQuantity(String productId, int quantity, {String? selectedVariant}) async {
    int productIndex = -1;
    Product? originalProduct;
    try {
      productIndex = _products.indexWhere((p) => p.id == productId);
      if (productIndex >= 0) {
        originalProduct = _products[productIndex];
        final product = _products[productIndex];
        String updatedVariantName = '';
        // If a variant is selected, only update that variant's quantity
        // If no variant selected, only update the first variant's quantity
        final updatedSizes = product.sizes.map((size) {
          if (selectedVariant != null) {
            // Only update the selected variant
            if (size.name == selectedVariant) {
              updatedVariantName = size.name;
              return ProductSize(name: size.name, price: size.price, quantity: quantity);
            }
          } else {
            // No variant selected, only update first variant
            if (size == product.sizes.first) {
              updatedVariantName = size.name;
              return ProductSize(name: size.name, price: size.price, quantity: quantity);
            }
          }
          return size; // Keep all other variants exactly the same
        }).toList();

        final updatedProduct = product.copyWith(
          sizes: updatedSizes,
        );
        // Update local state immediately
        _products[productIndex] = updatedProduct;
        notifyListeners();

        // Save to local storage
        await _saveToSharedPreferences();

        // Try to update Supabase if online
        try {
          final variantsPayload = updatedSizes.map((s) => {
            'name': s.name,
            'price': s.price,
            'quantity': s.quantity ?? 0,
          }).toList();
          print('[updateProductQuantity] Sending to Supabase:');
          print('productId: $productId');
          print('variants: ${variantsPayload.toString()}');
          print('quantity: $quantity');
          final response = await _supabase.from('products').update({
            'variants': variantsPayload,
            'quantity': quantity,
          }).eq('id', productId);
          print('[updateProductQuantity] Supabase response: $response');
          print('Successfully updated product quantity and status in Supabase');
        } catch (e) {
          print('Could not update Supabase (might be offline): $e');
          // Continue execution even if Supabase update fails
        }
        if (selectedVariant != null) {
          return 'Quantity updated for variant $updatedVariantName';
        } else {
          return 'Quantity updated for the first variant ($updatedVariantName)';
        }
      }
      return 'Product not found';
    } catch (e) {
      print('Error updating quantity: $e');
      // Revert local state if something goes wrong
      if (productIndex >= 0 && originalProduct != null) {
        _products[productIndex] = originalProduct;
        notifyListeners();
      }
      throw e;
    }
  }

  Future<void> _loadProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      print('[ProductProvider] Fetching products from Supabase...');
      final response = await _supabase.from('products').select();
      print('[ProductProvider] Supabase response type: \${response.runtimeType}');
      print('[ProductProvider] Supabase response: \${response}');

      if (response != null && response.isNotEmpty) {
        print('[ProductProvider] Successfully loaded \${response.length} products from Supabase');
        final List<dynamic> productsData = response;
        final supabaseProducts = productsData.map((data) {
          if (data['variants'] != null && data['variants'].isNotEmpty) {
            data['price'] = data['variants'][0]['price'];
          }
          return Product.fromSupabaseMap(data);
        }).toList();
        print('[ProductProvider] Successfully parsed \${supabaseProducts.length} products');

        // --- DIFFING LOGIC START ---
        // Build maps for fast lookup
        final Map<String, Product> supabaseMap = {
          for (final p in supabaseProducts) p.id: p
        };
        final Map<String, Product> currentMap = {
          for (final p in _products) p.id: p
        };

        // Remove products not in Supabase
        _products.removeWhere((p) => !supabaseMap.containsKey(p.id));

        // Update existing products and add new ones
        for (final supa in supabaseProducts) {
          final idx = _products.indexWhere((p) => p.id == supa.id);
          if (idx != -1) {
            // Update details if changed
            if (_products[idx] != supa) {
              _products[idx] = supa;
            }
          } else {
            // Add new product
            _products.add(supa);
          }
        }
        // --- DIFFING LOGIC END ---

        await _saveToSharedPreferences();
        print('[ProductProvider] Saved \${_products.length} products to local storage');
      } else {
        print('[ProductProvider] No products found in Supabase (response was null or empty)');
        print('[ProductProvider] Response was null: \${response == null}');
        print('[ProductProvider] Response was empty: \${response?.isEmpty}');
        // Do NOT clear _products here! Just keep showing the previous products.
        print('[ProductProvider] Keeping current products (hardcoded or cached)');
      }
    } catch (e, stackTrace) {
      if (!(await _isDeviceOnline())) {
        _error = 'You are offline. Please turn on your internet connection.';
      } else {
        _error = e.toString();
      }
      print('[ProductProvider] Error loading from Supabase: \${_error}');
      print('[ProductProvider] Stack trace: \${stackTrace}');
      print('[ProductProvider] Keeping current products (cache or hardcoded) due to Supabase error');
      // Do NOT clear _products here!
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> _isDeviceOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // =============================================
  // LOCAL STORAGE VERSION - START
  // =============================================
  // These methods handle local storage and offline functionality
  // They ensure the app works without internet connection
  // by caching products in SharedPreferences

  Future<void> _saveToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save products
      final productsJson = _products.map((p) => p.toJson()).toList();
      await prefs.setString('cached_products', jsonEncode(productsJson));
      print('Successfully cached ${_products.length} products locally');
      
      // Save product quantities
      await prefs.setString('product_quantities', jsonEncode(_productQuantities));
      print('Successfully cached product quantities');
      
      // Save the last product ID
      if (_products.isNotEmpty) {
        final lastProduct = _products.reduce((curr, next) => 
          int.parse(curr.id.substring(curr.id.length - 3)) > int.parse(next.id.substring(next.id.length - 3)) ? curr : next);
        await prefs.setString('last_product_id', lastProduct.id);
        print('Saved last product ID: ${lastProduct.id}');
      }
    } catch (e) {
      print('Error caching products: $e');
    }
  }

  Future<void> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load products
      final productsJson = prefs.getString('cached_products');
      if (productsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(productsJson);
          _products = decoded.map((data) => Product.fromSupabaseMap(data)).toList();
          print('[ProductProvider] Successfully loaded ${_products.length} products from local storage');
        } catch (e) {
          print('[ProductProvider] Error decoding cached products: $e. Falling back to hardcoded values.');
          _products = List<Product>.from(_hardcodedProducts);
        }
      } else {
        print('[ProductProvider] No cached products found in local storage, using hardcoded values');
        _products = List<Product>.from(_hardcodedProducts);
      }
      // Load product quantities
      final quantitiesJson = prefs.getString('product_quantities');
      if (quantitiesJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(quantitiesJson);
          _productQuantities.clear();
          decoded.forEach((key, value) {
            _productQuantities[key] = value as int;
          });
          print('[ProductProvider] Successfully loaded product quantities from local storage');
        } catch (e) {
          print('[ProductProvider] Error decoding product quantities: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      print('[ProductProvider] Error loading from local storage: $e. Using hardcoded values.');
      _products = List<Product>.from(_hardcodedProducts);
      notifyListeners();
    }
  }

  // Delete product from local state only (UI only)
  Future<void> deleteProductLocally(String productId) async {
    int productIndex = -1;
    try {
      productIndex = _products.indexWhere((p) => p.id == productId);
      if (productIndex >= 0) {
        // Remove from local state immediately
        _products.removeAt(productIndex);
        notifyListeners();
        
        // Save the updated products list to SharedPreferences
        await _saveToSharedPreferences();
        
        print('Successfully deleted product from local state only');
      }
    } catch (e) {
      print('Error deleting product locally: $e');
      // Revert local state if something goes wrong
      if (productIndex >= 0) {
        _products.insert(productIndex, _products[productIndex]);
        notifyListeners();
      }
      throw e;
    }
  }

  // =============================================
  // LOCAL STORAGE VERSION - END
  // =============================================

  Future<void> addOrUpdateProduct(Product product) async {
    try {
      final productData = product.toJson();
      await _supabase.from('products').upsert(productData);
      
      // Update local quantities
      int totalQuantity = product.sizes.fold(0, (sum, size) => sum + (size.quantity ?? 0));
      _productQuantities[product.id] = totalQuantity;
      
      // Save to SharedPreferences
      await _saveToSharedPreferences();
      
      notifyListeners();
    } catch (e) {
      print('Error in addOrUpdateProduct: $e');
      throw e;
    }
  }

  // Original delete method that affects both local state and Supabase
  Future<void> deleteProduct(String productId) async {
    int productIndex = -1;
    try {
      productIndex = _products.indexWhere((p) => p.id == productId);
      if (productIndex >= 0) {
        // Remove from local state immediately
        _products.removeAt(productIndex);
        notifyListeners();

        // Save to local storage
        await _saveToSharedPreferences();

        // Try to delete from Supabase if online
        try {
          await _supabase.from('products').delete().eq('id', productId);
          print('Successfully deleted product from Supabase');
        } catch (e) {
          print('Could not delete from Supabase (might be offline): $e');
          // Continue execution even if Supabase delete fails
        }
      }
    } catch (e) {
      print('Error deleting product: $e');
      // Revert local state if something goes wrong
      if (productIndex >= 0) {
        _products.insert(productIndex, _products[productIndex]);
        notifyListeners();
      }
      throw e;
    }
  }

  Future<List<String>> fetchAllProductIdsFromSupabase() async {
    final response = await _supabase.from('products').select('id');
    if (response != null && response is List) {
      return response.map<String>((item) => item['id'] as String).toList();
    }
    return [];
  }

  Future<String> getNextProductUuid() async {
    try {
      // First try to get from Supabase
      final response = await _supabase.from('products').select('id').order('id', ascending: false).limit(1);
      if (response != null && response is List && response.isNotEmpty) {
        final lastId = response[0]['id'] as String;
        // Extract the last number and increment
        final lastNumber = int.parse(lastId.substring(lastId.length - 3));
        final nextNumber = (lastNumber + 1).toString().padLeft(3, '0');
        return '00000000-0000-0000-0000-000000000$nextNumber';
      }

      // If no products in Supabase, check local products
      if (_products.isNotEmpty) {
        final lastProduct = _products.reduce((curr, next) => 
          int.parse(curr.id.substring(curr.id.length - 3)) > int.parse(next.id.substring(next.id.length - 3)) ? curr : next);
        final lastNumber = int.parse(lastProduct.id.substring(lastProduct.id.length - 3));
        final nextNumber = (lastNumber + 1).toString().padLeft(3, '0');
        return '00000000-0000-0000-0000-000000000$nextNumber';
      }

      // If no products anywhere, start with 014
      return '00000000-0000-0000-0000-000000000014';
    } catch (e) {
      print('Error getting next UUID: $e');
      // Fallback to 014 if there's an error
      return '00000000-0000-0000-0000-000000000014';
    }
  }

  Future<bool> addNewProduct({
    required String name,
    required double price,
    required String imageUrl,
    required String description,
    required String categoryId,
    required List<ProductColor> colors,
    required List<ProductSize> sizes,
    required bool isFeatured,
    required bool isNew,
    required List<String> specifications,
    int? quantity,
  }) async {
      final newId = await getNextProductUuid();
    List<ProductSize> updatedSizes = sizes.map((s) => s.copyWith(quantity: s.quantity ?? (quantity ?? 1))).toList();
      final newProduct = Product(
        id: newId,
        name: name,
        price: price,
        imageUrl: imageUrl,
        description: description,
        categoryId: categoryId,
        colors: colors,
        sizes: updatedSizes,
        isFeatured: isFeatured,
        isNew: isNew,
        specifications: specifications,
      );
    // Always add to local list and update UI immediately
      _products.add(newProduct);
      int totalQuantity = updatedSizes.fold(0, (sum, size) => sum + (size.quantity ?? 0));
      _productQuantities[newId] = totalQuantity;
      await _saveToSharedPreferences();
    notifyListeners();
    // Try to save to Supabase in the background
      try {
        await addOrUpdateProduct(newProduct);
      return true;
    } catch (e) {
      print('Error saving to Supabase: $e');
      // Optionally: mark as unsynced, show error, or queue for retry
      return false;
    }
  }

  void _setupRealtimeSubscription() {
    if (_isRealtimeSubscribed) return;
    _isRealtimeSubscribed = true;
    try {
      _productsChannel = _supabase.channel('public:products')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
          callback: (payload) async {
            print('[ProductProvider] Realtime event: \${payload.toString()}');
            await _loadProducts();
            },
        )
        .subscribe();
      print('[ProductProvider] Subscribed to Supabase realtime for products table.');
    } catch (e) {
      print('[ProductProvider] Error subscribing to realtime: \${e}');
    }
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload) {
    // Store current state as backup
    final currentProducts = List<Product>.from(_products);
    try {
      final eventType = payload.eventType;
      final record = payload.newRecord;
      final oldRecord = payload.oldRecord;

      if (eventType == null) return;

      switch (eventType) {
        case PostgresChangeEvent.insert:
          if (record != null) {
            try {
              final newProduct = Product.fromSupabaseMap(record);
              final existingIndex = _products.indexWhere((p) => p.id == newProduct.id);
              if (existingIndex == -1) {
                _products.add(newProduct);
                notifyListeners();
                print('Added new product from real-time update: ${newProduct.name}');
              } else {
                print('Product already exists, skipping insert: ${newProduct.name}');
              }
            } catch (e) {
              print('Error parsing new product in realtime insert: $e');
            }
          }
          break;
        case PostgresChangeEvent.update:
          if (record != null) {
            try {
              final updatedProduct = Product.fromSupabaseMap(record);
              final index = _products.indexWhere((p) => p.id == updatedProduct.id);
              if (index != -1) {
                _products[index] = updatedProduct;
                notifyListeners();
                print('Updated product from real-time update: ${updatedProduct.name}');
              } else {
                print('Product not found for update: ${updatedProduct.name}');
              }
            } catch (e) {
              print('Error parsing updated product in realtime update: $e');
            }
          }
          break;
        case PostgresChangeEvent.delete:
          if (oldRecord != null) {
            try {
              final deletedProduct = Product.fromSupabaseMap(oldRecord);
              final initialLength = _products.length;
              _products.removeWhere((p) => p.id == deletedProduct.id);
              if (_products.length < initialLength) {
                notifyListeners();
                print('Removed product from real-time update: ${deletedProduct.name}');
              } else {
                print('Product not found for deletion: ${deletedProduct.name}');
              }
            } catch (e) {
              print('Error parsing deleted product in realtime delete: $e');
            }
          }
          break;
        default:
          print('Unhandled event type: $eventType');
          break;
      }
    } catch (e, stackTrace) {
      print('Error in _handleRealtimeUpdate: $e');
      print(stackTrace);
      // Restore previous state if something goes wrong
      _products = currentProducts;
      notifyListeners();
      // Never throw!
    }
  }

  // Update product features
  Future<void> updateProductFeatures(String productId, {bool? isFeatured, bool? isNew}) async {
    try {
      final productIndex = _products.indexWhere((p) => p.id == productId);
      if (productIndex >= 0) {
        final product = _products[productIndex];
        final updatedProduct = product.copyWith(
          isFeatured: isFeatured ?? product.isFeatured,
          isNew: isNew ?? product.isNew,
        );

        // Update local state immediately
        _products[productIndex] = updatedProduct;
        notifyListeners();

        // Save to local storage
        await _saveToSharedPreferences();

        // Try to update Supabase if online
        try {
          await _supabase.from('products').update({
            'is_featured': updatedProduct.isFeatured,
            'is_new': updatedProduct.isNew,
          }).eq('id', productId);
          print('Successfully updated product features in Supabase');
        } catch (e) {
          print('Could not update Supabase (might be offline): $e');
          // Continue execution even if Supabase update fails
        }
      }
    } catch (e) {
      print('Error updating product features: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Properly cleanup the realtime subscription
    try {
      if (_productsChannel != null) {
        _supabase.removeChannel(_productsChannel!);
        _productsChannel = null;
      }
    } catch (e) {
      print('Error cleaning up realtime subscription: $e');
    }
    super.dispose();
  }

  // Debug method to check current data source
  String getCurrentDataSource() {
    if (_products.isEmpty) return 'No products loaded';
    
    // Check if products match hardcoded ones
    if (_products.length == _hardcodedProducts.length) {
      bool allMatch = true;
      for (int i = 0; i < _products.length; i++) {
        if (_products[i].id != _hardcodedProducts[i].id) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) return 'Hardcoded products (${_products.length} items)';
    }
    
    return 'Supabase/Cached products (${_products.length} items)';
  }

  // Debug method to print current products info
  void debugPrintProducts() {
    print('[ProductProvider] Current data source: ${getCurrentDataSource()}');
    print('[ProductProvider] Products count: ${_products.length}');
    if (_products.isNotEmpty) {
      print('[ProductProvider] First 3 products:');
      for (int i = 0; i < _products.length && i < 3; i++) {
        final product = _products[i];
        print('  ${i + 1}. ${product.name} (ID: ${product.id}) - Featured: ${product.isFeatured}, New: ${product.isNew}');
      }
    }
  }

  // Test Supabase connection and data access
  Future<void> testSupabaseConnection() async {
    print('[ProductProvider] Testing Supabase connection...');
    try {
      // Test 1: Check if we can reach Supabase
      print('[ProductProvider] Test 1: Checking Supabase connectivity...');
      final version = await _supabase.rpc('version');
      print('[ProductProvider] Supabase version: $version');
      
      // Test 2: Check if products table exists and is accessible
      print('[ProductProvider] Test 2: Checking products table access...');
      final tableCheck = await _supabase.from('products').select('id').limit(1);
      print('[ProductProvider] Products table accessible: ${tableCheck != null}');
      
      // Test 3: Count products in table
      print('[ProductProvider] Test 3: Counting products in table...');
      final allProducts = await _supabase.from('products').select('id');
      print('[ProductProvider] Total products in table: ${allProducts?.length ?? 0}');
      
      // Test 4: Get first product details
      if (allProducts != null && allProducts.isNotEmpty) {
        print('[ProductProvider] Test 4: Getting first product details...');
        final firstProduct = await _supabase.from('products').select().eq('id', allProducts.first['id']).single();
        print('[ProductProvider] First product data: $firstProduct');
      }
      
      print('[ProductProvider] All Supabase tests passed!');
    } catch (e) {
      print('[ProductProvider] Supabase connection test failed: $e');
    }
  }

  bool get isLoading => _isLoading;

  String? get userError {
    if (_error != null && _error!.toLowerCase().contains('offline')) {
      return 'You are offline. Please turn on your internet connection.';
    }
    return _error;
  }
}
