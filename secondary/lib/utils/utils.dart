import 'package:intl/intl.dart';

/// Formats a price with thousands separators and EGP, without decimal places
String formatPrice(double price) {
  final formatter = NumberFormat('#,##0', 'en_US');
  return '${formatter.format(price)} EGP';
} 