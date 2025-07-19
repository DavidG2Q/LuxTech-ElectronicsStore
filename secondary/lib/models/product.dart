import 'dart:convert';

class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final String categoryId; // UUID reference to category
  final List<ProductColor> colors;
  final List<ProductSize> sizes; // Each size/variant has its own quantity
  final bool isFeatured;
  final bool isNew;
  final List<String> specifications;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.categoryId,
    required this.colors,
    required this.sizes,
    required this.isFeatured,
    required this.isNew,
    required this.specifications,
  });

  // Calculate out of stock status based on all variants
  bool get isOutOfStock => sizes.fold(0, (sum, s) => sum + (s.quantity ?? 0)) <= 0;

  // Create from JSON map (for local/cache use)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String,
      description: json['description'] as String,
      categoryId: json['category_id'] as String? ?? json['categoryId'] as String,
      colors: (json['colors'] as List<dynamic>)
          .map((color) => ProductColor.fromJson(color as Map<String, dynamic>))
          .toList(),
      sizes: (json['variants'] as List<dynamic>? ?? json['sizes'] as List<dynamic>?)
          ?.map((size) {
            final s = ProductSize.fromJson(size as Map<String, dynamic>);
            return s.copyWith(quantity: s.quantity ?? 1);
          })
          .toList() ?? [],
      isFeatured: json['is_featured'] as bool? ?? json['isFeatured'] as bool? ?? false,
      isNew: json['is_new'] as bool? ?? json['isNew'] as bool? ?? false,
      specifications: (json['specifications'] as List<dynamic>?)
              ?.map((spec) => spec as String)
              .toList() ??
          [],
    );
  }

  // Convert to JSON map (for Supabase and cache)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'description': description,
      'category_id': categoryId,
      'colors': colors.map((color) => color.toJson()).toList(),
      'variants': sizes.map((size) => size.toJson()).toList(),
      'is_featured': isFeatured,
      'is_new': isNew,
      'specifications': specifications,
    };
  }

  // Create a copy with some properties changed
  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? description,
    String? categoryId,
    List<ProductColor>? colors,
    List<ProductSize>? sizes,
    bool? isFeatured,
    bool? isNew,
    List<String>? specifications,
  }) {
    double newPrice = price ?? this.price;
    if (sizes != null && sizes.isNotEmpty) {
          newPrice = sizes.first.price;
    }
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: newPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
      isFeatured: isFeatured ?? this.isFeatured,
      isNew: isNew ?? this.isNew,
      specifications: specifications ?? this.specifications,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, categoryId: $categoryId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.id == id &&
        other.name == name &&
        other.price == price &&
        other.imageUrl == imageUrl &&
        other.description == description &&
        other.categoryId == categoryId &&
        other.isFeatured == isFeatured &&
        other.isNew == isNew;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        price.hashCode ^
        imageUrl.hashCode ^
        description.hashCode ^
        categoryId.hashCode ^
        isFeatured.hashCode ^
        isNew.hashCode;
  }

  double get displayPrice {
    if (sizes.isEmpty) return price;
    return sizes.first.price;
  }

  // Convert to Supabase map format (identical to toJson now)
  Map<String, dynamic> toSupabaseMap() {
    return toJson();
  }

  // Create from Supabase map format
  factory Product.fromSupabaseMap(Map<String, dynamic> map) {
    List<ProductColor> parseColors(dynamic colorsData) {
      if (colorsData == null) return [];
      if (colorsData is String) {
        try {
          colorsData = jsonDecode(colorsData);
        } catch (e) {
          return [];
        }
      }
      return (colorsData as List).map((color) {
        String colorCode = color['colorCode'].toString();
        if (colorCode.startsWith('0x')) {
          colorCode = colorCode.substring(2);
        }
        return ProductColor(
          name: color['name'],
          colorCode: int.parse(colorCode, radix: 16),
        );
      }).toList();
    }

    List<ProductSize> parseSizes(dynamic sizesData) {
      if (sizesData == null) return [];
      if (sizesData is String) {
        try {
          sizesData = jsonDecode(sizesData);
        } catch (e) {
          return [];
        }
      }
      return (sizesData as List).map((size) {
        final s = ProductSize.fromJson(size);
        return s.copyWith(quantity: s.quantity ?? 1);
      }).toList();
    }

    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['image_url'] as String? ?? map['imageUrl'] as String,
      description: map['description'] as String,
      categoryId: map['category_id'] as String? ?? map['categoryId'] as String,
      colors: parseColors(map['colors']),
      sizes: parseSizes(map['variants'] ?? map['sizes']),
      isFeatured: map['is_featured'] as bool? ?? map['isFeatured'] as bool? ?? false,
      isNew: map['is_new'] as bool? ?? map['isNew'] as bool? ?? false,
      specifications: (map['specifications'] as List<dynamic>?)?.map((spec) => spec as String).toList() ?? [],
    );
  }
}

class ProductColor {
  final String name;
  final int colorCode;

  ProductColor({
    required this.name,
    required this.colorCode,
  });
  
  factory ProductColor.fromJson(Map<String, dynamic> json) {
    return ProductColor(
      name: json['name'] as String,
      colorCode: json['colorCode'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'colorCode': colorCode,
    };
  }

  ProductColor copyWith({
    String? name,
    int? colorCode,
  }) {
    return ProductColor(
      name: name ?? this.name,
      colorCode: colorCode ?? this.colorCode,
    );
  }

  @override
  String toString() => 'ProductColor(name: $name, colorCode: 0x${colorCode.toRadixString(16).padLeft(8, '0')})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductColor && other.name == name && other.colorCode == colorCode;
  }

  @override
  int get hashCode => name.hashCode ^ colorCode.hashCode;
}

class ProductSize {
  final String name;
  final double price;
  final int? quantity; // New: quantity per variant

  ProductSize({
    required this.name,
    required this.price,
    this.quantity,
  });
  
  factory ProductSize.fromJson(Map<String, dynamic> json) {
    return ProductSize(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      if (quantity != null) 'quantity': quantity,
    };
  }

  ProductSize copyWith({
    String? name,
    double? price,
    int? quantity,
  }) {
    return ProductSize(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  String toString() => 'ProductSize(name: $name, price: $price, quantity: $quantity)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductSize && other.name == name && other.price == price && other.quantity == quantity;
  }

  @override
  int get hashCode => name.hashCode ^ price.hashCode ^ (quantity ?? 0).hashCode;
}