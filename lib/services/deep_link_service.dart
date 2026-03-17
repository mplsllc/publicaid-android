import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/detail_screen.dart';
import '../screens/search_screen.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'bookmark_service.dart';
import 'location_service.dart';
import 'plan_service.dart';

class DeepLinkService {
  final ApiService apiService;
  final LocationService locationService;
  final AuthService authService;
  final BookmarkService bookmarkService;
  final PlanService planService;
  final GlobalKey<NavigatorState> navigatorKey;
  final void Function(int) switchTab;

  DeepLinkService({
    required this.apiService,
    required this.locationService,
    required this.authService,
    required this.bookmarkService,
    required this.planService,
    required this.navigatorKey,
    required this.switchTab,
  });

  // Known category slugs for path disambiguation.
  // /:state/:category is structurally identical to /about/team —
  // we validate segment 2 against this set. Unknown paths fall through
  // to in-app browser. The state segment is intentionally ignored:
  // SearchScreen uses the device's location for result ordering, so
  // filtering by state on top of that would be redundant/confusing.
  static const _categorySlugs = {
    'mental-health', 'substance-use', 'housing', 'food', 'healthcare',
    'legal-aid', 'employment', 'education', 'utilities', 'clothing',
    'transportation', 'childcare', 'veterans', 'disability', 'seniors',
  };

  Future<void> handleUri(Uri uri) async {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    // /entity/:slug
    if (segments.first == 'entity' && segments.length >= 2) {
      await _openEntityBySlug(segments[1]);
      return;
    }

    // /search?q=...&category=...
    if (segments.first == 'search') {
      _openSearch(
        query: uri.queryParameters['q'],
        category: uri.queryParameters['category'],
      );
      return;
    }

    // /crisis
    if (segments.first == 'crisis') {
      switchTab(4);
      return;
    }

    // /:state/:category — validate second segment is a known category
    if (segments.length == 2 && _categorySlugs.contains(segments[1])) {
      _openSearch(category: segments[1]);
      return;
    }

    // Unknown path — open in browser (not silent no-op)
    launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  /// Fetch entity by slug and push DetailScreen.
  /// Shows a loading overlay during fetch. On 404 or network error,
  /// shows a snackbar and does not navigate.
  Future<void> _openEntityBySlug(String slug) async {
    OverlayEntry? overlay;
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState != null) {
      overlay = OverlayEntry(
        builder: (_) => const ColoredBox(
          color: Color(0x44000000),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
      overlayState.insert(overlay);
    }

    try {
      final entity = await apiService.getEntityBySlug(slug);
      overlay?.remove();
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => DetailScreen(
          apiService: apiService,
          entityId: entity.id,
          entityName: entity.name,
          authService: authService,
          bookmarkService: bookmarkService,
          planService: planService,
          locationService: locationService,
        ),
      ));
    } catch (e) {
      overlay?.remove();
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Could not open that link.')),
        );
      }
    }
  }

  /// Push a SearchScreen with optional query/category params.
  void _openSearch({String? query, String? category}) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => SearchScreen(
        apiService: apiService,
        locationService: locationService,
        authService: authService,
        bookmarkService: bookmarkService,
        planService: planService,
        initialQuery: query,
        initialCategory: category,
      ),
    ));
  }
}
