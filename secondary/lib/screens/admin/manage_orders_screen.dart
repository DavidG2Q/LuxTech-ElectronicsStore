import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/star_rating.dart';
import '../../utils/utils.dart';
import '../profile_screen.dart';
import 'admin_dashboard_screen.dart';
import '../../widgets/app_cached_image.dart';
import '../../utils/price_calculator.dart';

class ManageOrdersScreen extends StatefulWidget {
  static const routeName = '/manage-orders';

  const ManageOrdersScreen({Key? key}) : super(key: key);

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _sortAscending = false; // false = descending, true = ascending
  String _sortBy = 'date'; // default sort by date
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateOrderStatus(String orderId, String newStatus) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.updateOrderStatus(orderId, newStatus);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order status updated for order $orderId to $newStatus')),
    );
  }

  void _showCancelOrderConfirmation(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
              orderProvider.cancelOrder(orderId);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$orderId has been cancelled successfully')),
              );
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: Theme.of(ctx),
        child: AlertDialog(
          backgroundColor: Theme.of(ctx).dialogBackgroundColor,
          title: Text(
            'Order information for order ${order.id}',
            style: TextStyle(color: Theme.of(ctx).textTheme.bodyLarge!.color),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Name: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).textTheme.bodyLarge!.color,
                        ),
                      ),
                      TextSpan(
                        text: order.customerName,
                        style: TextStyle(color: Theme.of(ctx).textTheme.bodyLarge!.color),
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Email: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).textTheme.bodyLarge!.color,
                        ),
                      ),
                      TextSpan(
                        text: order.customerEmail,
                        style: TextStyle(color: Theme.of(ctx).textTheme.bodyLarge!.color),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: Colors.grey.withOpacity(0.3),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Date: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).textTheme.bodyLarge!.color,
                        ),
                      ),
                      TextSpan(
                        text: '${order.date.day}/${order.date.month}/${order.date.year}',
                        style: TextStyle(color: Theme.of(ctx).textTheme.bodyLarge!.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Show return reason if order is in return process
                if (order.status == 'Return') ...[
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Return Reason: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(ctx).textTheme.bodyLarge!.color,
                          ),
                        ),
                        TextSpan(
                          text: order.returnReason ?? 'No reason provided',
                          style: TextStyle(color: Theme.of(ctx).textTheme.bodyLarge!.color),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: Colors.grey.withOpacity(0.3),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ],
                
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Shipping Address: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).textTheme.bodyLarge!.color,
                        ),
                      ),
                      TextSpan(
                        text: order.shippingAddress ?? 'Address not provided',
                        style: TextStyle(color: Theme.of(ctx).textTheme.bodyLarge!.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Payment Method: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(ctx).textTheme.bodyLarge!.color,
                          ),
                        ),
                        TextSpan(
                          text: _getPaymentMethodText(order.paymentMethod, order.cardDetails),
                          style: TextStyle(color: Theme.of(ctx).textTheme.bodyLarge!.color),
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.rating != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rating: ${order.rating!.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (order.bankDetails != null && order.bankDetails!.isNotEmpty) ...[
                  Container(
                    height: 1,
                    color: Colors.grey.withOpacity(0.3),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  Text(
                    'Bank Details for Refund',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(ctx).textTheme.titleMedium!.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Full Name: ${order.bankDetails!['fullName']}',
                    style: TextStyle(
                      color: Theme.of(ctx).textTheme.bodyMedium!.color,
                    ),
                  ),
                  Text(
                    'Account Number: ${order.bankDetails!['accountNumber']}',
                    style: TextStyle(
                      color: Theme.of(ctx).textTheme.bodyMedium!.color,
                    ),
                  ),
                  if (order.bankDetails!.containsKey('bankName') && order.bankDetails!['bankName']!.isNotEmpty)
                    Text(
                      'Bank Name: ${order.bankDetails!['bankName']}',
                      style: TextStyle(
                        color: Theme.of(ctx).textTheme.bodyMedium!.color,
                      ),
                    ),
                ],
                
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: Colors.grey.withOpacity(0.3),
                  margin: const EdgeInsets.only(bottom: 16),
                ),
                Text(
                  'Products: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) => _buildOrderItemCard(item, order)).toList(),
                const SizedBox(height: 16),
                _buildOrderSummary(order),
                const SizedBox(height: 16),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: Theme.of(ctx).primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemCard(OrderItem item, Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            AppCachedImage(
              imageUrl: item.imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 8),
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
                  const SizedBox(height: 4),
                  Text(
                    'Price: ${formatPrice(item.price)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Qty: ${item.quantity}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Orders'),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            ),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
              );
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Being Processed'),
              Tab(text: 'Shipped'),
              Tab(text: 'Delivered'),
              Tab(text: 'Cancelled'),
              Tab(text: 'Returned'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search and Sort Controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by ID, Customer, Email, or Payment',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Sorting Options
                  Row(
                    children: [
                      const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _sortBy,
                              items: const [
                                DropdownMenuItem(value: 'date', child: Text('Date')),
                                DropdownMenuItem(value: 'id', child: Text('Order ID')),
                                DropdownMenuItem(value: 'status', child: Text('Status')),
                                DropdownMenuItem(value: 'price', child: Text('Price')),
                                DropdownMenuItem(value: 'customer', child: Text('Customer Name')),
                                DropdownMenuItem(value: 'email', child: Text('Customer Email')),
                                DropdownMenuItem(value: 'payment', child: Text('Payment Method')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _sortBy = value!;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sort Toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _sortAscending = !_sortAscending;
                          });
                        },
                        child: Container(
                          height: 48, // Match the height of the dropdown
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Center(
                            child: Text(
                              _sortAscending ? 'Newest First' : 'Oldest First',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Being Processed Tab
                  _buildOrdersList('Being Processed'),
                  // Shipped Tab
                  _buildOrdersList('Shipped'),
                  // Delivered Tab
                  _buildOrdersList('Delivered'),
                  // Cancelled Tab
                  _buildOrdersList('Cancelled'),
                  // Returned Tab
                  _buildOrdersList('Return'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOrdersList(String statusFilter) {
    return Consumer<OrderProvider>(
      builder: (ctx, orderProvider, child) {
        // Filter orders by status
        var filteredOrders = orderProvider.allOrders
            .where((order) => order.status == statusFilter)
            .toList();
        
        // Apply search filter if search query is not empty
        if (_searchQuery.isNotEmpty) {
          filteredOrders = filteredOrders
              .where((order) => 
                  order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  order.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  order.customerEmail.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  order.paymentMethod.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (order.returnReason != null && 
                   order.returnReason!.toLowerCase().contains(_searchQuery.toLowerCase())))
              .toList();
        }
        
        // Sort orders based on selected sort option
        filteredOrders.sort((a, b) {
          int result = 0;
          
          switch (_sortBy) {
            case 'date':
              result = a.date.compareTo(b.date);
              break;
            case 'id':
              result = a.id.compareTo(b.id);
              break;
            case 'status':
              // For status sorting within the same tab, we can sort by return status if applicable
              if (a.status == 'Return' && b.status == 'Return') {
                result = (a.returnStatus ?? '').compareTo(b.returnStatus ?? '');
              } else {
                result = 0; // Same status within tab
              }
              break;
            case 'price':
              result = a.total.compareTo(b.total);
              break;
            case 'customer':
              result = a.customerName.compareTo(b.customerName);
              break;
            case 'email':
              result = a.customerEmail.compareTo(b.customerEmail);
              break;
            case 'payment':
              result = a.paymentMethod.compareTo(b.paymentMethod);
              break;
            default:
              result = a.date.compareTo(b.date);
          }
          
          // Apply ascending/descending order
          return _sortAscending ? result : -result;
        });

        return filteredOrders.isEmpty
            ? Center(
                child: Text(
                  'No ${statusFilter.toLowerCase()} orders found.',
                  style: const TextStyle(fontSize: 18),
                ),
              )
            : ListView.builder(
                itemCount: filteredOrders.length,
                itemBuilder: (ctx, index) {
                  final order = filteredOrders[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Add product images (up to 3) in a column
                              if (order.items.isNotEmpty)
                                Column(
                                  children: order.items.take(3).map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AppCachedImage(
                                        imageUrl: item.imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Order ${order.id}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Theme.of(context).textTheme.bodyLarge!.color,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: order.status == 'Being Processed'
                                                ? Colors.orange
                                                : order.status == 'Shipped'
                                                    ? Colors.blue
                                                    : order.status == 'Delivered'
                                                        ? Colors.green
                                                        : order.status == 'Cancelled'
                                                            ? Colors.red
                                                            : order.status == 'Return'
                                                                ? (order.returnStatus == 'Accepted Return' 
                                                                    ? Colors.green 
                                                                    : order.returnStatus == 'Returned'
                                                                        ? Colors.purple
                                                                        : Colors.amber)
                                                                : Colors.grey,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            order.status == 'Return' && order.returnStatus != null
                                                ? order.returnStatus!
                                                : order.status,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Date: ${order.date.day}/${order.date.month}/${order.date.year} ${order.date.hour > 12 ? order.date.hour - 12 : (order.date.hour == 0 ? 12 : order.date.hour)}:${order.date.minute.toString().padLeft(2, '0')} ${order.date.hour >= 12 ? 'PM' : 'AM'}',
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium!.color,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Customer: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).textTheme.bodyLarge!.color,
                                            ),
                                          ),
                                          TextSpan(
                                            text: order.customerName,
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyLarge!.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'email : ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).textTheme.bodyLarge!.color,
                                            ),
                                          ),
                                          TextSpan(
                                            text: order.customerEmail,
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyLarge!.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Shipping Address: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).textTheme.bodyLarge!.color,
                                            ),
                                          ),
                                          TextSpan(
                                            text: order.shippingAddress ?? 'Address not provided',
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyLarge!.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          _getPaymentIcon(order.paymentMethod),
                                          size: 16,
                                          color: Theme.of(context).textTheme.bodyMedium!.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Payment: ${_getPaymentMethodShortText(order.paymentMethod)}',
                                          style: TextStyle(
                                            color: Theme.of(context).textTheme.bodyMedium!.color,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Show rating if order has been rated
                                    if (order.rating != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Rating: ${order.rating!.toStringAsFixed(1)}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 12),
                                    
                                    // Status buttons - only show relevant buttons based on current status
                                    if (statusFilter == 'Being Processed') ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: _buildStatusButton(
                                              'Shipped',
                                              Colors.blue,
                                              order.id,
                                              false,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _showCancelOrderConfirmation(order.id),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              ),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (statusFilter == 'Shipped') ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: _buildStatusButton(
                                              'Delivered',
                                              Colors.green,
                                              order.id,
                                              false,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _showCancelOrderConfirmation(order.id),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              ),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (statusFilter == 'Return' && order.returnStatus == 'Being inspected') ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            // Complete the return immediately
                                            final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                                            orderProvider.completeReturn(order.id);
                                            
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Return completed for order ${order.id}'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Accept Returned Product'),
                                        ),
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Total Price: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                                fontSize: 16,
                                              ),
                                            ),
                                            TextSpan(
                                              text: formatPrice(order.total),
                                              style: const TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => _showOrderDetails(order),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text('Show Details'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
      },
    );
  }

  // Helper method to get color based on return status
  Color _getReturnStatusColor(String status) {
    switch (status) {
      case 'Return requested':
        return Colors.amber;
      case 'Received by the courier':
        return Colors.blue;
      case 'Being inspected':
        return Colors.orange;
      case 'Accepted Return':
        return Colors.green;
      case 'Returned':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusButton(
    String status,
    Color color,
    String orderId,
    bool isSelected,
  ) {
    return ElevatedButton(
      onPressed: isSelected
          ? null
          : () => _updateOrderStatus(orderId, status),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isSelected ? Colors.white70 : Colors.white,
          fontSize: 12,
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
        return 'Bank Transfer';
      
      case 'cash_on_delivery':
        return 'Cash on Delivery';
      
      default:
        return 'Not Specified';
    }
  }

  String _getSortByText() {
    switch (_sortBy) {
      case 'date':
        return _sortAscending ? 'Oldest First' : 'Newest First';
      case 'id':
        return _sortAscending ? 'ID (A-Z)' : 'ID (Z-A)';

      case 'price':
        return _sortAscending ? 'Price (Low-High)' : 'Price (High-Low)';
      case 'customer':
        return _sortAscending ? 'Name (A-Z)' : 'Name (Z-A)';
      case 'email':
        return _sortAscending ? 'Email (A-Z)' : 'Email (Z-A)';
      case 'payment':
        return _sortAscending ? 'Payment (A-Z)' : 'Payment (Z-A)';
      default:
        return '';
    }
  }

  IconData _getPaymentIcon(String paymentMethod) {
    switch (paymentMethod) {
      case 'credit_card':
        return Icons.credit_card;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'cash_on_delivery':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodShortText(String paymentMethod) {
    switch (paymentMethod) {
      case 'credit_card':
        return 'Credit Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cash_on_delivery':
        return 'Cash on Delivery';
      default:
        return 'Unknown';
    }
  }

  Widget _buildOrderSummary(Order order) {
    final priceComponents = PriceCalculator.getPriceComponentsFromTotal(order.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subtotal',
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
            ),
            Text(
              formatPrice(priceComponents['subtotal']!),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shipping',
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
            ),
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
            Text(
              'Taxes (${(PriceCalculator.taxRate * 100).toInt()}%)',
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
            ),
            Text(
              formatPrice(priceComponents['tax']!),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
            ),
          ],
        ),
        Container(
          height: 1,
          color: Colors.grey.withOpacity(0.3),
          margin: const EdgeInsets.symmetric(vertical: 12),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Price',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge!.color,
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
    );
  }

  // Bank details form widget
  Widget _buildBankDetailsForm(BuildContext context, String orderId) {
    final _formKey = GlobalKey<FormState>();
    String fullName = '';
    String accountNumber = '';
    String bankName = '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).primaryColor, width: 1),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Bank Details for Refund',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person, color: Theme.of(context).iconTheme.color),
                border: const OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
              onSaved: (value) {
                fullName = value!;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Bank Account Number',
                prefixIcon: Icon(Icons.account_balance, color: Theme.of(context).iconTheme.color),
                border: const OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your account number';
                }
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Please enter numbers only';
                }
                return null;
              },
              onSaved: (value) {
                accountNumber = value!;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Bank Name (Optional)',
                prefixIcon: Icon(Icons.business, color: Theme.of(context).iconTheme.color),
                border: const OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
              onSaved: (value) {
                bankName = value ?? '';
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    
                    // Save bank details
                    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                    orderProvider.saveBankDetails(orderId, fullName, accountNumber, bankName);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bank details submitted successfully!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit Bank Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


