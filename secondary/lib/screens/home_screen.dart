import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_grid_item.dart';
import '../widgets/category_item.dart';
import '../screens/cart_screen.dart';
import '../screens/search_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/category_products_screen.dart';
import 'dart:math' as math;
import '../screens/wishlist_screen.dart';
import '../models/product.dart';
import '../utils/utils.dart';
import '../providers/theme_provider.dart';
import 'dart:async';
import '../widgets/app_cached_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late PageController _pageController;
  
  // Fallback iPhone 15 Pro product
  final Product _fallbackProduct = Product(
    id: '00000000-0000-0000-0000-000000000001',
    name: 'iPhone 15 Pro',
    description: 'The most powerful iPhone ever with a titanium design, A17 Pro chip, and advanced camera system.',
    price: 999.99,
    imageUrl: 'https://store.storeimages.cdn-apple.com/4982/as-images.apple.com/is/iphone-15-pro-finish-select-202309-6-7inch-naturaltitanium?wid=5120&hei=2880&fmt=p-jpg&qlt=80&.v=1692845702708',
    categoryId: ProductProvider.getCategoryId('Smartphones', 'Iphone') ?? ProductProvider.categoryLookup.keys.first,
    isFeatured: true,
    isNew: true,
    colors: [
      ProductColor(name: 'Natural Titanium', colorCode: 0xFFE3D0BA),
      ProductColor(name: 'Blue Titanium', colorCode: 0xFF7D9AAA),
      ProductColor(name: 'White Titanium', colorCode: 0xFFF5F5F0),
      ProductColor(name: 'Black Titanium', colorCode: 0xFF4D4D4D),
    ],
    sizes: [
      ProductSize(name: '128GB', price: 999.99, quantity: 100),
      ProductSize(name: '256GB', price: 1099.99),
      ProductSize(name: '512GB', price: 1299.99),
      ProductSize(name: '1TB', price: 1499.99),
    ],
    specifications: [
      '6.1-inch Super Retina XDR display',
      'A17 Pro chip',
      '48MP Main | Ultra Wide | Telephoto',
      'Up to 23 hours video playback'
    ],
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _pageController = PageController();
  }

  @override
  void dispose() {
    try {
      _animationController.dispose();
      _pageController.dispose();
    } catch (e) {
      // Ignore any errors during disposal
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final featuredProducts = productProvider.featuredProducts;
    final newProducts = productProvider.newProducts;
    final categories = productProvider.categories;
    
    // Get products in priority order:
    // 1. Try to find iPhone 15 Pro in Supabase
    // 2. If not found or flags aren't true, find next product with both flags true
    // 3. If no product found, show empty state
    final products = productProvider.products;
    Product? iphone15Pro;
    try {
      iphone15Pro = products.firstWhere(
        (p) => p.id == '00000000-0000-0000-0000-000000000001' && p.isNew && p.isFeatured,
      );
    } catch (e) {
      iphone15Pro = null;
    }
    
    final otherNewFeatured = products
        .where((p) => p.isNew && p.isFeatured && p.id != '00000000-0000-0000-0000-000000000001')
        .toList();
    
    final newFeaturedProducts = [
      if (iphone15Pro != null) iphone15Pro,
      ...otherNewFeatured,
    ];

    return WillPopScope(
      onWillPop: () async {
        // Show a snackbar to inform the user
        
        return false; // Prevent back navigation
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _currentIndex == 0 ? CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                // Dynamic Luxury Electronics Logo
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotateAnimation.value,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.transparent, Color(0xFF3D3D3D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3 * _pulseAnimation.value),
                              blurRadius: 8 * _pulseAnimation.value,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.rotate(
                              angle: math.pi / 4 * _pulseAnimation.value * 0.1,
                              child: const Icon(
                                Icons.bolt,
                                color: Colors.blue,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'LUXE',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.transparent.withOpacity(0.5),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  colors: [
                                    const Color.fromARGB(255, 0, 162, 255),
                                    const Color.fromARGB(255, 196, 210, 255),
                                    const Color.fromARGB(255, 32, 32, 27),
                                  ],
                                  stops: [0.0, 0.5 * _pulseAnimation.value, 1.0],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds);
                              },
                              child: Text(
                                'TECH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) => IconButton(
                    icon: Icon(
                      themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                    onPressed: () {
                      themeProvider.setDarkMode(!themeProvider.isDarkMode);
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search, color: Theme.of(context).textTheme.bodyLarge!.color),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SearchScreen()),
                    );
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
          ),
          
          // Browse by category title
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Browse by category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Enhanced category section
          SliverToBoxAdapter(
            child: Container(
              height: 120,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  // Always use the canonical category name for navigation
                  final canonicalCategory = categories[index];
                  return CategoryItem(
                    title: _getCategoryDisplayName(canonicalCategory),
                    icon: _getCategoryIcon(canonicalCategory),
                    onTap: () {
                      // Navigate to enhanced category page with canonical name
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryProductsScreen(
                            categoryName: canonicalCategory,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          
          // Large featured Product Cards
          SliverToBoxAdapter(
            child: Container(
              height: 400,
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.horizontal,
                    itemCount: newFeaturedProducts.isEmpty ? 1 : newFeaturedProducts.length + 2,
                    physics: const BouncingScrollPhysics(),
                    pageSnapping: true,
                    onPageChanged: (index) {
                      if (newFeaturedProducts.isEmpty) return;
                      
                      // If we're at the last page (duplicate of first), jump to the real first page
                      if (index == newFeaturedProducts.length + 1) {
                        if (mounted) {
                          _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      }
                      // If we're at the first page (duplicate of last), jump to the real last page
                      else if (index == 0) {
                        if (mounted) {
                          _pageController.animateToPage(
                            newFeaturedProducts.length,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      }
                    },
                    itemBuilder: (context, index) {
                      if (newFeaturedProducts.isEmpty) {
                        // Show 'Coming Soon' placeholder ONLY if no new arrivals
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 64,
                                color: Theme.of(context).primaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'New products are on their way',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Calculate the actual product index
                      int actualIndex;
                      if (index == 0) {
                        // First page shows the last product
                        actualIndex = newFeaturedProducts.length - 1;
                      } else if (index == newFeaturedProducts.length + 1) {
                        // Last page shows the first product
                        actualIndex = 0;
                      } else {
                        // All other pages show their corresponding product
                        actualIndex = index - 1;
                      }
                      
                      final product = newFeaturedProducts[actualIndex];
                      
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AppCachedImage(
                                imageUrl: product.imageUrl,
                                height: 400,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            // Gradient overlay
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                  stops: const [0.6, 1.0],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 20,
                              left: 20,
                              right: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'New Arrival',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 10.0,
                                          color: Colors.black,
                                          offset: Offset(2.0, 2.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product.description,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8.0,
                                          color: Colors.black,
                                          offset: Offset(2.0, 2.0),
                                        ),
                                      ],
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              left: 20,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetailScreen(product: product),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 5,
                                ),
                                child: const Text(
                                  'Shop Now',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Add dots indicator
                  if (!newFeaturedProducts.isEmpty && newFeaturedProducts.length > 1)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          // Calculate the actual current page index immediately
                          int currentPage = 0;
                          if (_pageController.hasClients) {
                            double? rawPage = _pageController.page;
                            if (rawPage != null) {
                              if (rawPage >= newFeaturedProducts.length + 1) {
                                currentPage = 0;
                              } else if (rawPage <= 0) {
                                currentPage = newFeaturedProducts.length - 1;
                              } else {
                                // Round to nearest integer instead of using floor
                                currentPage = (rawPage - 1).round();
                              }
                            }
                          }
                          
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              newFeaturedProducts.length,
                              (index) {
                                return Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: currentPage == index
                                      ? Theme.of(context).primaryColor
                                      : Colors.white.withOpacity(0.5),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Featured Products Title
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Featured Products',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Featured Products Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return ProductGridItem(product: featuredProducts[index]);
                },
                childCount: featuredProducts.length,
              ),
            ),
          ),
          
          // Additional space at the bottom
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ) : _getScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).hintColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Homepage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'My Account',
          ),
        ],
      ),
    ));
  }

  // Update the _getScreen method to return the WishlistScreen for index 3
  Widget _getScreen() {
    switch (_currentIndex) {
      case 0:
        return Container(); // Homepage
      case 1:
        return const CartScreen(); // Cart page
      case 2:
        return const WishlistScreen(); // Wishlist page
      case 3:
        return const ProfileScreen(isFromBottomNav: true); // My Account page
      default:
        return Container();
    }
  }

  // set icon for each category
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Smartphones':
        return Icons.smartphone;
      case 'Laptops':
        return Icons.laptop;
      case 'iPad':
        return Icons.tablet_mac;
      case 'Watch':
        return Icons.watch;
      case 'AirPods':
        return Icons.headphones;
      case 'TV':
        return Icons.tv;
      default:
        return Icons.devices_other;
    }
  }

  // Get the appropriate display name for each category
  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'Smartphones':
        return 'Smart\nphones';
      case 'Laptops':
        return 'Personal\nComputers';
      case 'iPad':
        return 'Apple\'s\nipad';
      case 'Watch':
        return 'Smart\nwatches';
      case 'AirPods':
        return 'Wireless\nearphones';
      case 'TV':
        return 'Smart\nTVs';
      default:
        return category;
    }
  }
}
