import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_database/helpers/Database_helper.dart';

class ShopExpenses extends StatefulWidget {
  const ShopExpenses({super.key});

  @override
  State<ShopExpenses> createState() => _ShopExpensesState();
}

class _ShopExpensesState extends State<ShopExpenses> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  DateTime? startDate;
  DateTime? endDate;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  Timer? _debounce;
  late StreamSubscription _dataChangeSubscription;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final iqdFormatter = NumberFormat("#,##0 دینار", "en_US");
  final dateFormat = DateFormat('yyyy-MM-dd');
  final monthFormat = DateFormat('MMM yyyy');

  double _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _dataChangeSubscription = _dbHelper.onDataChanged.listen((_) {
      _loadExpenses();
    });
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    searchController.dispose();
    _debounce?.cancel();
    _dataChangeSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    final expenses = await _dbHelper.getAllExpenses();
    setState(() {
      _expenses = expenses.map((e) {
        return {...e, 'date': DateTime.parse(e['date'])};
      }).toList();
      _filteredExpenses = List.from(_expenses);
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalExpenses = _filteredExpenses.fold(
      0,
      (sum, expense) => sum + (expense['amount'] as double),
    );
  }

  Future<void> _pickDate(
    BuildContext context, {
    bool isStartDate = false,
    bool isMainDate = false,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isMainDate
          ? selectedDate
          : isStartDate
          ? startDate ?? DateTime.now()
          : endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isMainDate) {
          selectedDate = picked;
        } else if (isStartDate) {
          startDate = picked;
          if (endDate != null && picked.isAfter(endDate!)) {
            endDate = null;
          }
        } else {
          endDate = picked;
          if (startDate != null && picked.isBefore(startDate!)) {
            startDate = null;
          }
        }
        if (!isMainDate) _filterExpenses();
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _dbHelper.insertExpense({
          "amount": double.tryParse(amountController.text) ?? 0,
          "notes": notesController.text,
          "date": selectedDate,
        });

        // Clear fields after successful save
        _formKey.currentState!.reset();
        amountController.clear();
        notesController.clear();
        setState(() {
          selectedDate = DateTime.now();
        });

        FocusScope.of(context).unfocus();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خەرجی بە سەرکەوتوویی زیادکرا!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('هەڵە لە هەڵگرتنی خەرجی: $e')));
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _filterExpenses();
    });
  }

  Future<void> _filterExpenses() async {
    final query = searchController.text.toLowerCase();

    List<Map<String, dynamic>> results = _expenses;

    // Apply text search filter if query exists
    if (query.isNotEmpty) {
      results = results.where((expense) {
        return expense['notes']?.toString().toLowerCase().contains(query) ??
            false ||
                expense['amount'].toString().contains(query) ||
                dateFormat.format(expense['date']).contains(query);
      }).toList();
    }

    // Apply date range filter if dates are selected
    if (startDate != null || endDate != null) {
      results = results.where((expense) {
        final expenseDate = expense['date'];
        if (startDate != null && endDate != null) {
          return !expenseDate.isBefore(startDate!) &&
              !expenseDate.isAfter(endDate!);
        } else if (startDate != null) {
          return !expenseDate.isBefore(startDate!);
        } else {
          return !expenseDate.isAfter(endDate!);
        }
      }).toList();
    }

    setState(() {
      _filteredExpenses = results;
      _calculateTotal();
    });
  }

  Future<void> _deleteExpense(int index) async {
    final expense = _filteredExpenses[index];
    try {
      await _dbHelper.deleteExpense(expense['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خەرجی بە سەرکەوتوویی سڕایەوە'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('هەڵە لە سڕینەوەی خەرجی: $e')));
    }
  }

  void _clearDateFilters() {
    setState(() {
      startDate = null;
      endDate = null;
      _filterExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: Colors.grey[300]!)),
                ),
                child: _buildAddExpensePanel(),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildFiltersPanel(),
                      Expanded(child: _buildExpensesList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          _buildAddExpensePanel(),
          _buildFiltersPanel(),
          _buildExpensesList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen =
            constraints.maxWidth > 800; // widened breakpoint
        final bool isVerySmallScreen = constraints.maxWidth < 350;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isLargeScreen ? 20.0 : 12.0,
            vertical: 12.0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isLargeScreen
              ? _buildDesktopHeader()
              : _buildMobileHeader(isVerySmallScreen),
        );
      },
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'بەڕێوەبردنی خەرجی',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Wrap(
            spacing: 20,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            children: [
              _buildStatCard(
                'کۆی گشتی خەرجی',
                iqdFormatter.format(_totalExpenses),
                Icons.account_balance_wallet,
                Colors.red[400]!,
              ),
              _buildStatCard(
                'کۆی تۆمارەکان',
                _filteredExpenses.length.toString(),
                Icons.receipt_long,
                Colors.green[400]!,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader(bool isVerySmallScreen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'بەڕێوەبردنی خەرجی',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                'کۆی خەرجی',
                iqdFormatter.format(_totalExpenses),
                Icons.account_balance_wallet,
                Colors.red[400]!,
                isSmall: true,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'کۆی تۆمار',
                _filteredExpenses.length.toString(),
                Icons.receipt_long,
                Colors.green[400]!,
                isSmall: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isSmall = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: isSmall ? 20 : 24),
          SizedBox(height: isSmall ? 4 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmall ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: isSmall ? 2 : 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmall ? 14 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddExpensePanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "خەرجی نوێ زیادبکە",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: "بڕ",
                suffixText: "دینار",
                prefixIcon: const Icon(Icons.monetization_on, size: 24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'تکایە بڕێک بنووسە';
                }
                if (double.tryParse(value) == null) {
                  return 'تکایە ژمارەیەکی دروست بنووسە';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: notesController,
              maxLines: 3,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: "پێناسە / تێبینی",
                prefixIcon: const Icon(Icons.note_alt, size: 24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "بەروار",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(selectedDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _pickDate(context, isMainDate: true),
                    icon: Icon(Icons.calendar_today, color: Colors.blue[600]),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveExpense,
                icon: const Icon(Icons.add, size: 24),
                label: const Text(
                  "خەرجی زیادبکە",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "گەڕان و فلتر",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: "بە بڕ، تێبینی، یان بەروار بگەڕێ...",
              prefixIcon: const Icon(Icons.search, size: 24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        _filterExpenses();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateFilterButton(
                  label: 'لە بەرواری',
                  date: startDate,
                  isStartDate: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateFilterButton(
                  label: 'بۆ بەرواری',
                  date: endDate,
                  isStartDate: false,
                ),
              ),
              const SizedBox(width: 16),
              if (startDate != null || endDate != null)
                ElevatedButton.icon(
                  onPressed: _clearDateFilters,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('پاککردنەوە'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterButton({
    required String label,
    required DateTime? date,
    required bool isStartDate,
  }) {
    return OutlinedButton(
      onPressed: () => _pickDate(context, isStartDate: isStartDate),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        side: BorderSide(
          color: date != null ? Colors.blue[600]! : Colors.grey[300]!,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date != null ? dateFormat.format(date) : 'بەروار هەڵبژێرە',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: date != null ? Colors.blue[700] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList() {
    if (_filteredExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchController.text.isEmpty &&
                      (startDate == null && endDate == null)
                  ? "هیچ خەرجیەک تۆمارنەکراوە"
                  : "هیچ خەرجیەک نەدۆزرایەوە",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "یەکەم خەرجی زیادبکە بە فۆرمی لای چەپ",
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredExpenses.length,
      itemBuilder: (context, index) {
        final expense = _filteredExpenses[index];
        return Dismissible(
          key: Key(expense['id'].toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red[400],
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'سڕینەوە',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("سڕینەوەی خەرجی"),
                content: const Text("دڵنیای لە سڕینەوەی ئەم خەرجیە؟"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("پاشگەزبوونەوە"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("سڕینەوە"),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) => _deleteExpense(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.payment, color: Colors.blue[600], size: 24),
              ),
              title: Text(
                iqdFormatter.format(expense['amount']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    expense['notes']?.isEmpty ?? true
                        ? 'بێ پێناسە'
                        : expense['notes'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(expense['date']),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20),
                        SizedBox(width: 12),
                        Text('وردەکاری'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('سڕینەوە', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'details') {
                    _showExpenseDetails(context, expense);
                  } else if (value == 'delete') {
                    final confirmed = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("سڕینەوەی خەرجی"),
                        content: const Text("دڵنیای لە سڕینەوەی ئەم خەرجیە؟"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("پاشگەزبوونەوە"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text("سڕینەوە"),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _dbHelper.deleteExpense(expense['id']);
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExpenseDetails(BuildContext context, Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('وردەکاری خەرجی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('بڕ', iqdFormatter.format(expense['amount'])),
            _buildDetailRow('بەروار', dateFormat.format(expense['date'])),
            if (expense['notes']?.isNotEmpty ?? false)
              _buildDetailRow('تێبینی', expense['notes']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
