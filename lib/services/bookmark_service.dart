import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth.dart';
import 'api_service.dart';
import 'auth_service.dart';

class BookmarkService extends ChangeNotifier {
  final ApiService _api;
  final AuthService _auth;
  Set<String> _bookmarkedIds = {};
  List<BookmarkItem> _bookmarks = [];
  bool _loading = false;

  BookmarkService(this._api, this._auth);

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

  Future<bool> toggleBookmark(String entityId, {String? name, String? city, String? state, String? phone, String? categoryName}) async {
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
        city: city,
        state: state,
        phone: phone,
        categoryName: categoryName,
        savedAt: DateTime.now().toIso8601String(),
      ));
    }
    notifyListeners();
    await _saveLocal();

    // Sync with server if logged in
    if (_auth.isLoggedIn) {
      try {
        debugPrint('BookmarkService: toggling $entityId on server');
        final result = await _api.toggleBookmark(entityId);
        debugPrint('BookmarkService: server returned saved=$result');
      } catch (e) {
        debugPrint('BookmarkService: server toggle failed: $e');
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
