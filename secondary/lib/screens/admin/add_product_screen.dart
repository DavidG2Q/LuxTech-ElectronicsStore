import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
class AddProductScreen extends StatefulWidget {
  static const routeName = '/add-product';

  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _specificationController = TextEditingController();
  final _variantNameController = TextEditingController();
  final _variantPriceController = TextEditingController();
  final _colorNameController = TextEditingController();
  final _colorCodeController = TextEditingController();
  final _variantQuantityController = TextEditingController(text: '1');
  int? _selectedVariantIndex;

  String? _selectedCategoryId;
  bool _isFeatured = false;
  bool _isNew = false;
  List<Map<String, dynamic>> _variants = [];
  List<Map<String, dynamic>> _colors = [];
  List<String> _specifications = [];

  @override
  void initState() {
    super.initState();
    _variants = [];
    _colors = [];
    _specifications = [];
    final pairs = _getCategorySubcategoryPairs();
    _selectedCategoryId = pairs.isNotEmpty ? pairs.first['id'] : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _specificationController.dispose();
    _variantNameController.dispose();
    _variantPriceController.dispose();
    _colorNameController.dispose();
    _colorCodeController.dispose();
    _variantQuantityController.dispose();
    super.dispose();
  }

  void _addVariant() {
    if (_variantNameController.text.isEmpty || _variantPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both variant name and price')),
      );
      return;
    }

