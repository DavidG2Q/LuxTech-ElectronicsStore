import 'package:electronic_store/screens/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/wishlist_provider.dart';
import '../providers/cart_provider.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_command_button.dart';
import 'product_detail_screen.dart';
import 'home_screen.dart';
import '../models/product.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _readWishlistItems();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _readWishlistItems() async {
    final wishlistItems = context.read<WishlistProvider>().items;
    if (wishlistItems.isEmpty) {
      await _flutterTts.speak("Your wishlist is empty");
      return;
    }

    String wishlistText = "Items in your wishlist: ";
    for (var item in wishlistItems) {
      wishlistText += "${item.name}, price: ${item.price} EGP. ";
    }
    await _flutterTts.speak(wishlistText);
  }

  Future<void> _addToCart(String id, String name, double price) async {
    await context.read<CartProvider>().addItem(id, name, price);
    await _flutterTts.speak("$name added to cart");
  }

  Future<void> _removeFromWishlist(String id, String name) async {
    await context.read<WishlistProvider>().removeItem(id);
    await _flutterTts.speak("$name removed from wishlist");
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);

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
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartScreen()),
              ).then((_) {
                // Announce screen when returning
                voiceService.announceScreen('Wishlist');
              });
            },
            tooltip: 'Go to cart',
          ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<WishlistProvider>(
            builder: (context, wishlist, child) {
              if (wishlist.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your wishlist is empty',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add items to your wishlist to see them here',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: wishlist.items.length,
                itemBuilder: (context, index) {
                  final item = wishlist.items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: Image.network(
                        item.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          );
                        },
                      ),
                      title: Text(item.name),
                      subtitle: Text('${item.price} EGP'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart),
                            onPressed:
                                () =>
                                    _addToCart(item.id, item.name, item.price),
                            tooltip: 'Add to cart',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed:
                                () => _removeFromWishlist(item.id, item.name),
                            tooltip: 'Remove from wishlist',
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProductDetailScreen(
                                  product: Product(
                                    id: item.id,
                                    name: item.name,
                                    price: item.price,
                                    description: item.description,
                                    imageUrl: item.imageUrl,
                                    category: item.category,
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          const VoiceCommandButton(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
