// lib/widgets/product_search_dialog.dart

import 'package:flutter/material.dart';
import 'package:solar_database/helpers/Database_helper.dart';

class ProductSearchDialog extends StatefulWidget {
  final DatabaseHelper dbHelper;
  // Pass existing cart items to prevent showing already added items
  final List<Map<String, dynamic>> existingCartItems;

  const ProductSearchDialog({
    super.key,
    required this.dbHelper,
    required this.existingCartItems,
  });

  @override
  State<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final List<Map<String, dynamic>> _selectedProducts = [];
  final _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllProducts() async {
    try {
      final products = await widget.dbHelper.getAllItems();
      final existingBarcodes = widget.existingCartItems
          .map((item) => item['barcode'])
          .toSet();

      if (!mounted) return;

      setState(() {
        // Filter out products that are already in the cart
        _allProducts = products
            .where((p) => !existingBarcodes.contains(p['barcode']))
            .toList();
        _filteredProducts = _allProducts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching products: $e")));
      setState(() => _isLoading = false);
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final productName = product['item_name'].toString().toLowerCase();
        final productBarcode = product['barcode'].toString().toLowerCase();
        return productName.contains(query) || productBarcode.contains(query);
      }).toList();
    });
  }

  void _onProductSelected(bool? isSelected, Map<String, dynamic> product) {
    setState(() {
      if (isSelected == true) {
        _selectedProducts.add(product);
      } else {
        _selectedProducts.removeWhere(
          (p) => p['barcode'] == product['barcode'],
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search and Select Products'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name or barcode...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final isSelected = _selectedProducts.any(
                          (p) => p['barcode'] == product['barcode'],
                        );
                        return CheckboxListTile(
                          title: Text(product['item_name']),
                          subtitle: Text('Stock: ${product['quantity']}'),
                          value: isSelected,
                          onChanged: (bool? value) {
                            _onProductSelected(value, product);
                          },
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedProducts.isNotEmpty
              ? () {
                  Navigator.of(context).pop(_selectedProducts);
                }
              : null,
          child: const Text('Add Selected'),
        ),
      ],
    );
  }
}
