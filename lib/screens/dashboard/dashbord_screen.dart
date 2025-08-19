import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/helpers/Database_helper.dart';
import 'package:solar_database/helpers/texts/titles.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;

  // --- Data state for UNIFIED totals ---
  double _unifiedTotalCostInUSD = 0.0;
  double _unifiedTotalRevenueInUSD = 0.0;
  int _totalUniqueItems = 0;
  int _lowStockItemsCount = 0;
  List<Map<String, dynamic>> _recentlyAdded = [];
  Map<String, int> _categoryCounts = {};

  // --- Sales & Profit data ---
  int _totalQuantitySold = 0;
  double _totalSalesRevenueInUSD = 0.0;
  double _totalProfitInUSD = 0.0;

  // --- Control State ---
  double _exchangeRate = 1450.0;
  bool _isUsdPrimary = true;

  // --- Formatters ---
  final NumberFormat _priceFormatUSD = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
  );
  final NumberFormat _priceFormatIQD = NumberFormat.currency(
    locale: 'ar_IQ',
    symbol: 'IQD ',
    decimalDigits: 0,
  );
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
                  _calculateTotals(); // Make sure this method recalculates all values
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

  void _calculateTotals() async {
    // This should recalculate all the financial values based on the new exchange rate
    await _loadDashboardData();
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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int toInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    bool isUSD(dynamic currency, dynamic isCurrencyUsdFlag) {
      if (currency is String) return currency.toUpperCase() == 'USD';
      if (isCurrencyUsdFlag is int) return isCurrencyUsdFlag == 1;
      if (isCurrencyUsdFlag is bool) return isCurrencyUsdFlag;
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRate = prefs.getDouble('exchangeRate') ?? 1450.0;
      final isUsdPrimary = prefs.getBool('dashboardPrimaryIsUSD') ?? true;

      final items = await _dbHelper.getAllItems();
      final sales = await _dbHelper.getAllSales();

      // Inventory totals
      double unifiedCost = 0.0;
      double unifiedRevenue = 0.0;
      int lowStockCount = 0;
      final categoryCounter = <String, int>{};

      for (final item in items) {
        final qty = toInt(item['quantity']);
        final buying = toDouble(item['buying_price']);
        final selling = toDouble(item['selling_price']);
        final inUSD = isUSD(item['currency'], item['is_currency_usd']);

        final itemCostUSD = inUSD
            ? buying
            : (savedRate > 0 ? buying / savedRate : 0.0);
        final itemRevenueUSD = inUSD
            ? selling
            : (savedRate > 0 ? selling / savedRate : 0.0);

        unifiedCost += itemCostUSD * qty;
        unifiedRevenue += itemRevenueUSD * qty;

        if (qty <=
            (toInt(item['low_stock_threshold']) == 0
                ? 3
                : toInt(item['low_stock_threshold']))) {
          lowStockCount++;
        }

        final cat = (item['category'] as String?)?.trim();
        if (cat != null && cat.isNotEmpty) {
          categoryCounter[cat] = (categoryCounter[cat] ?? 0) + 1;
        }
      }

      // Sales totals from stored USD values
      int totalQuantitySold = 0;
      double totalSalesRevenueUSD = 0.0;
      double totalProfitUSD = 0.0;

      for (final sale in sales) {
        final qty = toInt(sale['quantity']);
        if (qty <= 0) continue;

        // Use already stored USD values at time of sale
        final revenueUSD = toDouble(sale['final_amount_usd']);
        final profitUSD = toDouble(sale['profit']);

        totalQuantitySold += qty;
        totalSalesRevenueUSD += revenueUSD;
        totalProfitUSD += profitUSD;
      }

      // Sort recently added items
      final sortedItems = List.of(items)
        ..sort((a, b) {
          final aD =
              DateTime.tryParse((a['purchase_date'] ?? '').toString()) ??
              DateTime(1970);
          final bD =
              DateTime.tryParse((b['purchase_date'] ?? '').toString()) ??
              DateTime(1970);
          return bD.compareTo(aD);
        });

      setState(() {
        _exchangeRate = savedRate;
        _isUsdPrimary = isUsdPrimary;

        _unifiedTotalCostInUSD = unifiedCost;
        _unifiedTotalRevenueInUSD = unifiedRevenue;
        _totalUniqueItems = items.length;
        _lowStockItemsCount = lowStockCount;
        _categoryCounts = categoryCounter;
        _recentlyAdded = sortedItems.take(5).toList();

        _totalQuantitySold = totalQuantitySold;
        _totalSalesRevenueInUSD = totalSalesRevenueUSD;
        _totalProfitInUSD = totalProfitUSD;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePrimaryCurrency(bool isUSD) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dashboardPrimaryIsUSD', isUSD);
    setState(() {
      _isUsdPrimary = isUSD;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _dbHelper.onDataChanged,
      builder: (context, snapshot) {
        if (_isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        // Format currency values according to selected currency and exchange rate
        final formattedTotalCostPrimary = _isUsdPrimary
            ? _priceFormatUSD.format(_unifiedTotalCostInUSD)
            : _priceFormatIQD.format(_unifiedTotalCostInUSD * _exchangeRate);
        final formattedTotalCostSecondary = _isUsdPrimary
            ? _priceFormatIQD.format(_unifiedTotalCostInUSD * _exchangeRate)
            : _priceFormatUSD.format(_unifiedTotalCostInUSD);

        final formattedRevenuePrimary = _isUsdPrimary
            ? _priceFormatUSD.format(_unifiedTotalRevenueInUSD)
            : _priceFormatIQD.format(_unifiedTotalRevenueInUSD * _exchangeRate);
        final formattedRevenueSecondary = _isUsdPrimary
            ? _priceFormatIQD.format(_unifiedTotalRevenueInUSD * _exchangeRate)
            : _priceFormatUSD.format(_unifiedTotalRevenueInUSD);

        final formattedSalesRevenuePrimary = _isUsdPrimary
            ? _priceFormatUSD.format(_totalSalesRevenueInUSD)
            : _priceFormatIQD.format(_totalSalesRevenueInUSD * _exchangeRate);
        final formattedSalesRevenueSecondary = _isUsdPrimary
            ? _priceFormatIQD.format(_totalSalesRevenueInUSD * _exchangeRate)
            : _priceFormatUSD.format(_totalSalesRevenueInUSD);

        final formattedProfitPrimary = _isUsdPrimary
            ? _priceFormatUSD.format(_totalProfitInUSD)
            : _priceFormatIQD.format(_totalProfitInUSD * _exchangeRate);
        final formattedProfitSecondary = _isUsdPrimary
            ? _priceFormatIQD.format(_totalProfitInUSD * _exchangeRate)
            : _priceFormatUSD.format(_totalProfitInUSD);

        final profitMarginPercent = _totalSalesRevenueInUSD > 0
            ? (_totalProfitInUSD / _totalSalesRevenueInUSD) * 100
            : 0;

        return RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: kPrimaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnimatedFadeSlide(
                  delay: 100,
                  child: _DashboardHeader(
                    isUsdPrimary: _isUsdPrimary,
                    onCurrencyToggle: _togglePrimaryCurrency,
                    onChangeRatePressed: _showChangeRateDialog,
                    usdExchangeprice: _exchangeRate,
                  ),
                ),
                const SizedBox(height: 24),
                _AnimatedFadeSlide(
                  delay: 200,
                  child: _SummaryGrid(
                    totalCostPrimary: formattedTotalCostPrimary,
                    totalCostSecondary: formattedTotalCostSecondary,
                    potentialRevenuePrimary: formattedRevenuePrimary,
                    potentialRevenueSecondary: formattedRevenueSecondary,
                    totalUniqueItems: _totalUniqueItems,
                    lowStockItemsCount: _lowStockItemsCount,
                    totalQuantitySold: _totalQuantitySold,
                    totalSalesRevenuePrimary: formattedSalesRevenuePrimary,
                    totalSalesRevenueSecondary: formattedSalesRevenueSecondary,
                    totalProfitPrimary: formattedProfitPrimary,
                    totalProfitSecondary: formattedProfitSecondary,
                    profitMarginPercent: (profitMarginPercent is num)
                        ? profitMarginPercent.toDouble()
                        : double.tryParse(profitMarginPercent.toString()) ??
                              0.0,
                  ),
                ),
                const SizedBox(height: 24),
                _AnimatedFadeSlide(
                  delay: 300,
                  child: _CategoryPieChart(categoryCounts: _categoryCounts),
                ),
                const SizedBox(height: 24),
                _AnimatedFadeSlide(
                  delay: 400,
                  child: _RecentActivity(recentlyAdded: _recentlyAdded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ... (The rest of the file remains unchanged)
// _AnimatedFadeSlide, _DashboardHeader, _SummaryGrid, _SummaryCard,
// _CategoryPieChart, _RecentActivity, and _getIconForCategory widgets are the same as before.
class _AnimatedFadeSlide extends StatefulWidget {
  final int delay;
  final Widget child;

  const _AnimatedFadeSlide({required this.delay, required this.child});

  @override
  State<_AnimatedFadeSlide> createState() => _AnimatedFadeSlideState();
}

class _AnimatedFadeSlideState extends State<_AnimatedFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isUsdPrimary;
  final ValueChanged<bool> onCurrencyToggle;
  final VoidCallback onChangeRatePressed; // Add this
  final double usdExchangeprice;
  const _DashboardHeader({
    required this.isUsdPrimary,
    required this.onCurrencyToggle,
    required this.onChangeRatePressed,
    required this.usdExchangeprice,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat(
      'EEEE, MMMM d',
      'en_US',
    ).format(DateTime.now());

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سڵاو، بەخێربێیت',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: kTextSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: kPrimaryColor.withOpacity(
                  0.1,
                ), // light background
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // rounded corners
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: onChangeRatePressed,
              icon: Icon(Icons.attach_money, color: kPrimaryColor),
              label: Text(
                usdExchangeprice.toStringAsFixed(2), // convert double to String
                style: TextStyle(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('USD'),
                  icon: Icon(Icons.attach_money, size: 16),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('IQD'),
                  icon: Icon(Icons.currency_exchange, size: 16),
                ),
              ],
              selected: {isUsdPrimary},
              onSelectionChanged: (newSelection) {
                onCurrencyToggle(newSelection.first);
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: kCardColor,
                foregroundColor: kTextSecondaryColor,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: kPrimaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final String totalCostPrimary;
  final String totalCostSecondary;
  final String potentialRevenuePrimary;
  final String potentialRevenueSecondary;
  final int totalUniqueItems;
  final int lowStockItemsCount;

  // New sales and profit fields
  final int? totalQuantitySold;
  final String? totalSalesRevenuePrimary;
  final String? totalSalesRevenueSecondary;
  final String? totalProfitPrimary;
  final String? totalProfitSecondary;
  final double? profitMarginPercent;

  const _SummaryGrid({
    required this.totalCostPrimary,
    required this.totalCostSecondary,
    required this.potentialRevenuePrimary,
    required this.potentialRevenueSecondary,
    required this.totalUniqueItems,
    required this.lowStockItemsCount,
    this.totalQuantitySold,
    this.totalSalesRevenuePrimary,
    this.totalSalesRevenueSecondary,
    this.totalProfitPrimary,
    this.totalProfitSecondary,
    this.profitMarginPercent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : (constraints.maxWidth > 700 ? 2 : 2);
        final childAspectRatio = crossAxisCount == 4
            ? 1.5
            : (crossAxisCount == 2 ? 1.8 : 2.5);

        final List<Widget> cards = [
          _SummaryCard(
            title: 'کۆی تێچوی کاڵاکانی ناو کۆگا', // Total Inventory Cost
            primaryValue: totalCostPrimary,
            secondaryValue: totalCostSecondary,
            icon: Iconsax.wallet_money,
            color1: const Color(0xFF5C6BC0),
            color2: const Color(0xFF3F51B5),
          ),
          _SummaryCard(
            title: 'قازانجی پێشبینیکراو', // Potential Revenue
            primaryValue: potentialRevenuePrimary,
            secondaryValue: potentialRevenueSecondary,
            icon: Iconsax.money_recive,
            color1: const Color(0xFF26A69A),
            color2: const Color(0xFF00796B),
          ),
          _SummaryCard(
            title: 'ژمارەی جۆرەکانی کاڵا لە کۆگا', // Unique Items
            primaryValue: totalUniqueItems.toString(),
            icon: Iconsax.box_1,
            color1: const Color(0xFFFFA726),
            color2: const Color(0xFFF57C00),
          ),
          _SummaryCard(
            title: 'کاڵای کەم', // Low Stock Items
            primaryValue: lowStockItemsCount.toString(),
            icon: Iconsax.warning_2,
            color1: const Color(0xFFEF5350),
            color2: const Color(0xFFD32F2F),
          ),
        ];

        if (totalQuantitySold != null) {
          cards.addAll([
            _SummaryCard(
              title: 'کۆی فرۆشتنی کاڵا', // Total Quantity Sold
              primaryValue: totalQuantitySold.toString(),
              icon: Iconsax.shopping_cart,
              color1: const Color(0xFF42A5F5),
              color2: const Color(0xFF1E88E5),
            ),
            _SummaryCard(
              title: 'کۆی داهاتی فرۆشتن', // Total Sales Revenue
              primaryValue: totalSalesRevenuePrimary ?? '',
              secondaryValue: totalSalesRevenueSecondary,
              icon: Iconsax.money_tick,
              color1: const Color(0xFF66BB6A),
              color2: const Color(0xFF388E3C),
            ),
            _SummaryCard(
              title: 'کۆی قازانجی ڕاستەقینە', // Total Profit
              primaryValue: totalProfitPrimary ?? '',
              secondaryValue: totalProfitSecondary,
              icon: Iconsax.money,
              color1: const Color(0xFFFFCA28),
              color2: const Color(0xFFF57F17),
            ),
            _SummaryCard(
              title: 'ڕێژەی قازانج', // Profit Margin %
              primaryValue:
                  '${profitMarginPercent?.toStringAsFixed(1) ?? '0'}%',
              icon: Iconsax.chart,
              color1: const Color(0xFFAB47BC),
              color2: const Color(0xFF7B1FA2),
            ),
          ]);
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: childAspectRatio,
          children: cards,
        );
      },
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final String title, primaryValue;
  final String? secondaryValue;
  final IconData icon;
  final Color color1, color2;

  const _SummaryCard({
    required this.title,
    required this.primaryValue,
    this.secondaryValue,
    required this.icon,
    required this.color1,
    required this.color2,
  });

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _isHovered
            ? (Matrix4.identity()..scale(1.03))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.color1, widget.color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.color2.withOpacity(_isHovered ? 0.4 : 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 32, color: Colors.white.withOpacity(0.8)),
              const Spacer(),
              titletext(
                widget.title,
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.primaryValue,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (widget.secondaryValue != null)
                Text(
                  widget.secondaryValue!,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPieChart extends StatefulWidget {
  final Map<String, int> categoryCounts;
  const _CategoryPieChart({required this.categoryCounts});

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int? touchedIndex;
  final ScrollController _scrollController = ScrollController();

  final List<Color> _categoryColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryCounts.isEmpty) {
      return Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: kCardColor,
        child: SizedBox(
          height: 300,
          child: Center(
            child: Text(
              "هیچ داتایەک نییە بۆ پیشاندان.",
              style: GoogleFonts.inter(color: kTextSecondaryColor),
            ),
          ),
        ),
      );
    }

    final sortedEntries = widget.categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: kCardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "کاڵا بەپێی پۆل",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.5,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: List.generate(sortedEntries.length, (i) {
                          final isTouched = i == touchedIndex;
                          final fontSize = isTouched ? 16.0 : 12.0;
                          final radius = isTouched ? 60.0 : 50.0;
                          final entry = sortedEntries[i];
                          final color =
                              _categoryColors[i % _categoryColors.length];
                          final total = widget.categoryCounts.values.fold(
                            0,
                            (a, b) => a + b,
                          );
                          final percentage = total > 0
                              ? (entry.value / total) * 100
                              : 0;

                          return PieChartSectionData(
                            color: color,
                            value: entry.value.toDouble(),
                            title: '${percentage.toStringAsFixed(1)}%',
                            radius: radius,
                            titleStyle: GoogleFonts.inter(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [
                                Shadow(color: Colors.black26, blurRadius: 2),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: double.infinity,
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: sortedEntries.length,
                          itemBuilder: (context, index) {
                            final entry = sortedEntries[index];
                            final color =
                                _categoryColors[index % _categoryColors.length];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    color: color,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${entry.key} (${entry.value})",
                                      style: GoogleFonts.inter(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  final List<Map<String, dynamic>> recentlyAdded;
  const _RecentActivity({required this.recentlyAdded});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "کاڵای نوێی زیادکراو",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kTextColor,
          ),
        ),
        const SizedBox(height: 16),
        if (recentlyAdded.isEmpty)
          Card(
            elevation: 0,
            color: kCardColor,
            child: SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  "هیچ کاڵایەک زیادنەکراوە.",
                  style: GoogleFonts.inter(color: kTextSecondaryColor),
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentlyAdded.length,
            itemBuilder: (context, index) {
              final item = recentlyAdded[index];
              final dateString = item['purchase_date'];
              String formattedDate = 'No Date';
              if (dateString != null) {
                try {
                  formattedDate = DateFormat.yMMMd().format(
                    DateTime.parse(dateString),
                  );
                } catch (_) {
                  // use default
                }
              }
              return Card(
                elevation: 0,
                color: kCardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kPrimaryColor.withOpacity(0.1),
                    child: Icon(
                      _getIconForCategory(item['category']),
                      color: kPrimaryColor,
                    ),
                  ),
                  title: Text(
                    item['model'] ?? "کاڵای بێ ناو",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: kTextColor,
                    ),
                  ),
                  subtitle: Text(
                    item['brand'] ?? "هیچ براندێک نییە",
                    style: GoogleFonts.inter(
                      color: kTextSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Text(
                    formattedDate,
                    style: GoogleFonts.inter(
                      color: kTextSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

IconData _getIconForCategory(String? category) {
  switch (category?.toLowerCase()) {
    case 'solar panel':
      return Icons.solar_power_outlined;
    case 'inverter':
      return Icons.transform_outlined;
    case 'battery':
      return Icons.battery_charging_full_outlined;
    case 'mounting kit':
      return Icons.construction_outlined;
    case 'cable':
      return Icons.cable_outlined;
    case 'charge controller':
      return Icons.tune_outlined;
    default:
      return Icons.category_outlined;
  }
}
