import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_command_button.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _hasReadCartDetails = false;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_hasReadCartDetails) {
          _readCartDetailsAutomatically();
        }
      });
    });
  }

  void _readCartDetailsAutomatically() {
    if (!mounted) return;
    
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    _hasReadCartDetails = true;
    
    if (cartProvider.items.isEmpty) {
      voiceService.speak("Your cart is empty. Please add items to continue shopping.");
      return;
    }

    // Build detailed cart reading
    List<String> cartSegments = ['Your cart contains:'];
    
    for (int i = 0; i < cartProvider.items.length; i++) {
      final item = cartProvider.items[i];
      final totalPrice = item.price * item.quantity;
      
      cartSegments.add(
        'Product ${i + 1}: ${item.name}, Quantity: ${item.quantity}, Unit price: ${item.price.toStringAsFixed(2)} Egyptian Pounds, Total: ${totalPrice.toStringAsFixed(2)} Egyptian Pounds'
      );
    }

    final totalAmount = cartProvider.totalAmount;
    cartSegments.add('Cart total: ${totalAmount.toStringAsFixed(2)} Egyptian Pounds');
    
    if (cartProvider.items.length > 1) {
      cartSegments.add('To remove an item, say "Delete product" followed by the product number.');
    }
    
    cartSegments.add('Say "checkout" to proceed to checkout, or "read again" to repeat this information.');

    // Store complete details for "read again" functionality
    String completeCartDetails = cartSegments.join(' ');
    voiceService.speakProductDetails(completeCartDetails);
  }

  void _deleteProduct(int index) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final voiceService = Provider.of<VoiceAssistantService>(context, listen: false);
    
    if (index >= 0 && index < cartProvider.items.length) {
      final item = cartProvider.items[index];
      cartProvider.removeItem(item.id);
      voiceService.speak('Removed ${item.name} from cart');
      
      // Re-read cart after deletion if there are still items
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted && cartProvider.items.isNotEmpty) {
          _hasReadCartDetails = false;
          _readCartDetailsAutomatically();
        }
      });
    } else {
      voiceService.speak('Product ${index + 1} not found in cart');
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);
    final cartProvider = Provider.of<CartProvider>(context);

    if (voiceService.lastCommand != null) {
      final command = voiceService.lastCommand!;

      if (command.type == VoiceCommandType.removeFromCart) {
        final productIndex = command.parameters['productIndex'] as int?;
        if (productIndex != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _deleteProduct(productIndex);
            voiceService.clearLastCommand();
          });
        }
      } else if (command.type == VoiceCommandType.checkout) {
        final action = command.parameters['action'] as String?;
        if (action == 'navigate_to_checkout') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (cartProvider.items.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CheckoutScreen()),
              );
            } else {
              voiceService.speak("Your cart is empty. Please add items before checkout.");
            }
            voiceService.clearLastCommand();
          });
        }
      } else if (command.type == VoiceCommandType.readAgain) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _hasReadCartDetails = false;
          _readCartDetailsAutomatically();
          voiceService.clearLastCommand();
        });
      } else if (command.type == VoiceCommandType.navigation) {
        final destination = command.parameters['destination'] as String?;
        if (destination == 'home') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pop(context);
            voiceService.clearLastCommand();
          });
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: _readCartDetailsAutomatically,
            tooltip: 'Read cart items',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (cartProvider.items.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cartProvider.items.length,
              itemBuilder: (context, index) {
                final item = cartProvider.items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unit Price: ${item.price.toStringAsFixed(2)} EGP'),
                        Text('Quantity: ${item.quantity}'),
                        Text(
                          'Total: ${item.totalPrice.toStringAsFixed(2)} EGP',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        cartProvider.removeItem(item.id);
                        voiceService.speak('Removed ${item.name} from cart');
                      },
                    ),
                  ),
                );
              },
            ),
          
          const VoiceCommandButton(),
        ],
      ),
      bottomNavigationBar: cartProvider.items.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${cartProvider.totalAmount.toStringAsFixed(2)} EGP',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Continue Shopping'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CheckoutScreen(),
                              ),
                            );
                          },
                          child: const Text('Checkout'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
