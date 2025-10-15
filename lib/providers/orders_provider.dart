import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class OrderItem {
  final String id;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'total_price': totalPrice,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'],
    );
  }
}

class Order {
  final String id;
  final List<OrderItem> items;
  final double amount;
  final DateTime dateTime;
  final String status;
  final String address;

  Order({
    required this.id,
    required this.items,
    required this.amount,
    required this.dateTime,
    required this.address,
    this.status = 'Processing',
  });

  double get totalAmount => amount;

  String get date => DateFormat('MMM dd, yyyy').format(dateTime);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'amount': amount,
      'address': address,
      'status': status,
      'created_at': dateTime.toIso8601String(),
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      items: (json['items'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList(),
      amount: (json['amount'] as num).toDouble(),
      address: json['address'],
      dateTime: DateTime.parse(json['created_at']),
      status: json['status'] ?? 'Processing',
    );
  }
}

class OrdersProvider with ChangeNotifier {
  List<Order> _orders = [];
  // Orders are only stored locally; no loading from Supabase

  List<Order> get orders => [..._orders];

  OrdersProvider() {
    // Orders are only stored locally; no loading from Supabase
  }

  // Orders are only stored locally; no loading from Supabase

  Future<void> addOrder(List<OrderItem> cartItems, double total, String address) async {
    final newOrder = Order(
      id: DateTime.now().toString(),
      items: cartItems,
      amount: total,
      dateTime: DateTime.now(),
      status: 'Processing',
      address: address,
    );
    _orders.insert(0, newOrder);
    notifyListeners();
    // Optionally, you can start local status progression if needed
    startOrderStatusProgression(newOrder.id);
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final orderIndex = _orders.indexWhere((o) => o.id == orderId);
    if (orderIndex != -1) {
      final updatedOrder = Order(
        id: _orders[orderIndex].id,
        items: _orders[orderIndex].items,
        amount: _orders[orderIndex].amount,
        dateTime: _orders[orderIndex].dateTime,
        address: _orders[orderIndex].address,
        status: newStatus,
      );
      _orders[orderIndex] = updatedOrder;
      notifyListeners();
    }
  }

  void startOrderStatusProgression(String orderId) async {
    const statusSteps = [
      'Processing',
      'Packing',
      'Handling',
      'Delivering',
      'Delivered',
    ];
    int currentStep = 0;

    while (currentStep < statusSteps.length - 1) {
      await Future.delayed(const Duration(seconds: 10));
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex == -1) break;
      
      final currentOrder = _orders[orderIndex];
      if (currentOrder.status == 'Delivered') break;
      
      if (currentOrder.status == statusSteps[currentStep]) {
        await updateOrderStatus(orderId, statusSteps[currentStep + 1]);
        currentStep++;
      } else {
        currentStep = statusSteps.indexOf(currentOrder.status);
        if (currentStep == -1 || currentStep >= statusSteps.length - 1) break;
      }
    }
  }

  Future<void> clearOrders() async {
    try {
      // No Supabase calls for clearing orders
      _orders = [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing orders: $e');
    }
  }
}
