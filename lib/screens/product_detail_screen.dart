import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_command_button.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';
import 'wishlist_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _hasReadProductDetails = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_hasReadProductDetails) {
          _readProductDetailsAutomatically();
        }
      });
    });
  }

  void _readProductDetailsAutomatically() {
    if (!mounted) return;
    
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );
    
    voiceService.updateShoppingState(
      voiceService.shoppingState.copyWith(isReadingDescription: true)
    );
    
    _hasReadProductDetails = true;
    
    voiceService.readProductDetailsSequentially(
      productName: widget.product.name,
      price: widget.product.price,
      description: widget.product.description,
      features: widget.product.features,
    );
  }

  void _readProductDescription() {
    if (!mounted) return;
    
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );
    
    voiceService.updateShoppingState(
      voiceService.shoppingState.copyWith(isReadingDescription: true)
    );
    
    // Use the enhanced product details reading method
    voiceService.readProductDetailsSequentially(
      productName: widget.product.name,
      price: widget.product.price,
      description: widget.product.description,
      features: widget.product.features,
    );
  }

  // Add methods to control quantity accurately
  void _increaseQuantity() {
    setState(() {
      // Limit maximum quantity to 10 for reasonable bounds
      if (_quantity < 10) {
        _quantity++;
        final voiceService = Provider.of<VoiceAssistantService>(
          context,
          listen: false,
        );
        voiceService.speak('Quantity set to $_quantity');
      } else {
        final voiceService = Provider.of<VoiceAssistantService>(
          context,
          listen: false,
        );
        voiceService.speak('Maximum quantity reached');
      }
    });
  }

  void _decreaseQuantity() {
    setState(() {
      if (_quantity > 1) {
        _quantity--;
        final voiceService = Provider.of<VoiceAssistantService>(
          context,
          listen: false,
        );
        voiceService.speak('Quantity set to $_quantity');
      } else {
        final voiceService = Provider.of<VoiceAssistantService>(
          context,
          listen: false,
        );
        voiceService.speak('Minimum quantity reached');
      }
    });
  }

  void _setQuantity(int value) {
    if (value >= 1 && value <= 10) {
      setState(() {
        _quantity = value;
        final voiceService = Provider.of<VoiceAssistantService>(
          context,
          listen: false,
        );
        voiceService.speak('Quantity set to $_quantity');
      });
    } else {
      final voiceService = Provider.of<VoiceAssistantService>(
        context,
        listen: false,
      );
      voiceService.speak('Please select a quantity between 1 and 10');
    }
  }

  Future<void> _addToWishlist() async {
    final wishlistProvider = Provider.of<WishlistProvider>(
      context,
      listen: false,
    );
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );

    final item = WishlistItem(
      id: widget.product.id,
      name: widget.product.name,
      price: widget.product.price,
      description: widget.product.description,
      imageUrl: widget.product.imageUrl,
      category: widget.product.category,
    );
    await wishlistProvider.addItem(item);
    voiceService.speak('Added ${widget.product.name} to your wishlist.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${widget.product.name} to wishlist'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeFromWishlist() async {
    final wishlistProvider = Provider.of<WishlistProvider>(
      context,
      listen: false,
    );
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );

    await wishlistProvider.removeItem(widget.product.id);
    voiceService.speak('Removed ${widget.product.name} from your wishlist.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${widget.product.name} from wishlist'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final wishlistProvider = Provider.of<WishlistProvider>(
      context,
      listen: false,
    );

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
        } else if (destination == 'wishlist') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WishlistScreen()),
            );
            voiceService.speakAfterDelay("Opening your wishlist");
            voiceService.clearLastCommand();
          });
        }
      } else if (command.type == VoiceCommandType.back) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          voiceService.speakAfterDelay("Going back to previous screen");
          Navigator.pop(context);
        });
      } else if (command.type == VoiceCommandType.setQuantity) {
        final quantity = command.parameters['quantity'] as int?;

        if (quantity != null && quantity > 0) {
          setState(() {
            _quantity = quantity;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            voiceService.speak(
              "Do you want to add more products? Say yes or no.",
            );
          });
        }
      } else if (command.type == VoiceCommandType.addToCart) {
        final specifiedQuantity =
            command.parameters['quantity'] as int? ?? _quantity;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _quantity = specifiedQuantity;
          });

          for (int i = 0; i < _quantity; i++) {
            cartProvider.addItem(
              widget.product.id,
              widget.product.name,
              widget.product.price,
            );
          }

          voiceService.speak('Added $_quantity ${widget.product.name} to cart. Say "My Cart" to go to your cart.');
          voiceService.clearLastCommand();
        });
      } else if (command.type == VoiceCommandType.addToWishlist) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _addToWishlist();
          voiceService.clearLastCommand();
        });
      } else if (command.type == VoiceCommandType.readDetails || 
                 command.type == VoiceCommandType.readAgain) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _readProductDescription();
          voiceService.clearLastCommand();
        });
      } else if (command.type == VoiceCommandType.selectProduct &&
          command.parameters.containsKey('byNumber') &&
          command.parameters['byNumber'] == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final productIndex = command.parameters['productIndex'] as int?;
          if (productIndex != null) {
            voiceService.clearLastCommand();
          }
        });
      } else if (command.type == VoiceCommandType.help) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          voiceService.speak(voiceService.getHelpText());
          voiceService.clearLastCommand();
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
            tooltip: 'Go to cart',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: Image.network(
                    widget.product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50),
                        ),
                      );
                    },
                  ),
                ),

                // Product info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.product.price.toStringAsFixed(2)} EGP',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),

                      // Features list if available
                      if (widget.product.features.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Features',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.product.features.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.product.features[index],
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Quantity selector
                      Row(
                        children: [
                          Text(
                            'Quantity:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _decreaseQuantity,
                                  icon: const Icon(Icons.remove),
                                  tooltip: 'Decrease quantity',
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    _quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _increaseQuantity,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Increase quantity',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Add to cart button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            for (int i = 0; i < _quantity; i++) {
                              cartProvider.addItem(
                                widget.product.id,
                                widget.product.name,
                                widget.product.price,
                              );
                            }

                            voiceService.speak(
                              'Added $_quantity ${widget.product.name} to cart. Say "My Cart" to go to your cart.',
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added $_quantity ${widget.product.name} to cart',
                                ),
                                duration: const Duration(seconds: 2),
                                action: SnackBarAction(
                                  label: 'My Cart',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const CartScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('Add to Cart'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Wishlist button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (wishlistProvider.isInWishlist(widget.product.id)) {
                              await _removeFromWishlist();
                            } else {
                              await _addToWishlist();
                            }
                          },
                          icon: Icon(
                            wishlistProvider.isInWishlist(widget.product.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: wishlistProvider.isInWishlist(widget.product.id)
                                ? Colors.red
                                : null,
                          ),
                          label: Text(
                            wishlistProvider.isInWishlist(widget.product.id)
                                ? 'Remove from Wishlist'
                                : 'Add to Wishlist',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const VoiceCommandButton(),

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
