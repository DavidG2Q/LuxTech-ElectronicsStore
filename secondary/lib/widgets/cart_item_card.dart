import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_item.dart';
import '../providers/product_provider.dart';
import '../utils/utils.dart';
import 'app_cached_image.dart';

class CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final Function(String, int) onUpdateQuantity;
  final Function(String) onRemove;

  const CartItemCard({
    super.key,
    required this.cartItem,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Get product provider to check stock availability
    final productProvider = Provider.of<ProductProvider>(context);
    final availableStock =
        productProvider.getProductQuantity(cartItem.productId);
    final isMaxQuantity = cartItem.quantity >= availableStock;

    return Dismissible(
      key: Key(cartItem.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).cardColor,
        ),
      ),
      onDismissed: (direction) {
        onRemove(cartItem.id);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cartItem.name} removed from cart'),
            action: SnackBarAction(
              label: 'Back',
              onPressed: () {
                // not implemented yet
              },
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 10.0, left: 10.0, right: 10.0),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: AppCachedImage(
                imageUrl: cartItem.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cartItem.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (cartItem.size.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Variant: ${cartItem.size}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (cartItem.color.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Color: ${cartItem.color}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Quantity: ${cartItem.quantity}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Price: ${formatPrice(cartItem.price)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatPrice(cartItem.price * cartItem.quantity),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                _buildQuantityButton(
                                  icon: Icons.remove,
                                  onPressed: () => onUpdateQuantity(
                                    cartItem.id,
                                    cartItem.quantity - 1,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '${cartItem.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _buildQuantityButton(
                                  icon: Icons.add,
                                  onPressed: isMaxQuantity
                                      ? null
                                      : () => onUpdateQuantity(
                                            cartItem.id,
                                            cartItem.quantity + 1,
                                          ),
                                  isDisabled: isMaxQuantity,
                                ),
                              ],
                            ),
                            // Show "Not Available" message when at max quantity
                            if (isMaxQuantity)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Not Available',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isDisabled = false,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey[300] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: isDisabled ? Colors.grey[500] : null),
        onPressed: onPressed,
      ),
    );
  }
}
