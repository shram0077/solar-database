import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/screens/Add_item/add_item.dart';
import 'package:solar_database/screens/Add_item/ViewItems/ViewItemsPage.dart';
import 'package:solar_database/screens/Debts/view_debts.dart';
import 'package:solar_database/screens/Hawala/hawala.dart';
import 'package:solar_database/screens/companyes/manage_companeis.dart';
import 'package:solar_database/screens/dashboard/dashbord_screen.dart';
import 'package:solar_database/screens/home/clurfulText.dart';
import 'package:solar_database/screens/jumla/jumla.dart';
import 'package:solar_database/screens/login/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_database/screens/monthlySpending/monthly_spending.dart';
import 'package:solar_database/screens/sales/add_sell_screen.dart';
import 'package:solar_database/screens/sales/view_sold_items.dart';
import 'dart:async';
import 'dart:convert';
import 'package:solar_database/screens/settings/settings_screen.dart';

class _NavItem {
  final String title;
  final String kurdishTitle;
  final IconData icon;
  final Widget page;
  final List<String> allowedRoles;

  _NavItem({
    required this.title,
    required this.kurdishTitle,
    required this.icon,
    required this.page,
    this.allowedRoles = const ['admin', 'user'],
  });
}

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _mobileNavIndex = 0;
  int? _desktopPageIndex;
  late List<_NavItem> _navItems;
  late List<Widget> _pages;
  late Map<String, dynamic> _currentUser;
  double _exchangeRate = 1450.0;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _initializeNavItems();
    _checkUserData();
  }

  Future<void> _checkUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      setState(() {
        _currentUser = json.decode(userDataString);
        _initializeNavItems(); // Reinitialize nav items if user data changes
      });
    }
  }

  void _initializeNavItems() {
    final allNavItems = [
      _NavItem(
        title: 'Dashboard',
        kurdishTitle: 'داشبۆرد',
        icon: Iconsax.home_1,
        page: const DashboardPage(key: PageStorageKey('dashboardPage')),
        allowedRoles: ['admin'],
      ),
      _NavItem(
        title: 'Add Sell',
        kurdishTitle: 'زیادکردنی فرۆش',
        icon: Iconsax.additem,
        page: const AddSellScreen(key: PageStorageKey('addSellPage')),
      ),
      _NavItem(
        title: 'Sales Report',
        kurdishTitle: 'ڕاپۆرتی فرۆشتنەکان',
        icon: Iconsax.receipt_1,
        page: SalesReportPage(key: const PageStorageKey('viewSoldItemsPage')),
        allowedRoles: ['admin'],
      ),
      _NavItem(
        title: 'Inventory',
        kurdishTitle: 'کۆگا',
        icon: Iconsax.box,
        page: ViewItemsPage(
          currentUser: widget.currentUser,
          key: const PageStorageKey('viewItemsPage'),
        ),
      ),
      _NavItem(
        title: 'Companies',
        kurdishTitle: 'کۆمپانیاکان',
        icon: Iconsax.building,
        page: const ManageCompanies(key: PageStorageKey('manageCompaniesPage')),
        allowedRoles: ['admin'],
      ),
      _NavItem(
        allowedRoles: ['admin'],
        title: 'Debts',
        kurdishTitle: 'قیستەکان',
        icon: Iconsax.wallet_money,
        page: const ViewDebts(key: PageStorageKey('viewDebtsPage')),
      ),
      _NavItem(
        allowedRoles: ['admin'],
        title: 'Settings',
        kurdishTitle: 'ڕێکخستن',
        icon: Iconsax.setting_2,
        page: SettingsScreen(
          key: const PageStorageKey('settingsPage'),
          currentUser: _currentUser,
        ),
      ),
      _NavItem(
        allowedRoles: ['admin'],
        title: 'ShopExpenses',
        kurdishTitle: 'مەسروفات',
        icon: Iconsax.bill,
        page: ShopExpenses(key: const PageStorageKey('shopexpenses')),
      ),
      _NavItem(
        allowedRoles: ['admin'],
        title: 'hawala',
        kurdishTitle: 'حەواڵە',
        icon: Icons.attach_money,
        page: HawalaScreen(),
      ),
      _NavItem(
        // allowedRoles: ['admin'],
        title: 'jumla',
        kurdishTitle: 'جوملە',
        icon: Iconsax.document,
        page: JumlaPreview(),
      ),
    ];

    // Filter navigation items based on user role
    _navItems = allNavItems.where((item) {
      return item.allowedRoles.contains(_currentUser['role'] ?? 'user');
    }).toList();

    _pages = _navItems.map((item) => item.page).toList();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onMobileNavItemTapped(int index) {
    setState(() {
      _mobileNavIndex = index;
    });
  }

  void _onDesktopCardTapped(int index) {
    setState(() {
      _desktopPageIndex = index;
    });
  }

  Widget _buildDesktopHub() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/logo.png", height: 120),
              const SizedBox(width: 16),
              ColorfulText(text: "Koden Energy"),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 100,
                vertical: 20,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250,
                childAspectRatio: 1.1,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                return _buildHubCard(
                  title: item.kurdishTitle,
                  icon: item.icon,
                  onTap: () => _onDesktopCardTapped(index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0, right: 15, left: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: kPrimaryColor.withOpacity(
                      0.1,
                    ), // light background
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // rounded corners
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _showChangeRateDialog,
                  icon: Icon(Icons.attach_money, color: kPrimaryColor),
                  label: Text(
                    _exchangeRate.toStringAsFixed(
                      2,
                    ), // convert double to String
                    style: TextStyle(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  "Logged in as: ${_currentUser['username'] ?? 'User'} | ${_currentUser['role'] ?? 'user'}",
                  style: TextStyle(color: kTextSecondaryColor),
                ),
                const SizedBox(width: 20),
                TextButton.icon(
                  icon: const Icon(Icons.logout, color: kTextSecondaryColor),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: kTextSecondaryColor),
                  ),
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'ar_IQ',
    symbol: 'IQD ',
    decimalDigits: 0,
  );
  void _showChangeRateDialog() {
    final rateController = TextEditingController(
      text: _exchangeRate.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('گۆڕینی نرخی IQD/USD'),
        content: TextField(
          controller: rateController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'نرخی نوێ (1 USD = ? IQD)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('هەڵوەشاندنەوە'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(rateController.text);
              if (newRate != null && newRate > 0) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('exchangeRate', newRate);
                setState(() {
                  _exchangeRate = newRate;
                });
                Navigator.pop(context);
                _showSnackBar(
                  'نرخی دراو نوێکرایەوە بۆ 1 USD = ${currencyFormat.format(newRate)} IQD',
                  isSuccess: true,
                );
              } else {
                _showSnackBar('نرخێکی نادروست داخڵکرا', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('پاشکەوتکردن'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : isSuccess
            ? Colors.green
            : kPrimaryColor,
      ),
    );
  }

  Widget _buildHubCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: kCardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: kPrimaryColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth >= 800;

        if (isWideScreen) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            body: _desktopPageIndex == null
                ? _buildDesktopHub()
                : Stack(
                    children: [
                      _pages[_desktopPageIndex!],
                      Positioned(
                        top: 20,
                        left: 20,
                        child: FloatingActionButton(
                          backgroundColor: kCardColor.withOpacity(0.8),
                          foregroundColor: kPrimaryColor,
                          tooltip: 'Back to Home',
                          onPressed: () {
                            setState(() {
                              _desktopPageIndex = null;
                            });
                          },
                          child: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                      ),
                    ],
                  ),
          );
        }

        // Mobile view
        final isInventoryPage = _navItems[_mobileNavIndex].title == 'Inventory';
        return Scaffold(
          floatingActionButton: isInventoryPage
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddItemScreen(),
                      ),
                    );
                  },
                  backgroundColor: kPrimaryColor,
                  tooltip: 'Add New Item',
                  child: const Icon(Iconsax.add, color: Colors.white, size: 28),
                )
              : null,
          backgroundColor: kBackgroundColor,
          body: IndexedStack(index: _mobileNavIndex, children: _pages),
          bottomNavigationBar: _BottomNavBar(
            selectedIndex: _mobileNavIndex,
            onItemTapped: _onMobileNavItemTapped,
            items: _navItems,
          ),
        );
      },
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final List<_NavItem> items;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: kCardColor,
      selectedItemColor: kPrimaryColor,
      unselectedItemColor: kTextSecondaryColor,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      items: items
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.title,
            ),
          )
          .toList(),
    );
  }
}
