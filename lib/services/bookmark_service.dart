import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class BookmarkService extends ChangeNotifier {
  final ApiService _api;
  final AuthService _auth;
  NotificationService? _notificationService;
  Set<String> _bookmarkedIds = {};
  List<BookmarkItem> _bookmarks = [];
  bool _loading = false;

  BookmarkService(this._api, this._auth);

  void setNotificationService(NotificationService svc) {
    _notificationService = svc;
  }

  Set<String> get bookmarkedIds => _bookmarkedIds;
  List<BookmarkItem> get bookmarks => _bookmarks;
  bool get loading => _loading;

  bool isBookmarked(String entityId) => _bookmarkedIds.contains(entityId);

  Future<void> init() async {
    await _loadLocal();
    if (_auth.isLoggedIn) {
      await syncWithServer();
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final idsJson = prefs.getString('bookmark_ids');
    final itemsJson = prefs.getString('bookmark_items');

    if (idsJson != null) {
      final ids = (json.decode(idsJson) as List<dynamic>)
          .map((e) => e.toString())
          .toSet();
      _bookmarkedIds = ids;
    }

    if (itemsJson != null) {
      _bookmarks = (json.decode(itemsJson) as List<dynamic>)
          .map((e) => BookmarkItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'bookmark_ids', json.encode(_bookmarkedIds.toList()));
    await prefs.setString(
        'bookmark_items', json.encode(_bookmarks.map((b) => b.toJson()).toList()));
  }

  Future<void> syncWithServer() async {
    if (!_auth.isLoggedIn) return;
    _loading = true;
    notifyListeners();

    try {
      final serverBookmarks = await _api.getBookmarks();
      _bookmarks = serverBookmarks;
      _bookmarkedIds = serverBookmarks.map((b) => b.entityId).toSet();
      await _saveLocal();
    } catch (_) {
      // Use local data if server fails
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> toggleBookmark(String entityId, {String? name, String? city, String? state, String? phone, String? categoryName, String? addressLine1, String? addressLine2, String? zip, String? description, String? website, double? lat, double? lng, String? slug}) async {
    final wasBookmarked = _bookmarkedIds.contains(entityId);

    // Optimistic update
    if (wasBookmarked) {
      _bookmarkedIds.remove(entityId);
      _bookmarks.removeWhere((b) => b.entityId == entityId);
    } else {
      _bookmarkedIds.add(entityId);
      _bookmarks.add(BookmarkItem(
        entityId: entityId,
        name: name ?? 'Unknown',
        slug: slug,
        city: city,
        state: state,
        phone: phone,
        categoryName: categoryName,
        savedAt: DateTime.now().toIso8601String(),
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        zip: zip,
        description: description,
        website: website,
        lat: lat,
        lng: lng,
      ));
    }
    notifyListeners();
    await _saveLocal();

    // FCM topic subscription
    if (wasBookmarked) {
      _notificationService?.unsubscribeFromEntity(entityId);
    } else {
      _notificationService?.subscribeToEntity(entityId);
    }

    // Sync with server if logged in
    if (_auth.isLoggedIn) {
      try {
        final result = await _api.toggleBookmark(entityId);
        if (kDebugMode) debugPrint('BookmarkService: server saved=$result');
      } catch (e) {
        if (kDebugMode) debugPrint('BookmarkService: server toggle failed: $e');
        // Revert on failure
        if (wasBookmarked) {
          _bookmarkedIds.add(entityId);
        } else {
          _bookmarkedIds.remove(entityId);
          _bookmarks.removeWhere((b) => b.entityId == entityId);
        }
        notifyListeners();
        await _saveLocal();
        rethrow;
      }
    }

    return !wasBookmarked;
  }

  void onAuthChanged() {
    if (_auth.isLoggedIn) {
      syncWithServer();
    }
  }
}
