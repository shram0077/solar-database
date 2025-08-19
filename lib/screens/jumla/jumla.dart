import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:solar_database/helpers/widget/Invoices/html_content/jumla_content.dart';
import 'package:solar_database/helpers/widget/Invoices/invoice_jumla.dart';

class JumlaPreview extends StatefulWidget {
  const JumlaPreview({super.key});

  @override
  State<JumlaPreview> createState() => _JumlaPreviewState();
}

class _JumlaPreviewState extends State<JumlaPreview> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();

  // State Management Variables
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  late Future<void> _initItemsFuture;

  // --- IMPROVED SELECTION & QUANTITY LOGIC ---
  // We now store the quantity for each selected item ID.
  // Key: item_id, Value: quantity
  final Map<int, int> _selectedItemsWithQuantity = {};

  @override
  void initState() {
    super.initState();
    _initItemsFuture = _fetchAndSetItems();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  // Fetches and filters items from the DB.
  Future<void> _fetchAndSetItems() async {
    try {
      final allFetchedItems = await _dbHelper.getAllItems();

      // REINSTATED: Filter for USD items only, as the title suggests.
      final usdItemsOnly = allFetchedItems.toList();

      if (mounted) {
        setState(() {
          _allItems = usdItemsOnly;
          _filteredItems = usdItemsOnly;
          // Clear selection on refresh
          _selectedItemsWithQuantity.clear();
        });
      }
    } catch (e) {
      debugPrint('Error fetching items: $e');
      throw Exception('Failed to load items');
    }
  }

  // Filters items based on the search query.
  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final itemName = item['item_name']?.toString().toLowerCase() ?? '';
        final category = item['category']?.toString().toLowerCase() ?? '';
        final brand = item['brand']?.toString().toLowerCase() ?? '';
        final model = item['model']?.toString().toLowerCase() ?? '';
        return itemName.contains(query) ||
            category.contains(query) ||
            brand.contains(query) ||
            model.contains(query);
      }).toList();
    });
  }

  // Refreshes the item list.
  Future<void> _refreshItems() async {
    _searchController.clear();
    await _fetchAndSetItems();
  }

  // --- NEW QUANTITY MANAGEMENT METHODS ---

  void _toggleItemSelection(Map<String, dynamic> item) {
    final itemId = item['id'] as int;
    setState(() {
      if (_selectedItemsWithQuantity.containsKey(itemId)) {
        _selectedItemsWithQuantity.remove(itemId);
      } else {
        _selectedItemsWithQuantity[itemId] =
            1; // Add with default quantity of 1
      }
    });
  }

  void _incrementQuantity(int itemId) {
    setState(() {
      _selectedItemsWithQuantity.update(itemId, (value) => value + 1);
    });
  }

  void _decrementQuantity(int itemId) {
    setState(() {
      if (_selectedItemsWithQuantity.containsKey(itemId) &&
          _selectedItemsWithQuantity[itemId]! > 1) {
        _selectedItemsWithQuantity.update(itemId, (value) => value - 1);
      } else {
        // If quantity is 1, decrementing removes the item
        _selectedItemsWithQuantity.remove(itemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'جوملە',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: kTextColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: kCardColor,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedItemsWithQuantity.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Badge(
                  label: Text(_selectedItemsWithQuantity.length.toString()),
                  child: const Icon(Iconsax.receipt_edit, size: 26),
                ),
                onPressed: () => _generateAndDisplayInvoice(),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshItems,
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: FutureBuilder(
                future: _initItemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: kPrimaryColor),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildEmptyState(
                      icon: Iconsax.warning_2,
                      message: 'هەڵەیەک ڕوویدا',
                    );
                  }
                  if (_allItems.isEmpty) {
                    return _buildEmptyState(
                      icon: Iconsax.box_remove,
                      message: 'هیچ پێکهاتەیەک بە دۆلار نیە',
                    );
                  }
                  if (_filteredItems.isEmpty) {
                    return _buildEmptyState(
                      icon: Iconsax.search_normal_1,
                      message: 'هیچ ئەنجامێک نەدۆزرایەوە',
                    );
                  }
                  return _buildItemsGrid();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '...بگەڕێ بەدوای ناو، جۆر، براند',
          hintStyle: TextStyle(color: kTextSecondaryColor.withOpacity(0.8)),
          prefixIcon: const Icon(
            Iconsax.search_normal_1,
            color: kTextSecondaryColor,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Iconsax.close_circle,
                    color: kTextSecondaryColor,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus(); // Dismiss keyboard
                  },
                )
              : null,
          filled: true,
          fillColor: kCardColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8, // Adjusted for quantity controls
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final itemId = item['id'] as int;
        final isSelected = _selectedItemsWithQuantity.containsKey(itemId);
        final quantity = _selectedItemsWithQuantity[itemId] ?? 0;
        return _buildItemCard(item, isSelected, quantity);
      },
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> item,
    bool isSelected,
    int quantity,
  ) {
    final itemId = item['id'] as int;
    return Card(
      margin: EdgeInsets.zero,
      elevation: isSelected ? 4 : 1,
      shadowColor: isSelected
          ? kPrimaryColor.withOpacity(0.3)
          : Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: kPrimaryColor, width: 2)
            : BorderSide(color: Colors.grey.shade200),
      ),
      color: isSelected ? kPrimaryColor.withOpacity(0.05) : kCardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleItemSelection(item),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(item, isSelected),
              const Divider(height: 24),
              _buildCardBody(item),
              const Spacer(),
              _buildCardFooter(item, isSelected, quantity, itemId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(Map<String, dynamic> item, bool isSelected) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(Iconsax.box, size: 28, color: kPrimaryColor),
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.tick_circle,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['item_name'] ?? 'بێ ناو',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item['category'] != null)
                Text(
                  item['category'],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: kTextSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardBody(Map<String, dynamic> item) {
    return Expanded(
      flex: 3,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['brand'] != null || item['model'] != null)
              _buildDetailSection('تایبەتمەندییەکان', [
                if (item['brand'] != null)
                  _buildSpecificationRow('براند', item['brand']),
                if (item['model'] != null)
                  _buildSpecificationRow('مۆدێل', item['model']),
                if (item['power'] != null)
                  _buildSpecificationRow('هێز', item['power']),
                if (item['voltage'] != null)
                  _buildSpecificationRow('ڤۆڵت', item['voltage']),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFooter(
    Map<String, dynamic> item,
    bool isSelected,
    int quantity,
    int itemId,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'نرخ: ${item['buying_price']?.toStringAsFixed(2) ?? '0.00'} \$',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kPrimaryColor,
            ),
          ),
        ),
        if (isSelected)
          Container(
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Iconsax.minus,
                    size: 20,
                    color: kPrimaryColor,
                  ),
                  onPressed: () => _decrementQuantity(itemId),
                ),
                Text(
                  '$quantity',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Iconsax.add, size: 20, color: kPrimaryColor),
                  onPressed: () => _incrementQuantity(itemId),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- Helper and Invoice Generation Widgets ---

  Future<void> _generateAndDisplayInvoice() async {
    try {
      final logoBase64 = await _loadAssetBase64('assets/images/logo.png');

      final List<Map<String, dynamic>> invoiceItems = [];
      double grandTotal = 0.0;

      for (var entry in _selectedItemsWithQuantity.entries) {
        final itemId = entry.key;
        final quantity = entry.value;
        // Find the full item details from our master list
        final item = _allItems.firstWhere((i) => i['id'] == itemId);

        final price = (item['buying_price'] ?? 0.0) as double;
        final total = price * quantity;
        grandTotal += total;

        invoiceItems.add({
          'name': item['item_name'] ?? 'Unknown',
          'price': price.toStringAsFixed(2),
          'quantity': quantity.toString(),
          'total': total.toStringAsFixed(2),
          'description': '${item['brand'] ?? ''} ${item['model'] ?? ''}'.trim(),
        });
      }

      final html = generateJumlaInvoiceHtml(
        logoBase64: logoBase64,
        items: invoiceItems,
        total: grandTotal.toStringAsFixed(2),
        date: DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now()), // Nicely formatted date
        invoiceNumber:
            'JML-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoicePrintJumla(htmlContent: html),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _loadAssetBase64(String path) async {
    final byteData = await rootBundle.load(path);
    return base64Encode(byteData.buffer.asUint8List());
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextColor,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildSpecificationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kTextSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 14, color: kTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: kTextSecondaryColor.withOpacity(0.7)),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 18, color: kTextSecondaryColor),
          ),
        ],
      ),
    );
  }
}
