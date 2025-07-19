import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_grid_item.dart';
import '../models/product.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Arabic dictionary
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
  };
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Enhanced search function that supports Arabic to English translation
  List<Product> _getSearchResults(ProductProvider provider) {
    if (_searchQuery.isEmpty) {
      return [];
    }

    final query = _searchQuery.toLowerCase().trim();

    // Check for exact category match
    final categoryMatch = provider.categories.firstWhere(
      (cat) => cat.toLowerCase() == query,
      orElse: () => '',
    );
    if (categoryMatch.isNotEmpty) {
      return provider.getProductsByCategory(categoryMatch);
    }

    // Check for exact subcategory match
    String? subcategoryMatch;
    for (final entry in provider.categories) {
      final subcats = provider.getSubcategories(entry);
      for (final subcat in subcats) {
        if (subcat.toLowerCase() == query) {
          subcategoryMatch = subcat;
          break;
        }
      }
      if (subcategoryMatch != null) break;
    }
    if (subcategoryMatch != null) {
      return provider.getProductsBySubcategory(subcategoryMatch);
    }

    // Otherwise, use the existing search logic
    // Direct search first
    var results = provider.products.where((product) {
      return product.name.toLowerCase().contains(query) ||
             product.description.toLowerCase().contains(query) ||
             (ProductProvider.categoryLookup[product.categoryId]?['category'] ?? '').toLowerCase().contains(query);
    }).toList();

    // If no results, try translating from Arabic to English
    if (results.isEmpty) {
      final queryWords = query.split(' ');
      final List<String> possibleTranslations = [];
      for (final word in queryWords) {
        for (final entry in _arabicToEnglishMap.entries) {
          if (word.contains(entry.key) || entry.key.contains(word)) {
            possibleTranslations.addAll(entry.value);
          }
        }
      }
      if (possibleTranslations.isNotEmpty) {
        results = provider.products.where((product) {
          final nameLower = product.name.toLowerCase();
          final descLower = product.description.toLowerCase();
          final categoryLower = (ProductProvider.categoryLookup[product.categoryId]?['category'] ?? '').toLowerCase();
          for (final translation in possibleTranslations) {
            if (nameLower.contains(translation) || 
                descLower.contains(translation) ||
                categoryLower.contains(translation)) {
              return true;
            }
          }
          return false;
        }).toList();
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final searchResults = _getSearchResults(productProvider);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        elevation: 0,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Seach for products...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: Theme.of(context).textTheme.bodyLarge!.color),

              onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
          ),
          textDirection: TextDirection.ltr, //typing direction
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          autofocus: true,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge!.color),

          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _searchQuery.isEmpty
          ? _buildInitialContent()
          : _buildSearchResults(searchResults),
    );
  }

  Widget _buildInitialContent() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final categories = productProvider.categories;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              return InkWell(
                onTap: () {
                  _searchController.text = category;
                  setState(() {
                    _searchQuery = category;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(category),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            'Search Suggestions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchSuggestion('iPhone 15 Pro'),
          _buildSearchSuggestion('MacBook Air'),
          _buildSearchSuggestion('AirPods Pro'),
          _buildSearchSuggestion('Apple Watch'),
          _buildSearchSuggestion('iPad Pro'),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestion(String suggestion) {
    return ListTile(
      leading: const Icon(Icons.search),
      title: Text(suggestion),
      onTap: () {
        _searchController.text = suggestion;
        setState(() {
          _searchQuery = suggestion;
        });
        // Remove focus from the text field to trigger UI update
        FocusScope.of(context).requestFocus(FocusNode());
      },
    );
  }

  Widget _buildSearchResults(List<Product> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Theme.of(context).hintColor,

            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchQuery"',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for something else.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ProductGridItem(product: results[index]);
      },
    );
  }
}