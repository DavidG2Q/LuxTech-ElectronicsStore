import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../providers/wishlist_provider.dart';
import '../utils/utils.dart';
import 'package:flutter/services.dart';
import '../providers/product_provider.dart';
import '../widgets/app_cached_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0;
  late PageController _pageController;
  int _selectedColorIndex = 0;
  int _selectedSizeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final wishlistProvider = Provider.of<WishlistProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    // Get the actual product quantity from the provider
    final productQuantity = productProvider.getProductQuantity(widget.product.id);

    // In build(), after _selectedSizeIndex is set, get the selected variant's quantity:
    final selectedVariant = widget.product.sizes[_selectedSizeIndex];
    final isVariantOutOfStock = (selectedVariant.quantity ?? 0) == 0;

    // --- CATEGORY/SUBCATEGORY LOGIC ---
    String category = '';
    String subcategory = '';
    final normalizedCategoryId = widget.product.categoryId.trim().toLowerCase();
    final lookup = ProductProvider.categoryLookup.entries.firstWhere(
      (e) => e.key.trim().toLowerCase() == normalizedCategoryId,
      orElse: () => MapEntry('', <String, String?>{}),
    ).value;
    if (lookup != null) {
      category = productProvider.getCategoryDisplayName(lookup['category'] ?? '');
      final subcatRaw = lookup['subcategory'];
      subcategory = (subcatRaw == null) ? '' : productProvider.getSubcategoryDisplayName(subcatRaw);
    } else {
      // Fallback: try to infer from product name
      final name = widget.product.name.toLowerCase();
      if (name.contains('iphone')) {
        category = 'Smartphones';
        subcategory = 'Iphone';
      } else if (name.contains('samsung')) {
        category = 'Smartphones';
        subcategory = 'Samsung';
      } else if (name.contains('macbook') || name.contains('laptop')) {
        category = 'Laptops';
        subcategory = name.contains('gaming') ? 'Gaming Laptops' : 'Business Laptops';
      } else if (name.contains('ipad')) {
        category = 'iPad';
        subcategory = '';
      } else if (name.contains('watch')) {
        category = 'Watch';
        subcategory = name.contains('apple') ? 'Apple Watch' : 'Samsung Watch';
      } else if (name.contains('airpods')) {
        category = 'AirPods';
        subcategory = name.contains('max') ? 'AirPods Max' : 'AirPods Pro';
      } else if (name.contains('tv')) {
        category = 'TV';
        subcategory = name.contains('apple') ? 'Apple TV' : (name.contains('samsung') ? 'Samsung TV' : 'Smart TV');
      } else {
        category = 'Other';
        subcategory = '';
      }
    }
    // --- END CATEGORY/SUBCATEGORY LOGIC ---

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge!.color),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.share_outlined, color: Theme.of(context).textTheme.bodyLarge!.color),
                onPressed: () async {
                  // Generate a random 5-letter (upper/lowercase) string
                  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
                  String randomString = String.fromCharCodes(
                    List.generate(5, (index) => chars.codeUnitAt((DateTime.now().millisecondsSinceEpoch + index * 17) % chars.length)),
                  );
                  // Extract only the trailing digits from the UUID for the product URL
                  final match = RegExp(r'(\d+)$').firstMatch(widget.product.id);
                  String shortId = match != null ? match.group(1) ?? '' : widget.product.id;
                  shortId = shortId.replaceFirst(RegExp(r'^0+'), '');
                  final productUrl = 'https://luxetech.com/products/$shortId${randomString}lt';
                  await Clipboard.setData(ClipboardData(text: productUrl));
                },
              ),
              IconButton(
                icon: Icon(Icons.shopping_bag_outlined, color: Theme.of(context).textTheme.bodyLarge!.color),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
            ],
          ),

          // Product images
          SliverToBoxAdapter(
            child: Column(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 400,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: 1, // Use only one image for simplicity
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return AppCachedImage(
                            imageUrl: widget.product.imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: 400,
                          );
                        },
                      ),
                    ),
                    if (isVariantOutOfStock)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Coming Soon',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Product details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subcategory.isNotEmpty
                                ? '$category - $subcategory'
                                : category,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodyMedium!.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          icon: Icon(
                            wishlistProvider.isInWishlist(widget.product.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: wishlistProvider.isInWishlist(widget.product.id)
                                ? Colors.red
                                : null,
                          ),
                          onPressed: () {
                            wishlistProvider.toggleWishlistItem(widget.product.id);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  wishlistProvider.isInWishlist(widget.product.id)
                                      ? '${widget.product.name} added to wishlist'
                                      : '${widget.product.name} removed from wishlist',
                                ),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.only(bottom: 10.0, left: 10.0, right: 10.0),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatPrice(widget.product.price),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                    ],
                  ),
             
      
                  const SizedBox(height: 14),
                  Text(
                    'Color',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildColorSelector(),
                  const SizedBox(height: 24),
                  Text(
                    'Variants',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSizeSelector(),
                  const SizedBox(height: 24),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Main specifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.product.specifications
                      .map((spec) => _buildSpecItem(spec)),
                  const SizedBox(height: 24),
                  Text(
                    'You may also like',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendations(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isVariantOutOfStock ? null : () {
                  // Add product to cart
                  cartProvider.addItem(
                    widget.product,
                    widget.product.colors[_selectedColorIndex].name,
                    widget.product.sizes[_selectedSizeIndex].name,
                    widget.product.sizes[_selectedSizeIndex].price,
                  );
                  // Show confirmation message
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Product added to cart!'),
                      action: SnackBarAction(
                        label: 'View Cart',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CartScreen()),
                          );
                        },
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.only(bottom: 10.0, left: 10.0, right: 10.0),
                      dismissDirection: DismissDirection.up,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text(
                  'Add to Cart',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    return Wrap(
      spacing: 12,
      children: List.generate(
        widget.product.colors.length,
        (index) => GestureDetector(
          onTap: () {
            setState(() {
              _selectedColorIndex = index;
            });
          },
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(widget.product.colors[index].colorCode),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColorIndex == index  ? Theme.of(context).textTheme.bodyLarge!.color!
                        : Theme.of(context).textTheme.bodyMedium!.color!,
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.product.colors[index].name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _selectedColorIndex == index
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _selectedColorIndex == index
                      ? Theme.of(context).textTheme.bodyLarge!.color
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeSelector() {
    return Column(
      children: List.generate(
        widget.product.sizes.length,
        (index) => GestureDetector(
          onTap: () {
            setState(() {
              _selectedSizeIndex = index;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedSizeIndex == index
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).dividerColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _selectedSizeIndex == index
                  ? Theme.of(context).primaryColor.withOpacity(0.05)
                  : Theme.of(context).cardColor,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.product.sizes[index].name,
                    style: TextStyle(
                      fontWeight: _selectedSizeIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  formatPrice(widget.product.sizes[index].price),
                  style: TextStyle(
                    fontWeight: _selectedSizeIndex == index
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).primaryColor,
            size: 20
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    List<Product> subcategoryProducts = [];
    List<Product> otherSubcategoryProducts = [];

    // Get current product's category and subcategory
    final normalizedCategoryId = widget.product.categoryId.trim().toLowerCase();
    final lookup = ProductProvider.categoryLookup.entries.firstWhere(
      (e) => e.key.trim().toLowerCase() == normalizedCategoryId,
      orElse: () => MapEntry('', <String, String?>{}),
    ).value;
    final category = lookup['category'] ?? '';
    final subcategory = lookup['subcategory'] ?? '';
  
    print('[Recommendations] Current product: ${widget.product.name}');
    print('[Recommendations] categoryId: ${widget.product.categoryId}');
    print('[Recommendations] category: $category, subcategory: $subcategory');
   
    // 1. Other products in the same subcategory (e.g., other Business Laptops)
    if (subcategory.isNotEmpty) {
      subcategoryProducts = productProvider.getProductsBySubcategory(subcategory)
        .where((p) => p.id != widget.product.id)
        .toList();
      print('[Recommendations] subcategoryProducts: ${subcategoryProducts.map((p) => p.name).toList()}');
    }

    // 2. Other products in the same category but different subcategories
    if (category.isNotEmpty) {
      final allSubcategories = ProductProvider.categoryLookup.entries
        .where((e) => (e.value['category'] ?? '').trim().toLowerCase() == category.trim().toLowerCase())
        .map((e) => e.value['subcategory'] ?? '')
        .where((s) => s != subcategory && s != null && (s as String).isNotEmpty)
        .toSet();
      for (final otherSubcat in allSubcategories) {
        final productsInOtherSubcat = productProvider.getProductsBySubcategory(otherSubcat as String)
          .where((p) => p.id != widget.product.id)
          .toList();
        otherSubcategoryProducts.addAll(productsInOtherSubcat);
      }
      otherSubcategoryProducts = otherSubcategoryProducts.toSet().toList();
      print('[Recommendations] otherSubcategoryProducts: ${otherSubcategoryProducts.map((p) => p.name).toList()}');
    }

    // Combine: subcategory first, then other subcategories in category
    List<Product> recommendations = [
      ...subcategoryProducts,
      ...otherSubcategoryProducts,
    ];

    // Limit to 5 recommendations
    if (recommendations.length > 5) {
      recommendations = recommendations.sublist(0, 5);
    }

    print('[Recommendations] Final recommendations: ${recommendations.map((p) => p.name).toList()}');

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final product = recommendations[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
            },
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: AppCachedImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPrice(product.price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
