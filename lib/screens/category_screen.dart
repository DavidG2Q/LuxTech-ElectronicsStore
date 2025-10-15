import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/voice_assistant_service.dart';
import '../services/product_service.dart';
import '../widgets/voice_command_button.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';

class CategoryScreen extends StatefulWidget {
  final Category? initialCategory;

  const CategoryScreen({super.key, this.initialCategory});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Category _selectedCategory;
  List<Product> _products = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    final productService = Provider.of<ProductService>(context, listen: false);

    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
      _products = productService.getProductsByCategory(_selectedCategory.id);
    } else {
      _selectedCategory = productService.categories.first;
      _products = productService.getProductsByCategory(_selectedCategory.id);
    }

    // Announce the screen after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _isInitialized = true;
        final voiceService = Provider.of<VoiceAssistantService>(
          context,
          listen: false,
        );

        // Set the current category in the voice assistant service
        voiceService.setCurrentCategory(_selectedCategory.id);

        voiceService.announceScreen(_selectedCategory.name);

        // Read available products
        _readProductsList();
      }
    });
  }

  void _readProductsList() {
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );

    List<String> productNames = _products.map((p) => p.name).toList();
    List<double> prices = _products.map((p) => p.price).toList();

    voiceService.readProductsList(productNames, prices);
  }

  void _changeCategory(Category category) {
    final productService = Provider.of<ProductService>(context, listen: false);
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );

    setState(() {
      _selectedCategory = category;
      _products = productService.getProductsByCategory(category.id);
    });

    // Set the current category in the voice assistant service
    voiceService.setCurrentCategory(category.id);

    // Schedule the announcement after the build phase
    Future.delayed(const Duration(milliseconds: 100), () {
      voiceService.announceScreen(category.name);

      // Read available products after category change
      _readProductsList();
    });
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
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
            voiceService.clearLastCommand();
          });
        } else if (destination == 'cart') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
            voiceService.clearLastCommand();
          });
        } else if (destination == 'profile') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            voiceService.clearLastCommand();
          });
        } else if (destination == 'orders') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrdersScreen()),
            );
            voiceService.clearLastCommand();
          });
        }
      } else if (command.type == VoiceCommandType.back) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          voiceService.speakAfterDelay("Going back to previous screen");
          Navigator.pop(context);
          voiceService.clearLastCommand();
        });
      } else if (command.type == VoiceCommandType.selectCategory) {
        final categoryName = command.parameters['categoryName'] as String?;

        if (categoryName != null && categoryName.isNotEmpty) {
          // Find the category by partial name match
          try {
            final category = productService.categories.firstWhere(
              (cat) =>
                  cat.name.toLowerCase().contains(categoryName.toLowerCase()),
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _changeCategory(category);
              voiceService.clearLastCommand();
            });
          } catch (e) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              voiceService.speakAfterDelay(
                "Category not found. Please try again.",
              );
              voiceService.clearLastCommand();
            });
          }
        }
      } else if (command.type == VoiceCommandType.selectProduct) {
        final productName = command.parameters['productName'] as String?;
        final productIndex = command.parameters['productIndex'] as int?;
        final openDetails = command.parameters['openDetails'] as bool? ?? false;

        if (productIndex != null && _products.length > productIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final product = _products[productIndex];
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
              ),
            );

            if (openDetails) {
              voiceService.speakAfterDelay(
                "Opening details for ${product.name}",
              );
            } else {
              voiceService.speakAfterDelay("Please say required quantity");
            }

            voiceService.clearLastCommand();
          });
        } else if (productName != null && productName.isNotEmpty) {
          try {
            final product = _products.firstWhere(
              (p) => p.name.toLowerCase().contains(productName.toLowerCase()),
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              voiceService.speakAfterDelay("Please say required quantity");

              // Navigate to product detail
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
              voiceService.clearLastCommand();
            });
          } catch (e) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              voiceService.speakAfterDelay(
                "Product not found. Please try again.",
              );
              voiceService.clearLastCommand();
            });
          }
        }
      } else if (command.type == VoiceCommandType.help) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          voiceService.speak(voiceService.getHelpText());
          voiceService.clearLastCommand();
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedCategory.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              ).then((_) {
                // Announce screen when returning
                voiceService.announceScreen(_selectedCategory.name);
              });
            },
            tooltip: 'Go to cart',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Category selector
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: productService.categories.length,
                  itemBuilder: (context, index) {
                    final category = productService.categories[index];
                    final isSelected = category.id == _selectedCategory.id;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            _changeCategory(category);
                          }
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Products grid
              Expanded(
                child:
                    _products.isEmpty
                        ? Center(
                          child: Text(
                            'No products found in this category',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        )
                        : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];

                            return Semantics(
                              label:
                                  'Product: ${product.name}, Price: ${product.price.toStringAsFixed(2)} EGP',
                              hint: 'Double tap to view product details',
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Product image
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            SizedBox(
                                              width: double.infinity,
                                              height: double.infinity,
                                              child: Image.network(
                                                product.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return Container(
                                                    color: Colors.grey[300],
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        size: 50,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            Positioned(
                                              right: 8,
                                              top: 8,
                                              child: CircleAvatar(
                                                backgroundColor:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                radius: 18,
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.add_shopping_cart,
                                                    size: 18,
                                                  ),
                                                  color: Colors.white,
                                                  onPressed: () {
                                                    productService.addToCart(
                                                      product,
                                                    );
                                                    voiceService.speakAfterDelay(
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
                                                  tooltip: 'Add to cart',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Product info
                                      Padding(
                                        padding: const EdgeInsets.all(8),
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
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${product.price.toStringAsFixed(2)} EGP',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge?.copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
