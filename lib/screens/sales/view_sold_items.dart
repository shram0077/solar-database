import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _soldItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  String _selectedPeriod = 'هەموو کاتێک';
  String? _paymentFilter;
  String? _sortColumn;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadSoldItems();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSoldItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _dbHelper.getAllSoldItems(descending: true);
      setState(() {
        _soldItems = items;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە لە بارکردنی فرۆشەکان: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#e94f37',
        'پاشگەزبوونەوە',
        true,
        ScanMode.BARCODE,
      );
      if (mounted && barcodeScanRes != '-1') {
        _searchController.text = barcodeScanRes;
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شکستی هێنا لە وەرگرتنی وەشانی پلاتفۆرم.'),
          ),
        );
      }
    }
  }

  Future<void> _deleteSale(int saleId) async {
    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed || !mounted) return;

    await _dbHelper.deleteSale(saleId);
    await _loadSoldItems(); // Refresh data
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('دڵنیایی سڕینەوە'),
            content: const Text(
              'ئایا دڵنیایت لە سڕینەوەی ئەم تۆمارەی فرۆشتن؟ ئەم کردارە بڕی کاڵاکە دەگەڕێنێتەوە و ناتوانرێت پاشگەز بکرێتەوە.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('پاشگەزبوونەوە'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('سڕینەوە'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _sortData(String columnName, bool ascending) {
    setState(() {
      _sortColumn = columnName;
      _sortAscending = ascending;

      _soldItems.sort((a, b) {
        var aValue = a[columnName] ?? 0;
        var bValue = b[columnName] ?? 0;

        int comparison;
        if (aValue is Comparable && bValue is Comparable) {
          comparison = aValue.compareTo(bValue);
        } else {
          comparison = aValue.toString().compareTo(bValue.toString());
        }

        return ascending ? comparison : -comparison;
      });
    });
  }

  List<Map<String, dynamic>> get _filteredItems {
    final now = DateTime.now();
    var filtered = _soldItems.where((item) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final searchFields = [
          item['item_name'],
          item['customer_name'],
          item['item_id'],
        ].map((e) => (e ?? '').toString().toLowerCase());
        if (!searchFields.any((field) => field.contains(query))) return false;
      }

      if (_paymentFilter != null) {
        if (item['payment_method']?.toString().toLowerCase() !=
            _paymentFilter) {
          return false;
        }
      }

      if (_selectedPeriod != 'هەموو کاتێک') {
        final saleDate = DateTime.tryParse(item['sale_date'] ?? '');
        if (saleDate == null) return false;

        switch (_selectedPeriod) {
          case 'ئەمڕۆ':
            return saleDate.year == now.year &&
                saleDate.month == now.month &&
                saleDate.day == now.day;
          case 'ئەم هەفتەیە':
            return saleDate.isAfter(now.subtract(const Duration(days: 7)));
          case 'ئەم مانگە':
            return saleDate.year == now.year && saleDate.month == now.month;
          case 'ئەم ساڵ':
            return saleDate.year == now.year;
        }
      }
      return true;
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرتی فرۆشەکان'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSoldItems,
            tooltip: 'نوێکردنەوەی داتا',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final sale = filtered[index];
                      return _buildSaleCard(sale);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final profitIQD = (sale['profit_iqd'] ?? 0.0).toDouble();
    final profitColor = profitIQD >= 0 ? Colors.green.shade700 : Colors.red;
    final finalAmountIQD = (sale['final_amount'] ?? 0.0).toDouble();
    final debtPrice = (sale['debt_price'] ?? 0.0).toDouble();

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSaleDetails(sale),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sale['item_name'] ?? 'N/A',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'MMM d, y',
                    ).format(DateTime.parse(sale['sale_date'])),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sale['customer_name'] ?? 'کڕیاری نەناسراو',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPriceInfo('کۆی گشتی', finalAmountIQD, 'IQD'),
                  _buildPriceInfo(
                    'قازانج',
                    profitIQD,
                    'IQD',
                    color: profitColor,
                  ),
                ],
              ),
              if (debtPrice > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'قەرزی ماوە: ${NumberFormat.currency(locale: 'ar_IQ', symbol: '', decimalDigits: 0).format(debtPrice)} IQD',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete_forever, color: Colors.redAccent),
                    onPressed: () => _deleteSale(sale['id']),
                    tooltip: 'سڕینەوەی فرۆش',
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      sale['payment_method']?.toString().toUpperCase() ?? 'N/A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceInfo(
    String label,
    double amount,
    String currency, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '${NumberFormat.currency(locale: 'ar_IQ', symbol: '', decimalDigits: 0).format(amount)} $currency',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'گەڕان بەپێی کاڵا، کڕیار، یان بارکۆد',
              hintText: 'تێرمی گەڕان بنووسە...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanBarcode,
                tooltip: 'سکانکردنی بارکۆد',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPeriod,
                  items:
                      [
                            'هەموو کاتێک',
                            'ئەمڕۆ',
                            'ئەم هەفتەیە',
                            'ئەم مانگە',
                            'ئەم ساڵ',
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => _selectedPeriod = val!),
                  decoration: InputDecoration(
                    labelText: 'ماوەی کات',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _paymentFilter,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('هەموو پارەدانەکان'),
                    ),
                    ...['cash', 'debt'].map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e == 'cash' ? 'نەخت' : 'قەرز'),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _paymentFilter = val),
                  decoration: InputDecoration(
                    labelText: 'شێوازی پارەدان',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSaleDetails(Map<String, dynamic> sale) {
    final quantity = (sale['quantity'] ?? 1).toInt();
    final totalSellingPriceIQD = (sale['selling_price'] ?? 0.0).toDouble();
    final totalSellingPriceUSD = (sale['selling_price_usd'] ?? 0.0).toDouble();

    final unitPriceIQD = quantity > 0 ? totalSellingPriceIQD / quantity : 0.0;
    final unitPriceUSD = quantity > 0 ? totalSellingPriceUSD / quantity : 0.0;

    final finalAmountIQD = (sale['final_amount'] ?? 0.0).toDouble();
    final finalAmountUSD = (sale['final_amount_usd'] ?? 0.0).toDouble();
    final profitIQD = (sale['profit_iqd'] ?? 0.0).toDouble();
    final profitUSD = (sale['profit'] ?? 0.0).toDouble();
    final debtPriceIQD = (sale['debt_price'] ?? 0.0).toDouble();
    final exchangeRate = (sale['exchange_rate'] ?? 0.0).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'وردەکاری فرۆشتن',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  _buildDetailRow('کاڵا:', sale['item_name'] ?? 'N/A'),
                  _buildDetailRow('کڕیار:', sale['customer_name'] ?? 'N/A'),
                  _buildDetailRow(
                    'بەروار:',
                    DateFormat.yMMMd().add_jm().format(
                      DateTime.parse(sale['sale_date']),
                    ),
                  ),
                  const Divider(),
                  _buildDetailRow('دانە:', quantity.toString()),
                  _buildDetailRow(
                    'نرخی یەکە (دینار):',
                    NumberFormat.currency(
                      locale: 'ar_IQ',
                      symbol: 'د.ع ',
                      decimalDigits: 0,
                    ).format(unitPriceIQD),
                  ),
                  _buildDetailRow(
                    'نرخی یەکە (دۆلار):',
                    NumberFormat.currency(
                      symbol: '\$',
                      decimalDigits: 2,
                    ).format(unitPriceUSD),
                  ),
                  _buildDetailRow('داشکاندن:', '${sale['discount'] ?? 0}%'),
                  const Divider(),
                  _buildDetailRow(
                    'کۆی گشتی (دینار):',
                    NumberFormat.currency(
                      locale: 'ar_IQ',
                      symbol: 'د.ع ',
                      decimalDigits: 0,
                    ).format(finalAmountIQD),
                    valueStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildDetailRow(
                    'کۆی گشتی (دۆلار):',
                    NumberFormat.currency(
                      symbol: '\$',
                      decimalDigits: 2,
                    ).format(finalAmountUSD),
                    valueStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildDetailRow(
                    'قازانج (دینار):',
                    NumberFormat.currency(
                      locale: 'ar_IQ',
                      symbol: 'د.ع ',
                      decimalDigits: 0,
                    ).format(profitIQD),
                    valueStyle: TextStyle(
                      color: profitIQD >= 0
                          ? Colors.green.shade700
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildDetailRow(
                    'قازانج (دۆلار):',
                    NumberFormat.currency(
                      symbol: '\$',
                      decimalDigits: 2,
                    ).format(profitUSD),
                    valueStyle: TextStyle(
                      color: profitUSD >= 0
                          ? Colors.green.shade700
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (debtPriceIQD > 0)
                    _buildDetailRow(
                      'قەرزی ماوە:',
                      NumberFormat.currency(
                        locale: 'ar_IQ',
                        symbol: 'د.ع ',
                        decimalDigits: 0,
                      ).format(debtPriceIQD),
                      valueStyle: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const Divider(),
                  _buildDetailRow(
                    'شێوازی پارەدان:',
                    sale['payment_method'] == 'debt' ? 'قەرز' : 'نەخت',
                  ),
                  _buildDetailRow(
                    'نرخی ئاڵوگۆڕ:',
                    '1 USD = ${NumberFormat.decimalPattern('ar_IQ').format(exchangeRate)} د.ع',
                  ),
                  if (sale['notes'] != null && sale['notes'].isNotEmpty)
                    _buildDetailRow('تێبینی:', sale['notes']),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value, style: valueStyle, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'هیچ فرۆشێک نەدۆزرایەوە',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'هەوڵی گۆڕینی گەڕانەکەت یان فلتەرەکان بدە.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
