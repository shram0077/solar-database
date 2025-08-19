import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';

class EditItemPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const EditItemPage({super.key, required this.item});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();
  final bool _isLoading = false;
  bool _isSaving = false;

  // Form controllers
  late TextEditingController _modelController;
  late TextEditingController _brandController;
  late TextEditingController _categoryController;
  late TextEditingController _quantityController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _powerController;
  late TextEditingController _voltageController;
  late TextEditingController _warrantyController;
  late TextEditingController _supplierController;
  late TextEditingController _notesController;
  late TextEditingController _purchaseDateController;
  late TextEditingController _barcodeController;
  late TextEditingController _buyingPriceRetailController;
  late TextEditingController _sellingPriceRetailController;
  // Form state
  bool _isCurrencyUSD = true;
  bool _isPaidCash = true; // Default to cash payment
  DateTime? _purchaseDate;

  // Available categories for suggestions
  final List<String> _categorySuggestions = [
    'پانێلی سۆلار',
    'ئینڤێرتەر',
    'باتری',
    'کۆنتڕۆڵەری پەڕین',
    'کیتەکانی دامەزراندن',
    'کەیبڵ',
    'ئامرازە پەیوەندیدارەکان',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with item data
    _modelController = TextEditingController(
      text: widget.item['model']?.toString() ?? '',
    );
    _brandController = TextEditingController(
      text: widget.item['brand']?.toString() ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.item['category']?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.item['quantity']?.toString() ?? '0',
    );
    _buyingPriceController = TextEditingController(
      text: widget.item['buying_price']?.toString() ?? '',
    );
    _sellingPriceController = TextEditingController(
      text: widget.item['selling_price']?.toString() ?? '',
    );
    _buyingPriceRetailController = TextEditingController(
      text:
          widget.item['buying_price_retail']?.toString() ??
          (widget.item['quantity'] != null &&
                  widget.item['buying_price'] != null &&
                  widget.item['quantity'] > 0
              ? (widget.item['buying_price'] / widget.item['quantity'])
                    .toStringAsFixed(2)
              : ''),
    );
    _sellingPriceRetailController = TextEditingController(
      text:
          widget.item['selling_price_retail']?.toString() ??
          (widget.item['quantity'] != null &&
                  widget.item['selling_price'] != null &&
                  widget.item['quantity'] > 0
              ? (widget.item['selling_price'] / widget.item['quantity'])
                    .toStringAsFixed(2)
              : ''),
    );
    _powerController = TextEditingController(
      text: widget.item['power']?.toString() ?? '',
    );
    _voltageController = TextEditingController(
      text: widget.item['voltage']?.toString() ?? '',
    );
    _warrantyController = TextEditingController(
      text: widget.item['warranty']?.toString() ?? '',
    );
    _supplierController = TextEditingController(
      text: widget.item['supplier']?.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.item['notes']?.toString() ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.item['barcode']?.toString() ?? '',
    );
    _purchaseDateController = TextEditingController(
      text:
          widget.item['purchase_date'] != null &&
              widget.item['purchase_date'].toString().isNotEmpty
          ? DateFormat.yMd().format(
              DateTime.parse(widget.item['purchase_date'].toString()),
            )
          : '',
    );

    // Initialize payment status
    _isCurrencyUSD = (widget.item['is_currency_usd'] is int)
        ? widget.item['is_currency_usd'] == 1
        : (widget.item['is_currency_usd'] ?? true);
    _isPaidCash = (widget.item['isPaidCash'] is int)
        ? widget.item['isPaidCash'] == 1
        : (widget.item['isPaidCash'] ?? true);
  }

  @override
  void dispose() {
    _modelController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _powerController.dispose();
    _voltageController.dispose();
    _warrantyController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _purchaseDateController.dispose();
    _barcodeController.dispose();
    _buyingPriceRetailController.dispose();
    _sellingPriceRetailController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
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
    if (picked != null && picked != _purchaseDate) {
      setState(() {
        _purchaseDate = picked;
        _purchaseDateController.text = DateFormat.yMd().format(picked);
      });
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedItem = {
        ...widget.item,
        'model': _modelController.text,
        'brand': _brandController.text,
        'category': _categoryController.text,
        'barcode': _barcodeController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'buying_price': double.tryParse(_buyingPriceController.text) ?? 0.0,
        'selling_price': double.tryParse(_sellingPriceController.text) ?? 0.0,
        'buying_price_retail':
            double.tryParse(_buyingPriceRetailController.text) ?? 0.0,
        'selling_price_retail':
            double.tryParse(_sellingPriceRetailController.text) ?? 0.0,
        'power': _powerController.text.isNotEmpty
            ? double.tryParse(_powerController.text)
            : null,
        'voltage': _voltageController.text.isNotEmpty
            ? double.tryParse(_voltageController.text)
            : null,
        'warranty': _warrantyController.text,
        'supplier': _supplierController.text,
        'notes': _notesController.text,
        'updated_at': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        'purchase_date': _purchaseDate != null
            ? DateFormat('yyyy-MM-dd').format(_purchaseDate!)
            : null,

        'is_currency_usd': _isCurrencyUSD ? 1 : 0,
        'isPaidCash': _isPaidCash ? 1 : 0,
      };

      await _dbHelper.updateItem(updatedItem);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هەڵە لە هەڵگرتنی بەرھەم: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isRequired = true,
    int? maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label${isRequired ? ' *' : ''}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            decoration: InputDecoration(
              filled: true,
              fillColor: kCardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              errorStyle: GoogleFonts.inter(fontSize: 12),
            ),
            style: GoogleFonts.inter(color: kTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'دراو',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    'دۆلار',
                    style: GoogleFonts.inter(
                      color: _isCurrencyUSD ? Colors.white : kPrimaryColor,
                    ),
                  ),
                  selected: _isCurrencyUSD,
                  onSelected: (selected) {
                    setState(() => _isCurrencyUSD = true);
                  },
                  selectedColor: kPrimaryColor,
                  backgroundColor: kPrimaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    'دینار',
                    style: GoogleFonts.inter(
                      color: !_isCurrencyUSD ? Colors.white : kPrimaryColor,
                    ),
                  ),
                  selected: !_isCurrencyUSD,
                  onSelected: (selected) {
                    setState(() => _isCurrencyUSD = false);
                  },
                  selectedColor: kPrimaryColor,
                  backgroundColor: kPrimaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جۆری پارەدان',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    'کاش',
                    style: GoogleFonts.inter(
                      color: _isPaidCash ? Colors.white : Colors.green,
                    ),
                  ),
                  selected: _isPaidCash,
                  onSelected: (selected) {
                    setState(() => _isPaidCash = true);
                  },
                  selectedColor: Colors.green,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    'قەرز',
                    style: GoogleFonts.inter(
                      color: !_isPaidCash ? Colors.white : Colors.blue,
                    ),
                  ),
                  selected: !_isPaidCash,
                  onSelected: (selected) {
                    setState(() => _isPaidCash = false);
                  },
                  selectedColor: Colors.blue,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'دەستکاریکردنی بەرھەم',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: kTextColor,
          ),
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPrimaryColor,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save, color: kPrimaryColor),
              onPressed: _saveItem,
              tooltip: 'پاشەکەوتکردنی گۆڕانکارییەکان',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    Text(
                      'زانیارییە سەرەکییەکان',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      label: 'بارکۆد',
                      controller: _barcodeController,
                      prefixIcon: const Icon(
                        Icons.qr_code,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'ناوی مۆدێل',
                      controller: _modelController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'تکایە ناوی مۆدێل بنووسە';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(
                        Icons.sell_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'براند',
                      controller: _brandController,
                      prefixIcon: const Icon(
                        Icons.branding_watermark_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'پۆل',
                      controller: _categoryController,
                      prefixIcon: const Icon(
                        Icons.category_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: kTextSecondaryColor,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return ListView(
                                children: _categorySuggestions
                                    .map(
                                      (category) => ListTile(
                                        title: Text(category),
                                        onTap: () {
                                          setState(() {
                                            _categoryController.text = category;
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    _buildFormField(
                      label: 'ژمارە',
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'تکایە ژمارە بنووسە';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Pricing Section
                    Text(
                      'نرخەکان',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCurrencyToggle(),
                    _buildPaymentTypeToggle(),
                    _buildFormField(
                      label: 'نرخی کڕین (کۆ)',
                      controller: _buyingPriceController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'تکایە نرخی کڕین بنووسە';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(
                        Icons.attach_money_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'نرخی کڕین (تاک)',
                      controller: _buyingPriceRetailController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'تکایە نرخی تاکە کڕین بنووسە';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(
                        Icons.money_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'نرخی فرۆشتن (کۆ)',
                      controller: _sellingPriceController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'تکایە نرخی فرۆشتن بنووسە';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(
                        Icons.sell_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'نرخی فرۆشتن (تاک)',
                      controller: _sellingPriceRetailController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'تکایە نرخی تاکە فرۆشتن بنووسە';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(
                        Icons.price_check_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),

                    // Specifications Section
                    Text(
                      'تایبەتمەندییەکان',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      label: 'هێز (واط)',
                      controller: _powerController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      prefixIcon: const Icon(
                        Icons.flash_on_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'ڤۆڵتیە (ڤۆڵت)',
                      controller: _voltageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      prefixIcon: const Icon(
                        Icons.electrical_services_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Additional Information Section
                    Text(
                      'زانیارییە زیاترەکان',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      label: 'کاتی ضمانەت',
                      controller: _warrantyController,
                      prefixIcon: const Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'دابینکەر',
                      controller: _supplierController,
                      prefixIcon: const Icon(
                        Icons.store_mall_directory_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'بەرواری کڕین',
                      controller: _purchaseDateController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      prefixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    _buildFormField(
                      label: 'تێبینییەکان',
                      controller: _notesController,
                      maxLines: 3,
                      isRequired: false,
                      prefixIcon: const Icon(
                        Icons.notes_outlined,
                        size: 20,
                        color: kTextSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'پاشەکەوتکردنی گۆڕانکارییەکان',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
