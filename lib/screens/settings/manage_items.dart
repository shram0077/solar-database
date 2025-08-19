import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enhanced Modern color palette for desktop
import 'package:solar_database/constans/colors.dart';

// Enhanced shadows
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x0F000000), blurRadius: 1, offset: Offset(0, 1)),
];

const List<BoxShadow> kElevatedShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
  BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
];

class ProductAttributeScreen extends StatefulWidget {
  final List<String> initialCategories;
  final List<String> initialBrands;
  final List<String> initialModels;
  final Function(
    List<String> categories,
    List<String> brands,
    List<String> models,
  )
  onSaveChanges;

  const ProductAttributeScreen({
    super.key,
    required this.initialCategories,
    required this.initialBrands,
    required this.initialModels,
    required this.onSaveChanges,
  });

  @override
  State<ProductAttributeScreen> createState() => _ProductAttributeScreenState();
}

class _ProductAttributeScreenState extends State<ProductAttributeScreen>
    with TickerProviderStateMixin {
  late List<String> _categories;
  late List<String> _brands;
  late List<String> _models;

  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.initialCategories);
    _brands = List.from(widget.initialBrands);
    _models = List.from(widget.initialModels);

    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _addItem(List<String> list, TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isNotEmpty && !list.contains(text)) {
      setState(() {
        list.insert(0, text);
        controller.clear();
      });
      HapticFeedback.lightImpact();
      _showSuccessSnackBar('بە سەرکەوتوویی "$text" زیاد کرا');
    } else if (list.contains(text)) {
      _showErrorSnackBar('$text پێشتر بوونی هەیە');
    } else {
      _showErrorSnackBar('تکایە ناوی دروست داخڵ بکە');
    }
  }

  void _removeItem(List<String> list, int index) {
    setState(() {
      final removedItem = list.removeAt(index);
      _showUndoSnackBar('سڕایەوە $removedItem', () {
        setState(() {
          list.insert(index, removedItem);
        });
      });
    });
    HapticFeedback.mediumImpact();
  }

  void _editItem(List<String> list, int index) {
    final controller = TextEditingController(text: list[index]);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildEditDialog(controller, (newValue) {
        if (newValue.trim().isNotEmpty && newValue != list[index]) {
          setState(() {
            list[index] = newValue.trim();
          });
          _showSuccessSnackBar('بە سەرکەوتوویی نوێکرایەوە');
        }
      }),
    );
  }

  Widget _buildEditDialog(
    TextEditingController controller,
    Function(String) onSave,
  ) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kElevatedShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPrimaryColor, kPrimaryGradientEnd],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'دەستکاریکردنی بابەت',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ناوی نوێی ئەم بابەتە داخڵ بکە',
              style: TextStyle(color: kTextSecondaryColor, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: 'ناوی نوێ داخڵ بکە...',
                  hintStyle: TextStyle(color: kTextSecondaryColor),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: kBorderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'هەڵوەشاندنەوە',
                        style: TextStyle(color: kTextSecondaryColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimaryColor, kPrimaryGradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () {
                        onSave(controller.text);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'پاشەکەوت',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: kSuccessColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showUndoSnackBar(String message, VoidCallback onUndo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        action: SnackBarAction(
          label: 'گەڕانەوە',
          textColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.2),
          onPressed: onUndo,
        ),
        backgroundColor: kWarningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: kPrimaryColor,
          secondary: kAccentColor,
          surface: kSurfaceColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPrimaryColor, kPrimaryGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AppBar(
              title: const Text(
                'تایبەتمەندییەکانی بەرهەم',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: kPrimaryColor,
                    unselectedLabelColor: Colors.white.withOpacity(0.8),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(icon: Icon(Iconsax.category), text: 'پۆلەکان'),
                      Tab(
                        icon: Icon(CupertinoIcons.cube_box),
                        text: 'براندەکان',
                      ),
                      Tab(icon: Icon(CupertinoIcons.photo), text: 'مۆدێلەکان'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAttributeTab(
                'پۆل',
                _categories,
                _categoryController,
                Iconsax.category,
                kPrimaryColor,
              ),
              _buildAttributeTab(
                'براند',
                _brands,
                _brandController,
                CupertinoIcons.cube_box,
                kAccentColor,
              ),
              _buildAttributeTab(
                'مۆدێل',
                _models,
                _modelController,
                CupertinoIcons.photo,
                kSuccessColor,
              ),
            ],
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kSuccessColor, Color(0xFF38A169)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kSuccessColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            backgroundColor: Colors.transparent,
            elevation: 0,
            onPressed: () {
              widget.onSaveChanges(_categories, _brands, _models);
              Navigator.pop(context);
              _saveItemData();
            },
            label: const Text(
              'هەموو گۆڕانکارییەکان پاشەکەوت بکە',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            icon: const Icon(Icons.save, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeTab(
    String attributeName,
    List<String> items,
    TextEditingController controller,
    IconData icon,
    Color themeColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            _buildAddSection(
              attributeName,
              controller,
              icon,
              themeColor,
              items,
            ),
            const SizedBox(height: 32),
            _buildItemsList(attributeName, items, themeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSection(
    String attributeName,
    TextEditingController controller,
    IconData icon,
    Color themeColor,
    List<String> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor, themeColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'زیادکردنی $attributeNameی نوێ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ناوی $attributeNameی نوێ داخڵ بکە بۆ فراوانکردنی زەمینەکەت',
                      style: TextStyle(
                        fontSize: 14,
                        color: kTextSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderColor),
            ),
            child: TextField(
              controller: controller,
              onSubmitted: (_) => _addItem(items, controller),
              decoration: InputDecoration(
                filled: false,
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: themeColor, size: 20),
                ),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor, themeColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 24),
                    onPressed: () => _addItem(items, controller),
                  ),
                ),
                hintText: 'ناوی $attributeName داخڵ بکە...',
                hintStyle: TextStyle(color: kTextSecondaryColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(
    String attributeName,
    List<String> items,
    Color themeColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'لیستی $attributeName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor, themeColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${items.length} دانە',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            _buildEmptyState(attributeName, themeColor)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kBorderColor.withOpacity(0),
                      kBorderColor,
                      kBorderColor.withOpacity(0),
                    ],
                  ),
                ),
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildListItem(item, index, items, themeColor);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String attributeName, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'هێشتا هیچ $attributeNameێک نییە',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'یەکەم $attributeNameی خۆت زیاد بکە بە بەکارهێنانی فۆڕمەکەی سەرەوە',
            style: TextStyle(
              fontSize: 14,
              color: kTextSecondaryColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    String item,
    int index,
    List<String> items,
    Color themeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeColor, themeColor.withOpacity(0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: kTextColor,
              ),
            ),
          ),
          _buildActionButton(
            icon: Icons.edit_outlined,
            color: themeColor,
            onTap: () => _editItem(items, index),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.delete_outline,
            color: Colors.red,
            onTap: () => _removeItem(items, index),
          ),
        ],
      ),
    );
  }

  Future<void> _saveItemData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('item_categories', json.encode(_categories));
    await prefs.setString('item_brands', json.encode(_brands));
    await prefs.setString('item_models', json.encode(_models));
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
