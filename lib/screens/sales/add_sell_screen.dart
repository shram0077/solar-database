import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:solar_database/helpers/widget/Invoices/html_content/frosh_content.dart';
import 'package:solar_database/helpers/widget/Invoices/coustomer_invoice.dart';
import 'package:solar_database/constans/colors.dart';

// A constant for the screen width breakpoint to switch between layouts.
const double kWideLayoutThreshold = 800.0;

class AddSellScreen extends StatefulWidget {
  const AddSellScreen({super.key});

  @override
  State<AddSellScreen> createState() => _AddSellScreenState();
}

class _AddSellScreenState extends State<AddSellScreen> {
  // --- Controllers ---
  final _barcodeController = TextEditingController();
  final _discountController = TextEditingController();
  final _paidController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _warrantyMonthsController = TextEditingController();
  final _warrantyPriceController = TextEditingController();

  // --- State variables ---
  String _paymentMethod = 'cash'; // 'cash' or 'debt'
  final String _selectedWarranty = 'بێ گرەنتی';
  String _paymentCurrency = 'USD';
  double iqdToUsdRate = 1460.0;
  bool _isProcessingSale = false;
  List<SaleItem> items = [];

  // --- Helpers ---
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NumberFormat currencyFormat = NumberFormat('#,##0.00');

  // --- Calculated properties ---
  double get _totalPriceUSD {
    final itemsTotal = items.fold(0.0, (sum, item) => sum + item.subtotal);
    final warrantyPrice = double.tryParse(_warrantyPriceController.text) ?? 0.0;
    return itemsTotal + warrantyPrice;
  }

  double get _totalPriceIQD => _totalPriceUSD * iqdToUsdRate;

