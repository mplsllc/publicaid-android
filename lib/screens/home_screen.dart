import 'package:flutter/material.dart';
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

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.locationService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<models.Category> _categories = [];
  bool _loadingCategories = true;
  String? _error;
  final _searchController = TextEditingController();

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
        setState(() {
          _error = 'Could not load categories';
          _loadingCategories = false;
        });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: RefreshIndicator(
        onRefresh: _loadCategories,
        child: CustomScrollView(
          slivers: [
            // Hero section
            SliverToBoxAdapter(child: _buildHero()),
            // Search card overlapping hero
            SliverToBoxAdapter(child: _buildSearchCard()),
            // Section title
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
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
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildCategoryCard(_categories[index]),
                    childCount: _categories.length,
                  ),
                ),
              ),
            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        left: 24,
        right: 24,
        bottom: 48,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.5, -0.87),
          end: Alignment(0.5, 0.87),
          colors: [Color(0xFF0D3B6E), Color(0xFF1565C0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          const Text(
            'Publicaid',
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 28,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          // Tagline
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'InstrumentSerif',
                fontSize: 30,
                height: 1.1,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: 'Find help ',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: 'near you.',
                  style: TextStyle(
                    color: Color(0xFF7AB8E8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Transform.translate(
      offset: const Offset(0, -32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyBlue.withAlpha(20),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'e.g. detox, food pantry, shelter...',
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.mediumGray, size: 22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.brightBlue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
                  hintStyle: const TextStyle(
                    fontFamily: 'DMSans',
                    color: AppColors.mediumGray,
                    fontSize: 14,
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
              const SizedBox(height: 12),
              // Search button row
              Row(
                children: [
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => _onSearch(_searchController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        elevation: 0,
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
              const SizedBox(height: 12),
              // Location status
              ListenableBuilder(
                listenable: widget.locationService,
                builder: (context, _) {
                  final hasLocation =
                      widget.locationService.permissionGranted;
                  return Row(
                    children: [
                      Icon(
                        hasLocation ? Icons.check_circle : Icons.location_off,
                        color: hasLocation
                            ? const Color(0xFF2E7D32)
                            : AppColors.mediumGray,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasLocation
                            ? 'Location set \u2014 showing nearby results'
                            : 'Enable location for nearby results',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          color: hasLocation
                              ? const Color(0xFF2E7D32)
                              : AppColors.grayText,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(models.Category category) {
    final emoji =
        _categoryEmojis[category.slug] ?? '\u{1F4CB}';
    return GestureDetector(
      onTap: () => _onCategoryTap(category),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFC8DAF0),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D3B6E).withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(16),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyBlue,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
