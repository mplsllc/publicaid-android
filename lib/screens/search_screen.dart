import 'package:flutter/material.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/bookmark_service.dart';
import '../services/location_service.dart';
import '../services/plan_service.dart';
import '../theme.dart';
import '../widgets/entity_card.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final ApiService apiService;
  final LocationService locationService;
  final AuthService? authService;
  final BookmarkService? bookmarkService;
  final PlanService? planService;
  final String? initialQuery;
  final String? initialCategory;

  const SearchScreen({
    super.key,
    required this.apiService,
    required this.locationService,
    this.authService,
    this.bookmarkService,
    this.planService,
    this.initialQuery,
    this.initialCategory,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Entity> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _total = 0;
  int _offset = 0;
  static const _limit = 20;

  String? _selectedCategory;
  String? _selectedState;

  // Filter options
  List<Map<String, String>> _categoryOptions = [];
  List<String> _stateOptions = [];
  // ignore: unused_field — reserved for future use
  bool _filtersLoaded = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';
    _selectedCategory = widget.initialCategory;
    _scrollController.addListener(_onScroll);
    _loadFilters();
    _doSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final filters = await widget.apiService.getFilters();
      if (mounted) {
        setState(() {
          _filtersLoaded = true;
          if (filters['categories'] is List) {
            _categoryOptions = (filters['categories'] as List)
                .map((c) => {
                      'slug': (c['slug'] ?? '').toString(),
                      'name': (c['name'] ?? '').toString(),
                    })
                .toList();
          }
          if (filters['states'] is List) {
            _stateOptions = (filters['states'] as List)
                .map((s) => s.toString())
                .toList();
          }
        });
      }
    } catch (_) {
      // Filters are optional, search still works
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _doSearch() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _results = [];
    });

    try {
      final loc = widget.locationService.effectiveLocation;
      final response = await widget.apiService.search(
        query: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        category: _selectedCategory,
        state: _selectedState,
        lat: widget.locationService.currentLocation != null
            ? loc.latitude
            : null,
        lng: widget.locationService.currentLocation != null
            ? loc.longitude
            : null,
        limit: _limit,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _results = response.data;
          _total = response.meta?.total ?? response.data.length;
          _offset = response.data.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Auto-retry once after delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted && _results.isEmpty) {
          _doSearch();
          return;
        }
        if (mounted) {
          setState(() {
            _error = 'Search failed. Tap to retry.';
            _loading = false;
          });
        }
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _offset >= _total) return;

    setState(() => _loadingMore = true);

    try {
      final loc = widget.locationService.effectiveLocation;
      final response = await widget.apiService.search(
        query: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        category: _selectedCategory,
        state: _selectedState,
        lat: widget.locationService.currentLocation != null
            ? loc.latitude
            : null,
        lng: widget.locationService.currentLocation != null
            ? loc.longitude
            : null,
        limit: _limit,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _results.addAll(response.data);
          _offset += response.data.length;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(
        categoryOptions: _categoryOptions,
        stateOptions: _stateOptions,
        selectedCategory: _selectedCategory,
        selectedState: _selectedState,
        onApply: (category, state) {
          Navigator.pop(ctx);
          setState(() {
            _selectedCategory = category;
            _selectedState = state;
          });
          _doSearch();
        },
      ),
    );
  }

  void _removeCategory() {
    setState(() => _selectedCategory = null);
    _doSearch();
  }

  void _removeState() {
    setState(() => _selectedState = null);
    _doSearch();
  }

  void _openDetail(Entity entity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          apiService: widget.apiService,
          entityId: entity.id,
          entityName: entity.name,
          authService: widget.authService,
          bookmarkService: widget.bookmarkService,
          planService: widget.planService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          color: AppColors.navyBlue,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back button row
                  Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 24),
                        ),
                      if (Navigator.of(context).canPop())
                        const SizedBox(width: 12),
                      const Text(
                        'Search',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: const Icon(Icons.tune,
                            color: Colors.white70, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search input row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'e.g. detox, food pantry, shelter...',
                              prefixIcon: const Icon(Icons.search,
                                  color: AppColors.mediumGray, size: 20),
                              filled: true,
                              fillColor: AppColors.surface(context),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              hintStyle: const TextStyle(
                                fontFamily: 'DMSans',
                                color: AppColors.mediumGray,
                                fontSize: 14,
                              ),
                            ),
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 14,
                              color: AppColors.text(context),
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _doSearch(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: _doSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surface(context),
                            foregroundColor: AppColors.accent(context),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 0),
                          ),
                          child: const Text(
                            'Search',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active filters + result count
          _buildFilterBar(),
          // Results
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final hasFilters = _selectedCategory != null || _selectedState != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasFilters) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_selectedCategory != null)
                  Chip(
                    label: Text(_selectedCategory!),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _removeCategory,
                  ),
                if (_selectedState != null)
                  Chip(
                    label: Text(_selectedState!),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _removeState,
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (!_loading)
            Text(
              'Showing ${_results.length} of $_total result${_total == 1 ? '' : 's'}',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                color: AppColors.muted(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
              onPressed: _doSearch,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 56, color: AppColors.mediumGray.withAlpha(128)),
            const SizedBox(height: 12),
            const Text(
              'No results found',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navyBlue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: AppColors.grayText,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: _results.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final entity = _results[index];
        return EntityCard(
          entity: entity,
          onTap: () => _openDetail(entity),
          isBookmarked: widget.bookmarkService?.isBookmarked(entity.id) ?? false,
          onBookmark: widget.bookmarkService != null
              ? () => widget.bookmarkService!.toggleBookmark(
                    entity.id,
                    name: entity.name,
                    slug: entity.slug,
                    city: entity.city,
                    state: entity.state,
                    phone: entity.phone,
                    categoryName: entity.categories.isNotEmpty
                        ? entity.categories.first.name
                        : null,
                    addressLine1: entity.addressLine1,
                    addressLine2: entity.addressLine2,
                    zip: entity.zip,
                    description: entity.description,
                    website: entity.website,
                    lat: entity.lat,
                    lng: entity.lng,
                  )
              : null,
        );
      },
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final List<Map<String, String>> categoryOptions;
  final List<String> stateOptions;
  final String? selectedCategory;
  final String? selectedState;
  final void Function(String? category, String? state) onApply;

  const _FilterSheet({
    required this.categoryOptions,
    required this.stateOptions,
    this.selectedCategory,
    this.selectedState,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _category;
  String? _state;

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _state = widget.selectedState;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontFamily: 'InstrumentSerif',
                  fontSize: 22,
                  color: AppColors.navyBlue,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _category = null;
                    _state = null;
                  });
                },
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Category dropdown
          const Text('Category',
              style: TextStyle(
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'All categories',
            ),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('All categories')),
              ...widget.categoryOptions.map((c) => DropdownMenuItem(
                    value: c['slug'],
                    child: Text(c['name'] ?? c['slug']!),
                  )),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
          // State dropdown
          const Text('State',
              style: TextStyle(
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _state,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'All states',
            ),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('All states')),
              ...widget.stateOptions.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s),
                  )),
            ],
            onChanged: (v) => setState(() => _state = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onApply(_category, _state),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}
