import 'package:flutter/material.dart';

class PriceCalculator {
  static const double taxRate = 0.14; // 14% tax rate
  static const double shippingCost = 0.0; // Free shipping

  /// Calculate the total price including tax and shipping
  static double calculateTotal(double subtotal) {
    final tax = calculateTax(subtotal);
    return subtotal + tax + shippingCost;
  }

  /// Calculate tax amount
  static double calculateTax(double subtotal) {
    return subtotal * taxRate;
  }

  /// Calculate subtotal from total (reverse calculation)
  static double calculateSubtotalFromTotal(double total) {
    return total / (1 + taxRate);
  }

  /// Get all price components
  static Map<String, double> getPriceComponents(double subtotal) {
    final tax = calculateTax(subtotal);
    final total = calculateTotal(subtotal);
    
    return {
      'subtotal': subtotal,
      'tax': tax,
      'shipping': shippingCost,
      'total': total,
    };
  }

  /// Get all price components from total
  static Map<String, double> getPriceComponentsFromTotal(double total) {
    final subtotal = calculateSubtotalFromTotal(total);
    final tax = calculateTax(subtotal);
    
    return {
      'subtotal': subtotal,
      'tax': tax,
      'shipping': shippingCost,
      'total': total,
    };
  }
} 