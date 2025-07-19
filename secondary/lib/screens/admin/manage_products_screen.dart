import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../widgets/app_cached_image.dart';

class ManageProductsScreen extends StatefulWidget {
  static const routeName = '/manage-products';

  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Product? selectedProduct;
  ProductSize? selectedSize;
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _specificationsController = TextEditingController();
  final TextEditingController _variantNameController = TextEditingController();
  final TextEditingController _variantPriceController = TextEditingController();
  final TextEditingController _colorNameController = TextEditingController();
  final TextEditingController _colorCodeController = TextEditingController();
  final TextEditingController _variantQuantityController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  List<Product> _searchResults = [];
  bool _isFeatured = false;
  bool _isNew = false;
  List<Map<String, dynamic>> _variants = [];
  List<Map<String, dynamic>> _colors = [];
  List<String> _specifications = [];
  int? _selectedVariantIndex;

  @override
  void initState() {
    super.initState();
    // Removed forced refreshProducts() to allow ProductProvider to handle initial loading automatically
  }

  @override
  void dispose() {
    _imageUrlController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    _descriptionController.dispose();
    _specificationsController.dispose();
    _variantNameController.dispose();
    _variantPriceController.dispose();
    _colorNameController.dispose();
    _colorCodeController.dispose();
    _variantQuantityController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value, List<Product> products) async {
    // Refresh products before searching
    await Provider.of<ProductProvider>(context, listen: false).refreshProducts();
    setState(() {
      _searchResults = [];
    });
    
    if (value.isNotEmpty) {
      final results = await Provider.of<ProductProvider>(context, listen: false).searchProducts(value);
      setState(() {
        _searchResults = results;
      });
    }
  }

  void _onProductSelected(Product product) {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();
    
    // Use Future.microtask to ensure keyboard is dismissed before updating state
    Future.microtask(() {
      setState(() {
        selectedProduct = product;
        _searchController.text = product.name;
        _searchResults = [];
        
        // Pre-fill image URL
        _imageUrlController.text = product.imageUrl;
        
        // Pre-fill quantity
        _quantityController.text = product.sizes.isNotEmpty ? product.sizes[0].quantity?.toString() ?? '' : '';
        
        // Pre-fill description
        _descriptionController.text = product.description;
        
        // Pre-fill specifications
        _specificationsController.text = product.specifications.join('\n');
        
        // Set flags
        _isFeatured = product.isFeatured;
        _isNew = product.isNew;
        
        // Set variants
        _variants = product.sizes.map((size) => {
          'name': size.name,
          'price': size.price,
        }).toList();
        
        // Set colors
        _colors = product.colors.map((color) => {
          'name': color.name,
          'colorCode': color.colorCode,
        }).toList();
        
        // Handle price based on variants
        if (product.sizes.length == 1) {
          selectedSize = product.sizes.first;
          _priceController.text = product.sizes.first.price.toString();
        } else {
          selectedSize = null;
          _priceController.text = product.price.toString();
        }

        // Update name controller
        _nameController.text = product.name;
      });
    });
  }

