import 'package:flutter/material.dart';
import '../widgets/app_menu.dart';
import '../models/category.dart' as models;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/bookmark_service.dart';
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
  final AuthService? authService;
  final BookmarkService? bookmarkService;
  final ValueChanged<int>? onSwitchTab;
  final VoidCallback? onOpenAccount;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.locationService,
    this.authService,
    this.bookmarkService,
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
          authService: widget.authService,
          bookmarkService: widget.bookmarkService,
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
          authService: widget.authService,
          bookmarkService: widget.bookmarkService,
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
      backgroundColor: AppColors.heroBgOf(context),
      appBar: AppBar(
        title: Image.asset('assets/images/logo-light.png', height: 28),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _showMobileMenu(context),
          ),
        ],
      ),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 10),
                child: Text(
                  'Browse by need',
                  style: TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 21,
                    color: AppColors.text(context),
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
                          style: TextStyle(color: AppColors.muted(context))),
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
              SliverFillRemaining(
                child: Center(
                  child: Text('No categories available',
                      style: TextStyle(color: AppColors.muted(context))),
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
                        backgroundColor: AppColors.card(context),
                        foregroundColor: AppColors.accent(context),
                        side: BorderSide(color: AppColors.cardBorderOf(context), width: 1.5),
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
                              color: AppColors.accent(context),
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
        padding: const EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: 0,
        ),
        child: Column(
          children: [
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
    showAppMenu(
      context,
      onNavigate: (route) {
        switch (route) {
          case 'home':
            widget.onSwitchTab?.call(0);
            break;
          case 'login':
          case 'register':
          case 'account':
            widget.onOpenAccount?.call();
            break;
        }
      },
      authService: widget.authService,
    );
  }

  Widget _buildSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
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
                              BorderSide(color: AppColors.inputBorderOf(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AppColors.inputBorderOf(context), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AppColors.accent(context), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppColors.bg(context),
                        hintStyle: const TextStyle(
                          fontFamily: 'DMSans',
                          color: AppColors.mediumGray,
                          fontSize: 15,
                        ),
                      ),
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 15,
                        color: AppColors.text(context),
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
                        backgroundColor: AppColors.accent(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        elevation: 2,
                        shadowColor: AppColors.accent(context).withAlpha(77),
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
        color: AppColors.heroBgOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorderOf(context), width: 1.5),
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
                color: AppColors.accent(context),
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
              color: AppColors.heroBgOf(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorderOf(context), width: 1.5),
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
                    color: AppColors.accent(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        // "or" divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'or',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted(context),
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
                  borderSide: BorderSide(
                      color: AppColors.inputBorderOf(context), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: AppColors.inputBorderOf(context), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: AppColors.accent(context), width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: AppColors.bg(context),
                hintStyle: const TextStyle(
                  fontFamily: 'DMSans',
                  color: AppColors.mediumGray,
                  fontSize: 13,
                ),
              ),
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: AppColors.text(context),
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
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _onCategoryTap(category),
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.heroBgOf(context),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            border: Border.all(
              color: AppColors.cardBorderOf(context),
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
                  color: AppColors.bg(context),
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
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
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
          color: AppColors.card(context),
          border: Border.all(color: AppColors.cardBorderOf(context), width: 1.5),
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
                color: AppColors.heroBgOf(context),
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
                  Text(
                    'Not sure where to start?',
                    style: TextStyle(
                      fontFamily: 'InstrumentSerif',
                      fontSize: 15,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "We'll help you find the right services.",
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      color: AppColors.muted(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.accent(context),
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
