import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:solar_database/models/company.dart';

class AddCompanies extends StatefulWidget {
  final Company? company;

  const AddCompanies({super.key, this.company});

  @override
  State<AddCompanies> createState() => _AddCompaniesState();
}

class _AddCompaniesState extends State<AddCompanies> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controller-کان
  late final TextEditingController _nameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _taxNumberController;
  late final TextEditingController _regNumberController;
  late final TextEditingController _notesController;

  String _companyType = 'کڕیار';
  static const List<String> _companyTypes = ['کڕیار', 'دابینکەر', 'هەردووکیان'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _contactPersonController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _countryController = TextEditingController();
    _taxNumberController = TextEditingController();
    _regNumberController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _taxNumberController.dispose();
    _regNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Company _createCompanyFromForm() {
    return Company(
      name: _nameController.text.trim(),
      companyType: _companyType,
      contactPerson: _contactPersonController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      taxNumber: _taxNumberController.text.trim(),
      registrationNumber: _regNumberController.text.trim(),
      notes: _notesController.text.trim(),
    );
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _contactPersonController.clear();
    _phoneController.clear();
    _emailController.clear();
    _addressController.clear();
    _cityController.clear();
    _countryController.clear();
    _taxNumberController.clear();
    _regNumberController.clear();
    _notesController.clear();
    setState(() => _companyType = 'کڕیار');
  }

  Future<void> _submitCompany() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showFeedbackSnackbar(
        'تکایە هەڵەکان چاک بکەرەوە پێش پاشەکەوتکردن',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    final company = _createCompanyFromForm();

    try {
      final dbHelper = DatabaseHelper();
      final id = await dbHelper.insertCompany(company.toMap());

      _showFeedbackSnackbar('کۆمپانیا بە سەرکەوتوویی پاشەکەوتکرا (ID: $id)');
      _clearForm();
    } catch (e) {
      _showFeedbackSnackbar(
        'هەڵە لە پاشەکەوتکردنی کۆمپانیا: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- PDF Generation Logic ---

  // --- Flutter UI Widgets ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'کۆمپانیای نوێ زیاد بکە',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kCardColor,
        foregroundColor: kTextColor,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionCard(
                    title: 'زانیارییە سەرەکییەکان',
                    icon: Icons.business,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'ناوی کۆمپانیا*',
                        icon: Icons.business_outlined,
                        validator: (val) =>
                            _validateRequired(val, 'ناوی کۆمپانیا'),
                      ),
                      const SizedBox(height: 16),
                      _buildCompanyTypeDropdown(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _contactPersonController,
                        label: 'پەیوەندیکار*',
                        icon: Icons.person_outlined,
                        validator: (val) =>
                            _validateRequired(val, 'پەیوەندیکار'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'زانیارییە پەیوەندییەکان',
                    icon: Icons.contact_phone,
                    children: [
                      _buildTextField(
                        controller: _phoneController,
                        label: 'ژمارەی مۆبایل*',
                        icon: Icons.phone_outlined,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'ئیمێڵ',
                        icon: Icons.email_outlined,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: 'ناونیشان',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'شار',
                              icon: Icons.location_city_outlined,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _countryController,
                              label: 'وڵات',
                              icon: Icons.flag_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'زانیارییە یاسایییەکان',
                    icon: Icons.gavel,
                    children: [
                      _buildTextField(
                        controller: _taxNumberController,
                        label: 'ژمارەی مالیات',
                        icon: Icons.receipt_long_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _regNumberController,
                        label: 'ژمارەی تۆمارکردن',
                        icon: Icons.numbers_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'تێبینییە زیاترەکان',
                    icon: Icons.note_alt_outlined,
                    children: [
                      _buildTextField(
                        controller: _notesController,
                        label: 'تێبینی',
                        icon: Icons.notes_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _submitCompany,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _isLoading
              ? 'لە پاشەکەوتکردندایە...'
              : 'پاشەکەوتکردن و چاپی کۆمپانیا',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSectionCard({
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kPrimaryColor),
                const SizedBox(width: 12),
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
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: kTextColor),
      decoration: _inputDecoration(label, icon),
      validator: validator,
    );
  }

  Widget _buildCompanyTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _companyType,
      onChanged: (String? newValue) {
        setState(() => _companyType = newValue ?? 'کڕیار');
      },
      items: _companyTypes.map((value) {
        return DropdownMenuItem(
          value: value,
          child: Text(value, style: GoogleFonts.inter(color: kTextColor)),
        );
      }).toList(),
      decoration: _inputDecoration('جۆری کۆمپانیا*', Icons.category_outlined),
      dropdownColor: kCardColor,
      icon: const Icon(Icons.arrow_drop_down, color: kTextSecondaryColor),
      style: GoogleFonts.inter(color: kTextColor),
      validator: (val) => _validateRequired(val, 'جۆری کۆمپانیا'),
    );
  }

  InputDecoration _inputDecoration(String label, [IconData? icon]) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: kTextSecondaryColor),
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

  // --- Feedback & Validation Methods ---

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String? _validateRequired(String? value, String fieldName) {
    return value == null || value.trim().isEmpty ? '$fieldName پێویستە' : null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final bool isValid = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$",
    ).hasMatch(value);
    return isValid ? null : 'تکایە ئیمێڵێکی دروست بنووسە';
  }

  String? _validatePhone(String? value) {
    if (_validateRequired(value, 'ژمارەی مۆبایل') != null) {
      return 'ژمارەی مۆبایل پێویستە';
    }
    final bool isValid = RegExp(r'^\+?[\d\s-]{7,}$').hasMatch(value!);
    return isValid ? null : 'تکایە ژمارەی مۆبایلێکی دروست بنووسە';
  }
}
