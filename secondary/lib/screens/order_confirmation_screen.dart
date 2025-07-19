import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../screens/home_screen.dart';
import '../screens/orders_screen.dart';
import '../utils/utils.dart';
import '../widgets/app_cached_image.dart';
import '../utils/price_calculator.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get providers
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    
    // Generate a random order number
    final orderNumber = '${DateTime.now().millisecondsSinceEpoch}'.substring(5);
    
    // Get order details
    final total = orderProvider.orderTotal;
    final paymentMethod = orderProvider.paymentMethod;
    final cardDetails = orderProvider.cardDetails;
    final cartItems = cartProvider.items.values.toList();
    
    // Calculate subtotal, tax, and shipping
    final priceComponents = PriceCalculator.getPriceComponentsFromTotal(total);
    
    // Create order items
    final orderItems = cartItems.map((item) => OrderItem(
      id: DateTime.now().millisecondsSinceEpoch.toString() + item.id,
      productId: item.id,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
      imageUrl: item.imageUrl,
      color: item.color,
      size: item.size,
    )).toList();
    
    // Create and add the order
    final newOrder = Order(
      id: orderNumber,
      userId: authProvider.userId!,
      customerName: authProvider.name ?? 'User',
      customerEmail: authProvider.email ?? 'user@example.com',
      total: priceComponents['total']!,
      date: DateTime.now(),
      status: 'Being Processed',
      items: orderItems,
      shippingAddress: authProvider.address,
      paymentMethod: paymentMethod,
      cardDetails: cardDetails,
    );
    
    // Add order to provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      orderProvider.addOrder(newOrder);
      cartProvider.clear();
    });
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),

                  shape: BoxShape.circle,
                ),
                child:  Icon(
                  Icons.check,
                  color: Theme.of(context).primaryColor,

                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              
              // Success message
               Text(
                'Order Placed Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Order number
              Text(
                'Order Number: #$orderNumber',
                style:  TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Additional details
              Text(
                'A confirmation email has been sent to ${authProvider.email} including the order details.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium!.color,

                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Order summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 1,
                      color: Colors.grey.withOpacity(0.3),
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                     Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Order items
                    ...orderItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          AppCachedImage(
                            imageUrl: item.imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if ((item.size ?? '').isNotEmpty || (item.color ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  if (item.size != null && item.size!.isNotEmpty)
                                    Text(
                                      'Variant: ${item.size}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  if (item.color != null && item.color!.isNotEmpty)
                                    Text(
                                      'Color: ${item.color}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                                Text(
                                  'Quantity: ${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatPrice(item.price * item.quantity),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${item.quantity} × ${formatPrice(item.price)}',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium!.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )).toList(),
                    
                    const Divider(height: 24),
                    
                    // Order totals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text(formatPrice(priceComponents['subtotal']!)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Shipping'),
                        Text(
                          priceComponents['shipping']! > 0 ? formatPrice(priceComponents['shipping']!) : 'Free',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taxes (${(PriceCalculator.taxRate * 100).toInt()}%)'),
                        Text(formatPrice(priceComponents['tax']!)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          formatPrice(priceComponents['total']!),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              // Shipping information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_shipping_outlined),
                        SizedBox(width: 8),
                        Text(
                          'Shipping Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'Address: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            authProvider.address ?? 'Address not provided',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Payment Method: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _getPaymentMethodText(paymentMethod, cardDetails),
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Estimated Delivery Time: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '3-5 business days',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Return to home button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // View orders button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const OrdersScreen()),
                      (route) => route.isFirst,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    foregroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                   'View Orders',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getPaymentMethodText(String paymentMethod, Map<String, String>? cardDetails) {
    switch (paymentMethod) {
      case 'credit_card':
        if (cardDetails != null && cardDetails['number'] != null) {
          final maskedNumber = cardDetails['number']!.replaceAll(' ', '');
          final lastFour = maskedNumber.length >= 4 
              ? maskedNumber.substring(maskedNumber.length - 4) 
              : '****';
          
          return 'Credit Card - ${cardDetails['type'] ?? 'Visa'} ****$lastFour';
        }
        return 'Credit Card';
      
      case 'bank_transfer':
        return 'Bank transfer';
      
      case 'cash_on_delivery':
        return 'Cash on delivery';
      
      default:
        return 'No payment method selected';
    }
  }
}
