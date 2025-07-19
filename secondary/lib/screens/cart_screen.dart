import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../models/cart_item.dart';
import '../screens/checkout_screen.dart';
import '../screens/home_screen.dart';
import '../utils/utils.dart';
import '../widgets/app_cached_image.dart';
import '../utils/price_calculator.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Cart',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge!.color),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          ),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          final cartItems = cartProvider.items.values.toList();

          if (cartItems.isEmpty) {
            return _buildEmptyCart(context);
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._groupItemsByCategoryAndSubcategory(context, cartItems).entries.map((categoryEntry) {
                        final category = categoryEntry.key;
                        final subcategoryItems = categoryEntry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                category.isNotEmpty ? category : 'Other',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...subcategoryItems.entries.map((subcategoryEntry) {
                              final subcategory = subcategoryEntry.key;
                              final items = subcategoryEntry.value;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (subcategory.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, bottom: 4, top: 8),
                                      child: Text(
                                        subcategory,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                  ...items.map((item) => ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: AppCachedImage(
                                      imageUrl: item.imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    title: Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${item.color} | ${item.size}'),
                                        Text(
                                          formatPrice(item.price * item.quantity),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: () => cartProvider.updateQuantity(item.id, item.quantity - 1),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        Text(
                                          '${item.quantity}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () => cartProvider.updateQuantity(item.id, item.quantity + 1),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  )),
                                ],
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              _buildOrderSummary(context, cartProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Your Cart is currently empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some products to your shopping cart',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate directly to home screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Start shopping',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(BuildContext context, CartProvider cartProvider) {
    final subtotal = cartProvider.totalAmount;
    final priceComponents = PriceCalculator.getPriceComponents(subtotal);

    return Card(
      margin: const EdgeInsets.all(16),
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
                  priceComponents['shipping']! > 0 
                      ? formatPrice(priceComponents['shipping']!) 
                      : 'Free',
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cartProvider.items.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Proceed to payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to group items by category and subcategory
  Map<String, Map<String, List<CartItem>>> _groupItemsByCategoryAndSubcategory(BuildContext context, List<CartItem> items) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final Map<String, Map<String, List<CartItem>>> groupedItems = {};
    
    for (var item in items) {
      final product = productProvider.findById(item.productId);
      if (product == null) continue;
      final normalizedCategoryId = product.categoryId.trim().toLowerCase();
      final lookup = ProductProvider.categoryLookup.entries.firstWhere(
        (e) => e.key.trim().toLowerCase() == normalizedCategoryId,
        orElse: () => MapEntry('', <String, String?>{}),
      ).value;
      final category = lookup['category'] ?? '';
      final subcategory = lookup['subcategory'] ?? '';
      
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = {};
      }
      
      if (!groupedItems[category]!.containsKey(subcategory)) {
        groupedItems[category]![subcategory] = [];
      }
      
      groupedItems[category]![subcategory]!.add(item);
    }
    
    return groupedItems;
  }
}
