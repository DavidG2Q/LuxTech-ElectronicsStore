import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart'; // 🔥 Import ThemeProvider
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/about_app_screen.dart';
import '../screens/help_center_screen.dart';
import '../utils/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/welcome_screen.dart';
import '../utils/validators.dart';
import '../providers/product_provider.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';
  final bool isFromBottomNav;

  const ProfileScreen({Key? key, this.isFromBottomNav = false}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final bool isFromBottomNav = false;

  Widget _buildSettingsItem(
      BuildContext context, IconData icon, String title, Function() onTap) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isAdmin = authProvider.email == 'admin@admin.com';

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Account'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing app data...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                
                try {
                  // Refresh all providers
                  await authProvider.refreshUserData();
                  
                  // Also refresh products data
                  await Provider.of<ProductProvider>(context, listen: false).refreshProducts();
                  
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data refreshed successfully'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('Error in profile screen refresh: ${e.toString()}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error refreshing data: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ],
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        child: Icon(
                          Icons.person,
                          size: 70,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) => Text(
                        authProvider.name ?? 'User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ),
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) => Text(
                        authProvider.email ?? 'user@example.com',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (authProvider.address != null &&
                          authProvider.address!.isNotEmpty)
                        Text(
                          authProvider.address!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (authProvider.phone != null &&
                          authProvider.phone!.isNotEmpty)
                        Text(
                          authProvider.phone!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                  'Settings',
                  style: TextStyle(
                      fontSize: 20,
                    fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        context,
                        Icons.person_outline,
                          'Edit Account Info',
                            () {
                          _showEditProfileDialog(context, authProvider);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        context,
                        Icons.shopping_bag_outlined,
                        'My orders',
                            () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const OrdersScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        context,
                        Icons.favorite_border,
                        'Wishlist',
                            () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const WishlistScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        context,
                        Icons.visibility,
                          'Colorblind Mode: ${_getModeName(themeProvider.currentMode)}',
                            () {
                          _showColorblindOptions(context);
                        },
                      ),


                      if (isAdmin) ...[
                        const Divider(height: 1),
                        _buildSettingsItem(
                          context,
                          Icons.admin_panel_settings,
                          'Admin Dashboard',
                              () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const AdminDashboardScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                  'Support',
                  style: TextStyle(
                      fontSize: 20,
                    fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        context,
                        Icons.help_outline,
                        'Help Center',
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpCenterScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        context,
                        Icons.info_outline,
                        'About our app',
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AboutAppScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // First clear any local references to user data in the UI state
                      // This makes the logout appear instant to the user
                      Provider.of<AuthProvider>(context, listen: false).clearLocalStateOnly();
                      
                      // Navigate to welcome screen immediately
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                        (route) => false, // Remove all previous routes from the stack
                      );
                      
                      // Then handle full logout in the background
                      Future.microtask(() {
                        Provider.of<AuthProvider>(context, listen: false).logout();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider authProvider) {
    final nameController = TextEditingController(text: authProvider.name);
    final phoneController = TextEditingController(text: authProvider.phone);
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
              ),
              const SizedBox(height: 16),
                TextFormField(
                controller: TextEditingController(text: authProvider.email),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                enabled: false,
              ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '01x xxx xxx xx',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    // Format phone number to ensure 01xxxxxxxxx format
                    final cleanNumber = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (cleanNumber.length != 11) {
                      return 'Phone number must be 11 digits';
                    }
                    if (!cleanNumber.startsWith('01')) {
                      return 'Phone number must start with 01';
                    }
                    // Check for valid Egyptian mobile prefixes
                    final validPrefixes = ['010', '011', '012', '015'];
                    final prefix = cleanNumber.substring(0, 3);
                    if (!validPrefixes.contains(prefix)) {
                      return 'Phone number must start with 010, 011, 012, or 015';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop(); // Close profile dialog
                    _showEditAddressDialog(context, authProvider); // Open address dialog
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          Icons.location_on_outlined,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Address',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authProvider.address ?? 'Add your address',
                                style: TextStyle(
                                  color: authProvider.address == null ? Colors.grey : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
              authProvider.updateProfile(
                nameController.text,
                authProvider.email ?? '',
                  phone: phoneController.text,
                  street: authProvider.street,
                  building: authProvider.building,
                  city: authProvider.city,
              );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully'),
                  duration: Duration(seconds: 1),
                ),
              );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(BuildContext context, AuthProvider authProvider) {
    final _formKey = GlobalKey<FormState>();
    final _streetController = TextEditingController(text: authProvider.street);
    final _buildingController = TextEditingController(text: authProvider.building);
    final _cityController = TextEditingController(text: authProvider.city);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Address'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _streetController,
                  decoration: const InputDecoration(
                    labelText: 'Street',
                    hintText: 'Enter street name',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter street name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _buildingController,
                  decoration: const InputDecoration(
                    labelText: 'Building',
                    hintText: 'Enter building number',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: Validators.validateBuilding,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    hintText: 'Enter city name',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter city name';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                authProvider.updateProfile(
                  authProvider.name ?? '',
                  authProvider.email ?? '',
                  street: _streetController.text,
                  building: _buildingController.text,
                  city: _cityController.text,
                  phone: authProvider.phone,  // Keep existing phone number
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address updated successfully!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showColorblindOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('OFF'),
              onTap: () {
                themeProvider.setColorBlindMode(ColorBlindMode.normal);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Deuteranopia (Green-Blind)'),
              onTap: () {
                themeProvider.setColorBlindMode(ColorBlindMode.deuteranopia);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Protanopia (Red-Blind)'),
              onTap: () {
                themeProvider.setColorBlindMode(ColorBlindMode.protanopia);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Tritanopia (Blue-Blind)'),
              onTap: () {
                themeProvider.setColorBlindMode(ColorBlindMode.tritanopia);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _getModeName(ColorBlindMode mode) {
    switch (mode) {
      case ColorBlindMode.deuteranopia:
        return 'Deuteranopia';
      case ColorBlindMode.protanopia:
        return 'Protanopia';
      case ColorBlindMode.tritanopia:
        return 'Tritanopia';
      case ColorBlindMode.normal:
      default:
        return 'OFF';
    }
  }
}
