import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_command_button.dart';
import 'order_summary_screen.dart';
import 'profile_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _hasReadCheckoutDetails = false;
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserAddress();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_hasReadCheckoutDetails) {
          _readCheckoutDetailsAutomatically();
        }
      });
    });
  }

  void _loadUserAddress() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userProfile = userProvider.userProfile;
    
    if (userProfile != null) {
      // Pre-fill address from user profile
      final fullAddress = '${userProfile.street}, ${userProfile.building}, ${userProfile.city}';
      _addressController.text = fullAddress;
    }
  }

  void _readCheckoutDetailsAutomatically() async {
    if (!mounted) return;

    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    _hasReadCheckoutDetails = true;

    if (cartProvider.items.isEmpty) {
      voiceService.speak(
        "Your cart is empty. Please add items before checkout.",
      );
      return;
    }

    // Read checkout details step by step with pauses
    await voiceService.speak("You are now on the checkout screen.");

    // Wait for speech to complete before continuing
    await Future.delayed(const Duration(milliseconds: 2000));

    // Read order summary
    String orderSummary = "Order summary: ";
    for (int i = 0; i < cartProvider.items.length; i++) {
      final item = cartProvider.items[i];
      final totalPrice = item.price * item.quantity;
      orderSummary +=
          'Product ${i + 1}: ${item.name}, Quantity: ${item.quantity}, Price: ${totalPrice.toStringAsFixed(2)} Egyptian Pounds. ';
    }
    await voiceService.speak(orderSummary);
    await Future.delayed(const Duration(milliseconds: 2000));

    // Read payment method - clearly state "Cash on delivery"
    await voiceService.speak("Payment method: Cash on delivery!");
    await Future.delayed(const Duration(milliseconds: 2000));

    // Read shipping - clearly state "Free delivery"
    await voiceService.speak("Shipping: Free delivery!");
    await Future.delayed(const Duration(milliseconds: 2000));

    // Read price breakdown with clear details
    final subtotal = cartProvider.totalAmount;
    final tax = subtotal * 0.14;
    final total = subtotal + tax;

    await voiceService.speak("Price breakdown:");
    await Future.delayed(const Duration(milliseconds: 1000));

    await voiceService.speak(
      "Subtotal: ${subtotal.toStringAsFixed(2)} Egyptian Pounds",
    );
    await Future.delayed(const Duration(milliseconds: 1000));

    await voiceService.speak("Tax: ${tax.toStringAsFixed(2)} Egyptian Pounds");
    await Future.delayed(const Duration(milliseconds: 1000));

    await voiceService.speak(
      "Total: ${total.toStringAsFixed(2)} Egyptian Pounds",
    );
    await Future.delayed(const Duration(milliseconds: 2000));

    // Final instructions
    if (_addressController.text.isEmpty) {
      await voiceService.speak(
        "Please enter your delivery address before confirming your order. Say 'read again' to repeat this information.",
      );
    } else {
      await voiceService.speak(
        "Say 'confirm' to place your order, or 'read again' to repeat this information.",
      );
    }

    // Store complete details for "read again" functionality
    List<String> allSegments = [
      "Checkout details:",
      orderSummary,
      "Payment method: Cash on delivery!",
      "Shipping: Free delivery!",
      "Price breakdown:",
      "Subtotal: ${subtotal.toStringAsFixed(2)} Egyptian Pounds",
      "Tax: ${tax.toStringAsFixed(2)} Egyptian Pounds",
      "Total: ${total.toStringAsFixed(2)} Egyptian Pounds",
      _addressController.text.isEmpty
          ? "Please enter your delivery address before confirming."
          : "Say 'confirm' to place your order.",
    ];

    String completeCheckoutDetails = allSegments.join(' ');
    voiceService.updateLastSpokenPhrase(completeCheckoutDetails);
  }

  double get subtotal =>
      Provider.of<CartProvider>(context, listen: false).totalAmount;
  double get tax => subtotal * 0.14;
  double get total => subtotal + tax;

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    if (voiceService.lastCommand != null) {
      final command = voiceService.lastCommand!;

      if (command.type == VoiceCommandType.confirm) {
        final action = command.parameters['action'] as String?;
        if (action == 'confirm_order') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (cartProvider.items.isEmpty) {
              voiceService.speak("Your cart is empty. Please add items before checkout.");
              return;
            }

            if (_addressController.text.trim().isEmpty) {
              voiceService.speak("Please provide a delivery address before confirming your order.");
              return;
            }

            // Get user profile address if available
            final userProfile = userProvider.userProfile;
            String deliveryAddress = _addressController.text.trim();
            
            // If no address entered but user has profile address, use that
            if (deliveryAddress.isEmpty && userProfile != null) {
              deliveryAddress = '${userProfile.street}, ${userProfile.building}, ${userProfile.city}';
              _addressController.text = deliveryAddress;
            }

            // Final validation
            if (deliveryAddress.isEmpty) {
              voiceService.speak("Please provide a delivery address before confirming your order.");
              return;
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OrderSummaryScreen(
                  cartItems: cartProvider.items,
                  subtotal: subtotal,
                  tax: tax,
                  total: total,
                  address: deliveryAddress,
                ),
              ),
            );
            voiceService.clearLastCommand();
          });
        }
      } else if (command.type == VoiceCommandType.readAgain) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _hasReadCheckoutDetails = false;
          _readCheckoutDetailsAutomatically();
          voiceService.clearLastCommand();
        });
      }
    }

    if (cartProvider.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              _hasReadCheckoutDetails = false;
              _readCheckoutDetailsAutomatically();
            },
            tooltip: 'Read checkout details',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Summary',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cartProvider.items.length,
                          itemBuilder: (context, index) {
                            final item = cartProvider.items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name),
                                        Text(
                                          'Qty: ${item.quantity} × ${item.price.toStringAsFixed(2)} EGP',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${item.totalPrice.toStringAsFixed(2)} EGP',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Delivery Address
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delivery Address',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            TextButton(
                              onPressed: () {
                                // Future enhancement: integrate with profile system
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter address directly below',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Enter Address'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Enter your delivery address',
                            border: OutlineInputBorder(),
                            hintText: 'Street, City, Postal Code',
                          ),
                          maxLines: 3,
                          onChanged: (value) {
                            // Re-read checkout details when address changes
                            if (value.isNotEmpty) {
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (mounted) {
                                    final voiceService =
                                        Provider.of<VoiceAssistantService>(
                                          context,
                                          listen: false,
                                        );
                                    voiceService.speak(
                                      "Address updated. Say 'read again' to hear the updated checkout details.",
                                    );
                                  }
                                },
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Payment Method
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.green.withOpacity(0.1),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.money, color: Colors.green),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cash on Delivery',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Pay when your order arrives at your doorstep',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Shipping
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shipping',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.blue.withOpacity(0.1),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.local_shipping, color: Colors.blue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Free Shipping',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'No additional shipping charges',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Price Breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price Breakdown',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text('${subtotal.toStringAsFixed(2)} EGP'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tax (14%):'),
                            Text('${tax.toStringAsFixed(2)} EGP'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Shipping:'),
                            const Text(
                              'Free',
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${total.toStringAsFixed(2)} EGP',
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          const VoiceCommandButton(),
        ],
      ),
      bottomNavigationBar: Container(
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
                  'Total: ${total.toStringAsFixed(2)} EGP',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_addressController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a delivery address'),
                      ),
                    );
                    final voiceService = Provider.of<VoiceAssistantService>(
                      context,
                      listen: false,
                    );
                    voiceService.speak(
                      "Please enter a delivery address before confirming your order.",
                    );
                    return;
                  }

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => OrderSummaryScreen(
                            cartItems: cartProvider.items,
                            subtotal: subtotal,
                            tax: tax,
                            total: total,
                            address: _addressController.text,
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Confirm Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
}
