import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:solar_database/helpers/widget/Invoices/html_content/debt_content.dart';
import 'package:solar_database/helpers/widget/Invoices/invoice_debt.dart';

// A more modern and visually appealing screen for managing debts.
class ViewDebts extends StatefulWidget {
  const ViewDebts({super.key});

  @override
  State<ViewDebts> createState() => _ViewDebtsState();
}

class _ViewDebtsState extends State<ViewDebts> with TickerProviderStateMixin {
  // State Management
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _allDebts = [];
  List<Map<String, dynamic>> _displayDebts = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _customerPayments = [];

  // Controllers and Formatters
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0');

  // Animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fetchDebts();
    _searchController.addListener(_filterDebts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- Data Fetching and Handling ---
  Future<void> _fetchDebts() async {
    setState(() => _isLoading = true);
    try {
      final debts = await _dbHelper.getAllDebts();
      if (!mounted) return;
      setState(() {
        _allDebts = debts;
        _filterDebts(); // Apply initial filter
      });
    } catch (e) {
      _showErrorSnackBar('هەڵە لە هێنانی  قیستەکان: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterDebts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (_selectedCustomer != null) {
        // If a customer is selected, show all their debts
        _displayDebts = _allDebts.where((debt) {
          return debt['customer_name'] == _selectedCustomer!['customer_name'];
        }).toList();
      } else {
        // Otherwise, apply the search query
        _displayDebts = _allDebts.where((debt) {
          final name = debt['customer_name'].toString().toLowerCase();
          final phone = debt['customer_phone']?.toString().toLowerCase() ?? '';
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchCustomerPayments(
    String customerName,
    String? customerPhone,
  ) async {
    try {
      final payments = await _dbHelper.getCustomerPayments(
        customerName,
        customerPhone,
      );
      if (!mounted) return;
      setState(() => _customerPayments = payments);
    } catch (e) {
      _showErrorSnackBar('هەڵە لە هێنانی پارەدانەکان: ${e.toString()}');
    }
  }

  Future<void> _payDebt(int debtId, double amountToPay) async {
    try {
      final debt = _allDebts.firstWhere((d) => d['id'] == debtId);
      final currentDebt = (debt['debt_amount'] as num).toDouble();
      final newPaidAmount = (debt['paid_amount'] as num) + amountToPay;
      final newDebtAmount = currentDebt - amountToPay;

      await _dbHelper.updateDebt({
        'id': debtId,
        'paid_amount': newPaidAmount,
        'debt_amount': newDebtAmount > 0 ? newDebtAmount : 0,
      });

      _showSuccessSnackBar('پارەدانەکە تۆمارکرا بە سەرکەوتوویی!');
      await _fetchDebts(); // Refresh all data
    } catch (e) {
      _showErrorSnackBar('هەڵە لە نوێکردنەوەی  قیست: ${e.toString()}');
    }
  }

  Future<void> _deleteDebt(int debtId) async {
    try {
      await _dbHelper.deleteDebt(debtId);
      _showSuccessSnackBar(' قیستەکە سڕایەوە بە سەرکەوتوویی!');
      await _fetchDebts(); // Refresh all data
    } catch (e) {
      _showErrorSnackBar('هەڵە لە سڕینەوەی  قیست: ${e.toString()}');
    }
  }

  // --- Invoice Generation ---
  Future<String> _loadAssetBase64(String path) async {
    try {
      final byteData = await rootBundle.load(path);
      return base64Encode(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading asset: $e');
      return '';
    }
  }

  List<Map<String, String>> _convertPaymentsToStringMap() {
    return _customerPayments.map((payment) {
      return payment.map(
        (key, value) => MapEntry(key, value?.toString() ?? 'N/A'),
      );
    }).toList();
  }

  Future<void> _generateAndDisplayInvoice(Map<String, dynamic> debt) async {
    // First, ensure we have the latest payment history for this customer
    await _fetchCustomerPayments(debt['customer_name'], debt['customer_phone']);

    try {
      final logoBase64 = await _loadAssetBase64('assets/images/logo.png');
      final batteryBase64 = await _loadAssetBase64('assets/images/battery.jpg');
      final panelBase64 = await _loadAssetBase64('assets/images/panel.png');

      final saleDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.parse(debt['sale_date']));
      final dueDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.parse(debt['sale_date']).add(const Duration(days: 30)));

      final html = generateDebtInvoiceHtml(
        transactionId: debt['id'].toString(),
        date: saleDate,
        dueDate: dueDate,
        companyName: debt['customer_name'],
        customerPhone: debt['customer_phone'] ?? 'N/A',
        customerAddress: debt['customer_address'] ?? 'N/A',
        totalAmount: _currencyFormat.format(debt['total_amount'] ?? ''),
        paidAmount: _currencyFormat.format(debt['paid_amount'] ?? ''),
        debtAmount: _currencyFormat.format(debt['debt_amount'] ?? ''),
        currency: debt['currency'] ?? "",
        notes: debt['notes'] ?? '',
        logoBase64: 'data:image/png;base64,$logoBase64',
        batteryBase64: 'data:image/png;base64,$batteryBase64',
        panelBase64: 'data:image/png;base64,$panelBase64',
        paymentHistory: _convertPaymentsToStringMap(),
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InvoicePrintDebt(htmlContent: html)),
      );
    } catch (e) {
      _showErrorSnackBar('هەڵە لە دروستکردنی پسوڵە: $e');
    }
  }

  // --- UI Event Handlers ---
  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
      _filterDebts();
      _animationController.forward(from: 0.0);
    });
  }

  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomer = null;
      _filterDebts();
    });
  }

  // --- Dialogs and Modals ---
  void _showPayDebtModal(Map<String, dynamic> debt) {
    final payController = TextEditingController();
    final currentDebt = (debt['debt_amount'] as num).toDouble();
    final currencySymbol = _getCurrencySymbol(debt['currency']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'پارەدان بۆ ${debt['customer_name']}',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'کۆی  قیستی ماوە: ${_currencyFormat.format(currentDebt)} $currencySymbol',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: payController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'بڕی پارە',
                  prefixIcon: Icon(Icons.attach_money, color: kPrimaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final amount = double.tryParse(payController.text);
                  if (amount == null || amount <= 0) {
                    _showErrorSnackBar('تکایە بڕێکی دروست بنوسە.');
                    return;
                  }
                  if (amount > currentDebt) {
                    _showErrorSnackBar(
                      'بڕەکە ناتوانێت زیاتر بێت لە  قیستی ماوە.',
                    );
                    return;
                  }
                  _payDebt(debt['id'], amount);
                  Navigator.pop(context);
                },
                child: Text('پارەدان', style: GoogleFonts.lato(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(int debtId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('دڵنیای لە سڕینەوە؟'),
        content: const Text('ئەم کردارە پاشگەزبوونەوەی نییە.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteDebt(debtId);
            },
            child: const Text('بەڵێ، بیسڕەوە'),
          ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'بەڕێوەبردنی  قیست',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kPrimaryColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDebts,
            tooltip: 'نوێکردنەوە',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      _SearchBar(controller: _searchController),
                      const SizedBox(height: 16),
                      _buildSummarySection(),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _selectedCustomer != null
                      ? _CustomerHeader(
                          customer: _selectedCustomer!,
                          onClear: _clearCustomerSelection,
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: _displayDebts.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchDebts,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _displayDebts.length,
                            itemBuilder: (context, index) {
                              final debt = _displayDebts[index];
                              return DebtListItem(
                                debt: debt,
                                currencyFormat: _currencyFormat,
                                onPay: () => _showPayDebtModal(debt),
                                onDelete: () =>
                                    _showDeleteConfirmationDialog(debt['id']),
                                onGenerateInvoice: () =>
                                    _generateAndDisplayInvoice(
                                      debt,
                                    ), // Hooked up invoice generation
                                onSelect: () => _selectCustomer(debt),
                                isSelected: _selectedCustomer != null,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummarySection() {
    final totalDebt = _allDebts.fold(
      0.0,
      (sum, debt) => sum + (debt['debt_amount'] as num),
    );
    final totalPaid = _allDebts.fold(
      0.0,
      (sum, debt) => sum + (debt['paid_amount'] as num),
    );

    return Row(
      children: [
        Expanded(
          child: SummaryCard(
            title: 'کۆی  قیست',
            amount: _currencyFormat.format(totalDebt),
            currency: 'ع.د',
            color: Colors.red.shade400,
            icon: Icons.money_off_csred_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryCard(
            title: 'کۆی پارەدراو',
            amount: _currencyFormat.format(totalPaid),
            currency: 'ع.د',
            color: Colors.green.shade500,
            icon: Icons.check_circle_rounded,
          ),
        ),
      ],
    );
  }

  // --- Helper Methods for UI ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade600),
    );
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'IQD':
        return 'ع.د';
      default:
        return currency;
    }
  }
}

// --- Reusable Widgets ---

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'گەڕان بەدوای ناوی کڕیار...',
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.5)),
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title, amount, currency;
  final Color color;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.lato(fontSize: 14, color: color)),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.lato(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              children: [
                TextSpan(text: amount),
                TextSpan(
                  text: ' $currency',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DebtListItem extends StatelessWidget {
  final Map<String, dynamic> debt;
  final NumberFormat currencyFormat;
  final VoidCallback onPay;
  final VoidCallback onDelete;
  final VoidCallback onGenerateInvoice; // New callback for generating invoice
  final VoidCallback onSelect;
  final bool isSelected;

  const DebtListItem({
    super.key,
    required this.debt,
    required this.currencyFormat,
    required this.onPay,
    required this.onDelete,
    required this.onGenerateInvoice,
    required this.onSelect,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = (debt['total_amount'] as num).toDouble();
    final debtAmount = (debt['debt_amount'] as num).toDouble();
    final paidAmount = totalAmount - debtAmount;
    final hasDebt = debtAmount > 0;
    final progress = totalAmount > 0 ? paidAmount / totalAmount : 0.0;
    final currencySymbol = _getCurrencySymbol(debt['currency']);

    return Card(
      elevation: isSelected ? 4 : 2,
      shadowColor: Colors.grey.withOpacity(0.3),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: kPrimaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      debt['customer_name'],
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(hasDebt: hasDebt),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                debt['customer_phone'] ?? 'ژمارەی مۆبایل نییە',
                style: GoogleFonts.lato(color: Colors.grey[600], fontSize: 14),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  _AmountInfo(
                    label: 'پارەدراو',
                    amount: currencyFormat.format(paidAmount),
                    currency: currencySymbol,
                    color: Colors.green,
                  ),
                  _AmountInfo(
                    label: 'ماوە',
                    amount: currencyFormat.format(debtAmount),
                    currency: currencySymbol,
                    color: Colors.red,
                  ),
                  _AmountInfo(
                    label: 'کۆی گشتی',
                    amount: currencyFormat.format(totalAmount),
                    currency: currencySymbol,
                    color: Colors.blueGrey,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasDebt ? Colors.orange.shade400 : Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat(
                      'MMM dd, yyyy',
                    ).format(DateTime.parse(debt['sale_date'])),
                    style: GoogleFonts.lato(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      if (hasDebt)
                        _ActionButton(
                          icon: Icons.payment,
                          color: kAccentColor,
                          onPressed: onPay,
                        ),
                      _ActionButton(
                        icon: Icons.picture_as_pdf,
                        color: Colors.purple.shade300,
                        onPressed: onGenerateInvoice,
                      ), // Using the new callback
                      if (!hasDebt)
                        _ActionButton(
                          icon: Icons.delete_outline,
                          color: Colors.red.shade300,
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'IQD':
        return 'ع.د';
      default:
        return currency;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final bool hasDebt;
  const _StatusChip({required this.hasDebt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasDebt
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        hasDebt ? ' قیستدار' : 'پارەدراوە',
        style: GoogleFonts.lato(
          color: hasDebt ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AmountInfo extends StatelessWidget {
  final String label, amount, currency;
  final Color color;

  const _AmountInfo({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '$amount $currency',
            style: GoogleFonts.lato(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      width: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onClear;

  const _CustomerHeader({required this.customer, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kPrimaryColor,
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وردەکاریەکانی ${customer['customer_name']}',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kPrimaryColor,
                  ),
                ),
                Text(
                  'بینینی هەموو  قیستەکانی ئەم کڕیارە',
                  style: GoogleFonts.lato(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: kPrimaryColor),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'هیچ  قیستێک نەدۆزرایەوە',
            style: GoogleFonts.lato(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'هەوڵ بدە گەڕانەکەت بگۆڕیت یان  قیستێکی نوێ زیاد بکەیت',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
