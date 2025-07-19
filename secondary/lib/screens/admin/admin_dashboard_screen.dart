// Modification for lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'manage_products_screen.dart';
import 'manage_orders_screen.dart';
import 'manage_users_screen.dart';
import 'visualization_screen.dart'; // Add this import
import '../../providers/product_provider.dart';
import '../profile_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  static const routeName = '/admin-dashboard';

  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Check if user is admin
    if (authProvider.email != 'admin@admin.com') {
      // Redirect non-admin users
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You are not authorized to access this page.')),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing data...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                
                // Refresh products
                await Provider.of<ProductProvider>(context, listen: false).refreshProducts();
                
                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data refreshed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                // Show error message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error refreshing data: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Welcome to the Admin Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAdminButton(
                    context,
                    'Manage Products',
                    Icons.inventory,
                    const Color.fromARGB(255, 0, 69, 146), // rgb(0, 69, 146)
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const ManageProductsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildAdminButton(
                    context,
                    'Manage Orders',
                    Icons.shopping_cart,
                    const Color.fromARGB(255, 0, 99, 190), // rgb(0, 99, 190)
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const ManageOrdersScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildAdminButton(
                    context,
                    'Manage Users',
                    Icons.people,
                    const Color.fromARGB(255, 24, 133, 224), // rgb(24, 133, 224)
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const ManageUsersScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Add new button for visualization screen
                  _buildAdminButton(
                    context,
                    'Sales Analytics',
                    Icons.bar_chart,
                    const Color.fromARGB(255, 98, 177, 243), // rgb(98, 177, 243)
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const VisualizationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}