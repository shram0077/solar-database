import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:solar_database/models/company.dart';
import 'package:solar_database/screens/companyes/Edit_Company.dart';
import 'package:solar_database/screens/companyes/add_compines_screen.dart';

class ManageCompanies extends StatefulWidget {
  const ManageCompanies({super.key});

  @override
  State<ManageCompanies> createState() => _ManageCompaniesState();
}

class _ManageCompaniesState extends State<ManageCompanies> {
  List<Company> _companies = [];
  List<Company> _filteredCompanies = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedType = 'هەموو';
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  static const List<String> _companyTypes = [
    'هەموو',
    'کڕیار',
    'دابینکەر',
    'هەردووکیان',
  ];

  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final dbHelper = DatabaseHelper();
      final companyMaps = _selectedType == 'هەموو'
          ? await dbHelper.getAllCompanies()
          : await dbHelper.getCompaniesByType(_selectedType);

      if (mounted) {
        setState(() {
          _companies = companyMaps.map((map) => Company.fromMap(map)).toList();
          _applySearchAndSort();
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('هەڵە لە بارکردنی کۆمپانیاکان: $e', isError: true);
        setState(() {
          _isLoading = false;
          _filteredCompanies = [];
        });
      }
    }
  }

  void _applySearchAndSort() {
    if (!mounted) return;

    final searchLower = _searchQuery.toLowerCase();

    setState(() {
      _filteredCompanies = _companies.where((company) {
        final name = company.name.toLowerCase();
        final contact = company.contactPerson.toLowerCase() ?? '';
        final phone = company.phone.toLowerCase() ?? '';
        final email = company.email.toLowerCase() ?? '';
        final city = company.city.toLowerCase() ?? '';
        return name.contains(searchLower) ||
            contact.contains(searchLower) ||
            phone.contains(searchLower) ||
            email.contains(searchLower) ||
            city.contains(searchLower);
      }).toList();

      // Apply sorting
      _filteredCompanies.sort((a, b) {
        int compareResult;
        switch (_sortColumnIndex) {
          case 0: // Name
            compareResult = a.name.compareTo(b.name);
            break;
          case 1: // Type
            compareResult = a.companyType.compareTo(b.companyType);
            break;
          case 2: // Contact
            compareResult = (a.contactPerson ?? '').compareTo(
              b.contactPerson ?? '',
            );
            break;
          case 3: // Phone
            compareResult = (a.phone ?? '').compareTo(b.phone ?? '');
            break;
          case 4: // Email
            compareResult = (a.email ?? '').compareTo(b.email ?? '');
            break;
          case 5: // City
            compareResult = (a.city ?? '').compareTo(b.city ?? '');
            break;
          default:
            compareResult = a.name.compareTo(b.name);
        }
        return _sortAscending ? compareResult : -compareResult;
      });

      _isLoading = false;
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
          _currentPage = 0; // Reset to first page on new search
          _applySearchAndSort();
        });
      }
    });
  }

  void _onFilterChanged(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _currentPage = 0; // Reset to first page on filter change
    });
    _loadCompanies();
  }

  Future<void> _deleteCompany(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دڵنیابوونەوە لە سڕینەوە'),
        content: const Text('دڵنیای لە سڕینەوەی ئەم کۆمپانیایە؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('پاشگەزبوونەوە'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('سڕینەوە', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.deleteCompany(id);
      if (mounted) {
        _showSnackbar('کۆمپانیا بە سەرکەوتوویی سڕایەوە');
        setState(() {
          _companies.removeWhere((c) => c.id == id);
          _applySearchAndSort();
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('هەڵە لە سڕینەوەی کۆمپانیا: $e', isError: true);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _navigateToAddCompany() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddCompanies()),
    );

    if (result == true && mounted) {
      _loadCompanies();
    }
  }

  void _navigateToEditCompany(Company company) async {
    final updatedCompany = await Navigator.push<Company>(
      context,
      MaterialPageRoute(builder: (context) => EditCompany(company: company)),
    );

    if (updatedCompany != null && mounted) {
      setState(() {
        final index = _companies.indexWhere((c) => c.id == updatedCompany.id);
        if (index != -1) {
          _companies[index] = updatedCompany;
          _applySearchAndSort();
        }
      });
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applySearchAndSort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'پێگەی کۆمپانیاکان',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBackgroundColor,
        foregroundColor: kTextColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCompanies,
            tooltip: 'نوێکردنەوەی لیست',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddCompany,
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'کۆمپانیای نوێ',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildDataTable()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'گەڕان بۆ کۆمپانیاکان...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: kCardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<int>(
                icon: const Icon(Icons.table_rows),
                itemBuilder: (context) => [5, 10, 25, 50, 100]
                    .map(
                      (value) => PopupMenuItem<int>(
                        value: value,
                        child: Text('$value ڕیز لە هەر پەڕەیەکدا'),
                      ),
                    )
                    .toList(),
                onSelected: (value) {
                  setState(() {
                    _rowsPerPage = value;
                    _currentPage = 0;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Filter Chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _companyTypes.map((type) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(type),
                    selected: _selectedType == type,
                    onSelected: (_) => _onFilterChanged(type),
                    backgroundColor: kCardColor,
                    selectedColor: kPrimaryColor.withOpacity(0.8),
                    labelStyle: TextStyle(
                      color: _selectedType == type ? Colors.white : kTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _selectedType == type
                            ? kPrimaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredCompanies.isEmpty) {
      return _buildEmptyState();
    }

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage > _filteredCompanies.length
        ? _filteredCompanies.length
        : startIndex + _rowsPerPage;
    final paginatedCompanies = _filteredCompanies.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: SizedBox(
                width: 1400, // Fixed width to allow horizontal scrolling
                child: Theme(
                  data: Theme.of(context).copyWith(
                    cardTheme: CardThemeData(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                  ),
                  child: _buildDataTableContent(paginatedCompanies),
                ),
              ),
            ),
          ),
        ),
        _buildPaginationControls(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_center_outlined,
            size: 80,
            color: kTextSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'هیچ کۆمپانیایەک نەدۆزرایەوە'
                : 'هیچ ئەنجامێک نییە بۆ "$_searchQuery"',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'کۆمپانیایەکی نوێ زیاد بکە بە دوگمەی +.'
                : 'گەڕان یان فلێتەرەکەت دەستکاری بکە.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTableContent(List<Company> companies) {
    return DataTable(
      columns: [
        DataColumn(label: const Text('ناوی کۆمپانیا'), onSort: _onSort),
        DataColumn(label: const Text('جۆر'), onSort: _onSort),
        DataColumn(label: const Text('پەیوەندیکار'), onSort: _onSort),
        DataColumn(label: const Text('ژمارەی مۆبایل'), onSort: _onSort),
        DataColumn(label: const Text('ئیمێڵ'), onSort: _onSort),
        DataColumn(label: const Text('شار'), onSort: _onSort),
        DataColumn(label: const Text('کردارەکان')),
      ],
      rows: companies.map((company) {
        return DataRow(
          cells: [
            DataCell(
              Text(
                company.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => _showCompanyDetails(company),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTypeColor(company.companyType),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  company.companyType,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            DataCell(Text(company.contactPerson ?? '—')),
            DataCell(Text(company.phone ?? '—')),
            DataCell(Text(company.email ?? '—')),
            DataCell(Text(company.city ?? '—')),
            DataCell(
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _navigateToEditCompany(company),
                    tooltip: 'دەستکاری',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => _deleteCompany(company.id!),
                    tooltip: 'سڕینەوە',
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowHeight: 48,
      dataRowHeight: 48,
      horizontalMargin: 16,
      columnSpacing: 24,
      showCheckboxColumn: false,
      dividerThickness: 1,
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        color: kTextColor,
      ),
      dataTextStyle: TextStyle(color: kTextColor),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = (_filteredCompanies.length / _rowsPerPage)
        .ceil()
        .toInt();
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage >= totalPages - 1;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: isFirstPage
                ? null
                : () => setState(() => _currentPage = 0),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: isFirstPage
                ? null
                : () => setState(() => _currentPage--),
          ),
          Text(
            'پەڕە ${_currentPage + 1} لە ${totalPages == 0 ? 1 : totalPages}',
            style: TextStyle(color: kTextColor),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isLastPage ? null : () => setState(() => _currentPage++),
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: isLastPage
                ? null
                : () => setState(() => _currentPage = totalPages - 1),
          ),
          const SizedBox(width: 16),
          Text(
            '${_filteredCompanies.length} کۆمپانیا دۆزرایەوە',
            style: TextStyle(color: kTextSecondaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'client':
        return Colors.blue;
      case 'supplier':
        return Colors.green;
      case 'both':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showCompanyDetails(Company company) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(company.name),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('جۆری کۆمپانیا', company.companyType),
                _buildDetailItem('پەیوەندیکار', company.contactPerson),
                _buildDetailItem('ژمارەی مۆبایل', company.phone),
                _buildDetailItem('ئیمێڵ', company.email),
                _buildDetailItem('ناونیشان', company.address),
                _buildDetailItem('شار', company.city),
                _buildDetailItem('وڵات', company.country),
                _buildDetailItem('ژمارەی مالیات', company.taxNumber),
                _buildDetailItem(
                  'ژمارەی تۆمارکردن',
                  company.registrationNumber,
                ),
                if (company.notes.isNotEmpty ?? false) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'تێبینی:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(company.notes ?? ''),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEditCompany(company);
            },
            child: const Text('دەستکاری'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: kTextSecondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
