import 'package:flutter/foundation.dart';
import 'dart:async'; // Add this import for Timer
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/price_calculator.dart';

class OrderItem {
  final String id;
  final String productId;
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  final String? color;
  final String? size;

  OrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    this.color,
    this.size,
  });
}

class Order {
  final String id;
  final String userId;
  final String customerName;
  final String customerEmail;
  double total;
  final DateTime date;
  String status;
  final List<OrderItem> items;
  final String? shippingAddress;
  final String paymentMethod;
  final Map<String, String>? cardDetails;
  double? rating;
  String? returnReason;
  String? returnStatus; // Add this field for return status
  DateTime? returnRequestTime; // Add this field to track when return was requested
  Map<String, String>? bankDetails; // Add this field for bank details
  DateTime? statusUpdateTime; // Add this field to track when status was last updated

  Order({
    required this.id,
    required this.userId,
    required this.customerName,
    required this.customerEmail,
    required this.total,
    required this.date,
    required this.status,
    required this.items,
    this.shippingAddress,
    required this.paymentMethod,
    this.cardDetails,
    this.rating,
    this.returnReason,
    this.returnStatus,
    this.returnRequestTime,
    this.bankDetails,
    this.statusUpdateTime,
  });
}

class Address {
  final String id;
  final String name;
  final String phone;
  final String street;
  final String building;
  final String city;
  final bool isDefault;

  Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.street,
    required this.building,
    required this.city,
    this.isDefault = false,
  });

  factory Address.fromForm({
    required String name,
    required String phone,
    required String street,
    required String building,
    required String city,
    bool isDefault = false,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    return Address(
      id: id,
      name: name,
      phone: phone,
      street: street,
      building: building,
      city: city,
      isDefault: isDefault,
    );
  }

  String get fullAddress => '$street, ${building.isNotEmpty ? 'building $building, ' : ''}$city';
}

class OrderProvider with ChangeNotifier {
  List<Order> _orders = [];
  String _paymentMethod = 'cash_on_delivery';
  Map<String, String>? _cardDetails;
  double _orderTotal = 0.0;
  Map<String, Timer> _returnTimers = {};
  Map<String, Timer> _statusTimers = {};
  bool _isInitialized = false;
  Set<String> _ratedOrders = {}; // Add this to track which orders have been rated

  OrderProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!_isInitialized) {
      await _loadOrdersFromPrefs();
      await _loadRatedOrders();
    _restartAllTimers();
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Get all orders (for admin)
  List<Order> get allOrders {
    if (!_isInitialized) {
      _initialize();
    }
    return [..._orders];
  }
  
  // Get orders for a specific user
  List<Order> getOrdersForUser(String userId) {
    if (!_isInitialized) {
      _initialize();
    }
    return _orders.where((order) => order.userId == userId).toList();
  }

  List<Order> get orders {
    if (!_isInitialized) {
      _initialize();
    }
    return [..._orders];
  }
  String get paymentMethod => _paymentMethod;
  Map<String, String>? get cardDetails => _cardDetails;
  double get orderTotal => _orderTotal;

  Future<void> _saveOrdersToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = _orders.map((order) => {
        'id': order.id,
        'userId': order.userId,
        'customerName': order.customerName,
        'customerEmail': order.customerEmail,
        'total': order.total,
        'date': order.date.toIso8601String(),
        'status': order.status,
        'items': order.items.map((item) => {
          'id': item.id,
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'imageUrl': item.imageUrl,
          'color': item.color,
          'size': item.size,
        }).toList(),
        'shippingAddress': order.shippingAddress,
        'paymentMethod': order.paymentMethod,
        'cardDetails': order.cardDetails,
        'rating': order.rating,
        'returnReason': order.returnReason,
        'returnStatus': order.returnStatus,
        'returnRequestTime': order.returnRequestTime?.toIso8601String(),
        'bankDetails': order.bankDetails,
        'statusUpdateTime': order.statusUpdateTime?.toIso8601String(),
      }).toList();
      
      await prefs.setString('orders', jsonEncode(ordersJson));
      print('Successfully saved ${_orders.length} orders to SharedPreferences');
    } catch (e) {
      print('Error saving orders to SharedPreferences: $e');
    }
  }

  Future<void> _loadOrdersFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString('orders');
      if (ordersJson != null) {
        final List<dynamic> decoded = jsonDecode(ordersJson);
        _orders = decoded.map((data) {
          // Ensure bank details are properly restored
          Map<String, String>? bankDetails;
          if (data['bankDetails'] != null) {
            bankDetails = Map<String, String>.from(data['bankDetails']);
          }
          
          return Order(
            id: data['id'],
            userId: data['userId'],
            customerName: data['customerName'],
            customerEmail: data['customerEmail'],
            total: data['total'],
            date: DateTime.parse(data['date']),
            status: data['status'],
            items: (data['items'] as List).map((item) => OrderItem(
              id: item['id'],
              productId: item['productId'],
              name: item['name'],
              price: item['price'],
              quantity: item['quantity'],
              imageUrl: item['imageUrl'],
              color: item['color'],
              size: item['size'],
            )).toList(),
            shippingAddress: data['shippingAddress'],
            paymentMethod: data['paymentMethod'],
            cardDetails: data['cardDetails'] != null ? Map<String, String>.from(data['cardDetails']) : null,
            rating: data['rating'],
            returnReason: data['returnReason'],
            returnStatus: data['returnStatus'],
            returnRequestTime: data['returnRequestTime'] != null ? DateTime.parse(data['returnRequestTime']) : null,
            bankDetails: bankDetails,
            statusUpdateTime: data['statusUpdateTime'] != null ? DateTime.parse(data['statusUpdateTime']) : null,
          );
        }).toList();
        print('Successfully loaded \x1B[32m${_orders.length}\x1B[0m orders from SharedPreferences');
        
        final now = DateTime.now();
        for (var order in _orders) {
          // Skip terminal states
          if (order.status == 'Delivered' || order.status == 'Cancelled') {
            continue;
          }

          // --- Main order status restoration ---
          if (order.status == 'Being Processed' || order.status == 'Shipped') {
            final lastUpdate = order.statusUpdateTime ?? order.date;
            final elapsed = now.difference(lastUpdate).inSeconds;
            
            // Calculate how many status updates should have occurred
            if (order.status == 'Being Processed') {
              if (elapsed >= 12) { // Enough time for both transitions
                order.status = 'Delivered';
                order.statusUpdateTime = lastUpdate.add(const Duration(seconds: 12));
              } else if (elapsed >= 6) { // Enough time for first transition
                order.status = 'Shipped';
                order.statusUpdateTime = lastUpdate.add(const Duration(seconds: 6));
                _startStatusUpdateTimer(order.id);
              } else {
                _startStatusUpdateTimer(order.id);
              }
            } else if (order.status == 'Shipped') {
              if (elapsed >= 6) { // Enough time for final transition
                order.status = 'Delivered';
                order.statusUpdateTime = lastUpdate.add(const Duration(seconds: 6));
              } else {
                _startStatusUpdateTimer(order.id);
              }
            }
          }

          // --- Return status restoration ---
          if (order.status == 'Return' && order.returnStatus != null) {
            // For accepted returns, ensure the status is preserved
            if (order.returnStatus == 'Accepted Return' || order.returnStatus == 'Returned') {
              // If bank details are not provided and status is Accepted Return, keep it as is
              if (order.returnStatus == 'Accepted Return' && (order.bankDetails == null || order.bankDetails!.isEmpty)) {
                continue; // Keep the status as Accepted Return to allow bank details entry
              }
              continue; // Skip timer restart for terminal states
            }

            final lastReturnUpdate = order.returnRequestTime ?? order.statusUpdateTime ?? order.date;
            final elapsed = now.difference(lastReturnUpdate).inSeconds;
            
            // Calculate how many return status updates should have occurred
            if (order.returnStatus == 'Return requested') {
              if (elapsed >= 10) { // Enough time for two transitions
                order.returnStatus = 'Being inspected';
                _startReturnStatusTimer(order.id);
              } else if (elapsed >= 5) { // Enough time for one transition
                order.returnStatus = 'Received by the courier';
                _startReturnStatusTimer(order.id);
              } else {
                _startReturnStatusTimer(order.id);
              }
            } else if (order.returnStatus == 'Received by the courier') {
              if (elapsed >= 5) { // Enough time for one transition
                order.returnStatus = 'Being inspected';
                _startReturnStatusTimer(order.id);
              } else {
                _startReturnStatusTimer(order.id);
              }
            } else if (order.returnStatus == 'Being inspected') {
              // Keep as Being inspected - no automatic transition
              _startReturnStatusTimer(order.id);
            }
          }
        }
        
        notifyListeners();
        // Save any updated statuses back to SharedPreferences
        await _saveOrdersToPrefs();
      }
    } catch (e) {
      print('Error loading orders from SharedPreferences: $e');
    }
  }

  void addOrder(Order order) {
    // Calculate subtotal from items
    final subtotal = order.items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    
    // Use PriceCalculator to get the total with tax and shipping
    final priceComponents = PriceCalculator.getPriceComponents(subtotal);
    order.total = priceComponents['total']!;
    
    // Set initial status update time
    order.statusUpdateTime = DateTime.now();
    
    _orders.add(order);
    notifyListeners();
    _saveOrdersToPrefs();
    
    // Start automatic status updates for new orders
    if (order.status == 'Being Processed') {
      _startStatusUpdateTimer(order.id);
    }
  }

  void updateOrderStatus(String orderId, String status) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      _orders[orderIndex].status = status;
      _orders[orderIndex].statusUpdateTime = DateTime.now();
      
      // Cancel existing timer if any
      if (_statusTimers.containsKey(orderId)) {
        _statusTimers[orderId]?.cancel();
        _statusTimers.remove(orderId);
      }
      
      // Start a new timer if needed
      if (status == 'Being Processed' || status == 'Shipped') {
        _startStatusUpdateTimer(orderId);
      }
      
      notifyListeners();
      _saveOrdersToPrefs();
    }
  }
  
  // Method to start automatic status updates
  void _startStatusUpdateTimer(String orderId) {
    // Cancel any existing timer for this order
    if (_statusTimers.containsKey(orderId)) {
      _statusTimers[orderId]?.cancel();
      _statusTimers.remove(orderId);
    }
    
    // Create a new timer that fires every 6 seconds
    _statusTimers[orderId] = Timer.periodic(const Duration(seconds: 6), (timer) {
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex < 0) {
        timer.cancel();
        _statusTimers.remove(orderId);
        return;
      }
      
      final currentStatus = _orders[orderIndex].status;
      String? newStatus;
      
      // Determine the next status based on the current one
      switch (currentStatus) {
        case 'Being Processed':
          newStatus = 'Shipped';
          break;
        case 'Shipped':
          newStatus = 'Delivered';
          // When we reach "Delivered", stop the timer
          timer.cancel();
          _statusTimers.remove(orderId);
          break;
        default:
          // For other statuses, stop the timer
          timer.cancel();
          _statusTimers.remove(orderId);
          return;
      }
      
      if (newStatus != null) {
        _orders[orderIndex].status = newStatus;
        _orders[orderIndex].statusUpdateTime = DateTime.now();
        notifyListeners();
        // Save to SharedPreferences after each status update
        _saveOrdersToPrefs();
      }
    });
  }

  // New method to update order item quantity
  void updateOrderItemQuantity(String orderId, String itemId, int newQuantity) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      final itemIndex = _orders[orderIndex].items.indexWhere((item) => item.id == itemId);
      if (itemIndex >= 0) {
        // Update the item quantity
        _orders[orderIndex].items[itemIndex].quantity = newQuantity;
        
        // Recalculate order total
        double newTotal = 0;
        for (var item in _orders[orderIndex].items) {
          newTotal += item.price * item.quantity;
        }
        _orders[orderIndex].total = newTotal;
        
        notifyListeners();
      }
    }
  }

  // New method to update order rating
  void updateOrderRating(String orderId, double rating) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex != -1) {
      _orders[orderIndex].rating = rating;
      _ratedOrders.add(orderId);
      _saveOrdersToPrefs();
      _saveRatedOrders();
      notifyListeners();
    }
  }

  // Add this method after the updateOrderRating method
  void cancelOrder(String orderId) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      // Cancel any existing timers
      if (_statusTimers.containsKey(orderId)) {
        _statusTimers[orderId]?.cancel();
        _statusTimers.remove(orderId);
      }
      
      _orders[orderIndex].status = 'Cancelled';
      notifyListeners();
    }
  }

  // Updated returnOrder method with automatic status transitions
  void returnOrder(String orderId, String reason) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      // Cancel any existing status timers
      if (_statusTimers.containsKey(orderId)) {
        _statusTimers[orderId]?.cancel();
        _statusTimers.remove(orderId);
      }
      
      _orders[orderIndex].status = 'Return';
      _orders[orderIndex].returnReason = reason;
      _orders[orderIndex].returnStatus = 'Return requested';
      _orders[orderIndex].returnRequestTime = DateTime.now();
      _orders[orderIndex].statusUpdateTime = DateTime.now(); // Update this too for consistency
      notifyListeners();
      _saveOrdersToPrefs(); // Save immediately after status change
      
      // Start the automatic status transition timer
      _startReturnStatusTimer(orderId);
    }
  }
  
  // Method to start the automatic return status transitions
  void _startReturnStatusTimer(String orderId) {
    // Cancel any existing timer for this order
    if (_returnTimers.containsKey(orderId)) {
      _returnTimers[orderId]?.cancel();
    }
    
    // Create a new timer that fires every 5 seconds
    _returnTimers[orderId] = Timer.periodic(const Duration(seconds: 5), (timer) {
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex < 0) {
        timer.cancel();
        return;
      }
      
      final currentStatus = _orders[orderIndex].returnStatus;
      String? newStatus;
      
      // Determine the next status based on the current one
      switch (currentStatus) {
        case 'Return requested':
          newStatus = 'Received by the courier';
          break;
        case 'Received by the courier':
          newStatus = 'Being inspected';
          // When we reach "Being inspected", stop the timer
          timer.cancel();
          _returnTimers.remove(orderId);
          break;
        case 'Being inspected':
          // No automatic transition - wait for admin action
          timer.cancel();
          _returnTimers.remove(orderId);
          return;
        case 'Accepted Return':
        case 'Returned':
          // These are terminal states, stop the timer
          timer.cancel();
          _returnTimers.remove(orderId);
          return;
        default:
          // For any other status, stop the timer
          timer.cancel();
          _returnTimers.remove(orderId);
          return;
      }
      
      if (newStatus != null) {
        _orders[orderIndex].returnStatus = newStatus;
        _orders[orderIndex].statusUpdateTime = DateTime.now();
        notifyListeners();
        _saveOrdersToPrefs();
      }
    });
  }
  
  // Method to save bank details for refund
  void saveBankDetails(String orderId, String fullName, String accountNumber, String? bankName) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      // Check if the order is in a state where bank details can be saved
      final order = _orders[orderIndex];
      if (order.status == 'Return' && 
          (order.returnStatus == 'Accepted Return' || order.returnStatus == 'Returned')) {
        _orders[orderIndex].bankDetails = {
          'fullName': fullName,
          'accountNumber': accountNumber,
          if (bankName != null && bankName.isNotEmpty) 'bankName': bankName,
        };
        
        // If status is Accepted Return, automatically transition to Returned
        if (order.returnStatus == 'Accepted Return') {
          _orders[orderIndex].returnStatus = 'Returned';
          _orders[orderIndex].statusUpdateTime = DateTime.now();
        }
        
        notifyListeners();
        // Save to SharedPreferences immediately after updating bank details
        _saveOrdersToPrefs();
      }
    }
  }

  // Method to check if bank details can be saved for an order
  bool canSaveBankDetails(String orderId) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      final order = _orders[orderIndex];
      return order.status == 'Return' && 
             (order.returnStatus == 'Accepted Return' || order.returnStatus == 'Returned');
    }
    return false;
  }

  // Method to get bank details for an order
  Map<String, String>? getBankDetails(String orderId) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      return _orders[orderIndex].bankDetails;
    }
    return null;
  }

  // Method to immediately set return status to "Returned" (for admin override)
  void completeReturn(String orderId) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      // Cancel any existing timer
      if (_returnTimers.containsKey(orderId)) {
        _returnTimers[orderId]?.cancel();
        _returnTimers.remove(orderId);
      }
      
      // First set to Accepted Return
      _orders[orderIndex].returnStatus = 'Accepted Return';
      _orders[orderIndex].statusUpdateTime = DateTime.now();
      notifyListeners();
      _saveOrdersToPrefs(); // Save immediately after status change
      
      // Then after a short delay, set to Returned
      Future.delayed(const Duration(seconds: 2), () {
        if (orderIndex < _orders.length) {  // Check if order still exists
          _orders[orderIndex].returnStatus = 'Returned';
          _orders[orderIndex].statusUpdateTime = DateTime.now();
          notifyListeners();
          _saveOrdersToPrefs(); // Save immediately after final status change
        }
      });
    }
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setCardDetails(String number, String holderName, String expiryDate) {
    // Determine card type based on first digit
    String cardType = 'Visa';
    if (number.isNotEmpty) {
      final firstDigit = number.replaceAll(' ', '')[0];
      if (firstDigit == '4') {
        cardType = 'Visa';
      } else if (firstDigit == '5') {
        cardType = 'MasterCard';
      } else if (firstDigit == '3') {
        cardType = 'Amex';
      } else if (firstDigit == '6') {
        cardType = 'Discover';
      }
    }
    
    _cardDetails = {
      'number': number,
      'holderName': holderName,
      'expiryDate': expiryDate,
      'type': cardType,
    };
    notifyListeners();
  }

  void setOrderTotal(double total) {
    // The total already includes tax from the checkout summary
    _orderTotal = total;
    notifyListeners();
  }

  void clearCurrentOrder() {
    _cardDetails = null;
    notifyListeners();
  }
  
  // Clean up timers when the provider is disposed
  @override
  void dispose() {
    for (var timer in _returnTimers.values) {
      timer.cancel();
    }
    _returnTimers.clear();
    
    for (var timer in _statusTimers.values) {
      timer.cancel();
    }
    _statusTimers.clear();
    
    super.dispose();
  }

  // Add this new method to restart all timers
  void _restartAllTimers() {
    for (var order in _orders) {
      if (order.status == 'Being Processed' || order.status == 'Shipped') {
        _startStatusUpdateTimer(order.id);
      } else if (order.status == 'Return' && order.returnStatus != null) {
        if (order.returnStatus != 'Accepted Return' && order.returnStatus != 'Returned') {
          _startReturnStatusTimer(order.id);
        }
      }
    }
  }

  Future<void> _loadRatedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratedOrdersJson = prefs.getStringList('rated_orders') ?? [];
      _ratedOrders = Set.from(ratedOrdersJson);
      print('Loaded ${_ratedOrders.length} rated orders');
    } catch (e) {
      print('Error loading rated orders: $e');
    }
  }

  Future<void> _saveRatedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('rated_orders', _ratedOrders.toList());
      print('Saved ${_ratedOrders.length} rated orders');
    } catch (e) {
      print('Error saving rated orders: $e');
    }
  }

  bool isOrderRated(String orderId) {
    return _ratedOrders.contains(orderId);
  }
}
