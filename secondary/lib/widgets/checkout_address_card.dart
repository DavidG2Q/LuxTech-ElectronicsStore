import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';

class CheckoutAddressCard extends StatefulWidget {
  const CheckoutAddressCard({super.key});

  @override
  State<CheckoutAddressCard> createState() => _CheckoutAddressCardState();
}

class _CheckoutAddressCardState extends State<CheckoutAddressCard> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isAddingNewAddress = false;

  @override
  void initState() {
    super.initState();
    // Initialize with the user's profile address if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.address != null && authProvider.address!.isNotEmpty) {
        // Pre-fill the form with existing address
        _nameController.text = authProvider.name ?? '';
        _phoneController.text = authProvider.phone ?? '';
        _streetController.text = authProvider.street ?? '';
        _buildingController.text = authProvider.building ?? '';
        _cityController.text = authProvider.city ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _saveNewAddress() {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Update profile with new address
      authProvider.updateProfile(
        _nameController.text,
        authProvider.email ?? '',
        street: _streetController.text,
        building: _buildingController.text,
        city: _cityController.text,
        phone: _phoneController.text,
      );

      setState(() {
        _isAddingNewAddress = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address updated successfully')),
      );

      // Clear form
      _nameController.clear();
      _phoneController.clear();
      _streetController.clear();
      _buildingController.clear();
      _cityController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentAddress = authProvider.address;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!_isAddingNewAddress) ...[
              // Show current address if available
              if (currentAddress != null && currentAddress.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentAddress,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (authProvider.phone != null && authProvider.phone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          authProvider.phone!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Button to edit address
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isAddingNewAddress = true;
                      // Pre-fill the form with existing address
                      _nameController.text = authProvider.name ?? '';
                      _phoneController.text = authProvider.phone ?? '';
                      _streetController.text = authProvider.street ?? '';
                      _buildingController.text = authProvider.building ?? '';
                      _cityController.text = authProvider.city ?? '';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(currentAddress != null ? 'Edit Address' : 'Add Address'),
                ),
              ),
            ] else ...[
              // Address form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: Validators.validateName,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '01x xxx xxx xx',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: Validators.validatePhone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
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
                      textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isAddingNewAddress = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                              side: BorderSide(color: Theme.of(context).primaryColor),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveNewAddress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save Address'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