  double get _displayDiscountPercent {
    if (_paymentMethod == 'cash') return 0.0;
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  // NOTE: This now represents an added fee for debt, hence the negative multiplier.
  // When subtracted from the total, it increases the final amount.
  double get _discountAmountUSD {
    if (_paymentMethod == 'cash') return 0.0;
    final discountPercent = double.tryParse(_discountController.text) ?? 0.0;
    return _totalPriceUSD * (-discountPercent / 100);
  }

  double get _discountAmountIQD {
    if (_paymentMethod == 'cash') return 0.0;
    final discountPercent = double.tryParse(_discountController.text) ?? 0.0;
    return _totalPriceIQD * (-discountPercent / 100);
  }

  double get _paidAmountUSD => double.tryParse(_paidController.text) ?? 0.0;
  double get _paidAmountIQD => _paidAmountUSD * iqdToUsdRate;

  // The final total amount after the debt fee is added.
  double get _finalTotalUSD => _totalPriceUSD - _discountAmountUSD;
  double get _finalTotalIQD => _totalPriceIQD - _discountAmountIQD;

  double get _balanceUSD => _finalTotalUSD - _paidAmountUSD;
  double get _balanceIQD => _finalTotalIQD - _paidAmountIQD;

  late SharedPreferences _prefs;

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      iqdToUsdRate = _prefs.getDouble('exchangeRate') ?? 1450.0;
    });
  }

  @override
  void initState() {
    super.initState();
    _initialize();
    _discountController.addListener(_calculateTotals);
    _paidController.addListener(_calculateTotals);
    _warrantyPriceController.addListener(_calculateTotals);
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _warrantyMonthsController.dispose();
    _warrantyPriceController.dispose();
    super.dispose();
  }

  void _calculateTotals() => setState(() {});

  // --- Core Business Logic (Your existing methods, no changes needed) ---
  Future<void> _scanItem() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final itemData = await _dbHelper.getItemByBarcode(barcode);
    if (itemData == null) {
      if (mounted) {
        _showSnackBar('کاڵا بە بارکۆدی "$barcode" نەدۆزرایەوە', isError: true);
      }
      return;
    }

    final quantityAvailable = itemData['quantity'] as int? ?? 0;
    if (quantityAvailable <= 0) {
      if (mounted) {
        _showSnackBar('کاڵای "$barcode" لە کۆگادا نەماوە', isError: true);
      }
      return;
    }

    setState(() {
      final index = items.indexWhere((item) => item.barcode == barcode);
      if (index != -1) {
        if (items[index].qty < quantityAvailable) {
          items[index].qty += 1;
        } else {
          _showSnackBar(
            'ئەوپەڕی کۆگاکردن $quantityAvailable گەیشت بۆ $barcode',
            isWarning: true,
          );
        }
      } else {
        items.add(
          SaleItem(
            barcode: barcode,
            name: itemData['item_name'] as String? ?? 'نادیار',
            price: (itemData['selling_price'] as num?)?.toDouble() ?? 0.0,
            qty: 1,
            availableQuantity: quantityAvailable,
            buyingPrice: (itemData['buying_price'] as num?)?.toDouble() ?? 0.0,
            warranty: itemData['warranty'] as String?,
            brand: itemData['brand'] as String?,
            model: itemData['model'] as String?,
          ),
        );
      }
      _barcodeController.clear();
      _calculateTotals();
    });
  }

  void _removeItem(int index) {
    setState(() {
      items.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateItemQty(int index, int newQty) {
    if (newQty <= 0) {
      _removeItem(index);
      return;
    }

    if (newQty > items[index].availableQuantity) {
      _showSnackBar(
        'تەنیا ${items[index].availableQuantity} بەردەستە بۆ ${items[index].name}',
        isWarning: true,
      );
      return;
    }

    setState(() {
      items[index].qty = newQty;
      _calculateTotals();
    });
  }

  Future<void> _processSale(String paymentMethod) async {
    if (items.isEmpty) {
      _showSnackBar('تکایە کاڵا زیاد بکە بۆ فرۆشتن', isError: true);
      return;
    }

    // Ensure customer details are provided for debt sales
    if (paymentMethod == 'debt' &&
        _customerNameController.text.trim().isEmpty) {
      _showSnackBar('تکایە ناوی کڕیار بۆ فرۆشتنی قیست بنووسە', isError: true);
      return;
    }

    setState(() => _isProcessingSale = true);

    try {
      final now = DateTime.now().toIso8601String();
      final customerName = _customerNameController.text.trim().isNotEmpty
          ? _customerNameController.text.trim()
          : 'کڕیاری کاتی';

      await _processDatabaseTransaction(now, customerName, paymentMethod);
      await _generateAndDisplayInvoice(now, customerName);

      _resetForm();

      _showSnackBar(
        'فرۆشتن بە سەرکەوتوویی ئەنجامدرا. کۆی گشتی: ${currencyFormat.format(_paymentCurrency == 'USD' ? _finalTotalUSD : _finalTotalIQD)} $_paymentCurrency',
        isSuccess: true,
      );
    } catch (e) {
      _showSnackBar('فرۆشتن شکستی هێنا: ${e.toString()}', isError: true);
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingSale = false);
    }
  }

  Future<void> _processDatabaseTransaction(
    String now,
    String customerName,
    String paymentMethod,
  ) async {
    await _dbHelper.database.then((db) async {
      await db.transaction((txn) async {
        for (final item in items) {
          final double itemDiscountUSD = _discountAmountUSD / items.length;
          final double itemDiscountIQD = _discountAmountIQD / items.length;

          await txn.insert(DatabaseHelper.tableSales, {
            'item_id': item.barcode,
            'item_name': item.name,
            'customer_name': customerName,
            'customer_phone': _customerPhoneController.text.trim(),
            'customer_address': _customerAddressController.text.trim(),
            'quantity': item.qty,
            'selling_price': item.price * iqdToUsdRate,
            'selling_price_usd': item.price,
            'buying_price': item.buyingPrice * iqdToUsdRate,
            'buying_price_usd': item.buyingPrice,
            'discount': itemDiscountIQD,
            'discount_usd': itemDiscountUSD,
            'total_amount': item.subtotal * iqdToUsdRate,
            'total_amount_usd': item.subtotal,
            'final_amount': _paymentCurrency == 'IQD'
                ? _finalTotalIQD
                : _finalTotalUSD,
            'final_amount_usd': _paymentCurrency == 'USD'
                ? _finalTotalUSD
                : _finalTotalIQD,
            'profit':
                items.fold(
                  0.0,
                  (sum, item) =>
                      sum + ((item.price - item.buyingPrice) * item.qty),
                ) +
                (double.tryParse(_warrantyPriceController.text) ?? 0.0),
            'profit_iqd':
                (items.fold(
                      0.0,
                      (sum, item) =>
                          sum + ((item.price - item.buyingPrice) * item.qty),
                    ) +
                    (double.tryParse(_warrantyPriceController.text) ?? 0.0)) *
                iqdToUsdRate,
            'payment_method': paymentMethod,
            'sale_date': now,
            'created_at': now,
            'warranty': _selectedWarranty,
            'exchange_rate': iqdToUsdRate,
            'currency': _paymentCurrency,
            'warranty_months':
                int.tryParse(_warrantyMonthsController.text) ?? 0,
            'warranty_price':
                double.tryParse(_warrantyPriceController.text) ?? 0.0,
          });

          await txn.update(
            DatabaseHelper.tableItems,
            {'quantity': item.availableQuantity - item.qty, 'updated_at': now},
            where: 'barcode = ?',
            whereArgs: [item.barcode],
          );
        }

        if (paymentMethod == 'debt' && _balanceUSD > 0) {
          await _dbHelper.addDebt(
            customerAddress: _customerAddressController.text.trim(),
            customerName: customerName,
            customerPhone: _customerPhoneController.text.trim(),
            totalAmount: _finalTotalUSD,
            paidAmount: _paidAmountUSD,
            debtAmount: _balanceUSD,
            saleDate: now,
            currency: 'USD',
            exchangeRate: iqdToUsdRate,
            transaction: txn,
          );
        }
      });
    });
  }

  Future<void> _generateAndDisplayInvoice(
    String now,
    String customerName,
  ) async {
    final logoBase64 = await _loadAssetBase64('assets/images/logo.png');
    final batteryBase64 = await _loadAssetBase64('assets/images/battery.jpg');
    final panelBase64 = await _loadAssetBase64('assets/images/panel.png');

    if (mounted && items.isNotEmpty) {
      final html = generateInvoiceHtml(
        discountPercent: _displayDiscountPercent,
        invoiceDate: DateTime.now(),
        invoiceNumber: '12',
        customerName: customerName,
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        items: items,
        paymentCurrency: _paymentCurrency,
        discountAmountUSD: _discountAmountUSD,
        discountAmountIQD: _discountAmountIQD,
        paidAmountUSD: _paidAmountUSD,
        paidAmountIQD: _paidAmountIQD,
        totalPriceUSD: _totalPriceUSD,
        totalPriceIQD: _totalPriceIQD,
        balanceUSD: _balanceUSD,
        balanceIQD: _balanceIQD,
        iqdToUsdRate: iqdToUsdRate,
        warrantyMonths: int.tryParse(_warrantyMonthsController.text) ?? 0,
        warrantyPriceUSD: double.tryParse(_warrantyPriceController.text) ?? 0.0,
        warrantyPriceIQD:
            (double.tryParse(_warrantyPriceController.text) ?? 0.0) *
            iqdToUsdRate,
        logoUrl: 'data:image/png;base64,$logoBase64',
        brandLogos: [
          'data:image/png;base64,$panelBase64',
          'data:image/png;base64,$batteryBase64',
        ],
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InvoicePrintPage(htmlContent: html)),
      );
    }
  }

  void _resetForm() {
    setState(() {
      items.clear();
      _discountController.clear();
      _paidController.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerAddressController.clear();
      _warrantyMonthsController.clear();
      _warrantyPriceController.clear();
      _paymentMethod = 'cash';
      _calculateTotals();
    });
  }

  // --- Helper Methods ---
  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isWarning = false,
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: isError
            ? Colors.red
            : isWarning
            ? kWarningColor
            : isSuccess
            ? kSuccessColor
            : kPrimaryColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveExchangeRate(double newRate) async {
    await _prefs.setDouble('exchangeRate', newRate);
    setState(() => iqdToUsdRate = newRate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exchange rate updated to 1 USD = ${iqdToUsdRate.toStringAsFixed(0)} IQD',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<String> _loadAssetBase64(String path) async {
    final byteData = await rootBundle.load(path);
    return base64Encode(byteData.buffer.asUint8List());
  }

  void _showChangeRateDialog() {
    final rateController = TextEditingController(text: iqdToUsdRate.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('گۆڕینی نرخی IQD/USD'),
        content: TextField(
          controller: rateController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'نرخی نوێ (1 USD = ? IQD)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('هەڵوەشاندنەوە'),
          ),
          ElevatedButton(
            onPressed: () {
              final newRate = double.tryParse(rateController.text);
              if (newRate != null && newRate > 0) {
                setState(() {
                  iqdToUsdRate = newRate;
                  _saveExchangeRate(newRate);

                  _calculateTotals();
                });
                Navigator.pop(context);
                _showSnackBar(
                  'نرخی دراو نوێکرایەوە بۆ 1 USD = ${currencyFormat.format(newRate)} IQD',
                  isSuccess: true,
                );
              } else {
                _showSnackBar('نرخێکی نادروست داخڵکرا', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('پاشکەوتکردن'),
          ),
        ],
      ),
    );
  }

  // --- UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: kPrimaryColor,
          secondary: kAccentColor,
          surface: Colors.white,
          error: Colors.red,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kPrimaryColor, width: 2.0),
          ),
          labelStyle: TextStyle(color: kTextColor),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: kBorderColor, width: 0.5),
          ),
          margin: EdgeInsets.symmetric(vertical: 8.0),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('بەشی فرۆشتن'),
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        // Use LayoutBuilder to create a responsive UI
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > kWideLayoutThreshold) {
              return _buildWideLayout();
            } else {
              return _buildNarrowLayout();
            }
          },
        ),
      ),
    );
  }

  // --- RESPONSIVE LAYOUT WIDGETS ---

  /// Layout for wide screens (e.g., desktop, landscape tablet)
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel (Main Content)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopSearchAndCustomerInfo(),
                SizedBox(height: 16),
                _buildItemList(),
              ],
            ),
          ),
        ),
        // Right Panel (Summary & Payment)
        Expanded(
          flex: 1,
          child: Container(
            color: kPrimaryColor.withOpacity(0.05),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: _buildSummaryAndPayment(),
            ),
          ),
        ),
      ],
    );
  }

  /// Layout for narrow screens (e.g., mobile, portrait tablet)
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopSearchAndCustomerInfo(),
          SizedBox(height: 16),
          _buildItemList(),
          SizedBox(height: 16),
          _buildSummaryAndPayment(),
        ],
      ),
    );
  }

  // --- UI COMPONENT WIDGETS ---

  Widget _buildTopSearchAndCustomerInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barcode Field
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'بارکۆد سکان بکە',
                hintText: 'بارکۆدی کاڵا داخڵ بکە یان سکانی بکە',
                prefixIcon: Icon(Icons.qr_code_scanner, color: kPrimaryColor),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _scanItem,
                ),
              ),
              onSubmitted: (_) => _scanItem(),
            ),
            SizedBox(height: 16),

            // Customer name & phone
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'ناوی کڕیار',
                      prefixIcon: Icon(Icons.person, color: kPrimaryColor),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _customerPhoneController,
                    decoration: InputDecoration(
                      labelText: 'تەلەفۆن',
                      prefixIcon: Icon(Icons.phone, color: kPrimaryColor),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Address field
            TextField(
              controller: _customerAddressController,
              decoration: InputDecoration(
                labelText: 'ناونیشانی کڕیار',
                prefixIcon: Icon(Icons.location_on, color: kPrimaryColor),
              ),
            ),
            SizedBox(height: 16),

            // Warranty fields
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _warrantyMonthsController,
                    decoration: InputDecoration(
                      labelText: 'ماوەی گرەنتی (مانگ)',
                      prefixIcon: Icon(
                        Icons.calendar_month,
                        color: kPrimaryColor,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _warrantyPriceController,
                    decoration: InputDecoration(
                      labelText: 'نرخی گرەنتی (\$)',
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: kPrimaryColor,
                      ),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// REFACTORED: Replaced DataTable with a more responsive ListView of Cards.
  Widget _buildItemList() {
    return items.isEmpty
        ? Card(
            child: Container(
              height: 200,
              alignment: Alignment.center,
              child: Text(
                'هێشتا هیچ کاڵایەک زیاد نەکراوە.',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ),
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(item, index);
            },
          );
  }

  /// NEW: A dedicated widget for displaying a single item in the list.
  Widget _buildItemCard(SaleItem item, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.brand ?? ''} ${item.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'مۆدێل: ${item.model ?? 'N/A'}',
                        style: TextStyle(color: kTextColor, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'نرخ: ${currencyFormat.format(item.price)} \$',
                        style: TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeItem(index),
                  tooltip: 'سڕینەوەی کاڵا',
                ),
              ],
            ),
            Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity controls
                Row(
                  children: [
                    Text(
                      'بڕ:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: kPrimaryColor,
                      ),
                      onPressed: () => _updateItemQty(index, item.qty - 1),
                    ),
                    Text(
                      item.qty.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: kPrimaryColor,
                      ),
                      onPressed: () => _updateItemQty(index, item.qty + 1),
                    ),
                    Text(
                      '(Max: ${item.availableQuantity})',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                // Subtotal
                Text(
                  '${currencyFormat.format(item.subtotal)} \$',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kSuccessColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryAndPayment() {
    return Column(
      children: [
        _buildCurrencyExchangeCard(),
        _buildTotalsSummaryCard(),
        _buildPaymentInputsCard(),
        SizedBox(height: 16),
        _buildPaymentMethodSelector(),
        SizedBox(height: 16),
        _buildProcessSaleButton(),
      ],
    );
  }

  Widget _buildCurrencyExchangeCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'گۆڕینەوەی دراو',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.currency_exchange, color: kPrimaryColor),
                  onPressed: _showChangeRateDialog,
                  tooltip: 'گۆڕینی نرخی دراو',
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '1 USD = ${currencyFormat.format(iqdToUsdRate)} IQD',
              style: TextStyle(
                color: kSuccessColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildCurrencyRow('کۆی نرخی:', _finalTotalUSD),
            _buildCurrencyRow('کۆی نرخی:', _finalTotalIQD, isIQD: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSummaryCard() {
    final warrantyPrice = double.tryParse(_warrantyPriceController.text) ?? 0.0;
    final itemsSubtotal = _totalPriceUSD - warrantyPrice;

    final warrantyPriceDisplay = _paymentCurrency == 'USD'
        ? warrantyPrice
        : warrantyPrice * iqdToUsdRate;
    final itemsSubtotalDisplay = _paymentCurrency == 'USD'
        ? itemsSubtotal
        : itemsSubtotal * iqdToUsdRate;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _paymentCurrency,
              items: ['USD', 'IQD'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _paymentCurrency = newValue!;
                  _calculateTotals();
                });
              },
              decoration: InputDecoration(
                labelText: 'دراوی پێدان',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money, color: kPrimaryColor),
              ),
            ),
            SizedBox(height: 20),
            _buildSummaryRow(
              'کۆی سەرەتایی',
              itemsSubtotalDisplay,
              _paymentCurrency,
            ),
            if (warrantyPrice > 0)
              _buildSummaryRow(
                'گرەنتی',
                warrantyPriceDisplay,
                _paymentCurrency,
              ),
            Divider(),
            if (_paymentMethod == 'debt')
              _buildSummaryRow(
                'زیادکردنی قیست (${_displayDiscountPercent.toStringAsFixed(2)}%)',
                _paymentCurrency == 'USD'
                    ? -_discountAmountUSD // Display as a positive number
                    : -_discountAmountIQD,
                _paymentCurrency,
              ),
            _buildSummaryRow(
              'کۆی گشتی',
              _paymentCurrency == 'USD' ? _finalTotalUSD : _finalTotalIQD,
              _paymentCurrency,
              isTotal: true,
            ),
            Divider(),
            _buildSummaryRow(
              'دراو',
              _paymentCurrency == 'USD' ? _paidAmountUSD : _paidAmountIQD,
              _paymentCurrency,
            ),
            _buildSummaryRow(
              'بەرماوە',
              _paymentCurrency == 'USD' ? _balanceUSD : _balanceIQD,
              _paymentCurrency,
              isBalance: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInputsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Visibility(
              visible: _paymentMethod == 'debt',
              child: Column(
                children: [
                  TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          'زیاد کردنی  بری پارە بە ڕێژە (%)', // Label reflects function
                      prefixIcon: Icon(
                        Icons.add_circle_outline,
                        color: kPrimaryColor,
                      ),
                      suffixText: '%',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,2}(\.\d{0,2})?'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
            TextField(
              controller: _paidController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'بڕی دراو ($_paymentCurrency)',
                prefixIcon: Icon(Icons.payment, color: kPrimaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: Text('کاش'),
            selected: _paymentMethod == 'cash',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _paymentMethod = 'cash';
                  _discountController.clear();
                  _calculateTotals();
                });
              }
            },
            avatar: Icon(
              Icons.money,
              color: _paymentMethod == 'cash' ? Colors.white : kSuccessColor,
            ),
            selectedColor: kSuccessColor,
            labelStyle: TextStyle(
              color: _paymentMethod == 'cash' ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _paymentMethod == 'cash' ? kSuccessColor : kBorderColor,
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ChoiceChip(
            label: Text('قیست'),
            selected: _paymentMethod == 'debt',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _paymentMethod = 'debt';
                  _calculateTotals();
                });
              }
            },
            avatar: Icon(
              Icons.credit_card,
              color: _paymentMethod == 'debt' ? Colors.white : kPrimaryColor,
            ),
            selectedColor: kPrimaryColor,
            labelStyle: TextStyle(
              color: _paymentMethod == 'debt' ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _paymentMethod == 'debt' ? kPrimaryColor : kBorderColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessSaleButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: _isProcessingSale
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.check_circle_outline, size: 28),
        label: Text('ئەنجامدانی فرۆشتن', style: TextStyle(fontSize: 20)),
        onPressed: _isProcessingSale
            ? null
            : () => _processSale(_paymentMethod),
        style: ElevatedButton.styleFrom(
          backgroundColor: _paymentMethod == 'cash'
              ? kSuccessColor
              : kPrimaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCurrencyRow(String label, double amount, {bool isIQD = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor),
          ),
          Text(
            '${currencyFormat.format(amount)} ${isIQD ? 'IQD' : '\$'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIQD ? kPrimaryColor : kSuccessColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    String currency, {
    bool isTotal = false,
    bool isBalance = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    Color textColor = kTextColor;
    TextStyle style = textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w500,
    );

    if (isTotal) {
      textColor = kPrimaryColor;
      style = textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold);
    } else if (isBalance) {
      textColor = amount < 0 ? Colors.red : kSuccessColor;
      style = textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.titleMedium),
          Text(
            '${currencyFormat.format(amount)} $currency',
            style: style.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class SaleItem {
  final String barcode;
  final String name;
  final double price;
  final double buyingPrice;
  int qty;
  final int availableQuantity;
  final String? warranty;
  final String? brand;
  final String? model;

  SaleItem({
    required this.barcode,
    required this.name,
    required this.price,
    required this.qty,
    required this.availableQuantity,
    required this.buyingPrice,
    this.warranty,
    this.brand,
    this.model,
  });

  double get subtotal => price * qty;
}
