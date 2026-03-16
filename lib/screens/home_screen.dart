import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/category.dart' as models;
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import 'search_screen.dart';

const _categoryEmojis = {
  'food': '\u{1F34E}',
  'housing': '\u{1F3E0}',
  'mental-health': '\u{1F9E0}',
  'substance-use': '\u{1F48A}',
  'healthcare': '\u2764\uFE0F',
  'seniors': '\u{1F474}',
  'disability': '\u267F',
  'legal-aid': '\u2696\uFE0F',
  'education': '\u{1F4DA}',
  'employment': '\u{1F4BC}',
  'utilities': '\u{1F4A1}',
  'clothing': '\u{1F455}',
  'childcare': '\u{1F476}',
  'veterans': '\u{1F396}\uFE0F',
  'transportation': '\u{1F68C}',
};

class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final LocationService locationService;
  final ValueChanged<int>? onSwitchTab;
  final VoidCallback? onOpenAccount;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.locationService,
    this.onSwitchTab,
    this.onOpenAccount,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _prioritySlugs = ['food', 'housing', 'employment', 'mental-health', 'childcare', 'healthcare'];

  List<models.Category> _categories = [];
  bool _loadingCategories = true;
  bool _showAllCategories = false;
  String? _error;
  final _searchController = TextEditingController();
  final _zipController = TextEditingController();

  List<models.Category> get _visibleCategories {
    if (_showAllCategories) return _categories;
    // Show priority categories first, in order
    final priority = <models.Category>[];
    for (final slug in _prioritySlugs) {
      final match = _categories.where((c) => c.slug == slug || c.slug.contains(slug)).firstOrNull;
      if (match != null) priority.add(match);
    }
    return priority.isNotEmpty ? priority : _categories.take(6).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await widget.locationService.requestPermission();
    await widget.locationService.getCurrentPosition();
  }

  Future<void> _loadCategories() async {
    // Don't reload if we already have data
    if (_categories.isNotEmpty) return;
    try {
      final categories = await widget.apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Auto-retry after a delay instead of showing error
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && _categories.isEmpty) _loadCategories();
      }
    }
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          apiService: widget.apiService,
          locationService: widget.locationService,
          initialQuery: query,
        ),
      ),
    );
  }

  void _onCategoryTap(models.Category category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          apiService: widget.apiService,
          locationService: widget.locationService,
          initialCategory: category.slug,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FA),
      body: RefreshIndicator(
        onRefresh: _loadCategories,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Hero section with search card inside (card pokes out via margin-bottom -32)
            SliverToBoxAdapter(child: _buildHeroWithSearch()),
            // "Browse by need" heading
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 48, 20, 10),
                child: Text(
                  'Browse by need',
                  style: TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 21,
                    color: AppColors.navyBlue,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            // Categories grid
            if (_loadingCategories)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.mediumGray),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.grayText)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _loadingCategories = true;
                            _error = null;
                          });
                          _loadCategories();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_categories.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('No categories available',
                      style: TextStyle(color: AppColors.grayText)),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildCategoryCard(_visibleCategories[index]),
                    childCount: _visibleCategories.length,
                  ),
                ),
              ),
              if (!_showAllCategories && _categories.length > _prioritySlugs.length)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _showAllCategories = true),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4A90D9),
                        side: const BorderSide(color: Color(0xFFC8DAF0), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Show all categories',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4A90D9),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.expand_more, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            // Guide CTA
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildGuideCta()),
            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  /// Hero gradient with search card inside — card pokes out 32px below via
  /// negative margin, exactly like the website template:
  ///   #hero { padding: 20px 0 24px }
  ///   .search-card { margin-bottom: -32px; z-index: 20 }
  Widget _buildHeroWithSearch() {
    return Container(
      // The gradient background — clipBehavior none so the card can poke out
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.5, -0.87),
          end: Alignment(0.5, 0.87),
          colors: [Color(0xFF0D3B6E), Color(0xFF1565C0)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20,
          left: 20,
          right: 20,
          bottom: 0, // card handles the bottom spacing
        ),
        child: Column(
          children: [
            // Header row: logo + hamburger
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset('assets/images/logo-light.png', height: 40),
                GestureDetector(
                  onTap: () => _showMobileMenu(context),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Icon(Icons.menu,
                          color: Colors.white.withAlpha(179), size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search card — white, rounded-2xl, shadow, pokes 32px below hero
            Transform.translate(
              offset: const Offset(0, 32),
              child: _buildSearchCard(),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A2F57),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _menuItem(ctx, 'Home', onAction: () {
                Navigator.pop(ctx);
                widget.onSwitchTab?.call(0);
              }, isActive: true),
              _menuItem(ctx, 'Guided Help', onAction: () {
                Navigator.pop(ctx);
                widget.onSwitchTab?.call(2);
              }),
              _menuItem(ctx, 'Blog', onAction: () {
                Navigator.pop(ctx);
                widget.onSwitchTab?.call(3);
              }),
              _menuItem(ctx, 'Crisis', color: const Color(0xFFEF9A9A),
                  onAction: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:988'));
              }),
              Divider(color: Colors.white.withAlpha(26), height: 24),
              _menuItem(ctx, 'Sign In', onAction: () {
                Navigator.pop(ctx);
                widget.onOpenAccount?.call();
              }),
              _menuItem(ctx, 'Create Account',
                  color: const Color(0xFF7AB8E8), onAction: () {
                Navigator.pop(ctx);
                widget.onOpenAccount?.call();
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext ctx, String label,
      {bool isActive = false, Color? color, VoidCallback? onAction}) {
    return GestureDetector(
      onTap: onAction ?? () => Navigator.pop(ctx),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            color: color ?? Colors.white.withAlpha(179),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(46),
            blurRadius: 28,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search input + button row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'e.g. detox, food pantry, shelter...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.inputBorder, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.brightBlue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppColors.lightBg,
                        hintStyle: const TextStyle(
                          fontFamily: 'DMSans',
                          color: AppColors.mediumGray,
                          fontSize: 15,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 15,
                        color: AppColors.navyBlue,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _onSearch(_searchController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        elevation: 2,
                        shadowColor: const Color(0xFF1565C0).withAlpha(77),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Location controls
              ListenableBuilder(
                listenable: widget.locationService,
                builder: (context, _) {
                  final hasLocation = widget.locationService.permissionGranted;
                  if (hasLocation) {
                    return _buildLocationSet();
                  }
                  return _buildLocationControls();
                },
              ),
            ],
          ),
    );
  }

  /// Green pill: "Location set — showing nearby results"
  Widget _buildLocationSet() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC2D6F0), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('\u2705', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Location set \u2014 showing nearby results',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.brightBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Location controls: "My location" button + "or" + ZIP input
  Widget _buildLocationControls() {
    return Row(
      children: [
        // "My location" button
        GestureDetector(
          onTap: () async {
            await widget.locationService.requestPermission();
            await widget.locationService.getCurrentPosition();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC2D6F0), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F4CD}', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  'My location',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.brightBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        // "or" divider
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'or',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFFB0C4DE),
            ),
          ),
        ),
        // ZIP code input
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _zipController,
              keyboardType: TextInputType.number,
              maxLength: 5,
              decoration: InputDecoration(
                hintText: 'ZIP code',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.inputBorder, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.inputBorder, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.brightBlue, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: AppColors.lightBg,
                hintStyle: const TextStyle(
                  fontFamily: 'DMSans',
                  color: AppColors.mediumGray,
                  fontSize: 13,
                ),
              ),
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: AppColors.navyBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(models.Category category) {
    final emoji = _categoryEmojis[category.slug] ?? '\u{1F4CB}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _onCategoryTap(category),
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.heroBg,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFC8DAF0),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navyBlue,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFC8DAF0), width: 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D3B6E).withAlpha(26),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.heroBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text('\u{1F914}', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Not sure where to start?',
                    style: TextStyle(
                      fontFamily: 'InstrumentSerif',
                      fontSize: 15,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "We'll help you find the right services.",
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      color: AppColors.grayText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    widget.onSwitchTab?.call(2); // Switch to Get Help tab
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      'Guide me',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
