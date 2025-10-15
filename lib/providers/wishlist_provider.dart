import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistItem {
  final String id;
  final String name;
  final double price;
  final String description;
  final String imageUrl;
  final String category;

  WishlistItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'description': description,
    'image_url': imageUrl,
    'category': category,
  };

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
    id: json['id'],
    name: json['name'],
    price: json['price'].toDouble(),
    description: json['description'],
    imageUrl: json['image_url'],
    category: json['category'] ?? '',
  );
}

class WishlistProvider with ChangeNotifier {
  final List<WishlistItem> _items = [];
  final _supabase = Supabase.instance.client;

  List<WishlistItem> get items => [..._items];

  Future<void> addItem(WishlistItem item) async {
    if (!_items.any((element) => element.id == item.id)) {
      _items.add(item);
      await _saveWishlistToSupabase();
      notifyListeners();
    }
  }

  Future<void> removeItem(String productId) async {
    _items.removeWhere((item) => item.id == productId);
    await _saveWishlistToSupabase();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _saveWishlistToSupabase();
    notifyListeners();
  }

  Future<void> _saveWishlistToSupabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('wishlists').upsert({
          'user_id': userId,
          'items': _items.map((item) => item.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (error) {
      debugPrint('Error saving wishlist: $error');
    }
  }

  Future<void> loadWishlist() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final response =
            await _supabase
                .from('wishlists')
                .select()
                .eq('user_id', userId)
                .single();

        final List<dynamic> itemsJson = response['items'];
        _items.clear();
        _items.addAll(
          itemsJson.map((item) => WishlistItem.fromJson(item)).toList(),
        );
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Error loading wishlist: $error');
    }
  }

  bool isInWishlist(String productId) {
    return _items.any((item) => item.id == productId);
  }
}
