import 'package:flutter/material.dart';
import '../models/category.dart' as models;
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/search_bar.dart';
import 'search_screen.dart';

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
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Browse by Category',
                  style: TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: 22,
                    color: AppColors.navyBlue,
                  ),
                ),
              ),
            ),
            // Categories list
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
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildCategoryTile(_categories[index]),
                  childCount: _categories.length,
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
        bottom: 40,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyBlue, AppColors.brightBlue],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / brand
          const Text(
            'publicaid',
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 28,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Find help\nnear you',
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 34,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          // Location indicator
          ListenableBuilder(
            listenable: widget.locationService,
            builder: (context, _) {
              final name = widget.locationService.locationName;
              return Row(
                children: [
                  Icon(
                    widget.locationService.permissionGranted
                        ? Icons.location_on
                        : Icons.location_off,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    name ?? (widget.locationService.permissionGranted
                        ? 'Location available'
                        : 'Location not set'),
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
              const Text(
                'What do you need help with?',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyBlue,
                ),
              ),
              const SizedBox(height: 10),
              AppSearchBar(
                controller: _searchController,
                hintText: 'Food, housing, healthcare...',
                onSubmitted: _onSearch,
                showFilter: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(models.Category category) {
    final iconCode = _getCategoryIcon(category.icon);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: () => _onCategoryTap(category),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.heroBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconCode, color: AppColors.brightBlue, size: 22),
          ),
          title: Text(
            category.name,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navyBlue,
            ),
          ),
          subtitle: category.description != null
              ? Text(
                  category.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    color: AppColors.grayText,
                  ),
                )
              : null,
          trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGray),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? icon) {
    switch (icon) {
      case 'food':
        return Icons.restaurant;
      case 'housing':
      case 'shelter':
        return Icons.home;
      case 'health':
      case 'healthcare':
        return Icons.local_hospital;
      case 'employment':
      case 'jobs':
        return Icons.work;
      case 'education':
        return Icons.school;
      case 'legal':
        return Icons.gavel;
      case 'transportation':
        return Icons.directions_bus;
      case 'clothing':
        return Icons.checkroom;
      case 'mental_health':
        return Icons.psychology;
      case 'substance_abuse':
        return Icons.healing;
      case 'utilities':
        return Icons.bolt;
      case 'childcare':
      case 'youth':
        return Icons.child_care;
      case 'disability':
        return Icons.accessible;
      case 'veterans':
        return Icons.military_tech;
      case 'financial':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }
}
