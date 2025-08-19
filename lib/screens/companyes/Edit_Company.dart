import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:solar_database/models/company.dart';

class EditCompany extends StatefulWidget {
  final Company company;

  const EditCompany({super.key, required this.company});

  @override
  State<EditCompany> createState() => _EditCompanyState();
}

class _EditCompanyState extends State<EditCompany> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

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

  String _companyType = 'Client';
  static const List<String> _companyTypes = ['کڕیار', 'دابینکەر', 'هەردووکیان'];

  @override
  void initState() {
    super.initState();
    _companyType = widget.company.companyType;

    _nameController = TextEditingController(text: widget.company.name);
    _contactPersonController = TextEditingController(
      text: widget.company.contactPerson,
    );
    _phoneController = TextEditingController(text: widget.company.phone);
    _emailController = TextEditingController(text: widget.company.email);
    _addressController = TextEditingController(text: widget.company.address);
    _cityController = TextEditingController(text: widget.company.city);
    _countryController = TextEditingController(text: widget.company.country);
    _taxNumberController = TextEditingController(
      text: widget.company.taxNumber,
    );
    _regNumberController = TextEditingController(
      text: widget.company.registrationNumber,
    );
    _notesController = TextEditingController(text: widget.company.notes);
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

  Future<void> _submitCompany() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('تکایە هەڵەکان چاکبکە پێش پاشەکەوتکردن', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final updatedCompany = Company(
      id: widget.company.id,
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

    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.updateCompany(updatedCompany.toMap());

      if (mounted) {
        _showSnackbar('کۆمپانیا بە سەرکەوتوویی نوێکرایەوە');
        Navigator.pop(context, updatedCompany); // Return the updated company
      }
    } catch (e) {
      _showSnackbar(
        'هەڵە لە نوێکردنەوەی کۆمپانیا: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        onPressed: _isLoading ? null : _submitCompany,
        tooltip: 'پاشەکەوتکردن',
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.save),
      ),

      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'دەستکاریکردنی کۆمپانیا',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kCardColor,
        foregroundColor: kTextColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _submitCompany,
            tooltip: 'پاشەکەوتکردنی گۆڕانکارییەکان',
          ),
        ],
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
                        validator: (val) =>
                            _validateRequired(val, 'ناوی کۆمپانیا'),
                      ),
                      const SizedBox(height: 16),
                      _buildCompanyTypeDropdown(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _contactPersonController,
                        label: 'کەسایەتی پەیوەندیدار*',
                        validator: (val) =>
                            _validateRequired(val, 'کەسایەتی پەیوەندیدار'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'زانیاری پەیوەندیکردن',
                    icon: Icons.contact_phone,
                    children: [
                      _buildTextField(
                        controller: _phoneController,
                        label: 'ژمارەی مۆبایل*',
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'ئیمەیڵ',
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: 'ناونیشان',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'شار',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _countryController,
                              label: 'وڵات',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'زانیاری یاسایی',
                    icon: Icons.gavel,
                    children: [
                      _buildTextField(
                        controller: _taxNumberController,
                        label: 'ژمارەی باج',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _regNumberController,
                        label: 'ژمارەی تۆمار',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: 'تێبینی زیادە',
                    icon: Icons.note_alt_outlined,
                    children: [
                      _buildTextField(
                        controller: _notesController,
                        label: 'تێبینییەکان',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: kTextColor),
      decoration: _inputDecoration(label, null),
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

  String? _validateRequired(String? value, String fieldName) {
    return value == null || value.trim().isEmpty ? '$fieldName پێویستە' : null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final bool isValid = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$",
    ).hasMatch(value);
    return isValid ? null : 'تکایە ئیمەیڵێکی دروست داخڵ بکە';
  }

  String? _validatePhone(String? value) {
    if (_validateRequired(value, 'ژمارەی مۆبایل') != null) {
      return 'ژمارەی مۆبایل پێویستە';
    }
    final bool isValid = RegExp(r'^\+?[\d\s-]{7,}$').hasMatch(value!);
    return isValid ? null : 'تکایە ژمارەی مۆبایلێکی دروست داخڵ بکە';
  }
}
