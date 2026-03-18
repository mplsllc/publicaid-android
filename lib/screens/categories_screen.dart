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

  // Icon mapping matches the server's category icon field values
  IconData _getIcon(String? icon) {
    switch (icon) {
      case 'brain':
        return Icons.psychology;
      case 'heart-pulse':
        return Icons.healing;
      case 'home':
        return Icons.home;
      case 'utensils':
        return Icons.restaurant;
      case 'stethoscope':
        return Icons.local_hospital;
      case 'scale':
        return Icons.gavel;
      case 'briefcase':
        return Icons.work;
      case 'book':
        return Icons.school;
      case 'zap':
        return Icons.bolt;
      case 'shirt':
        return Icons.checkroom;
      case 'car':
        return Icons.directions_bus;
      case 'baby':
        return Icons.child_care;
      case 'shield':
        return Icons.military_tech;
      case 'accessibility':
        return Icons.accessible;
      case 'heart-handshake':
        return Icons.elderly;
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
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.muted(context)),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: AppColors.muted(context))),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _loadCategories,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? Center(
                      child: Text('No categories available',
                          style: TextStyle(color: AppColors.muted(context))),
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
                color: isChild
                    ? AppColors.tagBgOf(context)
                    : AppColors.heroBgOf(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(category.icon),
                color: AppColors.accent(context),
                size: 20,
              ),
            ),
            title: Text(
              category.name,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: isChild ? 14 : 15,
                fontWeight: isChild ? FontWeight.w500 : FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
            subtitle: category.description != null && !isChild
                ? Text(
                    category.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  )
                : null,
            trailing: category.children.isNotEmpty
                ? Icon(Icons.expand_more, color: AppColors.muted(context))
                : Icon(Icons.chevron_right, color: AppColors.muted(context)),
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
