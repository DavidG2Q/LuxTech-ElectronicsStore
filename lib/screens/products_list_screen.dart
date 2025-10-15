import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/voice_assistant_service.dart';
import '../services/product_service.dart';
import '../providers/cart_provider.dart';
import '../widgets/voice_command_button.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

class ProductsListScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const ProductsListScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productService = Provider.of<ProductService>(
        context,
        listen: false,
      );
      setState(() {
        _products = productService.getProductsByCategory(widget.categoryId);
      });

      final voiceService = Provider.of<VoiceAssistantService>(
        context,
        listen: false,
      );
      voiceService.startProductSelection();
      _announceProducts();
    });
  }

  void _announceProducts() {
    if (_products.isEmpty) return;

    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );

    List<String> productNames = [];
    List<double> prices = [];

    for (var product in _products) {
      productNames.add(product.name);
      prices.add(product.price);
    }

    voiceService.readProductsList(productNames, prices);
  }

  void _addToCart(Product product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );

    cartProvider.addItem(product.id, product.name, product.price);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${product.name} to cart'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
        ),
      ),
    );

    voiceService.speak(
      'Added ${product.name} to cart. Would you like to view your cart or continue shopping?',
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (!voiceService.isListening) {
        voiceService.startListening();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);

    if (voiceService.lastCommand != null) {
      final command = voiceService.lastCommand!;

      if (command.type == VoiceCommandType.addToCart &&
          command.parameters['byNumber'] == true &&
          command.parameters.containsKey('productIndex')) {
        final int? index = command.parameters['productIndex'] as int?;

        if (index != null && index >= 0 && index < _products.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _addToCart(_products[index]);
            voiceService.clearLastCommand();
          });
        }
      } else if (command.type == VoiceCommandType.navigation &&
          command.parameters['destination'] == 'cart') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          voiceService.clearLastCommand();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          );
        });
      } else if (command.type == VoiceCommandType.selectProduct) {
        final int? index = command.parameters['productIndex'] as int?;

        if (index != null && index >= 0 && index < _products.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            voiceService.clearLastCommand();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ProductDetailScreen(product: _products[index]),
              ),
            );
          });
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: _announceProducts,
            tooltip: 'Read products',
          ),
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
          _products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(product.name),
                      subtitle: Text('${product.price.toStringAsFixed(2)} EGP'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        onPressed: () => _addToCart(product),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    ProductDetailScreen(product: product),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
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
