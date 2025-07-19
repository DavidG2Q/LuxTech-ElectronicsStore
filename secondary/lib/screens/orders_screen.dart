import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/star_rating.dart';
import '../utils/utils.dart';
import '../screens/profile_screen.dart';
import '../widgets/app_cached_image.dart';
import '../utils/price_calculator.dart';

class BankDetailsFormWidget extends StatefulWidget {
  final String orderId;

  const BankDetailsFormWidget({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<BankDetailsFormWidget> createState() => _BankDetailsFormWidgetState();
}

class _BankDetailsFormWidgetState extends State<BankDetailsFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Bank Details for Refund',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountNumberController,
              decoration: const InputDecoration(
                labelText: 'Bank Account Number',
                prefixIcon: Icon(Icons.account_balance),
                border: OutlineInputBorder(),
              ),
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Bank Name (Optional)',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Save bank details
                    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                    orderProvider.saveBankDetails(
                      widget.orderId,
                      _fullNameController.text,
                      _accountNumberController.text,
                      _bankNameController.text.isNotEmpty ? _bankNameController.text : null,
                    );
                    
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

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _searchQuery = '';
  bool _sortAscending = false; // false = descending (newest first), true = ascending (oldest first)
  String? _selectedStatus; // null means show all orders
  Map<String, double> _localRatings = {}; // Add this to track ratings locally
  Map<String, String> _localStatuses = {}; // Add this to track statuses locally

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    
    // Get user's orders
    final orders = orderProvider.getOrdersForUser(authProvider.userId!);

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? Theme.of(context).scaffoldBackgroundColor 
              : Colors.white,
          elevation: 0,
          surfaceTintColor: Theme.of(context).brightness == Brightness.dark 
              ? Theme.of(context).scaffoldBackgroundColor 
              : Colors.white,
          scrolledUnderElevation: 0,
          title: Text(
            'My Orders',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : Colors.black,
            ),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
              (route) => false,
            ),
          ),
        ),
        body: Column(
          children: [
            // Search and Filter Controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by Order ID, Product, or Status',
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
                  // Filter and Sort Row
                  Row(
                    children: [
                      // Filter Dropdown
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
                              value: _selectedStatus,
                              hint: const Text('All Orders'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Orders'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Being Processed',
                                  child: Text('Being Processed'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Shipped',
                                  child: Text('Shipped'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Delivered',
                                  child: Text('Delivered'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Return',
                                  child: Text('Returns'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Cancelled',
                                  child: Text('Cancelled'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value;
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
            
            // Orders List
            Expanded(
              child: _buildOrdersList(orders),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Order> allOrders) {
    // Apply status filter if selected
    var filteredOrders = _selectedStatus != null
        ? allOrders.where((order) => order.status == _selectedStatus).toList()
        : allOrders;
    
    // Apply search filter if search query is not empty
    if (_searchQuery.isNotEmpty) {
      filteredOrders = filteredOrders.where((order) {
        final searchLower = _searchQuery.toLowerCase();
        return order.id.toLowerCase().contains(searchLower) ||
               order.status.toLowerCase().contains(searchLower) ||
               order.items.any((item) => item.name.toLowerCase().contains(searchLower));
      }).toList();
    }
    
    // Sort orders by date
    filteredOrders.sort((a, b) {
      final result = a.date.compareTo(b.date);
      return _sortAscending ? result : -result;
    });

    return filteredOrders.isEmpty
        ? Center(
            child: Text(
              _selectedStatus != null
                  ? 'No ${_selectedStatus!.toLowerCase()} orders found.'
                  : 'No orders found.',
              style: const TextStyle(fontSize: 18),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredOrders.length,
            itemBuilder: (ctx, index) {
              final order = filteredOrders[index];
              final currentStatus = _getOrderStatus(order);
              final currentReturnStatus = _getOrderReturnStatus(order);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Theme.of(context).cardColor,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order ID : ${order.id}',
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
                                color: currentStatus == 'Being Processed'
                                    ? Colors.orange
                                    : currentStatus == 'Shipped'
                                        ? Colors.blue
                                        : currentStatus == 'Return'
                                            ? (currentReturnStatus == 'Accepted Return' 
                                                ? Colors.green 
                                                : currentReturnStatus == 'Returned'
                                                    ? Colors.purple
                                                    : Colors.amber)
                                            : currentStatus == 'Cancelled'
                                                ? Colors.red
                                                : Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                currentStatus == 'Return' && currentReturnStatus.isNotEmpty
                                    ? currentReturnStatus
                                    : currentStatus,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Date: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge!.color,
                                ),
                              ),
                              TextSpan(
                                text: '${order.date.day}/${order.date.month}/${order.date.year} ${order.date.hour > 12 ? order.date.hour - 12 : (order.date.hour == 0 ? 12 : order.date.hour)}:${order.date.minute.toString().padLeft(2, '0')} ${order.date.hour >= 12 ? 'PM' : 'AM'}',
                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (order.status == 'Return') ...[
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Return Reason: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                ),
                                TextSpan(
                                  text: order.returnReason ?? 'No reason provided',
                                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
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
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Payment method: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge!.color,
                                ),
                              ),
                              TextSpan(
                                text: _getPaymentMethodText(order.paymentMethod, order.cardDetails),
                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
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
                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 1,
                          color: Colors.grey.withOpacity(0.3),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Products',
                          style: TextStyle(fontWeight: FontWeight.bold , fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        ...order.items.take(3).map((item) => ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppCachedImage(
                                  imageUrl: item.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              title: Column(
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
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (item.color != null && item.color!.isNotEmpty)
                                      Text(
                                        'Color: ${item.color}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                  Text(
                                    'Quantity: ${item.quantity}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: Text(
                                formatPrice(item.price * item.quantity),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            )),
                        if (order.items.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text(
                              '+ ${order.items.length - 3} more products',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        
                        // Show rating for delivered orders or orders that have been rated
                        if (_getOrderStatus(order).trim() == 'Delivered' || order.rating != null) ...[
                          const SizedBox(height: 16),
                          _buildRatingSection(order, isDialog: true),
                        ],
                        
                        // Show bank details form when return status is Accepted
                        if (currentStatus == 'Return' && 
                            (currentReturnStatus == 'Accepted Return' || currentReturnStatus == 'Returned') && 
                            (order.bankDetails == null || order.bankDetails!.isEmpty)) ...[
                          const SizedBox(height: 16),
                          Container(
                            height: 1,
                            color: Colors.grey.withOpacity(0.3),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          _buildBankDetailsForm(context, order.id),
                        ],
                        
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
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
                                formatPrice(order.total),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 1,
                          color: Colors.grey.withOpacity(0.3),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _showOrderDetails(context, order);
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                ),
                                child: const Text('Order information'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (currentStatus.trim() == 'Delivered' && order.returnStatus == null)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showReturnDialog(context, order.id);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Return'),
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (currentStatus != 'Delivered' && currentStatus != 'Cancelled' && currentStatus != 'Return')
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showCancelOrderConfirmation(context, order.id);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Cancel Order'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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

  // Bank details form widget
  Widget _buildBankDetailsForm(BuildContext context, String orderId) {
    return BankDetailsFormWidget(orderId: orderId);
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => WillPopScope(
          onWillPop: () async {
            Navigator.of(ctx).pop();
            return false;
          },
          child: AlertDialog(
            title: Text('Order ${order.id}'),
        content: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Date: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    TextSpan(
                      text: '${order.date.day}/${order.date.month}/${order.date.year} ${order.date.hour > 12 ? order.date.hour - 12 : (order.date.hour == 0 ? 12 : order.date.hour)}:${order.date.minute.toString().padLeft(2, '0')} ${order.date.hour >= 12 ? 'PM' : 'AM'}',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (order.status == 'Return') ...[
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Return Reason: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      TextSpan(
                        text: order.returnReason ?? 'No reason provided',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
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
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Payment method: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    TextSpan(
                      text: _getPaymentMethodText(order.paymentMethod, order.cardDetails),
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
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
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: Colors.grey.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
              const SizedBox(height: 14),
              const Text(
                'Products',
                style: TextStyle(fontWeight: FontWeight.bold , fontSize: 18),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        AppCachedImage(
                          imageUrl: item.imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(4),
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (item.color != null && item.color!.isNotEmpty)
                                  Text(
                                    'Color: ${item.color}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
              Container(
                height: 1,
                color: Colors.grey.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
              _buildOrderSummary(order),
              if (order.bankDetails != null && order.bankDetails!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bank Details for Refund',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Full Name: ${order.bankDetails!['fullName']}'),
                      const SizedBox(height: 4),
                      Text('Account Number: ${order.bankDetails!['accountNumber']}'),
                      if (order.bankDetails!.containsKey('bankName') && order.bankDetails!['bankName']!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Bank Name: ${order.bankDetails!['bankName']}'),
                      ],
                    ],
                  ),
                ),
              ],
              
              // Rating section - only show if already rated
              if (order.rating != null && order.rating! > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rating:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      StarRating(
                        rating: order.rating!,
                        onRatingChanged: null,
                        isEnabled: false,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
            child: Text(
              'Close',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
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
        return 'Bank Transfer';
      
      case 'cash_on_delivery':
        return 'Cash on delivery';
      
      default:
        return 'No payment method selected';
    }
  }

  void _showCancelOrderConfirmation(BuildContext context, String orderId) {
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
                const SnackBar(
                  content: Text('Order has been cancelled'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showReturnDialog(BuildContext context, String orderId) {
    String selectedReason = 'Item doesn\'t fit';
    String otherReason = '';
    bool isOtherSelected = false;
    
    final reasons = [
      'Item doesn\'t fit',
      'Item damaged',
      'Wrong item received',
      'Item not as described',
      'Changed my mind',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Return Order'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please select the reason for return:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value!;
                        isOtherSelected = value == 'Other';
                      });
                    },
                  )).toList(),
                  if (isOtherSelected) ...[
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Please specify',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        otherReason = value;
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                  final finalReason = isOtherSelected ? otherReason : selectedReason;
                  
                  // Update order status to Return and save the reason
                  orderProvider.returnOrder(orderId, finalReason);
                  
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Return request submitted successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Send', style: TextStyle(color: Colors.green)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildOrderSummary(Order order) {
    final priceComponents = PriceCalculator.getPriceComponentsFromTotal(order.total);

    return Column(
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
              priceComponents['shipping']! > 0 ? formatPrice(priceComponents['shipping']!) : 'Free',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
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
            Text(
              'Total Price ',
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
        Container(
          height: 1,
          color: Colors.grey.withOpacity(0.3),
          margin: const EdgeInsets.symmetric(vertical: 16),
        ),
      ],
    );
  }

  void _updateOrderRating(String orderId, double rating) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.updateOrderRating(orderId, rating);
    setState(() {
      _localRatings[orderId] = rating;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rating submitted successfully!'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildRatingSection(Order order, {bool isDialog = false}) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final rating = order.rating ?? 0;
    final hasRating = rating > 0 || orderProvider.isOrderRated(order.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: hasRating
        ? Row(  // Always show this simple layout after rating
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rating:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              StarRating(
                rating: rating,
                onRatingChanged: null,
                isEnabled: false,
                size: 24,
              ),
            ],
          )
        : Column(  // Show this layout only before rating
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Center(
                child: Text(
                  'Rate Your Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rating:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  StarRating(
                    rating: rating,
                    onRatingChanged: (newRating) {
                      _updateOrderRating(order.id, newRating);
                    },
                    isEnabled: true,
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
    );
  }

  void _updateOrderStatus(String orderId, String status) {
    setState(() {
      _localStatuses[orderId] = status;
    });
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.updateOrderStatus(orderId, status);
  }

  String _getOrderStatus(Order order) {
    return _localStatuses[order.id] ?? order.status;
  }

  String _getOrderReturnStatus(Order order) {
    if (_localStatuses.containsKey(order.id)) {
      return order.returnStatus ?? '';
    }
    return order.returnStatus ?? '';
  }
}