    // Prevent duplicate variant name (case-insensitive)
    final variantName = _variantNameController.text.trim().toLowerCase();
    final duplicateVariant = _variants.any((v) => (v['name'] as String).trim().toLowerCase() == variantName);
    if (duplicateVariant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A variant with this name already exists')),
      );
      return;
    }

    final price = double.tryParse(_variantPriceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    final quantity = int.tryParse(_variantQuantityController.text) ?? 1;
    setState(() {
      _variants.add({
        'name': _variantNameController.text,
        'price': price,
        'quantity': quantity,
      });
      _variantNameController.clear();
      _variantPriceController.clear();
      _variantQuantityController.text = '1';
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
  }

  void _addColor() {
    if (_colorNameController.text.isEmpty || _colorCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both color name and code')),
      );
      return;
    }

    String input = _colorCodeController.text.trim();
    if (input.startsWith('#')) input = input.substring(1);
    if (input.startsWith('0x')) input = input.substring(2);
    if (input.length == 6) input = 'FF$input';
    if (input.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Color code must be 6 or 8 hex digits')),
      );
      return;
    }

    try {
      final colorCode = int.parse(input, radix: 16);
      // Prevent duplicate color code
      final duplicateCode = _colors.any((c) => c['colorCode'] == colorCode);
      if (duplicateCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A color with this code already exists')),
        );
        return;
      }
      // Prevent duplicate color name (case-insensitive)
      final colorName = _colorNameController.text.trim().toLowerCase();
      final duplicateName = _colors.any((c) => (c['name'] as String).trim().toLowerCase() == colorName);
      if (duplicateName) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A color with this name already exists')),
        );
        return;
      }
      setState(() {
        _colors.add({
          'name': _colorNameController.text,
          'colorCode': colorCode,
        });
        _colorNameController.clear();
        _colorCodeController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid color code format')),
      );
    }
  }

  void _removeColor(int index) {
    setState(() {
      _colors.removeAt(index);
    });
  }

  void _updateSpecifications(String value) {
    setState(() {
      _specifications = value
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
    });
  }

  // Add URL validation function
  bool _isValidImageUrl(String url) {
    return url.contains('.');
  }

  void _setVariantQuantity() {
    if (_selectedVariantIndex == null) return;
    final quantity = int.tryParse(_variantQuantityController.text) ?? 1;
    setState(() {
      _variants[_selectedVariantIndex!]['quantity'] = quantity;
    });
  }

  Future<void> _saveProduct() async {
    try {
      if (!_formKey.currentState!.validate()) return;
      
      // Validate image URL
      if (!_isValidImageUrl(_imageUrlController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid image URL (e.g., example.com/image.jpg)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate all required fields
      if (_nameController.text.isEmpty ||
          _imageUrlController.text.isEmpty ||
          _descriptionController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields')),
        );
        return;
      }

      if (_variants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one variant')),
        );
        return;
      }
      if (_colors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one color')),
        );
        return;
      }
      if (_specifications.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add specifications')),
        );
        return;
      }
      if (!_isFeatured && !_isNew) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one: New Arrival or Featured Product')),
        );
        return;
      }

      // Check if user is authenticated
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuth) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to add products')),
        );
        return;
      }

      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      // Create product sizes from variants with null checks
      final sizes = _variants.map((v) {
        final name = v['name'] as String?;
        final price = v['price'] as double?;
        final quantity = v['quantity'] as int? ?? 1;
        if (name == null || price == null) {
          throw Exception('Invalid variant data');
        }
        return ProductSize(name: name, price: price, quantity: quantity);
      }).toList();

      // Create product colors with null checks
      final colors = _colors.map((c) {
        final name = c['name'] as String?;
        final colorCode = c['colorCode'] as int?;
        if (name == null || colorCode == null) {
          throw Exception('Invalid color data');
        }
        return ProductColor(name: name, colorCode: colorCode);
      }).toList();

      // Save product with error handling
      final categoryId = _selectedCategoryId ?? ProductProvider.categoryLookup.keys.first;
      final success = await productProvider.addNewProduct(
        name: _nameController.text.trim(),
        price: sizes.first.price,
        imageUrl: _imageUrlController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: categoryId,
        colors: colors,
        sizes: sizes,
        isFeatured: _isFeatured,
        isNew: _isNew,
        specifications: _specifications,
      );

      if (success) {
        // Clear all fields immediately after successful save
        _clearAllFields();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add product. Please try again.')),
        );
      }
    } catch (e) {
      print('Error adding product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: ${e.toString()}')),
      );
    }
  }

  void _clearAllFields() {
    _nameController.clear();
    _priceController.clear();
    _imageUrlController.clear();
    _descriptionController.clear();
    _quantityController.clear();
    _specificationController.clear();
    _variantNameController.clear();
    _variantPriceController.clear();
    _colorNameController.clear();
    _colorCodeController.clear();
    setState(() {
      _variants = [];
      _colors = [];
      _specifications = [];
      _selectedCategoryId = null;
      _isFeatured = false;
      _isNew = false;
    });
  }

  // Add new method for JSONB validation
  bool _validateJsonbFields(List<ProductColor> colors, List<ProductSize> sizes, List<String> specifications) {
    try {
      // Test JSON serialization for colors
      final colorsJson = colors.map((c) => {
        'name': c.name,
        'colorCode': c.colorCode,
      }).toList();
      json.encode(colorsJson);

      // Test JSON serialization for sizes
      final sizesJson = sizes.map((s) => {
        'name': s.name,
        'price': s.price,
      }).toList();
      json.encode(sizesJson);

      // Test JSON serialization for specifications
      json.encode(specifications);

      return true;
    } catch (e) {
      return false;
    }
  }

  List<Map<String, String>> _getCategorySubcategoryPairs() {
    final pairs = <Map<String, String>>[];
    ProductProvider.categoryLookup.forEach((id, map) {
      final category = map['category'] ?? '';
      final subcategory = map['subcategory'] ?? '';
      final label = subcategory != null && subcategory.isNotEmpty
          ? '$category - $subcategory'
          : category;
      pairs.add({'id': id, 'label': label});
    });
    return pairs;
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an image URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Category Selection
              const Text(
                'Category Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Category - Subcategory',
                  border: OutlineInputBorder(),
                ),
                items: _getCategorySubcategoryPairs().map((pair) {
                  return DropdownMenuItem(
                    value: pair['id'],
                    child: Text(pair['label'] ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Product Flags
              const Text(
                'Product Flags',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Featured Product'),
                      value: _isFeatured,
                      onChanged: (value) {
                        setState(() {
                          _isFeatured = value ?? false;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('New Arrival'),
                      value: _isNew,
                      onChanged: (value) {
                        setState(() {
                          _isNew = value ?? false;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Variants
              const Text(
                'Product Variants',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _variantNameController,
                      decoration: const InputDecoration(
                        labelText: 'Variant Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _variantPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _variantQuantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _addVariant,
                    child: const Text('Add Variant'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _variants.length,
                itemBuilder: (context, index) {
                  final variant = _variants[index];
                  return ListTile(
                    title: Text('${variant['name']} - ${variant['price']} EGP'),
                    subtitle: Text('Quantity: ${variant['quantity'] ?? 1}'),
                    selected: _selectedVariantIndex == index,
                    onTap: () {
                      setState(() {
                        _selectedVariantIndex = index;
                        _variantQuantityController.text = (variant['quantity'] ?? 1).toString();
                      });
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeVariant(index),
                        ),
                        if (_selectedVariantIndex == index)
                          ElevatedButton(
                            onPressed: _setVariantQuantity,
                            child: const Text('Set Quantity'),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Colors
              const Text(
                'Product Colors',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _colorNameController,
                      decoration: const InputDecoration(
                        labelText: 'Color Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _colorCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Color Code (e.g., FF3C3C3C)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _addColor,
                    child: const Text('Add Color'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final color = _colors[index];
                  return ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(color['colorCode']),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                    title: Text(color['name']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeColor(index),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Specifications
              const Text(
                'Product Specifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specificationController,
                decoration: const InputDecoration(
                  labelText: 'Specifications (one per line)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                onChanged: _updateSpecifications,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter specifications';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Save Product',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 