import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/screens/settings/add_user.dart';
import 'package:solar_database/screens/settings/manage_items.dart';
import 'package:solar_database/screens/settings/manage_users.dart';

// Enhanced Modern color palette for desktop

// Enhanced shadows
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x0F000000), blurRadius: 1, offset: Offset(0, 1)),
];

const List<BoxShadow> kElevatedShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
  BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
];

// Kurdish text constants
const String kSettingsTitle = 'ڕێکخستنەکان';
const String kItemDataTitle = 'داتای کاڵاکان';
const String kManageCategories = 'بەڕێوەبردنی پۆل و مارکەکان';
const String kCategoriesCount = 'پۆلەکان: %d بەردەستە';
const String kBrandsCount = 'مارکەکان: %d بەردەستە';
const String kModelsCount = 'مۆدێلەکان: %d بەردەستە';
const String kUsersTitle = 'هەژمارەکان';
const String kManageUsers = 'بەڕێوەبردنی بەکارهێنەران';
const String kAddUser = 'زیادکردنی بەکارهێنەر';
const String kNoUsersFound = 'هیچ بەکارهێنەرێک نەدۆزرایەوە';
const String kRoleLabel = 'ڕۆڵ: %s';
const String kJoinedLabel = 'بەشداری: %s';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const SettingsScreen({super.key, required this.currentUser});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<String> _categories = [];
  List<String> _brands = [];
  List<String> _models = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadAllData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _loadUsers();
    await _loadItemData();
    setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersString = prefs.getString('users') ?? '[]';
    setState(
      () => _users = List<Map<String, dynamic>>.from(json.decode(usersString)),
    );
  }

  Future<void> _loadItemData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _categories = List<String>.from(
        json.decode(prefs.getString('item_categories') ?? '[]'),
      );
      _brands = List<String>.from(
        json.decode(prefs.getString('item_brands') ?? '[]'),
      );
      _models = List<String>.from(
        json.decode(prefs.getString('item_models') ?? '[]'),
      );
    });
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users', json.encode(_users));
  }

  void _navigateToAddUser() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AddUserScreen(
          onUserAdded: (newUser) {
            setState(() => _users.add(newUser));
            _saveUsers();
          },
          currentUserRole: widget.currentUser['role'] ?? 'user',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _navigateToManageUsers() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ManageUsersScreen(
              users: _users,
              onUsersUpdated: (updatedUsers) {
                setState(() => _users = updatedUsers);
                _saveUsers();
              },
              currentUserRole: widget.currentUser['role'] ?? 'user',
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _navigateToManageAttributes() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProductAttributeScreen(
              initialCategories: _categories,
              initialBrands: _brands,
              initialModels: _models,
              onSaveChanges: (updatedCategories, updatedBrands, updatedModels) {
                setState(() {
                  _categories = updatedCategories;
                  _brands = updatedBrands;
                  _models = updatedModels;
                });
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildUsersListView() {
    if (_users.isEmpty) {
      return _buildEmptyState();
    }

    return _buildModernCard(
      child: Column(
        children: [
          _buildSectionHeader(
            title: 'لیستی بەکارهێنەران',
            subtitle: '${_users.length} بەکارهێنەر تۆمارکراوە',
            icon: Icons.people_outline,
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users.length,
            separatorBuilder: (_, __) => Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              final user = _users[index];
              return _buildUserTile(user, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildUserAvatar(user, index),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                _buildRoleBadge(user['role']),
              ],
            ),
          ),
          if (user['createdAt'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
              ),
              child: Text(
                _formatDate(user['createdAt']),
                style: TextStyle(
                  fontSize: 12,
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> user, int index) {
    final colors = [kPrimaryColor, kAccentColor, kSuccessColor, kWarningColor];
    final color = colors[index % colors.length];

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          user['username'][0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    IconData badgeIcon;

    switch (role.toLowerCase()) {
      case 'admin':
        badgeColor = Colors.red;
        badgeIcon = Icons.admin_panel_settings;
        break;
      case 'manager':
        badgeColor = kWarningColor;
        badgeIcon = Icons.supervisor_account;
        break;
      default:
        badgeColor = kSuccessColor;
        badgeIcon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildModernCard(
      child: Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(Icons.people_outline, size: 40, color: kPrimaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              kNoUsersFound,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kTextSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'دەستپێکە بە زیادکردنی بەکارهێنەری نوێ بۆ بەڕێوەبردنی سیستەمەکە',
              style: TextStyle(
                fontSize: 14,
                color: kTextSecondaryColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDataCard() {
    final currentUserRole = widget.currentUser['role'] ?? 'user';
    final canManageData = currentUserRole == 'admin';

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: kItemDataTitle,
            subtitle: 'بەڕێوەبردنی داتای بەرهەمەکان و پۆلەکان',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 24),
          _buildDataSummaryGrid(),
          if (canManageData) ...[
            const SizedBox(height: 24),
            _buildGradientButton(
              icon: Icons.category_outlined,
              label: kManageCategories,
              onPressed: _navigateToManageAttributes,
              gradient: const LinearGradient(
                colors: [kPrimaryColor, kPrimaryGradientEnd],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataSummaryGrid() {
    final summaryItems = [
      {
        'title': 'پۆلەکان',
        'count': _categories.length,
        'icon': Icons.category,
        'color': kPrimaryColor,
      },
      {
        'title': 'براندەکان',
        'count': _brands.length,
        'icon': Icons.branding_watermark,
        'color': kAccentColor,
      },
      {
        'title': 'مۆدێلەکان',
        'count': _models.length,
        'icon': Icons.model_training,
        'color': kSuccessColor,
      },
    ];

    return Row(
      children: summaryItems.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (item['color'] as Color).withOpacity(0.1),
                  (item['color'] as Color).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (item['color'] as Color).withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (item['color'] as Color).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${item['count']}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: item['color'] as Color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    color: kTextSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUsersCard() {
    final currentUserRole = widget.currentUser['role'] ?? 'user';
    final canManageUsers = currentUserRole == 'admin';

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: kUsersTitle,
            subtitle: 'بەڕێوەبردنی بەکارهێنەران و دەسەڵاتەکان',
            icon: Icons.people_outline,
          ),
          if (canManageUsers) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildGradientButton(
                    icon: Icons.people,
                    label: kManageUsers,
                    onPressed: _navigateToManageUsers,
                    gradient: const LinearGradient(
                      colors: [kSuccessColor, Color(0xFF38A169)],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGradientButton(
                    icon: Icons.person_add,
                    label: kAddUser,
                    onPressed: _navigateToAddUser,
                    gradient: const LinearGradient(
                      colors: [kAccentColor, Color(0xFF0BC5EA)],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kPrimaryColor, kPrimaryGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: kTextSecondaryColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required LinearGradient gradient,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
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
          preferredSize: const Size.fromHeight(80),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AppBar(
              title: Text(
                kSettingsTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: kTextColor,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        body: _isLoading
            ? Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: kCardShadow,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: kPrimaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _buildItemDataCard(),
                                  _buildUsersCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: _buildUsersListView()),
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
}
