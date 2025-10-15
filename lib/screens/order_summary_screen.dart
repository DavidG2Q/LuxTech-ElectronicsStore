import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/orders_provider.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_command_button.dart';
import 'home_screen.dart';
import 'orders_screen.dart';

class OrderSummaryScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final double subtotal;
  final double tax;
  final double total;
  final String address;

  const OrderSummaryScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.address,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  bool _hasReadOrderSummary = false;
  String? _orderId;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processOrder();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_hasReadOrderSummary) {
          _readOrderSummaryAutomatically();
        }
      });
    });
  }

  void _processOrder() {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Convert cart items to order items
    final orderItems = widget.cartItems.map((cartItem) => OrderItem(
      id: cartItem.id,
      name: cartItem.name,
      price: cartItem.price,
      quantity: cartItem.quantity,
    )).toList();

    // Add order to orders provider with address
    ordersProvider.addOrder(orderItems, widget.total, widget.address);
    
    // Get the order ID (it will be the most recent order)
    if (ordersProvider.orders.isNotEmpty) {
      _orderId = ordersProvider.orders.first.id;
    }

    // Clear the cart
    cartProvider.clear();
  }

  void _readOrderSummaryAutomatically() {
    if (!mounted) return;
    
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );
    
    _hasReadOrderSummary = true;
    
    String orderSummary = "Order confirmation: ";
    orderSummary += "Your order has been placed successfully. ";
    if (_orderId != null) {
      orderSummary += "Order ID: $_orderId. ";
    }
    orderSummary += "Total amount: ${widget.total.toStringAsFixed(2)} Egyptian Pounds. ";
    orderSummary += "Delivery address: ${widget.address}. ";
    orderSummary += "Payment method: Cash on delivery. ";
    orderSummary += "Estimated delivery time: 3 to 5 days. ";
    orderSummary += "Thank you for shopping with us!";
    
    voiceService.speak(orderSummary);
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
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
            voiceService.clearLastCommand();
            voiceService.announceScreen('Home');
          });
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmation'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: _readOrderSummaryAutomatically,
            tooltip: 'Read order summary',
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
                // Success Icon and Message
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Order Placed Successfully!',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (_orderId != null)
                        Text(
                          'Order ID: $_orderId',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Order Details
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.cartItems.length,
                          itemBuilder: (context, index) {
                            final item = widget.cartItems[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          'Qty: ${item.quantity} × ${item.price.toStringAsFixed(2)} EGP',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${item.totalPrice.toStringAsFixed(2)} EGP',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text('${widget.subtotal.toStringAsFixed(2)} EGP'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tax (14%):'),
                            Text('${widget.tax.toStringAsFixed(2)} EGP'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Shipping:'),
                            const Text('Free', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${widget.total.toStringAsFixed(2)} EGP',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

                const SizedBox(height: 16),

                // Delivery Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Delivery Address:',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(widget.address),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.orange),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estimated Delivery:',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '3-5 business days',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.payment, color: Colors.green),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Method:',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text('Cash on Delivery'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Action Buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.home),
                        label: const Text('Continue Shopping'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Navigate to orders screen
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const OrdersScreen()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('View My Orders'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          const VoiceCommandButton(),
        ],
      ),
    );
  }
}