  Future<void> _updateProductImage() async {
    if (selectedProduct == null || _imageUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter a valid image URL')),
        );
      return;
    }
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final updatedProduct = selectedProduct!.copyWith(imageUrl: _imageUrlController.text);
    await productProvider.addOrUpdateProduct(updatedProduct);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Image updated successfully')),
      );
    setState(() {
      _imageUrlController.clear();
      selectedProduct = updatedProduct;
    });
  }

  Future<void> _updateProductPrice() async {
    if (selectedProduct == null || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter a valid price')),
        );
      return;
    }
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter a valid price')),
        );
      return;
    }
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    if (selectedSize == null) {
      // No variant selected: update base price and all variants
      List<ProductSize> updatedSizes = List.from(selectedProduct!.sizes);
      if (updatedSizes.isNotEmpty) {
        int? newQuantity;
        if (_variantQuantityController.text.isNotEmpty) {
          newQuantity = int.tryParse(_variantQuantityController.text);
        }
        final oldQuantity = updatedSizes[0].quantity ?? 1;
        newQuantity ??= oldQuantity;
        final quantityChanged = newQuantity != oldQuantity;
        // Update both price and quantity for the first variant
        updatedSizes[0] = updatedSizes[0].copyWith(price: price, quantity: newQuantity);
        final firstVariantName = updatedSizes[0].name;
        await productProvider.updateProductPrice(
          selectedProduct!.id,
          price,
          updatedSizes,
        );
        // Refresh local state from provider
        setState(() {
          selectedProduct = productProvider.findById(selectedProduct!.id);
          if (selectedProduct != null && selectedProduct!.sizes.isNotEmpty) {
            selectedSize = selectedProduct!.sizes.first;
            _priceController.text = selectedSize!.price.toString();
            _quantityController.text = (selectedSize!.quantity ?? '').toString();
          }
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(quantityChanged
              ? "Price and quantity for variant '$firstVariantName' have been updated!"
              : "Price for variant '$firstVariantName' has been updated!"
            )),
          );
      }
    } else {
      // Update only the selected variant's price
      final updatedSizes = selectedProduct!.sizes.map((size) {
        if (size.name == selectedSize!.name) {
          return ProductSize(name: size.name, price: price, quantity: size.quantity);
        }
        return size;
      }).toList();
      final updatedProduct = selectedProduct!.copyWith(sizes: updatedSizes);
      await productProvider.addOrUpdateProduct(updatedProduct);
      // Refresh local state from provider
      setState(() {
        selectedProduct = productProvider.findById(selectedProduct!.id);
        if (selectedProduct != null && selectedSize != null) {
          final match = selectedProduct!.sizes.firstWhere(
            (s) => s.name == selectedSize!.name,
            orElse: () => selectedSize!,
          );
          selectedSize = match;
          _priceController.text = match.price.toString();
          _quantityController.text = (match.quantity ?? '').toString();
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Price for variant '${selectedSize!.name}' has been updated!")),
        );
    }
  }

  Future<void> _updateProductQuantity() async {
    if (selectedProduct == null || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter a valid quantity')),
        );
      return;
    }
    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity < 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter a valid quantity')),
        );
      return;
    }
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    String message = '';
    if (selectedProduct != null) {
      if (selectedSize != null) {
        message = await productProvider.updateProductQuantity(
          selectedProduct!.id,
          quantity,
          selectedVariant: selectedSize!.name,
        );
      } else {
        message = await productProvider.updateProductQuantity(
          selectedProduct!.id,
          quantity,
        );
      }
      // Refresh local state from provider
      setState(() {
        selectedProduct = productProvider.findById(selectedProduct!.id);
        if (selectedProduct != null && selectedSize != null) {
          final hasMatch = selectedProduct!.sizes.any((s) => s.name == selectedSize!.name);
          if (hasMatch) {
            selectedSize = selectedProduct!.sizes.firstWhere((s) => s.name == selectedSize!.name);
            _quantityController.text = (selectedSize!.quantity ?? '').toString();
            _priceController.text = selectedSize!.price.toString();
          } else if (selectedProduct!.sizes.isNotEmpty) {
            selectedSize = selectedProduct!.sizes.first;
            _quantityController.text = (selectedSize!.quantity ?? '').toString();
            _priceController.text = selectedSize!.price.toString();
          } else {
            selectedSize = null;
            _quantityController.text = '';
            _priceController.text = '';
          }
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  Future<void> _updateProductFlags() async {
    if (selectedProduct == null) return;
    
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final updatedProduct = selectedProduct!.copyWith(
      isFeatured: _isFeatured,
      isNew: _isNew,
    );
    await productProvider.addOrUpdateProduct(updatedProduct);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Product flags updated successfully'),
          duration: Duration(seconds: 1),
        ),
      );
    setState(() {
      selectedProduct = updatedProduct;
    });
  }

  Future<void> _updateProductDescription() async {
    if (selectedProduct == null || _descriptionController.text.isEmpty) return;
    
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final updatedProduct = selectedProduct!.copyWith(
      description: _descriptionController.text,
    );
    await productProvider.addOrUpdateProduct(updatedProduct);
    setState(() {
      selectedProduct = updatedProduct;
    });
  }

  Future<void> _updateProductSpecifications() async {
    if (selectedProduct == null || _specificationsController.text.isEmpty) return;
    
    final specifications = _specificationsController.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final updatedProduct = selectedProduct!.copyWith(
      specifications: specifications,
    );
    await productProvider.addOrUpdateProduct(updatedProduct);
    setState(() {
      selectedProduct = updatedProduct;
    });
  }

  Future<void> _updateProductVariantsAndColors() async {
    if (selectedProduct == null) return;
    
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      // Format colors as JSON array
      final colorsJson = _colors.map((c) => {
        'name': c['name'] as String,
        'colorCode': c['colorCode'] is int 
          ? '0x${c['colorCode'].toRadixString(16).padLeft(8, '0')}'
          : c['colorCode'].toString(),
      }).toList();

      // Format variants as JSON array
      final variantsJson = _variants.map((v) => {
        'name': v['name'] as String,
        'price': v['price'] is double ? v['price'] : (v['price'] as num).toDouble(),
      }).toList();

      // Update Supabase with the formatted data
      await _supabase.from('products').update({
        'colors': colorsJson,
        'variants': variantsJson,
      }).eq('id', selectedProduct!.id);
      
      // Create updated product with the new data
      final updatedProduct = selectedProduct!.copyWith(
        sizes: _variants.map((v) => ProductSize(
          name: v['name'] as String,
          price: v['price'] is double ? v['price'] : (v['price'] as num).toDouble(),
        )).toList(),
        colors: _colors.map((c) => ProductColor(
          name: c['name'] as String,
          colorCode: c['colorCode'] is int 
            ? c['colorCode'] 
            : int.parse((c['colorCode'] as String).replaceAll('0x', ''), radix: 16),
        )).toList(),
      );
      
      // Update local state
      await productProvider.addOrUpdateProduct(updatedProduct);
      
      setState(() {
        selectedProduct = updatedProduct;
      });
      
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Variants and colors updated successfully')),
        );
    } catch (e) {
      print('Error updating variants and colors: $e');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Error updating variants and colors: $e')),
        );
      throw e;
    }
  }

  void _addVariant() async {
    if (selectedProduct == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select a product first')),
        );
      return;
    }
    
    if (_variantNameController.text.isEmpty || _variantPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter both name and price')),
        );
      return;
    }

    final price = double.tryParse(_variantPriceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter a valid price')),
        );
      return;
    }

    try {
      // Check if variant name already exists
      final existingVariants = await _supabase
          .from('products')
          .select('variants')
          .eq('id', selectedProduct!.id)
          .single();

      if (existingVariants != null && existingVariants['variants'] != null) {
        final List<dynamic> variants = existingVariants['variants'];
        final variantExists = variants.any((v) => 
          v['name'].toString().toLowerCase() == _variantNameController.text.toLowerCase()
        );

        if (variantExists) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('A variant with this name already exists')),
            );
          return;
        }
      }

      // Create updated variants list
      final updatedVariants = List<Map<String, dynamic>>.from(_variants);
      updatedVariants.add({
        'name': _variantNameController.text,
        'price': price,
      });

      // Format variants as JSON array
      final variantsJson = updatedVariants.map((v) => {
        'name': v['name'] as String,
        'price': v['price'] is double ? v['price'] : (v['price'] as num).toDouble(),
      }).toList();

      // Update Supabase
      await _supabase.from('products').update({
        'variants': variantsJson,
      }).eq('id', selectedProduct!.id);

      // Update local product state
      final updatedProduct = selectedProduct!.copyWith(
        sizes: updatedVariants.map((v) => ProductSize(
          name: v['name'] as String,
          price: v['price'] is double ? v['price'] : (v['price'] as num).toDouble(),
        )).toList(),
      );

      // Update through provider
      await Provider.of<ProductProvider>(context, listen: false)
          .addOrUpdateProduct(updatedProduct);

      // Update all states at once
      setState(() {
        _variants = updatedVariants;
        selectedProduct = updatedProduct;
        // Set selectedSize to last added variant
        selectedSize = updatedProduct.sizes.isNotEmpty ? updatedProduct.sizes.last : null;
        _variantNameController.clear();
        _variantPriceController.clear();
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Variant added successfully')),
        );
    } catch (e) {
      print('Error adding variant: $e');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Error adding variant: $e')),
        );
    }
  }

  void _removeVariant(int index) async {
    if (selectedProduct == null) return;
    
    // Check if this is the last variant
    if (_variants.length <= 1) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Cannot delete the only variant left')),
        );
      return;
    }
    
    try {
      // Create a copy of variants and remove the item
      final updatedVariants = List<Map<String, dynamic>>.from(_variants);
      updatedVariants.removeAt(index);

      // Format variants as JSON array
      final variantsJson = updatedVariants.map((v) => {
        'name': v['name'] as String,
        'price': v['price'] is double ? v['price'] : (v['price'] as num).toDouble(),
      }).toList();

      // Update Supabase
      await _supabase.from('products').update({
        'variants': variantsJson,
      }).eq('id', selectedProduct!.id);

      // Update local product state
      final updatedProduct = selectedProduct!.copyWith(
        sizes: updatedVariants.map((v) => ProductSize(
          name: v['name'] as String,
          price: v['price'] is double ? v['price'] : (v['price'] as num).toDouble(),
        )).toList(),
      );

      // Update through provider
      await Provider.of<ProductProvider>(context, listen: false)
          .addOrUpdateProduct(updatedProduct);

      // Update all states at once
      setState(() {
        _variants = updatedVariants;
        selectedProduct = updatedProduct;
        // Set selectedSize to first variant if available, else null
        selectedSize = updatedProduct.sizes.isNotEmpty ? updatedProduct.sizes.first : null;
        _selectedVariantIndex = null;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Variant removed successfully')),
        );
    } catch (e) {
      print('Error removing variant: $e');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Error removing variant: $e')),
        );
    }
  }

  void _addColor() async {
    if (selectedProduct == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select a product first')),
        );
      return;
    }
    
    if (_colorNameController.text.isEmpty || _colorCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please enter both name and color code')),
        );
      return;
    }

    String input = _colorCodeController.text.trim();
    // Remove leading # or 0x if present
    if (input.startsWith('#')) input = input.substring(1);
    if (input.startsWith('0x')) input = input.substring(2);
    // Should now be RRGGBB or AARRGGBB
    if (input.length == 6) {
      input = 'FF$input'; // Add full opacity if not provided
    }
    if (input.length != 8) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Color code must be 6 or 8 hex digits (e.g., 3c3c3c or FF3c3c3c)')),
        );
      return;
    }

    try {
      final colorCode = int.parse(input, radix: 16);
      
      // Check if color name already exists
      final existingColors = await _supabase
          .from('products')
          .select('colors')
          .eq('id', selectedProduct!.id)
          .single();

      if (existingColors != null && existingColors['colors'] != null) {
        final List<dynamic> colors = existingColors['colors'];
        final colorExists = colors.any((c) => 
          c['name'].toString().toLowerCase() == _colorNameController.text.toLowerCase()
        );

        if (colorExists) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('A color with this name already exists')),
            );
          return;
        }
      }
      
      // Create updated colors list
      final updatedColors = List<Map<String, dynamic>>.from(_colors);
      updatedColors.add({
        'name': _colorNameController.text,
        'colorCode': colorCode,
      });

      // Format colors as JSON array
      final colorsJson = updatedColors.map((c) => {
        'name': c['name'] as String,
        'colorCode': '0x${c['colorCode'].toRadixString(16).padLeft(8, '0')}',
      }).toList();

      // Update Supabase
      await _supabase.from('products').update({
        'colors': colorsJson,
      }).eq('id', selectedProduct!.id);

      // Update local product state
      final updatedProduct = selectedProduct!.copyWith(
        colors: updatedColors.map((c) => ProductColor(
          name: c['name'] as String,
          colorCode: c['colorCode'] as int,
        )).toList(),
      );

      // Update through provider
      await Provider.of<ProductProvider>(context, listen: false)
          .addOrUpdateProduct(updatedProduct);

      // Update all states at once
      setState(() {
        _colors = updatedColors;
        selectedProduct = updatedProduct;
        _colorNameController.clear();
        _colorCodeController.clear();
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Color added successfully')),
        );
    } catch (e) {
      print('Error adding color: $e');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Error adding color: $e')),
        );
    }
  }

  void _removeColor(int index) async {
    if (selectedProduct == null) return;
    
    // Check if this is the last color
    if (_colors.length <= 1) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Cannot delete the only color left')),
        );
      return;
    }
    
    try {
      // Create a copy of colors and remove the item
      final updatedColors = List<Map<String, dynamic>>.from(_colors);
      updatedColors.removeAt(index);

      // Format colors as JSON array
      final colorsJson = updatedColors.map((c) => {
        'name': c['name'] as String,
        'colorCode': '0x${c['colorCode'].toRadixString(16).padLeft(8, '0')}',
      }).toList();

      // Update Supabase
      await _supabase.from('products').update({
        'colors': colorsJson,
      }).eq('id', selectedProduct!.id);

      // Update local product state
      final updatedProduct = selectedProduct!.copyWith(
        colors: updatedColors.map((c) => ProductColor(
          name: c['name'] as String,
          colorCode: c['colorCode'] as int,
        )).toList(),
      );

      // Update through provider
      await Provider.of<ProductProvider>(context, listen: false)
          .addOrUpdateProduct(updatedProduct);

      // Update all states at once
      setState(() {
        _colors = updatedColors;
        selectedProduct = updatedProduct;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Color removed successfully')),
        );
    } catch (e) {
      print('Error removing color: $e');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Error removing color: $e')),
        );
    }
  }

  void _deleteProduct() {
    if (selectedProduct == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select a product to delete')),
        );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${selectedProduct!.name}"?'),
            const SizedBox(height: 16),
            const Text(
              'Choose delete type:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• UI Only: Removes from screen but keeps in database'),
            const Text('• Permanent: Removes from both screen and database'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              await productProvider.deleteProductLocally(selectedProduct!.id);
              Navigator.of(ctx).pop();
              setState(() {
                selectedProduct = null;
                _isFeatured = false;
                _isNew = false;
                _searchController.clear();
                _imageUrlController.clear();
                _priceController.clear();
                _quantityController.clear();
                _descriptionController.clear();
                _specificationsController.clear();
                _variants.clear();
                _colors.clear();
              });
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Product removed from UI only'),
                    duration: Duration(seconds: 1),
                  ),
                );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Delete from UI'),
          ),
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Permanent Deletion'),
                  content: const Text('Are you sure you want to permanently delete this product from Supabase? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              try {
                // First delete from Supabase
                await _supabase
                    .from('products')
                    .delete()
                    .eq('id', selectedProduct!.id);
                
                // Then delete from local state
                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                await productProvider.deleteProduct(selectedProduct!.id);
                
                Navigator.of(ctx).pop();
                setState(() {
                  selectedProduct = null;
                  _isFeatured = false;
                  _isNew = false;
                  _searchController.clear();
                  _imageUrlController.clear();
                  _priceController.clear();
                  _quantityController.clear();
                  _descriptionController.clear();
                  _specificationsController.clear();
                  _variants.clear();
                  _colors.clear();
                });
                
                // Refresh the product list to ensure UI is in sync
                await productProvider.refreshProducts();
                
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Product deleted permanently'),
                      duration: Duration(milliseconds: 800),
                    ),
                  );
              } catch (e) {
                print('Error deleting product: $e');
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Error deleting product: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _setVariantQuantity() {
    if (_selectedVariantIndex == null) return;
    final quantity = int.tryParse(_variantQuantityController.text) ?? 1;
    setState(() {
      _variants[_selectedVariantIndex!]['quantity'] = quantity;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Variant quantity updated!')),
      );
  }

  void _showOfflineMessage(BuildContext context, ProductProvider provider) {
    final error = provider.userError;
    if (error != null && error.toLowerCase().contains('offline')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        centerTitle: true,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          final products = productProvider.products;
          return Padding(
            padding: const EdgeInsets.all(9.0),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a Product',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Enter product name',
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchResults = [];
                                // Reset all product details
                                selectedProduct = null;
                                selectedSize = null;
                                _isFeatured = false;
                                _isNew = false;
                                _imageUrlController.clear();
                                _priceController.clear();
                                _quantityController.clear();
                                _descriptionController.clear();
                                _specificationsController.clear();
                                _variants.clear();
                                _colors.clear();
                              });
                            },
                          )
                        : null,
                    ),
                    onChanged: (value) => _onSearchChanged(value, products),
                  ),
                  const SizedBox(height: 10),
                  if (selectedProduct == null && _searchController.text.isEmpty) ...[
                    const Center(
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/add-product');
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Add Product',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  if (_searchResults.isNotEmpty)
                    Container(
                      height: MediaQuery.of(context).size.height * 0.4, // 40% of screen height
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).scaffoldBackgroundColor
                            : Colors.grey[50], // Slightly greyish color in light mode
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Scrollbar(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final product = _searchResults[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppCachedImage(
                                  imageUrl: product.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).textTheme.titleMedium!.color,
                                ),
                              ),
                              subtitle: Text(
                                '${product.price} EGP',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodyMedium!.color,
                                ),
                              ),
                              isThreeLine: false,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              onTap: () {
                                // Dismiss keyboard
                                FocusScope.of(context).unfocus();
                                
                                setState(() {
                                  selectedProduct = product;
                                  _searchController.text = product.name;
                                  _searchResults = [];
                                  
                                  // Pre-fill image URL
                                  _imageUrlController.text = product.imageUrl;
                                  
                                  // Pre-fill quantity
                                  _quantityController.text = product.sizes.isNotEmpty ? product.sizes[0].quantity?.toString() ?? '' : '';
                                  
                                  // Pre-fill description
                                  _descriptionController.text = product.description;
                                  
                                  // Pre-fill specifications
                                  _specificationsController.text = product.specifications.join('\n');
                                  
                                  // Set flags
                                  _isFeatured = product.isFeatured;
                                  _isNew = product.isNew;
                                  
                                  // Set variants
                                  _variants = product.sizes.map((size) => {
                                    'name': size.name,
                                    'price': size.price,
                                  }).toList();
                                  
                                  // Set colors
                                  _colors = product.colors.map((color) => {
                                    'name': color.name,
                                    'colorCode': color.colorCode,
                                  }).toList();
                                  
                                  // Handle price based on variants
                                  if (product.sizes.length == 1) {
                                    selectedSize = product.sizes.first;
                                    _priceController.text = product.sizes.first.price.toString();
                                  } else {
                                    selectedSize = null;
                                    _priceController.text = product.price.toString();
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                  if (selectedProduct != null) ...[
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      'Editing Product: ${selectedProduct!.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Move name edit and update button here, side by side
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Product Name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                selectedProduct = selectedProduct!.copyWith(name: value);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (selectedProduct == null || selectedProduct!.name.trim().isEmpty) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid product name')),
                                );
                              return;
                            }
                            final productProvider = Provider.of<ProductProvider>(context, listen: false);
                            await productProvider.addOrUpdateProduct(selectedProduct!);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(content: Text('Product name updated successfully')),
                              );
                          },
                          child: const Text('Update'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Variant size dropdown
                    if (selectedProduct!.sizes.isNotEmpty) ...[
                      const Text(
                        'Select Variant:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<ProductSize>(
                        isExpanded: true,
                        value: selectedSize,
                        hint: const Text('Select an variant'),
                        onChanged: (ProductSize? newValue) {
                          setState(() {
                            selectedSize = newValue;
                            // Find the latest selectedProduct from provider
                            final latestProduct = Provider.of<ProductProvider>(context, listen: false).findById(selectedProduct!.id);
                            if (latestProduct != null) {
                              final match = latestProduct.sizes.firstWhere(
                                (s) => s.name == newValue?.name,
                                orElse: () => newValue!,
                              );
                              _quantityController.text = (match.quantity ?? '').toString();
                              _priceController.text = (match.price).toString();
                            } else {
                              _quantityController.text = newValue?.quantity?.toString() ?? '';
                              _priceController.text = newValue?.price.toString() ?? '';
                            }
                          });
                        },
                        items: selectedProduct!.sizes.map((size) {
                          return DropdownMenuItem<ProductSize>(
                            value: size,
                            child: Text(size.name),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 15),
                    ],
                    // Change Quantity
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_quantityController.text.isEmpty) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid quantity')),
                                  );
                                return;
                              }
                              final quantity = int.tryParse(_quantityController.text);
                              if (quantity == null || quantity < 0) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid quantity')),
                                  );
                                return;
                              }
                              final productProvider = Provider.of<ProductProvider>(context, listen: false);
                              String message = '';
                              if (selectedProduct != null) {
                                if (selectedSize != null) {
                                  message = await productProvider.updateProductQuantity(
                                    selectedProduct!.id,
                                    quantity,
                                    selectedVariant: selectedSize!.name,
                                  );
                                } else {
                                  message = await productProvider.updateProductQuantity(
                                    selectedProduct!.id,
                                    quantity,
                                  );
                                }
                                // Refresh local state from provider
                                setState(() {
                                  selectedProduct = productProvider.findById(selectedProduct!.id);
                                  if (selectedProduct != null && selectedSize != null) {
                                    final hasMatch = selectedProduct!.sizes.any((s) => s.name == selectedSize!.name);
                                    if (hasMatch) {
                                      selectedSize = selectedProduct!.sizes.firstWhere((s) => s.name == selectedSize!.name);
                                      _quantityController.text = (selectedSize!.quantity ?? '').toString();
                                      _priceController.text = selectedSize!.price.toString();
                                    } else if (selectedProduct!.sizes.isNotEmpty) {
                                      selectedSize = selectedProduct!.sizes.first;
                                      _quantityController.text = (selectedSize!.quantity ?? '').toString();
                                      _priceController.text = selectedSize!.price.toString();
                                    } else {
                                      selectedSize = null;
                                      _quantityController.text = '';
                                      _priceController.text = '';
                                    }
                                  }
                                });
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Update'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Change Product Image
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _imageUrlController,
                            decoration: InputDecoration(
                              labelText: 'Image URL',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: _updateProductImage,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Change Price
                    if (selectedProduct!.sizes.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _priceController,
                              decoration: InputDecoration(
                                labelText: 'Price',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_priceController.text.isEmpty) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(content: Text('Please enter a valid price')),
                                    );
                                  return;
                                }
                                final price = double.tryParse(_priceController.text);
                                if (price == null || price <= 0) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(content: Text('Please enter a valid price')),
                                    );
                                  return;
                                }
                                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                                if (selectedSize == null) {
                                  // No variant selected: update base price and all variants
                                  List<ProductSize> updatedSizes = List.from(selectedProduct!.sizes);
                                  if (updatedSizes.isNotEmpty) {
                                    int? newQuantity;
                                    if (_variantQuantityController.text.isNotEmpty) {
                                      newQuantity = int.tryParse(_variantQuantityController.text);
                                    }
                                    final oldQuantity = updatedSizes[0].quantity ?? 1;
                                    newQuantity ??= oldQuantity;
                                    final quantityChanged = newQuantity != oldQuantity;
                                    // Update both price and quantity for the first variant
                                    updatedSizes[0] = updatedSizes[0].copyWith(price: price, quantity: newQuantity);
                                    final firstVariantName = updatedSizes[0].name;
                                    await productProvider.updateProductPrice(
                                      selectedProduct!.id,
                                      price,
                                      updatedSizes,
                                    );
                                    // Refresh local state from provider
                                    setState(() {
                                      selectedProduct = productProvider.findById(selectedProduct!.id);
                                      if (selectedProduct != null && selectedProduct!.sizes.isNotEmpty) {
                                        selectedSize = selectedProduct!.sizes.first;
                                        _priceController.text = selectedSize!.price.toString();
                                        _quantityController.text = (selectedSize!.quantity ?? '').toString();
                                      }
                                    });
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(content: Text(quantityChanged
                                          ? "Price and quantity for variant '$firstVariantName' have been updated!"
                                          : "Price for variant '$firstVariantName' has been updated!"
                                        )),
                                      );
                                  }
                                } else {
                                  // Update only the selected variant's price
                                  final updatedSizes = selectedProduct!.sizes.map((size) {
                                    if (size.name == selectedSize!.name) {
                                      return ProductSize(name: size.name, price: price, quantity: size.quantity);
                                    }
                                    return size;
                                  }).toList();
                                  final updatedProduct = selectedProduct!.copyWith(sizes: updatedSizes);
                                  await productProvider.addOrUpdateProduct(updatedProduct);
                                  // Refresh local state from provider
                                  setState(() {
                                    selectedProduct = productProvider.findById(selectedProduct!.id);
                                    if (selectedProduct != null && selectedSize != null) {
                                      final match = selectedProduct!.sizes.firstWhere(
                                        (s) => s.name == selectedSize!.name,
                                        orElse: () => selectedSize!,
                                      );
                                      selectedSize = match;
                                      _priceController.text = match.price.toString();
                                      _quantityController.text = (match.quantity ?? '').toString();
                                    }
                                  });
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(content: Text("Price for variant '${selectedSize!.name}' has been updated!")),
                                    );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Update'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                    ],
                    // Product Flags
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.5),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Featured Product'),
                              value: _isFeatured,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onChanged: (bool? value) {
                                setState(() {
                                  _isFeatured = value ?? false;
                                });
                                _updateProductFlags();
                              },
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: Theme.of(context).primaryColor.withOpacity(0.5),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('New Arrival'),
                              value: _isNew,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onChanged: (bool? value) {
                                setState(() {
                                  _isNew = value ?? false;
                                });
                                _updateProductFlags();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Description
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) => _updateProductDescription(),
                    ),
                    const SizedBox(height: 15),
                    // Specifications
                    TextField(
                      controller: _specificationsController,
                      decoration: const InputDecoration(
                        labelText: 'Specifications (one per line)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      onChanged: (value) => _updateProductSpecifications(),
                    ),
                    const SizedBox(height: 15),
                    // Variants
                    const Text(
                      'Variants',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _variantNameController,
                            decoration: const InputDecoration(
                              labelText: 'Variant Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _variantPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _variantQuantityController,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (selectedProduct == null) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(content: Text('Please select a product first')),
                                );
                              return;
                            }
                            _addVariant();
                          },
                          child: const Text('Add Variant'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._variants.asMap().entries.map((entry) {
                      final index = entry.key;
                      final variant = entry.value;
                      return ListTile(
                        title: Text('${variant['name']} - ${variant['price']} EGP'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeVariant(index),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 15),
                    // Colors
                    const Text(
                      'Colors',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _colorNameController,
                            decoration: const InputDecoration(
                              labelText: 'Color Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _colorCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Color Code (e.g., 3c3c3c)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (selectedProduct == null) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(content: Text('Please select a product first')),
                                );
                              return;
                            }
                            _addColor();
                          },
                          child: const Text('Add Color'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._colors.asMap().entries.map((entry) {
                      final index = entry.key;
                      final color = entry.value;
                      return ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(color['colorCode'] is int 
                              ? color['colorCode'] 
                              : int.parse(color['colorCode'].toString())),
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
                    }).toList(),
                    const SizedBox(height: 15),
                    // Delete Product
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _deleteProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Delete Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
