import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solar_database/constans/colors.dart';

class ViewFullItemDetails extends StatefulWidget {
  final Map<String, dynamic> item;
  const ViewFullItemDetails({super.key, required this.item});

  @override
  State<ViewFullItemDetails> createState() => _ViewFullItemDetailsState();
}

class _ViewFullItemDetailsState extends State<ViewFullItemDetails>
    with TickerProviderStateMixin {
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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final isUSD = (item['is_currency_usd'] == 1);
    final currencyFormat = NumberFormat.currency(symbol: isUSD ? '\$' : 'د.ع');

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(item, isDesktop),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: isDesktop
                  ? _buildDesktopLayout(item, currencyFormat)
                  : _buildMobileLayout(item, currencyFormat),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> item, bool isDesktop) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: kPrimaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          item['item_name'] ?? 'کاڵای بێ ناو',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 20 : 16,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kPrimaryColor, kAccentColor],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    Map<String, dynamic> item,
    NumberFormat currencyFormat,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section with item overview
          _buildHeroSection(item, currencyFormat),
          const SizedBox(height: 32),

          // Main content in grid layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column - Basic Info & Image
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildItemImageCard(item),
                    const SizedBox(height: 24),
                    _buildBasicInfoCard(item),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right column - Financial Info & Actions
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildFinancialInfoCard(item, currencyFormat),
                    const SizedBox(height: 24),
                    _buildInventoryCard(item),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    Map<String, dynamic> item,
    NumberFormat currencyFormat,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildHeroSection(item, currencyFormat),
          const SizedBox(height: 24),
          _buildItemImageCard(item),
          const SizedBox(height: 16),
          _buildBasicInfoCard(item),
          const SizedBox(height: 16),
          _buildFinancialInfoCard(item, currencyFormat),
          const SizedBox(height: 16),
          _buildInventoryCard(item),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
    Map<String, dynamic> item,
    NumberFormat currencyFormat,
  ) {
    final profit = (item['selling_price'] ?? 0) - (item['buying_price'] ?? 0);
    final profitMargin = (item['buying_price'] ?? 0) != 0
        ? (profit / (item['buying_price'] ?? 1)) * 100
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildInfoChip(
                Icons.inventory_2_outlined,
                item['category']?.toString() ?? 'بێ پۆل',
                kPrimaryColor,
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                Icons.branding_watermark_outlined,
                item['brand']?.toString() ?? 'بێ براند',
                kAccentColor,
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'نرخی ئێستا',
                  currencyFormat.format(item['selling_price'] ?? 0),
                  Icons.price_change,
                  kSuccessColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'قازانج',
                  '${profitMargin.toStringAsFixed(1)}%',
                  profit >= 0 ? Icons.trending_up : Icons.trending_down,
                  profit >= 0 ? kSuccessColor : kLossColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'ئاستی کاڵا',
                  item['quantity']?.toString() ?? '0',
                  Icons.inventory,
                  _getStockColor(item['quantity'] ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemImageCard(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kPrimaryColor.withOpacity(0.1),
              kAccentColor.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: kPrimaryColor),
              const SizedBox(height: 16),
              Text(
                item['item_name']?.toString() ?? 'بێ ناو',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              if (item['barcode'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'بارکۆد: ${item['barcode']}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: kTextSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'زانیاری کاڵا',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailRow('مۆدێل', item['model']?.toString(), Icons.devices),
          _buildDetailRow('وات', item['power']?.toString(), Icons.power),
          _buildDetailRow(
            'ڤۆلت',
            item['voltage']?.toString(),
            Icons.electrical_services,
          ),
          _buildDetailRow(
            'بەرواری کڕین',
            item['purchase_date'] != null
                ? DateFormat.yMMMMd().format(
                    DateTime.parse(item['purchase_date']),
                  )
                : 'بەردەست نییە',
            Icons.calendar_today,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialInfoCard(
    Map<String, dynamic> item,
    NumberFormat currencyFormat,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'زانیاری دارایی',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 20),
          _buildPriceRow(
            'نرخی کڕین (فرۆشگا)',
            item['buying_price'],
            currencyFormat,
            Icons.shopping_cart,
          ),
          _buildPriceRow(
            'نرخی فرۆشتن (فرۆشگا)',
            item['selling_price'],
            currencyFormat,
            Icons.sell,
          ),
          _buildPriceRow(
            'نرخی کڕین (تاک)',
            item['buying_price_retail'],
            currencyFormat,
            Icons.shopping_basket,
          ),
          _buildPriceRow(
            'نرخی فرۆشتن (تاک)',
            item['selling_price_retail'],
            currencyFormat,
            Icons.storefront,
          ),
          const SizedBox(height: 20),
          _buildPaymentMethod(item['isPaidCash'] == 1),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final quantity = item['quantity'] ?? 0;
    final stockStatus = _getStockStatus(quantity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بارەگای کاڵا',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStockColor(quantity).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getStockColor(quantity).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getStockIcon(quantity),
                      color: _getStockColor(quantity),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quantity.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getStockColor(quantity),
                          ),
                        ),
                        Text(
                          stockStatus,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _getStockColor(quantity),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: kTextSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kTextSecondaryColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: kTextSecondaryColor,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value ?? 'بەردەست نییە',
              style: GoogleFonts.inter(
                color: kTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    dynamic price,
    NumberFormat currencyFormat,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kTextSecondaryColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: kTextSecondaryColor,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            currencyFormat.format(price ?? 0),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: kTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(bool isCash) {
    final color = isCash ? kSuccessColor : kPrimaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isCash ? Icons.payments : Icons.credit_card, color: color),
          const SizedBox(width: 12),
          Text(
            isCash ? 'پارەیەکی' : 'قەرز',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Color _getStockColor(int quantity) {
    if (quantity == 0) return kLossColor;
    if (quantity < 10) return kWarningColor;
    return kSuccessColor;
  }

  IconData _getStockIcon(int quantity) {
    if (quantity == 0) return Icons.warning;
    if (quantity < 10) return Icons.inventory_outlined;
    return Icons.inventory;
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return 'کاڵا تەواو بووە';
    if (quantity < 10) return 'کاڵا کەمە';
    return 'کاڵا بەردەستە';
  }
}
