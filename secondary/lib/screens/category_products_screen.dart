import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_grid_item.dart';
import '../models/product.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  String _sortOption = 'featured';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  TabController? _tabController;
  String? _selectedSubcategory;

  // Translation dictionary for common words (can be expanded later)
  final Map<String, List<String>> _arabicToEnglishMap = {
    'ايفون': ['iphone', 'phone', 'smartphone'],
    'هاتف': ['phone', 'iphone', 'smartphone'],
    'ماك': ['mac', 'macbook', 'laptop'],
    'لابتوب': ['laptop', 'macbook', 'computer'],
    'حاسوب': ['computer', 'laptop', 'mac'],
    'ايباد': ['ipad', 'tablet'],
    'تابلت': ['tablet', 'ipad'],
    'ساعة': ['watch', 'apple watch'],
    'سماعة': ['airpods', 'headphones', 'earphones'],
    'تلفزيون': ['tv', 'television', 'apple tv'],
    'برو': ['pro', 'professional'],
    'اير': ['air'],
    'ماكس': ['max', 'maximum'],
    'ميني': ['mini', 'small'],
    'جديد': ['new', 'latest'],
    'احدث': ['new', 'latest', 'newest'],
    'افضل': ['best', 'top', 'featured'],
    'رخيص': ['cheap', 'affordable', 'low price'],
    'غالي': ['expensive', 'premium', 'high price'],
    'سامسونج': ['samsung', 'galaxy'],
    'جوجل': ['google', 'pixel'],
    'شاومي': ['xiaomi', 'mi', 'redmi'],
    'اندرويد': ['android'],
    'لينوفو': ['lenovo'],
    'العاب': ['gaming', 'games'],
  };

  @override
  void initState() {
    super.initState();
    // tab controller will be initialzied later in  didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final subcategories = productProvider.getSubcategories(widget.categoryName);

    if (subcategories.isNotEmpty) {
      _tabController =
          TabController(length: subcategories.length + 1, vsync: this);
      _tabController!.addListener(() {
        if (_tabController!.index == 0) {
          setState(() {
            _selectedSubcategory = null;
          });
        } else {
          setState(() {
            _selectedSubcategory = subcategories[_tabController!.index - 1];
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  // Enhanced search function that supports Arabic to English translation
  List<Product> _getFilteredProducts(ProductProvider provider) {
    List<Product> categoryProducts;

    if (_selectedSubcategory != null) {
      categoryProducts =
          provider.getProductsBySubcategory(_selectedSubcategory!);
    } else {
      categoryProducts = provider.getProductsByCategory(widget.categoryName);
    }

    if (_searchQuery.isEmpty) {
      return _sortProducts(categoryProducts);
    }

    // Convert search query to lowercase
    final query = _searchQuery.toLowerCase().trim();

    // Direct search first with improved category matching
    var results = categoryProducts.where((product) {
      final nameLower = product.name.toLowerCase();
      final descLower = product.description.toLowerCase();
      final categoryInfo = ProductProvider.categoryLookup[product.categoryId];
      final category = (categoryInfo?['category'] ?? '').toLowerCase();
      final subcategory = (categoryInfo?['subcategory'] ?? '').toLowerCase();
      
      return nameLower.contains(query) ||
             descLower.contains(query) ||
             category.contains(query) ||
             subcategory.contains(query) ||
             (category == 'laptops' && (query.contains('laptop') || query.contains('laptops'))) ||
             (category == 'laptops' && (query.contains('computer') || query.contains('pc')));
    }).toList();

    // If no results, try translating from Arabic to English
    if (results.isEmpty) {
      // Split the query into words
      final queryWords = query.split(' ');

      // Collect all possible translations for each word
      final List<String> possibleTranslations = [];

      for (final word in queryWords) {
        // Search for translations for the word
        for (final entry in _arabicToEnglishMap.entries) {
          if (word.contains(entry.key) || entry.key.contains(word)) {
            possibleTranslations.addAll(entry.value);
          }
        }
      }

      // Search using translations with improved category matching
      if (possibleTranslations.isNotEmpty) {
        results = categoryProducts.where((product) {
          final nameLower = product.name.toLowerCase();
          final descLower = product.description.toLowerCase();
          final categoryInfo = ProductProvider.categoryLookup[product.categoryId];
          final category = (categoryInfo?['category'] ?? '').toLowerCase();
          final subcategory = (categoryInfo?['subcategory'] ?? '').toLowerCase();

          for (final translation in possibleTranslations) {
            if (nameLower.contains(translation) ||
                descLower.contains(translation) ||
                category.contains(translation) ||
                subcategory.contains(translation) ||
                (category == 'laptops' && (translation == 'laptop' || translation == 'computer' || translation == 'pc'))) {
              return true;
            }
          }
          return false;
        }).toList();
      }
    }

    return _sortProducts(results);
  }

  // Sorting function
  List<Product> _sortProducts(List<Product> products) {
    switch (_sortOption) {
      case 'featured':
        return products..sort((a, b) => b.isFeatured ? 1 : -1);
      case 'newest':
        return products..sort((a, b) => b.isNew ? 1 : -1);
      case 'price_low':
        return products..sort((a, b) => a.price.compareTo(b.price));
      case 'price_high':
        return products..sort((a, b) => b.price.compareTo(a.price));
      case 'name_asc':
        return products..sort((a, b) => a.name.compareTo(b.name));
      default:
        return products;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final filteredProducts = _getFilteredProducts(productProvider);
    final subcategories = productProvider.getSubcategories(widget.categoryName);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText:
                      'Search in  ${productProvider.getCategoryDisplayName(widget.categoryName)}...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                ),
                textDirection: TextDirection.ltr,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Text(
                productProvider.getCategoryDisplayName(widget.categoryName),
                style: const TextStyle(color: Colors.black),
              ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge!.color),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Search button
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
                if (_isSearching) {
                  _searchFocusNode.requestFocus();
                }
              });
            },
          ),
          // Sort button
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.black),
            onSelected: (value) {
              setState(() {
                _sortOption = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'featured',
                child: Text('featured'),
              ),
              const PopupMenuItem(
                value: 'newest',
                child: Text('newest'),
              ),
              const PopupMenuItem(
                value: 'price_low',
                child: Text('Price : low to high'),
              ),
              const PopupMenuItem(
                value: 'price_high',
                child: Text('Price : high to low'),
              ),
              const PopupMenuItem(
                value: 'name_asc',
                child: Text('Name: A-Z'),
              ),
            ],
          ),
        ],
        bottom: subcategories.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
          labelColor: Theme.of(context).textTheme.bodyLarge!.color,
          unselectedLabelColor: Theme.of(context).hintColor,
          indicatorColor: Theme.of(context).primaryColor,
                tabs: [
                  const Tab(text: 'All'),
                  ...subcategories.map((subcategory) =>
                      Tab(text: productProvider.getSubcategoryDisplayName(subcategory))),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'Show Product ${filteredProducts.length}',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium!.color,

                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Show active filter
                Row(
                  children: [
                    Icon(
                      _getSortIcon(_sortOption),
                      size: 18,
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getSortName(_sortOption),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, _) {
                final isLoading = productProvider.isLoading;

                if (filteredProducts.isNotEmpty) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      return ProductGridItem(product: filteredProducts[index]);
                    },
                  );
                } else if (isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  );
                } else {
                  return Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Get sort name in English
  String _getSortName(String sortOption) {
    switch (sortOption) {
      case 'featured':
        return 'Featured';
      case 'newest':
        return 'Newest';
      case 'price_low':
        return 'Price : low to high';
      case 'price_high':
        return 'Price : high to low';
      case 'name_asc':
        return 'Name: A-Z';
      default:
        return 'featured';
    }
  }

  // Get sort icon
  IconData _getSortIcon(String sortOption) {
    switch (sortOption) {
      case 'featured':
        return Icons.star;
      case 'newest':
        return Icons.new_releases;
      case 'price_low':
        return Icons.arrow_downward;
      case 'price_high':
        return Icons.arrow_upward;
      case 'name_asc':
        return Icons.sort_by_alpha;
      default:
        return Icons.sort;
    }
  }
}
