import 'package:flutter/material.dart';
import '../models/category.dart' as models;
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final ApiService apiService;
  final LocationService locationService;

  const CategoriesScreen({
    super.key,
    required this.apiService,
    required this.locationService,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<models.Category> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load categories';
          _loading = false;
        });
      }
    }
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

  IconData _getIcon(String? icon) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                        onPressed: _loadCategories,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? const Center(
                      child: Text('No categories available',
                          style: TextStyle(color: AppColors.grayText)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          return _buildCategoryItem(cat, isChild: false);
                        },
                      ),
                    ),
    );
  }

  Widget _buildCategoryItem(models.Category category,
      {required bool isChild}) {
    return Column(
      children: [
        Card(
          margin: EdgeInsets.only(
            left: isChild ? 32 : 16,
            right: 16,
            top: 3,
            bottom: 3,
          ),
          child: ListTile(
            onTap: () => _onCategoryTap(category),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isChild ? AppColors.tagBg : AppColors.heroBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(category.icon),
                color: AppColors.brightBlue,
                size: 20,
              ),
            ),
            title: Text(
              category.name,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: isChild ? 14 : 15,
                fontWeight: isChild ? FontWeight.w500 : FontWeight.w600,
                color: AppColors.navyBlue,
              ),
            ),
            subtitle: category.description != null && !isChild
                ? Text(
                    category.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: AppColors.grayText,
                    ),
                  )
                : null,
            trailing: category.children.isNotEmpty
                ? const Icon(Icons.expand_more, color: AppColors.mediumGray)
                : const Icon(Icons.chevron_right, color: AppColors.mediumGray),
          ),
        ),
        // Children
        if (category.children.isNotEmpty)
          ...category.children
              .map((child) => _buildCategoryItem(child, isChild: true)),
      ],
    );
  }
}
