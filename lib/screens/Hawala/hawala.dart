import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:solar_database/helpers/widget/Invoices/html_content/hawala_content.dart';
import 'package:solar_database/helpers/widget/Invoices/invoice_hawala.dart';
import 'package:solar_database/models/company.dart';
import 'package:intl/intl.dart';

class HawalaTransaction {
  final String id;
  final int? companyId;
  final String companyName;
  final String companyType;
  final double amount;
  final String currency;
  final DateTime date;
  final String? notes;
  final DateTime? createdAt;
  final bool isSent; // true if sent to company, false if received from company
  final String? senderName;
  final String? receiverName;

  HawalaTransaction({
    required this.id,
    this.companyId,
    required this.companyName,
    required this.companyType,
    required this.amount,
    required this.currency,
    required this.date,
    this.notes,
    this.createdAt,
    required this.isSent,
    this.senderName,
    this.receiverName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'company_name': companyName,
      'company_type': companyType,
      'amount': amount,
      'currency': currency,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'is_sent': isSent ? 1 : 0,
      'sender_name': senderName,
      'receiver_name': receiverName,
    };
  }

  factory HawalaTransaction.fromMap(Map<String, dynamic> map) {
    return HawalaTransaction(
      id: map['id'],
      companyId: map['company_id'],
      companyName: map['company_name'],
      companyType: map['company_type'],
      amount: map['amount'],
      currency: map['currency'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      notes: map['notes'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      isSent: map['is_sent'] == 1,
      senderName: map['sender_name'],
      receiverName: map['receiver_name'],
    );
  }
}

class HawalaScreen extends StatefulWidget {
  const HawalaScreen({super.key});

  @override
  State<HawalaScreen> createState() => _HawalaScreenState();
}

class _HawalaScreenState extends State<HawalaScreen> {
  // --- UI Theme Colors ---
  static const _primaryColor = Color(0xFF0D47A1);
  static const _accentColor = Color(0xFF448AFF);
  static const _backgroundColor = Color(0xFFF5F7FA);
  static const _cardColor = Colors.white;
  static const _textColor = Color(0xFF333333);
  static const _subtleTextColor = Color(0xFF666666);
  static const _sentColor = Colors.green;
  static const _receivedColor = Colors.blue;

  // --- State Variables ---
  Company? selectedCompany;
  String selectedCurrency = 'IQD';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _senderController = TextEditingController();
  final TextEditingController _receiverController = TextEditingController();
  bool isSending = true;

  List<Company> companies = [];
  bool isLoadingCompanies = true;
  bool isLoadingTransactions = true;
  List<HawalaTransaction> _transactions = [];

  final List<Map<String, dynamic>> currencies = [
    {'symbol': 'USD', 'name': 'American Dollar'},
    {'symbol': 'IQD', 'name': 'Iraqi Dinar'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _senderController.dispose();
    _receiverController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadCompanies();
    await _loadTransactions();
  }

  Future<void> _loadCompanies() async {
    if (!mounted) return;
    setState(() => isLoadingCompanies = true);

    try {
      final dbHelper = DatabaseHelper();
      final companyMaps = await dbHelper.getAllCompanies();
      final loadedCompanies = companyMaps
          .map((map) => Company.fromMap(map))
          .toList();

      if (mounted) {
        setState(() {
          companies = loadedCompanies;
          isLoadingCompanies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading companies: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => isLoadingCompanies = false);
      }
    }
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() => isLoadingTransactions = true);

    try {
      final dbHelper = DatabaseHelper();
      final transactionMaps = await dbHelper.getAllHawalaTransactions();
      final loadedTransactions = transactionMaps
          .map((map) => HawalaTransaction.fromMap(map))
          .toList();

      if (mounted) {
        setState(() {
          _transactions = loadedTransactions;
          isLoadingTransactions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => isLoadingTransactions = false);
      }
    }
  }

  void _onSendPressed() {
    FocusScope.of(context).unfocus();

    if (selectedCompany == null ||
        _amountController.text.isEmpty ||
        (double.tryParse(_amountController.text) ?? 0) <= 0 ||
        (isSending && _receiverController.text.isEmpty) ||
        (!isSending && _senderController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    _showConfirmationDialog();
  }

  Future<void> _executeTransaction() async {
    final newTransaction = HawalaTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      companyId: selectedCompany?.id,
      companyName: selectedCompany!.name,
      companyType: selectedCompany!.companyType,
      amount: double.parse(_amountController.text),
      currency: selectedCurrency,
      date: DateTime.now(),
      isSent: isSending,
      senderName: !isSending
          ? _senderController.text
          : "Me", // Assuming 'Me' for sender when sending
      receiverName: isSending
          ? _receiverController.text
          : "Me", // Assuming 'Me' for receiver when receiving
    );

    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.insertHawalaTransaction(newTransaction);

      if (mounted) {
        setState(() {
          _transactions.insert(0, newTransaction);
          _resetForm();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hawala ${isSending ? 'sent' : 'received'} successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      selectedCompany = null;
      _amountController.clear();
      _senderController.clear();
      _receiverController.clear();
      selectedCurrency = 'IQD';
      isSending = true;
    });
  }

  List<HawalaTransaction> get _filteredTransactions {
    if (selectedCompany == null) return _transactions;
    return _transactions
        .where((tx) => tx.companyId == selectedCompany!.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'حەواڵەکان',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _textColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _primaryColor),
            onPressed: _loadInitialData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isLoadingCompanies
            ? _buildLoadingIndicator()
            : companies.isEmpty
            ? _buildEmptyCompanyState()
            : _buildMainLayout(),
      ),
    );
  }

  Widget _buildMainLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _buildInputForm(),
        ),
        const Divider(indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                selectedCompany != null
                    ? 'مێژووی مەمەڵە بۆ  ${selectedCompany!.name}'
                    : 'مامەڵەکانی ئەم دواییە',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const Spacer(),
              if (selectedCompany != null)
                TextButton(
                  onPressed: () => setState(() => selectedCompany = null),
                  child: const Text('هەموو نیشان بدە'),
                ),
            ],
          ),
        ),
        Expanded(
          child: isLoadingTransactions
              ? _buildLoadingIndicator()
              : _buildTransactionsList(),
        ),
      ],
    );
  }

  Widget _buildInputForm() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransactionTypeToggle(),
            const SizedBox(height: 20),
            _buildCompanySelector(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: isSending ? _buildReceiverInput() : _buildSenderInput(),
            ),
            const SizedBox(height: 16),
            _buildAmountInput(),
            const SizedBox(height: 24),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleOption('ناردن', true),
          _buildToggleOption('وەرگرتن', false),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String title, bool value) {
    final isSelected = isSending == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isSending = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : _textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanySelector() {
    return InkWell(
      onTap: companies.isNotEmpty
          ? () => _showCompanySelectionSheet(companies)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.business_center, color: _primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedCompany?.name ?? 'دەسنیشانکردنی کۆمپانیا',
                style: TextStyle(
                  color: selectedCompany != null
                      ? _textColor
                      : _subtleTextColor,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: _subtleTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderInput() {
    return TextField(
      controller: _senderController,
      decoration: _inputDecoration(
        label: 'نێرەر (لە کۆمپانیاوە)',
        icon: Icons.person_outline,
      ),
    );
  }

  Widget _buildReceiverInput() {
    return TextField(
      controller: _receiverController,
      decoration: _inputDecoration(label: 'وەرگر (کەس)', icon: Icons.person),
    );
  }

  Widget _buildAmountInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: _inputDecoration(label: 'بڕ', icon: Icons.attach_money),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: selectedCurrency,
            decoration: _inputDecoration(
              label: 'جۆری دراو',
              icon: null,
              isDropdown: true,
            ),
            items: currencies
                .map(
                  (currency) => DropdownMenuItem(
                    value: currency['symbol'] as String,
                    child: Text(
                      currency['symbol'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedCurrency = value);
              }
            },
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    bool isDropdown = false,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: _accentColor) : null,
      filled: true,
      fillColor: _backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: isDropdown
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
          : null,
    );
  }

  Widget _buildSendButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accentColor, _primaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onSendPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  isSending ? 'ناردنی حەواڵە' : 'تۆمارکردنی وەرگرتن',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    final filteredList = _filteredTransactions;

    if (filteredList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'هێشتا هیچ مامەڵەیەک نییە',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _subtleTextColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'مامەڵەکانی حەواڵەت لێرە دەردەکەون..',
              style: TextStyle(color: _subtleTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        return TransactionCard(
          transaction: filteredList[index],
          onGenerateInvoice: _generateAndDisplayInvoice,
        );
      },
    );
  }

  Future<String> _loadAssetBase64(String path) async {
    final byteData = await rootBundle.load(path);
    return base64Encode(byteData.buffer.asUint8List());
  }

  Future<void> _generateAndDisplayInvoice(HawalaTransaction transaction) async {
    try {
      final logoBase64 = await _loadAssetBase64('assets/images/logo.png');
      final batteryBase64 = await _loadAssetBase64('assets/images/battery.jpg');
      final panelBase64 = await _loadAssetBase64('assets/images/panel.png');

      final html = generateHawalaInvoiceHtml(
        receiverName: transaction.receiverName ?? '',
        transactionId: transaction.id,
        companyName: transaction.companyName,
        companyType: transaction.companyType,
        amount: transaction.amount,
        currency: transaction.currency,
        date: DateFormat('yyyy/MM/dd').format(DateTime.now()),

        notes: transaction.notes ?? '',
        isSent: transaction.isSent,
        senderName: transaction.senderName ?? '',
        logoBase64: logoBase64,
        batteryBase64: batteryBase64,
        panelBase64: panelBase64,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoicePrintHawala(htmlContent: html),
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

  Widget _buildLoadingIndicator() {
    return const Center(
      key: ValueKey('loading'),
      child: CircularProgressIndicator(color: _primaryColor),
    );
  }

  Widget _buildEmptyCompanyState() {
    return Center(
      key: const ValueKey('emptyState'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.store_mall_directory_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'هیچ کۆمپانیایەک نەدۆزرایەوە',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'تکایە لیستەکە تازە بکەوە یان گرێدانی بنکەی زانیارێکانت بپشکنە..',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompanySelectionSheet(List<Company> companies) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, controller) {
              return Material(
                color: _cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: CompanySelectionContent(
                  companies: companies,
                  scrollController: controller,
                  onCompanySelected: (company) {
                    setState(() => selectedCompany = company);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'دووپاتکردنەوەی مامەڵە',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isSending ? 'تۆ خەریکە دەنێریت:' : 'تۆ خەریکە وەردەگریت:'),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 22, color: _textColor),
                children: [
                  TextSpan(
                    text: '${_amountController.text} $selectedCurrency',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  TextSpan(text: isSending ? ' بۆ' : ' لە'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selectedCompany!.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_receiverController.text.isNotEmpty ||
                _senderController.text.isNotEmpty)
              Text(
                isSending
                    ? 'وەرگر: ${_receiverController.text}'
                    : 'نێرەر: ${_senderController.text}',
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'هەڵوەشاندنەوه',
              style: TextStyle(color: _subtleTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeTransaction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('دووپاتکردنەوە'),
          ),
        ],
      ),
    );
  }
}

// --- Custom Widgets for UI enhancement ---

class TransactionCard extends StatelessWidget {
  final HawalaTransaction transaction;
  final Function(HawalaTransaction) onGenerateInvoice;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onGenerateInvoice,
  });

  static const _sentColor = Colors.green;
  static const _receivedColor = Colors.blue;
  static const _subtleTextColor = Color(0xFF666666);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,##0.00", "en_US");
    final color = transaction.isSent ? _sentColor : _receivedColor;
    final icon = transaction.isSent ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          transaction.isSent ? 'نێردرا بۆ:' : 'وەرگیرا لە:',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _subtleTextColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          transaction.companyName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if ((transaction.isSent &&
                            transaction.receiverName != "Me") ||
                        (!transaction.isSent && transaction.senderName != "Me"))
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          transaction.isSent
                              ? 'وەرگر: ${transaction.receiverName}'
                              : 'نێرەر: ${transaction.senderName}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _subtleTextColor,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('yyyy/MM/dd').format(transaction.date),
                          style: const TextStyle(
                            color: _subtleTextColor,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(transaction.amount)} ${transaction.currency}',
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.receipt, color: Colors.grey),
                        onPressed: () => onGenerateInvoice(transaction),
                        tooltip: 'View Invoice',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompanySelectionContent extends StatefulWidget {
  final List<Company> companies;
  final ScrollController scrollController;
  final ValueChanged<Company> onCompanySelected;

  const CompanySelectionContent({
    super.key,
    required this.companies,
    required this.scrollController,
    required this.onCompanySelected,
  });

  @override
  State<CompanySelectionContent> createState() =>
      _CompanySelectionContentState();
}

class _CompanySelectionContentState extends State<CompanySelectionContent> {
  final TextEditingController searchController = TextEditingController();
  List<Company> filteredCompanies = [];

  @override
  void initState() {
    super.initState();
    filteredCompanies = widget.companies;
    searchController.addListener(_filterCompanies);
  }

  void _filterCompanies() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredCompanies = widget.companies
          .where((c) => c.name.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'کۆمپانیا هەلبژێرە', // Select a Company
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText:
                      'گەڕان بە ناوی کۆمپانیا...', // Search by company name...
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: _HawalaScreenState._backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filteredCompanies.length,
            itemBuilder: (context, index) {
              final company = filteredCompanies[index];
              return ListTile(
                leading: const Icon(
                  Icons.business,
                  color: _HawalaScreenState._accentColor,
                ),
                title: Text(
                  company.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(company.companyType),
                onTap: () => widget.onCompanySelected(company),
              );
            },
          ),
        ),
      ],
    );
  }
}
