// lib/screens/admin/visualization_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:developer' as developer;
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/utils.dart';

// Data classes for charts
class ChartData {
  final String label;
  final double value;
  
  ChartData(this.label, this.value);
}

class PieSegment {
  final double percentage;
  final Color color;
  final String label;
  
  PieSegment(this.percentage, this.color, this.label);
}

class LegendItem {
  final String label;
  final Color color;
  final int value;
  
  LegendItem(this.label, this.color, this.value);
}

// Custom painters for charts
class FancyPieChartPainter extends CustomPainter {
  final List<PieSegment> segments;
  final double animation;
  
  FancyPieChartPainter({
    required this.segments,
    required this.animation,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width < size.height ? size.width / 2 : size.height / 2;
    
    double startAngle = -90 * (math.pi / 180); // Start from top (in radians)
    
    for (final segment in segments) {
      final sweepAngle = segment.percentage / 100 * 2 * math.pi * animation;
      
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.fill
        ..strokeWidth = 2;
      
      // Draw main arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      // Draw arc border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );
      
      startAngle += sweepAngle;
    }
    
    // Draw center circle (for donut chart effect)
    canvas.drawCircle(
      center,
      radius * 0.6, // Inner circle radius
      Paint()..color = Colors.white,
    );
    
    // Draw shadow for inner circle
    canvas.drawCircle(
      center,
      radius * 0.6, // Inner circle radius
      Paint()
        ..color = Colors.black.withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineChartPainter extends CustomPainter {
  final List<ChartData> data;
  final double maxValue;
  final double animation;
  final Color color;
  
  LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.animation,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    final barWidth = size.width / data.length;
    
    for (int i = 0; i < data.length * animation; i++) {
      if (i >= data.length) break;
      
      final x = barWidth * (i + 0.5);
      final y = size.height - (data[i].value / maxValue * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw dots at each data point
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final dotStrokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    for (int i = 0; i < data.length * animation; i++) {
      if (i >= data.length) break;
      
      final x = barWidth * (i + 0.5);
      final y = size.height - (data[i].value / maxValue * size.height);
      
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 4, dotStrokePaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class VisualizationScreen extends StatefulWidget {
  const VisualizationScreen({Key? key}) : super(key: key);

  @override
  State<VisualizationScreen> createState() => _VisualizationScreenState();
}

class _VisualizationScreenState extends State<VisualizationScreen> with TickerProviderStateMixin {
  String _timeRange = 'monthly'; // 'weekly' or 'monthly'
  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _salesAnalysisController;
  late Animation<double> _salesAnalysisAnimation;
  String _sortBy = 'date'; // 'date' or 'price'
  bool _sortAscending = false;
  String _selectedChartType = 'categories'; // 'categories', 'subcategories', 'products'
  String _searchQuery = ''; // Add search query state
  
  // Add search controller
  final TextEditingController _searchController = TextEditingController();
  
  // Navy blue color palette
  final Color primaryColor = const Color(0xFF0A2463); // Dark navy blue
  final Color secondaryColor = const Color(0xFF3E92CC); // Medium blue
  final Color accentColor = const Color(0xFF2DC7FF); // Light blue
  final Color backgroundColor = const Color(0xFFF8F9FA); // Light background
  final Color textColor = const Color(0xFF1E2749); // Dark text
  
  // Chart colors
  final List<Color> chartColors = [
    const Color(0xFF3E92CC), // Medium blue
    const Color(0xFF2DC7FF), // Light blue
    const Color(0xFF5C6BC0), // Indigo
    const Color(0xFF7986CB), // Light indigo
    const Color(0xFF64B5F6), // Sky blue
  ];
  
  // Comprehensive category mappings
  final Map<String, List<String>> categoryMappings = {
    'Smartphones': ['iphone', 'samsung', 'smartphone', 'mobile', 'phone', 'galaxy'],
    'Laptops': ['laptop', 'notebook', 'macbook', 'lenovo', 'dell', 'hp', 'asus', 'acer', 'msi', 'gaming laptop'],
    'iPad': ['ipad', 'tablet', 'galaxy tab', 'surface', 'android tablet'],
    'Watch': ['watch', 'apple watch', 'galaxy watch', 'fitbit', 'smartwatch', 'fitness tracker'],
    'AirPods': ['airpods', 'headphones', 'earbuds', 'speaker', 'soundbar', 'bluetooth speaker'],
    'TV': ['tv', 'television', 'monitor', 'display', 'smart tv', 'led tv', 'apple tv'],
  };

  // Comprehensive subcategory mappings
  final Map<String, List<String>> subcategoryMappings = {
    // Smartphone subcategories
    'Iphone': ['iphone', 'apple iphone'],
    'Samsung': ['samsung', 'galaxy'],
    
    // Laptop subcategories
    'Gaming Laptops': ['gaming', 'gaming laptop', 'msi', 'alienware', 'legion', 'predator'],
    'Business Laptops': ['business', 'thinkpad', 'latitude', 'elitebook', 'probook', 'macbook'],
    
    // Watch subcategories
    'Apple Watch': ['apple watch', 'iwatch'],
    
    // AirPods subcategories
    'AirPods Pro': ['airpods pro', 'air pods pro'],
    'AirPods Max': ['airpods max', 'air pods max'],
    
    // TV subcategories
    'Apple TV': ['apple tv'],
  };

  // Helper method to detect category from product name
  String detectCategory(String productName) {
    final lowerName = productName.toLowerCase();
    
    // First try to find an exact match in category mappings
    for (var entry in categoryMappings.entries) {
      if (entry.value.any((keyword) => lowerName.contains(keyword))) {
        return entry.key;
      }
    }
    
    // If no match found, return 'Other'
    return 'Other';
  }

  // Helper method to detect subcategory from product name
  String detectSubcategory(String productName) {
    final lowerName = productName.toLowerCase();
    
    // First try to find an exact match in subcategory mappings
    for (var entry in subcategoryMappings.entries) {
      if (entry.value.any((keyword) => lowerName.contains(keyword))) {
        return entry.key;
      }
    }
    
    // If no match found, try to determine subcategory based on category
    final category = detectCategory(productName);
    switch (category) {
      case 'Smartphones':
        return 'Other Smartphones';
      case 'Laptops':
        return 'Other Laptops';
      case 'iPad':
        return 'Other iPads';
      case 'Watch':
        return 'Other Watches';
      case 'AirPods':
        return 'Other AirPods';
      case 'TV':
        return 'Other TVs';
      default:
        return 'Other';
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    
    _salesAnalysisController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _salesAnalysisAnimation = CurvedAnimation(
      parent: _salesAnalysisController,
      curve: Curves.easeInOutCubic,
    );
    
    _animationController.forward();
    _salesAnalysisController.forward();
  }
  
  @override
  void dispose() {
    _searchController.dispose(); // Dispose search controller
    _animationController.dispose();
    _salesAnalysisController.dispose();
    super.dispose();
  }

  // Add search filter function
  List<Order> _filterOrders(List<Order> orders) {
    if (_searchQuery.isEmpty) return orders;
    
    final query = _searchQuery.toLowerCase();
    return orders.where((order) {
      // Search in order ID
      if (order.id.toLowerCase().contains(query)) return true;
      
      // Search in customer name
      if (order.customerName.toLowerCase().contains(query)) return true;
      
      // Search in customer email
      if (order.customerEmail.toLowerCase().contains(query)) return true;
      
      // Search in products
      if (order.items.any((item) => item.name.toLowerCase().contains(query))) return true;
      
      // Search in status
      if (order.status.toLowerCase().contains(query)) return true;
      
      // Search in price
      if (formatPrice(order.total).toLowerCase().contains(query)) return true;
      
      // Search in date (format: MM/dd/yyyy)
      final dateStr = DateFormat('MM/dd/yyyy').format(order.date);
      if (dateStr.contains(query)) return true;
      
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Sales Analytics',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                // Restart animation when refreshing
                _animationController.reset();
                _animationController.forward();
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _timeRange = value;
                // Restart animation when time range changes
                _animationController.reset();
                _animationController.forward();
              });
            },
            color: Colors.white,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'weekly',
                child: Text('Weekly'),
              ),
              const PopupMenuItem(
                value: 'monthly',
                child: Text('Monthly'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          final allOrders = orderProvider.allOrders;
          
          // Debug log the orders
          developer.log('Total orders: ${allOrders.length}', name: 'VisualizationScreen');
          for (var order in allOrders) {
            developer.log('Order ID: ${order.id}, Status: ${order.status}, Items: ${order.items.length}', name: 'VisualizationScreen');
            for (var item in order.items) {
              developer.log('  Item: ${item.name}, ProductID: ${item.productId}, Quantity: ${item.quantity}', name: 'VisualizationScreen');
            }
          }
          
          // Calculate order statistics
          final totalOrders = allOrders.length;
          final inProgressOrders = allOrders.where((order) => 
              order.status == 'Being Processed' || order.status == 'Shipped').length;
          final completedOrders = allOrders.where((order) => 
              order.status == 'Delivered').length;
          final cancelledOrders = allOrders.where((order) => 
              order.status == 'Cancelled' || order.status == 'Return').length;
          
          // Calculate revenue
          final totalRevenue = allOrders.fold(0.0, (sum, order) => 
              sum + (order.status != 'Cancelled' ? order.total : 0));
          
          // Calculate average order value
          final averageOrderValue = totalOrders > 0 
              ? totalRevenue / totalOrders 
              : 0.0;
          
          // Get order status data for pie chart
          final pendingOrders = allOrders.where((order) => 
              order.status == 'Being Processed').length;
          final shippedOrders = allOrders.where((order) => 
              order.status == 'Shipped').length;
          final deliveredOrders = allOrders.where((order) => 
              order.status == 'Delivered').length;
          final cancelledOrdersCount = allOrders.where((order) => 
              order.status == 'Cancelled').length;
          
          // Get recent orders and sort them
          final recentOrders = List<Order>.from(allOrders);
          
          if (_sortBy == 'date') {
            recentOrders.sort((a, b) => _sortAscending 
                ? a.date.compareTo(b.date) 
                : b.date.compareTo(a.date));
          } else if (_sortBy == 'price') {
            recentOrders.sort((a, b) => _sortAscending 
                ? a.total.compareTo(b.total) 
                : b.total.compareTo(a.total));
          }
          
          final displayedRecentOrders = recentOrders.take(5).toList();
          
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withOpacity(0.05),
                  backgroundColor,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with total revenue
                  _buildHeader(totalRevenue, averageOrderValue),
                  
                  const SizedBox(height: 24),
                  
                  // Order Statistics Cards
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _animation.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _animation.value)),
                          child: child,
                        ),
                      );
                    },
                    child: _buildOrderStatisticsCards(
                      totalOrders, 
                      inProgressOrders, 
                      completedOrders, 
                      cancelledOrders
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Revenue Overview
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _animation.value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - _animation.value)),
                          child: child,
                        ),
                      );
                    },
                    child: _buildRevenueOverview(
                      totalRevenue, 
                      _timeRange, 
                      allOrders, 
                      averageOrderValue
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Order Status Chart and Categories Chart
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _animation.value,
                        child: Transform.translate(
                          offset: Offset(0, 40 * (1 - _animation.value)),
                          child: child,
                        ),
                      );
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Status Pie Chart
                        Expanded(
                          child: Column(
                            children: [
                              _buildSectionTitle('Order Status'),
                              const SizedBox(height: 8),
                              _buildCreativePieChart(
                                pendingOrders, 
                                shippedOrders, 
                                deliveredOrders, 
                                cancelledOrdersCount
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Most Ordered Categories
                        Expanded(
                          child: Column(
                            children: [
                              _buildSectionTitle('Top Categories'),
                              const SizedBox(height: 8),
                              _buildCreativeCategoriesChart(allOrders, context),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sales by Category/Subcategory/Product Chart
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _animation.value,
                        child: Transform.translate(
                          offset: Offset(0, 45 * (1 - _animation.value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionTitle('Sales Analysis'),
                            Row(
                              children: [
                                // Time filter dropdown
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _timeRange,
                                      icon: const Icon(Icons.calendar_today, size: 16),
                                      iconSize: 16,
                                      elevation: 16,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _timeRange = newValue!;
                                          _salesAnalysisController.reset();
                                          _salesAnalysisController.forward();
                                        });
                                      },
                                      items: <String>['weekly', 'monthly']
                                          .map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value == 'weekly' ? 'This Week' : 'This Month',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: primaryColor,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                // Chart type dropdown
                                Container(
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedChartType,
                                      icon: const Icon(Icons.arrow_drop_down),
                                      iconSize: 20,
                                      elevation: 16,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedChartType = newValue!;
                                          _salesAnalysisController.reset();
                                          _salesAnalysisController.forward();
                                        });
                                      },
                                      items: <String>['categories', 'subcategories', 'products']
                                          .map<DropdownMenuItem<String>>((String value) {
                                        String displayText;
                                        switch (value) {
                                          case 'categories':
                                            displayText = 'Categories';
                                            break;
                                          case 'subcategories':
                                            displayText = 'Subcategories';
                                            break;
                                          case 'products':
                                            displayText = 'Products';
                                            break;
                                          default:
                                            displayText = value;
                                        }
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            displayText,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: primaryColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSalesAnalysisChart(allOrders, context),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Recent Orders Table
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _animation.value,
                        child: Transform.translate(
                          offset: Offset(0, 50 * (1 - _animation.value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Recent Orders'),
                        const SizedBox(height: 8),
                        _buildRecentOrdersTable(displayedRecentOrders),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildHeader(double totalRevenue, double averageOrderValue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Colors.white.withOpacity(0.9),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Sales Overview',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Revenue',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatPrice(totalRevenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Average Order',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(averageOrderValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildOrderStatisticsCards(
    int totalOrders, 
    int inProgressOrders, 
    int completedOrders, 
    int cancelledOrders
  ) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      children: [
        _buildStatCard(
          'Total Orders',
          totalOrders.toString(),
          Icons.shopping_cart,
          primaryColor,
        ),
        _buildStatCard(
          'In Progress',
          inProgressOrders.toString(),
          Icons.pending_actions,
          secondaryColor,
        ),
        _buildStatCard(
          'Completed',
          completedOrders.toString(),
          Icons.check_circle,
          const Color(0xFF2E7D32), // Green
        ),
        _buildStatCard(
          'Cancelled',
          cancelledOrders.toString(),
          Icons.cancel,
          const Color(0xFFD32F2F), // Red
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Faded background icon in lower right
          Positioned(
            bottom: 0,
            right: 0,
            child: Icon(
              icon,
              size: 64,
              color: color.withOpacity(0.08),
            ),
          ),
          // Main content row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueOverview(
    double totalRevenue, 
    String timeRange, 
    List<Order> allOrders, 
    double averageOrderValue
  ) {
    // Generate revenue data for chart
    final revenueData = _generateRevenueData(allOrders, timeRange);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Revenue Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    timeRange == 'weekly' ? 'Last 7 Days' : 'Last 6 Months',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: revenueData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No revenue data available',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildCreativeLineChart(revenueData),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCreativeLineChart(List<ChartData> data) {
    // Find max value for scaling
    final maxValue = data.isEmpty ? 0.0 : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Y-axis labels
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatPrice(maxValue), style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6))),
                      Text(formatPrice(maxValue * 0.75), style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6))),
                      Text(formatPrice(maxValue * 0.5), style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6))),
                      Text(formatPrice(maxValue * 0.25), style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6))),
                      Text('₹0', style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6))),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Chart
                  Expanded(
                    child: Stack(
                      children: [
                        // Grid lines
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) {
                            return Container(
                              height: 1,
                              color: Colors.grey[200],
                            );
                          }),
                        ),
                        // Bars
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(data.length, (index) {
                            final item = data[index];
                            final height = maxValue > 0 ? (item.value / maxValue) * 150 * _animation.value : 0.0;
                            
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 20,
                                  height: height,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        accentColor,
                                        primaryColor,
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.label,
                                  style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7)),
                                ),
                              ],
                            );
                          }),
                        ),
                        // Line chart overlay
                        if (data.length > 1)
                          CustomPaint(
                            size: Size.infinite,
                            painter: LineChartPainter(
                              data: data,
                              maxValue: maxValue,
                              animation: _animation.value,
                              color: accentColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  List<ChartData> _generateRevenueData(List<Order> orders, String timeRange) {
    if (orders.isEmpty) return [];
    
    final now = DateTime.now();
    final Map<String, double> revenueMap = {};
    
    if (timeRange == 'weekly') {
      // Generate data for the last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('MM/dd').format(date);
        revenueMap[dateStr] = 0;
      }
      
      // Calculate revenue for each day
      for (final order in orders) {
        if (order.status != 'Cancelled' && 
            order.date.isAfter(now.subtract(const Duration(days: 7)))) {
          final dateStr = DateFormat('MM/dd').format(order.date);
          if (revenueMap.containsKey(dateStr)) {
            revenueMap[dateStr] = (revenueMap[dateStr] ?? 0) + order.total;
          }
        }
      }
    } else {
      // Generate data for the last 6 months
      for (int i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final dateStr = DateFormat('MMM').format(date);
        revenueMap[dateStr] = 0;
      }
      
      // Calculate revenue for each month
      for (final order in orders) {
        if (order.status != 'Cancelled' && 
            order.date.isAfter(DateTime(now.year, now.month - 6, 1))) {
          final dateStr = DateFormat('MMM').format(order.date);
          if (revenueMap.containsKey(dateStr)) {
            revenueMap[dateStr] = (revenueMap[dateStr] ?? 0) + order.total;
          }
        }
      }
    }
    
    // Convert map to list of ChartData
    return revenueMap.entries
        .map((entry) => ChartData(entry.key, entry.value))
        .toList();
  }
  
  Widget _buildCreativePieChart(
    int pendingOrders, 
    int shippedOrders, 
    int deliveredOrders, 
    int cancelledOrders
  ) {
    final total = pendingOrders + shippedOrders + deliveredOrders + cancelledOrders;
    
    if (total == 0) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pie_chart,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No order data available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Calculate percentages
    final pendingPercent = (pendingOrders / total) * 100;
    final shippedPercent = (shippedOrders / total) * 100;
    final deliveredPercent = (deliveredOrders / total) * 100;
    final cancelledPercent = (cancelledOrders / total) * 100;
    
    final segments = [
      PieSegment(pendingPercent, const Color(0xFFFFA726), 'Pending'), // Orange
      PieSegment(shippedPercent, secondaryColor, 'Shipped'), // Blue
      PieSegment(deliveredPercent, const Color(0xFF66BB6A), 'Delivered'), // Green
      PieSegment(cancelledPercent, const Color(0xFFEF5350), 'Cancelled'), // Red
    ];
    
    return Container(
      height: 320, // Increased height to fix overflow
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: FancyPieChartPainter(
                          segments: segments,
                          animation: _animation.value,
                        ),
                        size: const Size(180, 180),
                      );
                    },
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          '$total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Scrollable legend to prevent overflow
            SizedBox(
              height: 90,
              child: SingleChildScrollView(
                child: _buildFancyChartLegend(
                  [
                    LegendItem('Pending', const Color(0xFFFFA726), pendingOrders),
                    LegendItem('Shipped', secondaryColor, shippedOrders),
                    LegendItem('Delivered', const Color(0xFF66BB6A), deliveredOrders),
                    LegendItem('Cancelled', const Color(0xFFEF5350), cancelledOrders),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFancyChartLegend(List<LegendItem> items) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.value}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildCreativeCategoriesChart(List<Order> orders, BuildContext context) {
    // Get product provider
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    // Debug log the product provider
    developer.log('Product provider has ${productProvider.products.length} products', name: 'VisualizationScreen');
    
    // Calculate category quantities
    final Map<String, int> categoryQuantities = {};
    
    // Count quantities by category from orders
    for (final order in orders) {
      if (order.status != 'Cancelled') { // Only count non-cancelled orders
        for (final item in order.items) {
          // Try to find the product by ID
          final product = productProvider.findById(item.productId);
          
          if (product != null) {
            // Use the main category from the product model
            final normalizedCategoryId = product.categoryId.trim().toLowerCase();
            final lookup = ProductProvider.categoryLookup.entries.firstWhere(
              (e) => e.key.trim().toLowerCase() == normalizedCategoryId,
              orElse: () => MapEntry('', <String, String?>{}),
            ).value;
            final category = lookup['category'] ?? '';
            categoryQuantities[category] = (categoryQuantities[category] ?? 0) + item.quantity;
            developer.log('Added to category: $category, product: ${product.name}', name: 'VisualizationScreen');
          } else {
            // If product lookup fails, use the improved category detection
            final category = detectCategory(item.name);
            categoryQuantities[category] = (categoryQuantities[category] ?? 0) + item.quantity;
            developer.log('Added to category (fallback): $category', name: 'VisualizationScreen');
          }
        }
      }
    }
    
    // Debug log the category quantities
    developer.log('Category quantities: $categoryQuantities', name: 'VisualizationScreen');
    
    // If no data, show empty state
    if (categoryQuantities.isEmpty) {
      return Container(
        height: 320, // Match pie chart height
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No category data available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort categories by quantity
    final sortedCategories = categoryQuantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take top 5 categories
    final topCategories = sortedCategories.take(5).toList();
    
    // Find max value for scaling
    final maxValue = topCategories.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...topCategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      final color = chartColors[index % chartColors.length];
                      
                      return AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final animatedWidth = _animation.value * (category.value / maxValue);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        productProvider.getCategoryDisplayName(category.key),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).textTheme.bodyLarge!.color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${category.value} items',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Stack(
                                  children: [
                                    Container(
                                      height: 8,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: animatedWidth,
                                      child: Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              color,
                                              color.withOpacity(0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: color.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSalesAnalysisChart(List<Order> orders, BuildContext context) {
    // Get product provider
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    // Data maps for different chart types (now using double for total price)
    final Map<String, double> categoryData = {};
    final Map<String, double> subcategoryData = {};
    final Map<String, double> productData = {};
    
    // Calculate total price data from real orders
    for (final order in orders) {
      if (order.status != 'Cancelled') {
        // Apply time range filter
        final now = DateTime.now();
        bool isInTimeRange = false;
        
        if (_timeRange == 'weekly') {
          isInTimeRange = order.date.isAfter(now.subtract(const Duration(days: 7)));
        } else { // monthly
          isInTimeRange = order.date.isAfter(DateTime(now.year, now.month - 1, 1));
        }
        
        if (isInTimeRange) {
          for (final item in order.items) {
            // Try to find the product by ID
            final product = productProvider.findById(item.productId);
            double itemTotal = 0;
            if (product != null) {
              itemTotal = item.quantity * product.price;
              // Category data - use the main category from the product model
              final normalizedCategoryId = product.categoryId.trim().toLowerCase();
              final lookup = ProductProvider.categoryLookup.entries.firstWhere(
                (e) => e.key.trim().toLowerCase() == normalizedCategoryId,
                orElse: () => MapEntry('', <String, String?>{}),
              ).value;
              final category = lookup['category'] ?? '';
              categoryData[category] = (categoryData[category] ?? 0) + itemTotal;
              // Subcategory data - use the subcategory from the product model
              final normalizedCategoryId2 = product.categoryId.trim().toLowerCase();
              final lookup2 = ProductProvider.categoryLookup.entries.firstWhere(
                (e) => e.key.trim().toLowerCase() == normalizedCategoryId2,
                orElse: () => MapEntry('', <String, String?>{}),
              ).value;
              final subcategory = lookup2['subcategory'] ?? '';
              subcategoryData[subcategory] = (subcategoryData[subcategory] ?? 0) + itemTotal;
              // Product data - use the product name
              productData[product.name] = (productData[product.name] ?? 0) + itemTotal;
            } else {
              // If product lookup fails, use the improved detection methods
              final category = detectCategory(item.name);
              final subcategory = detectSubcategory(item.name);
              final productName = item.name;
              // Fallback: use order item price if available, else skip
              itemTotal = item.quantity * (item.price ?? 0);
              categoryData[category] = (categoryData[category] ?? 0) + itemTotal;
              subcategoryData[subcategory] = (subcategoryData[subcategory] ?? 0) + itemTotal;
              productData[productName] = (productData[productName] ?? 0) + itemTotal;
            }
          }
        }
      }
    }
    
    // Sort and get top entries based on selected chart type
    List<MapEntry<String, double>> sortedData;
    String title;
    
    switch (_selectedChartType) {
      case 'categories':
        sortedData = categoryData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        title = 'Sales by Category';
        break;
      case 'subcategories':
        sortedData = subcategoryData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        title = 'Sales by Subcategory';
        break;
      case 'products':
        sortedData = productData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        title = 'Sales by Product';
        break;
      default:
        sortedData = categoryData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        title = 'Sales by Category';
    }
    
    // Take top 10 entries
    final topEntries = sortedData.take(10).toList();
    
    if (topEntries.isEmpty) {
      return Container(
        height: 350,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No sales data available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Find max value for scaling
    final maxValue = topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: topEntries.length,
                itemBuilder: (context, index) {
                  final entry = topEntries[index];
                  final color = chartColors[index % chartColors.length];
                  
                  return AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final animatedWidth = _animation.value * (entry.value / maxValue);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatPrice(entry.value),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Stack(
                              children: [
                                Container(
                                  height: 12,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: animatedWidth,
                                  child: Container(
                                    height: 12,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          color,
                                          color.withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentOrdersTable(List<Order> recentOrders) {
    // Filter orders based on search query
    final filteredOrders = _filterOrders(recentOrders);
    
    // Calculate total price of displayed orders
    final totalPrice = filteredOrders.fold(0.0, (sum, order) => sum + order.total);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by ID, customer, product, status, price, or date (MM/dd/yyyy)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Sorting controls
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Sort by:',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_sortBy == 'date') {
                        _sortAscending = !_sortAscending;
                      } else {
                        _sortBy = 'date';
                        _sortAscending = false;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _sortBy == 'date' ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _sortBy == 'date' ? FontWeight.bold : FontWeight.normal,
                            color: _sortBy == 'date' ? primaryColor : textColor.withOpacity(0.7),
                          ),
                        ),
                        if (_sortBy == 'date')
                          Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14,
                            color: primaryColor,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_sortBy == 'price') {
                        _sortAscending = !_sortAscending;
                      } else {
                        _sortBy = 'price';
                        _sortAscending = false;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _sortBy == 'price' ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _sortBy == 'price' ? FontWeight.bold : FontWeight.normal,
                            color: _sortBy == 'price' ? primaryColor : textColor.withOpacity(0.7),
                          ),
                        ),
                        if (_sortBy == 'price')
                          Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14,
                            color: primaryColor,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Order ID',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Customer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Product',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Price',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            
            // Table Rows
            if (filteredOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No recent orders' : 'No orders match your search',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredOrders.map((order) => Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () => _showOrderDetails(order),
                        child: Text(
                          '#${order.id.substring(0, 6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Text(
                        order.customerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        order.items.isNotEmpty 
                            ? '${order.items.first.name}${order.items.length > 1 ? ' +${order.items.length - 1}' : ''}'
                            : 'No items',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getShortStatus(order.status),
                          style: TextStyle(
                            fontSize: 11,
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('MM/dd').format(order.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        formatPrice(order.total),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )).toList(),
              
            // Add totals row at the bottom
            if (filteredOrders.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Orders: ${filteredOrders.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Total Amount: ${formatPrice(totalPrice)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Being Processed':
        return const Color(0xFFFFA726); // Orange
      case 'Shipped':
        return secondaryColor; // Blue
      case 'Delivered':
        return const Color(0xFF66BB6A); // Green
      case 'Cancelled':
        return const Color(0xFFEF5350); // Red
      case 'Return':
        return const Color(0xFFFFCA28); // Amber
      default:
        return Colors.grey;
    }
  }
  
  String _getShortStatus(String status) {
    switch (status) {
      case 'Being Processed':
        return 'Processing';
      case 'Shipped':
        return 'Shipped';
      case 'Delivered':
        return 'Delivered';
      case 'Cancelled':
        return 'Cancelled';
      case 'Return':
        return 'Returned';
      default:
        return status;
    }
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Order Info
              _buildInfoRow('Order ID', '#${order.id}'),
              _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(order.date)),
              _buildInfoRow('Status', order.status),
              _buildInfoRow('Total', formatPrice(order.total)),
              const SizedBox(height: 16),

              // Customer Info
              Text(
                'Customer Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Name', order.customerName),
              _buildInfoRow('Email', order.customerEmail),
              const SizedBox(height: 16),

              // Shipping Address
              Text(
                'Shipping Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                order.shippingAddress ?? 'No shipping address provided',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),

              // Order Items
              Text(
                'Order Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quantity: ${item.quantity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        formatPrice(item.price ?? 0),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
