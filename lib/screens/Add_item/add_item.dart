import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  // Using a map for easy access and disposal, now with retail prices
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'buyingPrice': TextEditingController(),
    'sellingPrice': TextEditingController(),
    'buyingPriceRetail': TextEditingController(), // ADDED
    'sellingPriceRetail': TextEditingController(), // ADDED
    'quantity': TextEditingController(),
    'category': TextEditingController(),
    'brand': TextEditingController(),
    'model': TextEditingController(),
    'power': TextEditingController(),
    'voltage': TextEditingController(),
    'origin': TextEditingController(),
    'warranty': TextEditingController(),
    'supplier': TextEditingController(),
    'purchaseDate': TextEditingController(),
    'notes': TextEditingController(),
    'barcode': TextEditingController(),
  };

  bool _isCurrencyUSD = true;
  bool _ispaidCash = false;
  bool _isLoading = false;

  // Focus nodes for all numeric fields
  final _quantityFocusNode = FocusNode();
  final _buyingPriceFocusNode = FocusNode();
  final _sellingPriceFocusNode = FocusNode();
  final _buyingPriceRetailFocusNode = FocusNode(); // ADDED
  final _sellingPriceRetailFocusNode = FocusNode(); // ADDED

  // --- Enhanced Data for Dropdown Suggestions ---
  List<String> _categoryOptions = [];
  List<String> _brandOptions = [];
  List<String> _brandModels = [];

  Future<void> _loadItemData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _categoryOptions = List<String>.from(
        json.decode(prefs.getString('item_categories') ?? '[]'),
      );
      _brandOptions = List<String>.from(
        json.decode(prefs.getString('item_brands') ?? '[]'),
      );
      _brandModels = List<String>.from(
        json.decode(prefs.getString('item_models') ?? '[]'),
      );

      // Initialize with empty if null
      _categoryOptions = _categoryOptions.where((e) => e.isNotEmpty).toList();
      _brandOptions = _brandOptions.where((e) => e.isNotEmpty).toList();
      _brandModels = _brandModels.where((e) => e.isNotEmpty).toList();
    });
  }

  @override
  void initState() {
    super.initState();

    _loadItemData().then((_) {
      // Force rebuild after data loads
      if (mounted) setState(() {});
    });
    // Add listeners for numeric formatting
    _controllers['quantity']?.addListener(_formatQuantityInput);
    _controllers['buyingPrice']?.addListener(_formatBuyingPriceInput);
    _controllers['sellingPrice']?.addListener(_formatSellingPriceInput);
    _controllers['buyingPriceRetail']?.addListener(
      _formatBuyingPriceRetailInput,
    ); // ADDED
    _controllers['sellingPriceRetail']?.addListener(
      _formatSellingPriceRetailInput,
    ); // ADDED
    _controllers['brand']?.addListener(_updateModelSuggestions);
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _quantityFocusNode.dispose();
    _buyingPriceFocusNode.dispose();
    _sellingPriceFocusNode.dispose();
    _buyingPriceRetailFocusNode.dispose(); // ADDED
    _sellingPriceRetailFocusNode.dispose(); // ADDED
    super.dispose();
  }

  // --- Input Formatting Methods ---
  void _formatNumericInput(TextEditingController? controller) {
    if (controller == null) return;
    final text = controller.text;
    if (text.isEmpty) return;
    final cleanText = text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleanText != text) {
      controller.value = TextEditingValue(
        text: cleanText,
        selection: TextSelection.collapsed(offset: cleanText.length),
      );
    }
  }

  void _formatQuantityInput() => _formatNumericInput(_controllers['quantity']);
  void _formatBuyingPriceInput() =>
      _formatNumericInput(_controllers['buyingPrice']);
  void _formatSellingPriceInput() =>
      _formatNumericInput(_controllers['sellingPrice']);
  void _formatBuyingPriceRetailInput() =>
      _formatNumericInput(_controllers['buyingPriceRetail']);
  void _formatSellingPriceRetailInput() =>
      _formatNumericInput(_controllers['sellingPriceRetail']);
  void _updateModelSuggestions() => setState(() {});

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submitItem() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      _showFeedbackSnackbar(
        'تکایە هەموو خانە پێویستەکان بە ڕێکی پڕ بکەرەوە.',
        isError: true,
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final buyingPrice =
          double.tryParse(_controllers['buyingPrice']!.text.trim()) ?? 0.0;
      final sellingPrice =
          double.tryParse(_controllers['sellingPrice']!.text.trim()) ?? 0.0;
      final buyingPriceRetail =
          double.tryParse(_controllers['buyingPriceRetail']!.text.trim()) ??
          0.0; // ADDED
      final sellingPriceRetail =
          double.tryParse(_controllers['sellingPriceRetail']!.text.trim()) ??
          0.0; // ADDED
      final quantity = int.tryParse(_controllers['quantity']!.text.trim()) ?? 0;

      String? purchaseDate;
      if (_controllers['purchaseDate']!.text.trim().isNotEmpty) {
        purchaseDate = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.parse(_controllers['purchaseDate']!.text.trim()));
      }

      final itemData = {
        'item_name': _controllers['name']!.text.trim(),
        'category': _controllers['category']!.text.trim(),
        'buying_price': buyingPrice,
        'selling_price': sellingPrice,
        'buying_price_retail': buyingPriceRetail, // ADDED FOR DB
        'selling_price_retail': sellingPriceRetail, // ADDED FOR DB
        'quantity': quantity,
        'supplier': _controllers['supplier']!.text.trim(),
        'purchase_date': purchaseDate,
        'brand': _controllers['brand']!.text.trim(),
        'model': _controllers['model']!.text.trim(),
        'power': _controllers['power']!.text.trim(),
        'voltage': _controllers['voltage']!.text.trim(),
        'origin_country': _controllers['origin']!.text.trim(),
        'warranty': _controllers['warranty']!.text.trim(),
        'notes': _controllers['notes']!.text.trim(),
        'is_currency_usd': _isCurrencyUSD ? 1 : 0,
        'isPaidCash': _ispaidCash ? 1 : 0,
        'barcode': _controllers['barcode']!.text.trim(),
      };

      debugPrint('Attempting to insert: $itemData');

      final dbHelper = DatabaseHelper();
      final id = await dbHelper.insertItem(itemData);

      _showFeedbackSnackbar(
        'ID: $id کاڵاکە بە سەرکەوتوویی تۆمار کرا.',
        isError: false,
      );
      _formKey.currentState?.reset();
      for (var controller in _controllers.values) {
        controller.clear();
      }
    } catch (e, stackTrace) {
      debugPrint('Error: $e\nStack trace: $stackTrace');
      _showFeedbackSnackbar(
        'هەڵەیەکی چاوەڕوان نەکراو ڕوویدا: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final initialDate =
        DateTime.tryParse(_controllers['purchaseDate']!.text) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              onSurface: kTextColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      _controllers['purchaseDate']!.text = DateFormat(
        'yyyy-MM-dd',
      ).format(pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Brands: $_brandOptions');
    debugPrint('Models: $_brandModels');
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'زیاد کردنی کاڵا بۆ ناو کۆگا',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kCardColor,
        foregroundColor: kTextColor,
        elevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1400,
          ), // Increased max width for 3 columns
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Use a more compact 3-column layout on wider screens
                  final isWideScreen = constraints.maxWidth > 1100;
                  return isWideScreen
                      ? _buildWideLayout()
                      : _buildNarrowLayout();
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildSubmitBar(),
    );
  }

  /// **Three-column layout for wide screens**
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- COLUMN 1: BASIC INFO & SPECS ---
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildSection(
                title: 'زانیارییە سەرەکییەکان',
                icon: Icons.article,
                children: [
                  _buildTextField(
                    key: 'name',
                    label: 'ناوی کاڵا*',
                    icon: Icons.label_important_outline,
                    validator: (val) => _validateRequired(val, 'ناوی کاڵا'),
                  ),
                  _buildDropdownField(
                    key: 'category',
                    label: 'هاوپۆل*',
                    icon: Icons.category_outlined,
                    items: _categoryOptions,
                    validator: (val) => _validateRequired(val, 'هاوپۆل'),
                  ),
                  _buildTextField(
                    key: 'quantity',
                    label: 'عدد*',
                    icon: Icons.inventory_2_outlined,
                    isNumeric: true,
                    focusNode: _quantityFocusNode,
                    validator: (val) => _validateNumber(val, 'عدد'),
                  ),
                  _buildTextField(
                    key: 'barcode',
                    label: 'بارکۆد',
                    icon: Icons.qr_code_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'زانیاری کڕین',
                icon: Icons.store_mall_directory_outlined,
                children: [
                  _buildTextField(
                    key: 'supplier',
                    label: 'دابینکەر',
                    icon: Icons.person_search_outlined,
                  ),
                  _buildDateField(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // --- COLUMN 2: PRICING ---
        Expanded(
          flex: 2,
          child: _buildSection(
            title: 'نرخەکان',
            icon: Icons.price_change_outlined,
            children: [
              Text(
                'نرخی کۆ (جملە)',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
              const SizedBox(height: 8),
              _buildTextField(
                key: 'buyingPrice',
                label: 'نرخی کڕینی کۆ*',
                icon: Icons.shopping_bag_outlined,
                isNumeric: true,
                focusNode: _buyingPriceFocusNode,
                validator: (val) => _validateNumber(val, 'نرخی کڕینی کۆ'),
              ),
              _buildTextField(
                key: 'sellingPrice',
                label: 'نرخی فرۆشتنی کۆ*',
                icon: Icons.price_check_outlined,
                isNumeric: true,
                focusNode: _sellingPriceFocusNode,
                validator: (val) => _validateNumber(val, 'نرخی فرۆشتنی کۆ'),
              ),
              const Divider(height: 32),
              Text(
                'نرخی تاک (مفرد)',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
              const SizedBox(height: 8),
              _buildTextField(
                key: 'buyingPriceRetail',
                label: 'نرخی کڕینی تاک*',
                icon: Icons.shopping_basket_outlined,
                isNumeric: true,
                focusNode: _buyingPriceRetailFocusNode,
                validator: (val) => _validateNumber(val, 'نرخی کڕینی تاک'),
              ),
              _buildTextField(
                key: 'sellingPriceRetail',
                label: 'نرخی فرۆشتنی تاک*',
                icon: Icons.point_of_sale_outlined,
                isNumeric: true,
                focusNode: _sellingPriceRetailFocusNode,
                validator: (val) => _validateNumber(val, 'نرخی فرۆشتنی تاک'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // --- COLUMN 3: SPECS & NOTES ---
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildSection(
                title: 'تایبەتمەندییەکان',
                icon: Icons.build_circle_outlined,
                children: [
                  _buildDropdownField(
                    key: 'brand',
                    label: 'براند',
                    icon: Icons.branding_watermark_outlined,
                    items: _brandOptions,
                  ),
                  _buildDropdownField(
                    key: 'model',
                    label: 'مۆدێل',
                    icon: Icons.devices_other_outlined,
                    items: _brandModels,
                  ),
                  _buildTextField(
                    key: 'power',
                    label: 'ووزە (وەک: 550W)',
                    icon: Icons.power_outlined,
                  ),
                  _buildTextField(
                    key: 'voltage',
                    label: 'فۆڵت (وەک: 48V)',
                    icon: Icons.flash_on_outlined,
                  ),
                  _buildTextField(
                    key: 'origin',
                    label: 'وڵاتی بەرهەمهێنەر',
                    icon: Icons.flag_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'تێبینییە زیاترەکان',
                icon: Icons.note_alt_outlined,
                children: [
                  _buildTextField(
                    key: 'notes',
                    label: 'تێبینییەکان',
                    maxLines: 6,
                  ), // Taller notes field
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// **Single-column layout for narrow screens**
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildSection(
          title: 'زانیارییە سەرەکییەکان',
          icon: Icons.article,
          children: [
            _buildTextField(
              key: 'name',
              label: 'ناوی کاڵا*',
              icon: Icons.label_important_outline,
              validator: (val) => _validateRequired(val, 'ناوی کاڵا'),
            ),
            _buildDropdownField(
              key: 'category',
              label: 'هاوپۆل*',
              icon: Icons.category_outlined,
              items: _categoryOptions,
              validator: (val) => _validateRequired(val, 'هاوپۆل'),
            ),
            _buildTextField(
              key: 'quantity',
              label: 'ژمارە*',
              icon: Icons.inventory_2_outlined,
              isNumeric: true,
              focusNode: _quantityFocusNode,
              validator: (val) => _validateNumber(val, 'ژمارە'),
            ),
            _buildTextField(
              key: 'barcode',
              label: 'بارکۆد*',
              icon: Icons.qr_code_outlined,
              validator: (val) => _validateRequired(val, 'بارکۆد'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: 'نرخ و کڕین',
          icon: Icons.shopping_cart_checkout,
          children: [
            _buildTextField(
              key: 'buyingPrice',
              label: 'نرخی کڕینی کۆ*',
              icon: Icons.shopping_bag_outlined,
              isNumeric: true,
              focusNode: _buyingPriceFocusNode,
              validator: (val) => _validateNumber(val, 'نرخی کڕینی کۆ'),
            ),
            _buildTextField(
              key: 'sellingPrice',
              label: 'نرخی فرۆشتنی کۆ*',
              icon: Icons.price_check_outlined,
              isNumeric: true,
              focusNode: _sellingPriceFocusNode,
              validator: (val) => _validateNumber(val, 'نرخی فرۆشتنی کۆ'),
            ),
            const Divider(),
            _buildTextField(
              key: 'buyingPriceRetail',
              label: 'نرخی کڕینی تاک*',
              icon: Icons.shopping_basket_outlined,
              isNumeric: true,
              focusNode: _buyingPriceRetailFocusNode,
              validator: (val) => _validateNumber(val, 'نرخی کڕینی تاک'),
            ),
            _buildTextField(
              key: 'sellingPriceRetail',
              label: 'نرخی فرۆشتنی تاک*',
              icon: Icons.point_of_sale_outlined,
              isNumeric: true,
              focusNode: _sellingPriceRetailFocusNode,
              validator: (val) => _validateNumber(val, 'نرخی فرۆشتنی تاک'),
            ),
            const Divider(),
            _buildTextField(
              key: 'supplier',
              label: 'دابینکەر',
              icon: Icons.store_mall_directory_outlined,
            ),
            _buildDateField(),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: 'تایبەتمەندییەکان',
          icon: Icons.build_circle_outlined,
          children: [
            _buildDropdownField(
              key: 'brand',
              label: 'براند',
              icon: Icons.branding_watermark_outlined,
              items: _brandOptions,
            ),
            _buildDropdownField(
              key: 'model',
              label: 'مۆدێل',
              icon: Icons.devices_other_outlined,
              items: _brandModels,
            ),
            _buildTextField(
              key: 'power',
              label: 'ووزە (وەک: 550W)',
              icon: Icons.power_outlined,
            ),
            _buildTextField(
              key: 'voltage',
              label: 'فۆڵت (وەک: 48V)',
              icon: Icons.flash_on_outlined,
            ),
            _buildTextField(
              key: 'origin',
              label: 'وڵاتی بەرهەمهێنەر',
              icon: Icons.flag_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: 'تێبینییە زیاترەکان',
          icon: Icons.note_alt_outlined,
          children: [
            _buildTextField(key: 'notes', label: 'تێبینییەکان', maxLines: 4),
          ],
        ),
      ],
    );
  }

  // List<String> _getModelSuggestions() {
  //   final selectedBrand = _controllers['brand']?.text.trim() ?? '';

  //   if (selectedBrand.isEmpty)
  //     return _brandModels; // Return all models if no brand selected

  //   // Filter models that start with the brand name or contain it
  //   final brandLower = selectedBrand.toLowerCase();
  //   return _brandModels.where((model) {
  //     final modelLower = model.toLowerCase();
  //     return modelLower.startsWith(brandLower) ||
  //         modelLower.contains(brandLower);
  //   }).toList();
  // }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    if (double.tryParse(value) == null) return 'Please enter a valid number';
    if (double.parse(value) <= 0) return '$fieldName must be greater than zero';
    return null;
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: kCardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kPrimaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String key,
    required String label,
    IconData? icon,
    bool isNumeric = false,
    int maxLines = 1,
    FocusNode? focusNode,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: _controllers[key],
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: GoogleFonts.inter(color: kTextColor),
      decoration: _inputDecoration(label, icon),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String key,
    required String label,
    required IconData icon,
    required List<String> items,
    String? Function(String?)? validator,
  }) {
    debugPrint(
      'Building dropdown for $key with value: ${_controllers[key]!.text}',
    );
    debugPrint('Available items: $items');
    return DropdownButtonFormField<String>(
      value: _controllers[key]!.text.isEmpty ? null : _controllers[key]!.text,
      onChanged: (String? newValue) {
        setState(() {
          debugPrint('Selected $newValue for $key');

          _controllers[key]!.text = newValue ?? '';
          if (key == 'brand') {
            // When brand changes, clear the model selection
            _controllers['model']!.clear();
          }
        });
      },
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            style: GoogleFonts.inter(color: kTextColor),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      decoration: _inputDecoration(label, icon),
      validator: validator,
      dropdownColor: kCardColor,
      icon: const Icon(Icons.arrow_drop_down, color: kTextSecondaryColor),
      style: GoogleFonts.inter(color: kTextColor),
      borderRadius: BorderRadius.circular(12),
      isExpanded: true,
      menuMaxHeight: 300, // Add this to prevent overflow
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _controllers['purchaseDate'],
      readOnly: true,
      onTap: _pickDate,
      style: GoogleFonts.inter(color: kTextColor),
      decoration: _inputDecoration(
        'بەرواری کڕین',
        Icons.calendar_today_outlined,
      ),
      validator: (val) => _validateRequired(val, 'Purchase date'),
    );
  }

  InputDecoration _inputDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      hintText: label.endsWith('*') ? null : 'Optional',
      labelStyle: GoogleFonts.inter(color: kTextSecondaryColor),
      hintStyle: GoogleFonts.inter(color: kTextSecondaryColor.withOpacity(0.6)),
      prefixIcon: icon != null
          ? Icon(icon, color: kTextSecondaryColor, size: 20)
          : null,
      filled: true,
      fillColor: kBackgroundColor.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: kCardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'جۆری دراو دۆلارە؟',
                  style: GoogleFonts.inter(color: kTextColor),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isCurrencyUSD,
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _isCurrencyUSD = value),
                  activeColor: kPrimaryColor,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ئایە پارە بە کاش دەدرێت؟',
                  style: GoogleFonts.inter(color: kTextColor),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _ispaidCash,
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _ispaidCash = value),
                  activeColor: kPrimaryColor,
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitItem,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: Text(_isLoading ? 'زیاد دەکرێت.....' : 'زیاد کردنی کاڵا'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
