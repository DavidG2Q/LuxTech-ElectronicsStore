import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../utils/utils.dart';
import '../utils/price_calculator.dart';

class CheckoutSummaryCard extends StatelessWidget {
  const CheckoutSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    
    final cartItems = cartProvider.items.values.toList();
    final subtotal = cartProvider.totalAmount;
    final priceComponents = PriceCalculator.getPriceComponents(subtotal);

    // Update total in order provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      orderProvider.setOrderTotal(priceComponents['total']!);
    });

    // Get payment method details
    final paymentMethod = orderProvider.paymentMethod;
    final cardDetails = orderProvider.cardDetails;
    
    // Get address from profile
    final address = authProvider.address;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Shipping address summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Shipping Address',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (address == null || address!.isEmpty)
                    Text(
                      'Please complete your profile information',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Text('Address: '),
                        Expanded(
                          child: Text(
                            address!,
                            style: const TextStyle(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (authProvider.phone == null || authProvider.phone!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Please add your phone number in your profile',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (authProvider.phone != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Text('Phone: '),
                          Text(
                        authProvider.phone!,
                            style: const TextStyle(
                          fontSize: 14,
                        ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            
            // Payment method summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.payment, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Payment Method: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: _buildPaymentMethodText(paymentMethod, cardDetails),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            
            // Order items
            const Text(
              'Products in your order',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cartItems.length,
              itemBuilder: (ctx, index) {
                final item = cartItems[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(item.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.size.isNotEmpty)
                        Text(
                          'Variant: ${item.size}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      if (item.color.isNotEmpty)
                        Text(
                          'Color: ${item.color}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        'Quantity: ${item.quantity}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    formatPrice(item.price * item.quantity),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
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
                  style: TextStyle(
                    color: Colors.green,
                  ),
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
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethodText(String paymentMethod, Map<String, String>? cardDetails) {
    String text;
    switch (paymentMethod) {
      case 'credit_card':
        if (cardDetails != null && cardDetails['number'] != null) {
          final maskedNumber = cardDetails['number']!.replaceAll(' ', '');
          final lastFour = maskedNumber.length >= 4 
              ? maskedNumber.substring(maskedNumber.length - 4) 
              : '****';
          
          text = 'Credit Card - ${cardDetails['type'] ?? 'Visa'} ****$lastFour';
        } else {
          text = 'Credit Card';
        }
        break;
      
      case 'bank_transfer':
        text = 'Bank Transfer';
        break;
      
      case 'cash_on_delivery':
        text = 'Cash on Delivery';
        break;
      
      default:
        text = 'No payment method selected';
    }
    
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
      ),
    );
  }
}
