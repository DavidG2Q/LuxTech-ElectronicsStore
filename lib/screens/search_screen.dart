import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/voice_assistant_service.dart';
import '../services/product_service.dart';
import '../widgets/voice_command_button.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  List<Product> _searchResults = [];

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(text: widget.initialQuery);

    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }

    // Announce the screen after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceService = Provider.of<VoiceAssistantService>(
        context,
        listen: false,
      );

      if (widget.initialQuery.isNotEmpty) {
        voiceService.announceScreen(
          'Search Results',
          additionalInfo:
              'Showing ${_searchResults.length} results for "${widget.initialQuery}"',
        );
      } else {
        voiceService.announceScreen(
          'Search',
          additionalInfo:
              'Enter a search term or use voice commands to search.',
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    // Reset results if query is empty
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final productService = Provider.of<ProductService>(
        context,
        listen: false,
      );
      final voiceService = Provider.of<VoiceAssistantService>(
        context,
        listen: false,
      );

      final results = await productService.searchProducts(query);

      // Update state with results
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });

      if (results.isEmpty) {
        await voiceService.speak('No products found matching "$query".');
      } else {
        await voiceService.speak(
          'Found ${results.length} products matching "$query".',
        );
      }
    } catch (error) {
      debugPrint('Error during search: $error');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while searching. Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );

      // Reset results on error
      setState(() {
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);
    final productService = Provider.of<ProductService>(context);

    if (voiceService.lastCommand != null) {
      final command = voiceService.lastCommand!;

      if (command.type == VoiceCommandType.navigation) {
        final destination = command.parameters['destination'] as String?;

        if (destination == 'home') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pop(context);
          });
        }
      } else if (command.type == VoiceCommandType.search) {
        final query = command.parameters['query'] as String?;

        if (query != null && query.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchController.text = query;
            _performSearch(query);
          });
        }
      } else if (command.type == VoiceCommandType.readDetails) {
        final productName = command.parameters['productName'] as String?;

        if (productName != null && productName.isNotEmpty) {
          final product = productService.findProductByName(productName);

          if (product != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
            });
          } else {
            voiceService.speak('Product "$productName" not found.');
          }
        }
      } else if (command.type == VoiceCommandType.addToCart) {
        final productName = command.parameters['productName'] as String?;

        if (productName != null && productName.isNotEmpty) {
          final product = productService.findProductByName(productName);

          if (product != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              productService.addToCart(product);
              voiceService.speak('Added ${product.name} to cart.');

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${product.name} to cart'),
                  duration: const Duration(seconds: 2),
                ),
              );
            });
          } else {
            voiceService.speak('Product "$productName" not found.');
          }
        }
      }

      // Reset the command after handling it
      voiceService.clearLastCommand();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
            tooltip: 'Go to cart',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for products...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => _performSearch(value),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _performSearch(value),
                ),
              ),

              // Search results
              Expanded(
                child:
                    _searchResults.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchController.text.isEmpty
                                    ? Icons.search
                                    : Icons.search_off,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Enter a search term'
                                    : 'No products found',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              if (_searchController.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Try a different search term',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final product = _searchResults[index];

                            return Semantics(
                              label:
                                  'Product: ${product.name}, Price: ${product.price.toStringAsFixed(2)} EGP',
                              hint: 'Double tap to view product details',
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: InkWell(
                                  onTap: () {
                                    voiceService.speak(
                                      'Selected product: ${product.name}',
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ProductDetailScreen(
                                              product: product,
                                            ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Product image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            product.imageUrl,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Container(
                                                width: 100,
                                                height: 100,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Product details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${product.price.toStringAsFixed(2)} EGP',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                product.description,
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.bodyMedium,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: () {
                                                      productService.addToCart(
                                                        product,
                                                      );
                                                      voiceService.speak(
                                                        'Added ${product.name} to cart',
                                                      );

                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Added ${product.name} to cart',
                                                          ),
                                                          duration:
                                                              const Duration(
                                                                seconds: 2,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.add_shopping_cart,
                                                    ),
                                                    label: const Text(
                                                      'Add to Cart',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),

          // Voice command button
          const VoiceCommandButton(),

          // Voice listening indicator
          if (voiceService.isListening)
            Container(
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Listening...',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        voiceService.lastWords.isEmpty
                            ? 'Say a command'
                            : voiceService.lastWords,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
