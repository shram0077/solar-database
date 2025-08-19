import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'dart:async';
import 'package:solar_database/screens/Add_item/ViewItems/EditItemPage.dart';
import 'package:solar_database/screens/Add_item/ViewItems/full_itemDetails.dart';
import 'package:solar_database/screens/Add_item/add_item.dart';

class ViewItemsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const ViewItemsPage({super.key, required this.currentUser});

  @override
  State<ViewItemsPage> createState() => _ViewItemsPageState();
}

class _ViewItemsPageState extends State<ViewItemsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeFilterController =
      TextEditingController();
  final TextEditingController _exchangeRateController = TextEditingController();

  // Filter and sort state
  String _sortOption = 'date_desc';
  String? _selectedCategoryFilter;
  String? _selectedBrandFilter;
  String? _stockStatusFilter;
  String? _paymentStatusFilter;
  bool _filterDebtsOnly = false;
  List<String> _availableCategories = [];
  List<String> _availableBrands = [];
  double _exchangeRate = 1450.0;
  late SharedPreferences _prefs;

  // Number formatting
  final NumberFormat _priceFormatUSD = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
  );
  final NumberFormat _priceFormatIQD = NumberFormat.currency(
    locale: 'ar_IQ',
    symbol: 'IQD ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initialize();
    _searchController.addListener(_applyFiltersAndSort);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFiltersAndSort);
    _searchController.dispose();
    _exchangeRateController.dispose();
    _barcodeFilterController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _exchangeRate = _prefs.getDouble('exchangeRate') ?? 1450.0;
    _exchangeRateController.text = _exchangeRate.toStringAsFixed(0);
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final items = await _dbHelper.getAllItems();
      if (mounted) {
        setState(() {
          _allItems = List<Map<String, dynamic>>.from(items);
          _availableCategories =
              _allItems
                  .map((e) => e['category'] as String?)
                  .where((c) => c != null && c.isNotEmpty)
                  .map((c) => c!)
                  .toSet()
                  .toList()
                ..sort();
          _availableBrands =
              _allItems
                  .map((e) => e['brand'] as String?)
                  .where((b) => b != null && b.isNotEmpty)
                  .map((b) => b!)
                  .toSet()
                  .toList()
                ..sort();
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading items: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method for fuzzy matching
  double _calculateSimilarity(String str1, String str2) {
    str1 = str1.toLowerCase();
    str2 = str2.toLowerCase();

    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;
    if (str1.contains(str2) || str2.contains(str1)) return 0.9;

    final set1 = str1.split('').toSet();
    final set2 = str2.split('').toSet();
    final intersection = set1.intersection(set2);
    final union = set1.union(set2);

    return intersection.length / union.length;
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> results = List.from(_allItems);

    // Apply payment status filter
    if (_paymentStatusFilter != null) {
      if (_paymentStatusFilter == 'cash') {
        results = results.where((item) => item['isPaidCash'] == 1).toList();
      } else if (_paymentStatusFilter == 'debts') {
        results = results.where((item) => item['isPaidCash'] == 0).toList();
      }
    }

    // Apply debts filter
    if (_filterDebtsOnly) {
      results = results.where((item) {
        final isPaidCash = item['isPaidCash'];
        return isPaidCash is int && isPaidCash == 0;
      }).toList();
    }

    // Apply search with scoring
    final searchTerms = _searchController.text
        .toLowerCase()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();

    if (searchTerms.isNotEmpty) {
      results =
          results
              .map((item) {
                double score = 0.0;
                final fields = {
                  'barcode': 5.0,
                  'model': 3.0,
                  'brand': 2.0,
                  'category': 2.0,
                  'power': 1.0,
                  'voltage': 1.0,
                  'supplier': 1.0,
                };
                for (var term in searchTerms) {
                  fields.forEach((field, weight) {
                    final value = item[field]?.toString().toLowerCase() ?? '';
                    if (value.contains(term)) {
                      score += weight;
                    } else if (_calculateSimilarity(value, term) > 0.8) {
                      score += weight * 0.8;
                    }
                  });
                }
                return {'item': item, 'score': score};
              })
              .where((scored) => (scored['score'] as double) > 0)
              .toList()
            ..sort(
              (a, b) => (b['score'] as double).compareTo(a['score'] as double),
            );

      results = results
          .map((scored) => scored['item'] as Map<String, dynamic>)
          .toList();
    }

    // Apply category filter
    if (_selectedCategoryFilter != null &&
        _selectedCategoryFilter!.isNotEmpty) {
      results = results
          .where((item) => item['category'] == _selectedCategoryFilter)
          .toList();
    }

    // Apply brand filter
    if (_selectedBrandFilter != null && _selectedBrandFilter!.isNotEmpty) {
      results = results
          .where((item) => item['brand'] == _selectedBrandFilter)
          .toList();
    }

    // Apply stock status filter
    if (_stockStatusFilter != null) {
      qty(int? value) => value ?? 0;
      if (_stockStatusFilter == 'out_of_stock') {
        results = results.where((item) => qty(item['quantity']) <= 0).toList();
      } else if (_stockStatusFilter == 'low_stock') {
        results = results.where((item) {
          final quantity = qty(item['quantity']);
          return quantity > 0 && quantity <= 5;
        }).toList();
      } else if (_stockStatusFilter == 'in_stock') {
        results = results.where((item) => qty(item['quantity']) > 5).toList();
      }
    }

    // Apply barcode filter
    if (_barcodeFilterController.text.isNotEmpty) {
      results = results
          .where(
            (item) => (item['barcode']?.toString() ?? '').contains(
              _barcodeFilterController.text,
            ),
          )
          .toList();
    }

    // Sorting
    results.sort((a, b) {
      dynamic getValue(Map<String, dynamic> item, String key) => item[key];

      switch (_sortOption) {
        case 'name_asc':
          return (getValue(a, 'model') ?? '').compareTo(
            getValue(b, 'model') ?? '',
          );
        case 'name_desc':
          return (getValue(b, 'model') ?? '').compareTo(
            getValue(a, 'model') ?? '',
          );
        case 'price_asc':
          return (getValue(a, 'selling_price') ??
              0.0.compareTo(getValue(b, 'selling_price') ?? 0.0));
        case 'price_desc':
          return (getValue(b, 'selling_price') ??
              0.0.compareTo(getValue(a, 'selling_price') ?? 0.0));
        case 'qty_asc':
          return (getValue(a, 'quantity') ??
              0.compareTo(getValue(b, 'quantity') ?? 0));
        case 'qty_desc':
          return (getValue(b, 'quantity') ??
              0.compareTo(getValue(a, 'quantity') ?? 0));
        case 'date_asc':
          final dateA = DateTime.tryParse(getValue(a, 'purchase_date') ?? '');
          final dateB = DateTime.tryParse(getValue(b, 'purchase_date') ?? '');
          if (dateA == null || dateB == null) return 0;
          return dateA.compareTo(dateB);
        case 'date_desc':
        default:
          final dateA = DateTime.tryParse(getValue(a, 'purchase_date') ?? '');
          final dateB = DateTime.tryParse(getValue(b, 'purchase_date') ?? '');
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
      }
    });

    setState(() => _filteredItems = results);
  }

  void _resetFilters() {
    _searchController.clear();
    _barcodeFilterController.clear();
    setState(() {
      _sortOption = 'date_desc';
      _selectedCategoryFilter = null;
      _selectedBrandFilter = null;
      _stockStatusFilter = null;
      _paymentStatusFilter = null;
      _filterDebtsOnly = false;
      _applyFiltersAndSort();
    });
  }

  bool _hasActiveFilters() {
    return _selectedCategoryFilter != null ||
        _selectedBrandFilter != null ||
        _stockStatusFilter != null ||
        _paymentStatusFilter != null ||
        _filterDebtsOnly ||
        _barcodeFilterController.text.isNotEmpty;
  }

  int _getActiveFilterCount() {
    return [
      _selectedCategoryFilter,
      _selectedBrandFilter,
      _stockStatusFilter,
      _paymentStatusFilter,
      _filterDebtsOnly ? 'debts' : null,
      _barcodeFilterController.text.isNotEmpty ? 'barcode' : null,
    ].where((filter) => filter != null).length;
  }

  Future<void> _saveExchangeRate(double newRate) async {
    await _prefs.setDouble('exchangeRate', newRate);
    setState(() => _exchangeRate = newRate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exchange rate updated to 1 USD = ${_exchangeRate.toStringAsFixed(0)} IQD',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatPrice(double? amount, bool isUSD) {
    if (amount == null) return 'N/A';
    return isUSD
        ? _priceFormatUSD.format(amount)
        : _priceFormatIQD.format(amount);
  }

  String _getConvertedPrice(double? amount, bool isUSD) {
    if (amount == null) return 'N/A';
    return isUSD
        ? _priceFormatIQD.format(amount * _exchangeRate)
        : _priceFormatUSD.format(amount / _exchangeRate);
  }

  /// Handles the item deletion process, including checking for associated sales.
  Future<void> _deleteItem(int id, String itemName, String? barcode) async {
    // Ensure the context is still valid before proceeding.
    if (!mounted) return;

    if (barcode == null || barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item has no barcode and cannot be checked for sales.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool itemHasSales = false;
    try {
      itemHasSales = await _dbHelper.hasSales(barcode);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking for sales records: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Stop execution if the check fails.
    }

    if (itemHasSales) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 10),
              Text(
                'Cannot Delete Item',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            "'$itemName' cannot be deleted because it is linked to one or more sales records. To maintain data integrity, please remove the associated sales first.",
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return; // Stop the deletion process.
    }

    final confirmed = await _showDeleteConfirmation(itemName);
    if (confirmed != true || !mounted) return;

    try {
      final itemToDelete = _allItems.firstWhere((item) => item['id'] == id);
      final originalIndex = _allItems.indexWhere((item) => item['id'] == id);

      // Optimistic UI update
      setState(() {
        _allItems.removeAt(originalIndex);
        _applyFiltersAndSort();
      });

      final rowsAffected = await _dbHelper.deleteItem(id);

      if (!mounted) return;

      if (rowsAffected > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'$itemName' deleted successfully"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                await _dbHelper.insertItem(itemToDelete);
                _loadItems();
              },
            ),
          ),
        );
      } else {
        // If deletion failed for other reasons, revert the UI change.
        setState(() {
          _allItems.insert(originalIndex, itemToDelete);
          _applyFiltersAndSort();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deletion failed. The item might not exist anymore.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred during deletion: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      // Refresh to ensure UI is in sync with the database.
      _loadItems();
    }
  }

  Future<bool> _showDeleteConfirmation(String itemName) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 10),
                Text(
                  'Confirm Deletion',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to delete:'),
                const SizedBox(height: 8),
                Text(
                  itemName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone!',
                  style: GoogleFonts.inter(color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.inter(color: kTextSecondaryColor),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'DELETE',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ) ??
        false;
  }

  Future<void> _showExchangeRateDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Update Exchange Rate',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _exchangeRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '1 USD to IQD',
              prefixText: 'IQD ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.inter()),
              onPressed: () {
                _exchangeRateController.text = _exchangeRate.toStringAsFixed(0);
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final newRate = double.tryParse(_exchangeRateController.text);
                if (newRate != null && newRate > 0) {
                  _saveExchangeRate(newRate);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid number.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category?.toLowerCase()) {
      case 'solar panel':
        return Icons.solar_power_outlined;
      case 'inverter':
        return Icons.transform_outlined;
      case 'battery':
        return Icons.battery_charging_full_outlined;
      case 'mounting kit':
        return Icons.construction_outlined;
      case 'cable':
        return Icons.cable_outlined;
      case 'charge controller':
        return Icons.tune_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _buildStockLevelChip(int quantity) {
    Color color;
    String text;

    if (quantity <= 0) {
      color = Colors.red.shade700;
      text = 'Out of Stock';
    } else if (quantity <= 5) {
      color = Colors.orange.shade700;
      text = '$quantity in Stock (Low)';
    } else {
      color = Colors.green.shade700;
      text = '$quantity in Stock';
    }

    return Chip(
      avatar: Icon(Icons.inventory_2_outlined, size: 16, color: color),
      label: Text(
        text,
        style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildExchangeRateChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: _showExchangeRateDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1\$ =',
                style: GoogleFonts.inter(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _exchangeRate.toStringAsFixed(0),
                style: GoogleFonts.inter(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'IQD',
                style: GoogleFonts.inter(
                  color: kPrimaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        label: Text(
          label,
          style: GoogleFonts.inter(
            color: kPrimaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: kPrimaryColor.withOpacity(0.1),
        deleteIcon: const Icon(Icons.close_rounded, size: 18),
        onDeleted: onRemove,
        deleteIconColor: kPrimaryColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: kTextSecondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'ئامارەکەت بەتاڵە',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'کرتە بکە لەسەر دوگمەی '
              ' لەسەر شاشەی سەرەکی بۆ زیادکردنی یەکەم ئایتم.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: kTextSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: kTextSecondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'هیچ ئەنجامێک نەدۆزرایەوە',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'هەوڵ بدە گەڕانەکەت ڕێک بخە یان فلتەرەکان خاوێن بکەیتەوە.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: kTextSecondaryColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear_all),
            label: const Text('فلتەرەکان بسڕەوە'),
            onPressed: _resetFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: kCardColor.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'گەڕان بە بەناو مۆدێل، براند، هاوپۆل یان بارکۆد...',
                      hintStyle: GoogleFonts.inter(
                        color: kTextSecondaryColor.withOpacity(0.7),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: kPrimaryColor.withOpacity(0.7),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _applyFiltersAndSort();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: kCardColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: kCardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    fixedSize: const Size(56, 56),
                  ),
                  icon: Stack(
                    children: [
                      const Icon(
                        Icons.filter_list_rounded,
                        color: kPrimaryColor,
                      ),
                      if (_hasActiveFilters())
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _getActiveFilterCount().toString(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: _showFilterBottomSheet,
                  tooltip: 'Filter & Sort',
                ),
              ),
            ],
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedCategoryFilter != null)
                    _buildFilterChip(
                      'Category: $_selectedCategoryFilter',
                      () => setState(() {
                        _selectedCategoryFilter = null;
                        _applyFiltersAndSort();
                      }),
                    ),
                  if (_selectedBrandFilter != null)
                    _buildFilterChip(
                      'Brand: $_selectedBrandFilter',
                      () => setState(() {
                        _selectedBrandFilter = null;
                        _applyFiltersAndSort();
                      }),
                    ),
                  if (_stockStatusFilter != null)
                    _buildFilterChip(
                      'Stock: ${_stockStatusFilter!.replaceAll('_', ' ').toUpperCase()}',
                      () => setState(() {
                        _stockStatusFilter = null;
                        _applyFiltersAndSort();
                      }),
                    ),
                  if (_paymentStatusFilter != null)
                    _buildFilterChip(
                      'Payment: ${_paymentStatusFilter!.toUpperCase()}',
                      () => setState(() {
                        _paymentStatusFilter = null;
                        _applyFiltersAndSort();
                      }),
                    ),
                  if (_filterDebtsOnly)
                    _buildFilterChip(
                      'Debts Only',
                      () => setState(() {
                        _filterDebtsOnly = false;
                        _applyFiltersAndSort();
                      }),
                    ),
                  if (_barcodeFilterController.text.isNotEmpty)
                    _buildFilterChip(
                      'Barcode: ${_barcodeFilterController.text}',
                      () => setState(() {
                        _barcodeFilterController.clear();
                        _applyFiltersAndSort();
                      }),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Theme(
          data: Theme.of(context).copyWith(
            dataTableTheme: DataTableThemeData(
              headingTextStyle: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
              dataTextStyle: GoogleFonts.inter(color: kTextColor),
              headingRowColor: WidgetStateProperty.all(
                kCardColor.withOpacity(0.5),
              ),
              dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return kPrimaryColor.withOpacity(0.08);
                }
                if (states.contains(WidgetState.hovered)) {
                  return kPrimaryColor.withOpacity(0.04);
                }
                return null;
              }),
            ),
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(kCardColor),
            dataRowColor: WidgetStateProperty.all(kBackgroundColor),
            columnSpacing: 15,
            dividerThickness: 1,
            border: TableBorder.all(
              width: 1.0,
              color: Colors.grey.shade300,

              borderRadius: BorderRadius.circular(16),
            ),
            decoration: BoxDecoration(
              color: kCardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            horizontalMargin: 12,
            columns: [
              DataColumn(
                label: Text(
                  'ناوی کاڵا',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'بارکۆد',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'مۆدێل',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'پۆل',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'براند',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'ژمارە',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'شێوازی پارەدان',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              if (widget.currentUser['role'] == 'admin')
                DataColumn(
                  label: Text(
                    'نرخی کڕین',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),
                ),
              DataColumn(
                label: Text(
                  'نرخی فرۆشتن',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              if (widget.currentUser['role'] == 'admin')
                DataColumn(
                  label: Text(
                    'نرخی کڕین بە تاک',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),
                ),
              DataColumn(
                label: Text(
                  'نرخی فرۆشتن بە تاک',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              // DataColumn(
              //   label: Text(
              //     'وات',
              //     style: GoogleFonts.inter(
              //       fontWeight: FontWeight.bold,
              //       color: kTextColor,
              //     ),
              //   ),
              // ),
              // DataColumn(
              //   label: Text(
              //     'ڤۆلت',
              //     style: GoogleFonts.inter(
              //       fontWeight: FontWeight.bold,
              //       color: kTextColor,
              //     ),
              //   ),
              // ),
              DataColumn(
                label: Text(
                  'ڕێکەوتی کڕین',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'کردارەکان',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
            ],
            rows: _filteredItems.map((item) {
              final isUSD = (item['is_currency_usd'] == 1);
              final quantity = item['quantity'] as int? ?? 1;
              final buyingPrice = item['buying_price'] as double? ?? 0.0;
              final sellingPrice = item['selling_price'] as double? ?? 0.0;
              final buyingPriceRetail =
                  item['buying_price_retail'] as double? ?? 0.0;
              final sellingPriceRetails =
                  item['selling_price_retail'] as double? ?? 0.0;
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      item['item_name']?.toString() ?? 'بەردەست نییە',
                      style: GoogleFonts.inter(color: kTextColor),
                    ),
                  ),
                  DataCell(
                    Text(
                      item['barcode']?.toString() ?? 'بەردەست نییە',
                      style: GoogleFonts.inter(color: kTextColor),
                    ),
                  ),
                  DataCell(
                    Text(
                      item['model']?.toString() ?? 'بەردەست نییە',
                      style: GoogleFonts.inter(color: kTextColor),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconForCategory(item['category']),
                            size: 16,
                            color: kPrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item['category']?.toString() ?? 'بەردەست نییە',
                            style: GoogleFonts.inter(color: kPrimaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item['brand']?.toString() ?? 'بەردەست نییە',
                      style: GoogleFonts.inter(color: kTextColor),
                    ),
                  ),
                  DataCell(_buildStockLevelChip(quantity)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: item['isPaidCash'] == 1
                            ? Colors.green.withOpacity(0.15)
                            : Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: item['isPaidCash'] == 1
                              ? Colors.green.shade300
                              : Colors.blue.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item['isPaidCash'] == 1
                                ? Icons.money
                                : Icons.credit_card,
                            size: 18,
                            color: item['isPaidCash'] == 1
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['isPaidCash'] == 1 ? 'واسڵ' : 'قەرز',
                            style: GoogleFonts.inter(
                              color: item['isPaidCash'] == 1
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.currentUser['role'] == 'admin')
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatPrice(buyingPrice, isUSD),
                            style: GoogleFonts.inter(color: kTextColor),
                          ),
                          Text(
                            _getConvertedPrice(buyingPrice, isUSD),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: kTextSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatPrice(sellingPrice, isUSD),
                          style: GoogleFonts.inter(color: kTextColor),
                        ),
                        Text(
                          _getConvertedPrice(sellingPrice, isUSD),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: kTextSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.currentUser['role'] == 'admin')
                    DataCell(
                      Text(
                        _formatPrice(buyingPriceRetail, isUSD),
                        style: GoogleFonts.inter(color: kTextColor),
                      ),
                    ),
                  DataCell(
                    Text(
                      _formatPrice(sellingPriceRetails, isUSD),
                      style: GoogleFonts.inter(color: kTextColor),
                    ),
                  ),
                  // DataCell(
                  //   Text(
                  //     item['power']?.toString() ?? 'بەردەست نییە',
                  //     style: GoogleFonts.inter(color: kTextColor),
                  //   ),
                  // ),
                  // DataCell(
                  //   Text(
                  //     item['voltage']?.toString() ?? 'بەردەست نییە',
                  //     style: GoogleFonts.inter(color: kTextColor),
                  //   ),
                  // ),
                  DataCell(
                    Text(
                      item['purchase_date'] != null
                          ? DateFormat.yMMMd().format(
                              DateTime.parse(item['purchase_date']),
                            )
                          : 'بەردەست نییە',
                      style: GoogleFonts.inter(color: kTextColor),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: kPrimaryColor,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditItemPage(item: item),
                            ),
                          ),
                          tooltip: 'دەستکاری',
                        ),

                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteItem(
                            item['id'],
                            item['model'] ?? 'Item ${item['id']}',
                            item['barcode']?.toString(),
                          ),
                          tooltip: 'Delete',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.visibility_outlined,
                            color: Colors.blue,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ViewFullItemDetails(item: item),
                            ),
                          ),
                          tooltip: 'بینین',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Define a base style to avoid repetition
            final kurdishTextStyle = GoogleFonts.notoNaskhArabic(
              color: kTextColor,
            );
            final headerStyle = kurdishTextStyle.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            );

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
                minHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ڕیزکردن و فلتەرکردن', // Translated
                            style: headerStyle,
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() => _resetFilters());
                            },
                            child: Text(
                              'سڕینەوەی گشتی', // Translated
                              style: GoogleFonts.notoNaskhArabic(
                                color: kPrimaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Responsive layout
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final sections = _buildFilterSections(setModalState);
                          if (constraints.maxWidth > 600) {
                            // Wide screen layout
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: sections[0]),
                                const SizedBox(width: 20),
                                Expanded(child: sections[1]),
                              ],
                            );
                          } else {
                            // Narrow screen layout
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [sections[0], sections[1]],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            'جێبەجێکردن', // Translated
                            style: GoogleFonts.notoNaskhArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: () {
                            _applyFiltersAndSort();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to build filter sections to avoid code duplication
  List<Widget> _buildFilterSections(StateSetter setModalState) {
    return [
      // Column 1
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterSection(
            'ڕیزکردن بەپێی', // Translated
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('نوێترین', 'date_desc', setModalState),
                _buildChoiceChip('کۆنترین', 'date_asc', setModalState),
                _buildChoiceChip('ناو A-Z', 'name_asc', setModalState),
                _buildChoiceChip('ناو Z-A', 'name_desc', setModalState),
                _buildChoiceChip('نرخ ↓', 'price_desc', setModalState),
                _buildChoiceChip('نرخ ↑', 'price_asc', setModalState),
                _buildChoiceChip('ژمارە ↓', 'qty_desc', setModalState),
                _buildChoiceChip('ژمارە ↑', 'qty_asc', setModalState),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildFilterSection(
            'دۆخی پارەدان', // Translated
            Wrap(
              spacing: 8,
              children: [
                _buildPaymentStatusChip('هەمووی', null, setModalState),
                _buildPaymentStatusChip('نەقد', 'cash', setModalState),
                _buildPaymentStatusChip('قەرز', 'debts', setModalState),
              ],
            ),
          ),
        ],
      ),
      // Column 2
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterSection(
            'دۆخی کۆگا', // Translated
            Wrap(
              spacing: 8.0,
              children: [
                _buildStockStatusChip('لە کۆگایە', 'in_stock', setModalState),
                _buildStockStatusChip(
                  'کەمە لە کۆگا',
                  'low_stock',
                  setModalState,
                ),
                _buildStockStatusChip('نەماوە', 'out_of_stock', setModalState),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildFilterSection(
            'فلتەرەکان', // Translated
            Column(
              children: [
                _buildDropdownFilter(
                  'پۆل', // Translated
                  _selectedCategoryFilter,
                  _availableCategories,
                  (newValue) =>
                      setModalState(() => _selectedCategoryFilter = newValue),
                ),
                const SizedBox(height: 12),
                _buildDropdownFilter(
                  'براند', // Translated
                  _selectedBrandFilter,
                  _availableBrands,
                  (newValue) =>
                      setModalState(() => _selectedBrandFilter = newValue),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcodeFilterController,
                  style: GoogleFonts.notoNaskhArabic(), // Set font for input
                  decoration: InputDecoration(
                    labelText: 'بارکۆد', // Translated
                    labelStyle: GoogleFonts.notoNaskhArabic(),
                    hintText: 'بۆ گەڕان بارکۆد بنووسە', // Translated
                    hintStyle: GoogleFonts.notoNaskhArabic(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.qr_code),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildChoiceChip(
    String label,
    String value,
    StateSetter setModalState,
  ) {
    final bool isSelected = _sortOption == value;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.notoNaskhArabic()),
      selected: isSelected,
      onSelected: (selected) => setModalState(() => _sortOption = value),
      labelStyle: GoogleFonts.inter(
        color: isSelected ? Colors.white : kPrimaryColor,
      ),
      selectedColor: kPrimaryColor,
      backgroundColor: kPrimaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildStockStatusChip(
    String label,
    String value,
    StateSetter setModalState,
  ) {
    final isSelected = _stockStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) =>
          setModalState(() => _stockStatusFilter = selected ? value : null),
      labelStyle: GoogleFonts.inter(
        color: isSelected ? Colors.white : kPrimaryColor,
      ),
      selectedColor: kPrimaryColor,
      backgroundColor: kPrimaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildPaymentStatusChip(
    String label,
    String? value,
    StateSetter setModalState,
  ) {
    final isSelected = _paymentStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) =>
          setModalState(() => _paymentStatusFilter = selected ? value : null),
      labelStyle: GoogleFonts.inter(
        color: isSelected ? Colors.white : kPrimaryColor,
      ),
      selectedColor: kPrimaryColor,
      backgroundColor: kPrimaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildDropdownFilter(
    String hint,
    String? selectedValue,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: selectedValue,
      hint: Text(hint, style: GoogleFonts.inter(color: kTextSecondaryColor)),
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: kCardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: selectedValue != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () => onChanged(null),
              )
            : null,
      ),
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: GoogleFonts.inter()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (widget.currentUser['role'] == 'admin') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddItemScreen()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'ئەم کردارە بەردەست نییە',
                  style: GoogleFonts.notoNaskhArabic(),
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Inventory",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: kTextColor,
          ),
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        actions: [
          _buildExchangeRateChip(),
          IconButton(
            icon: const Icon(Icons.refresh, color: kTextSecondaryColor),
            onPressed: _loadItems,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadItems,
        color: kPrimaryColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              )
            : Column(
                children: [
                  _buildSearchAndFilterControls(),
                  Expanded(
                    child: _allItems.isEmpty
                        ? _buildEmptyState()
                        : _filteredItems.isEmpty
                        ? _buildNoResultsState()
                        : _buildItemsList(),
                  ),
                ],
              ),
      ),
    );
  }
}
