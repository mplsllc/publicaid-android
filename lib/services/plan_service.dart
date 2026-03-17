import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plan.dart';
import 'api_service.dart';
import 'auth_service.dart';

class PlanService extends ChangeNotifier {
  final ApiService _api;
  final AuthService _auth;
  List<PlanItem> _items = [];
  bool _loading = false;

  PlanService(this._api, this._auth);

  List<PlanItem> get items => _items;
  bool get loading => _loading;

  bool isInPlan(String entityId) =>
      _items.any((item) => item.entityId == entityId);

  Future<void> init() async {
    await _loadLocal();
    if (_auth.isLoggedIn) {
      await syncWithServer();
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString('plan_items');
    if (itemsJson != null) {
      final list = json.decode(itemsJson) as List<dynamic>;
      _items = list
          .map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'plan_items', json.encode(_items.map((i) => i.toJson()).toList()));
  }

  Future<void> syncWithServer() async {
    if (!_auth.isLoggedIn) return;
    _loading = true;
    notifyListeners();

    try {
      final serverItems = await _api.getPlan();
      _items = serverItems;
      await _saveLocal();
    } catch (_) {
      // Use local data if server fails
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> addToPlan(String entityId,
      {String? entityName, String? city, String? state, String? phone, String? addressLine1}) async {
    if (isInPlan(entityId)) return;

    // Optimistic local add
    final tempItem = PlanItem(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      entityId: entityId,
      sortOrder: _items.length,
      entityName: entityName ?? 'Unknown',
      city: city,
      state: state,
      phone: phone,
      addressLine1: addressLine1,
    );
    _items.add(tempItem);
    notifyListeners();
    await _saveLocal();

    if (_auth.isLoggedIn) {
      try {
        final serverId = await _api.addToPlan(entityId);
        // Replace temp item with server-assigned ID
        final idx = _items.indexWhere((i) => i.entityId == entityId);
        if (idx >= 0) {
          _items[idx] = tempItem.copyWith(sortOrder: idx);
          _items[idx] = PlanItem(
            id: serverId,
            entityId: entityId,
            sortOrder: idx,
            entityName: tempItem.entityName,
            city: city,
            state: state,
            phone: phone,
            addressLine1: addressLine1,
          );
          await _saveLocal();
          notifyListeners();
        }
      } catch (e) {
        // Revert on failure
        _items.removeWhere((i) => i.entityId == entityId);
        notifyListeners();
        await _saveLocal();
        rethrow;
      }
    }
  }

  Future<void> removeFromPlan(String itemId) async {
    final removed = _items.where((i) => i.id == itemId).toList();
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
    await _saveLocal();

    if (_auth.isLoggedIn) {
      try {
        await _api.deletePlanItem(itemId);
      } catch (e) {
        // Revert on failure
        _items.addAll(removed);
        _items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        notifyListeners();
        await _saveLocal();
        rethrow;
      }
    }
  }

  Future<void> updateItem(String itemId, {String? notes, bool? completed}) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;

    final old = _items[idx];
    _items[idx] = old.copyWith(
      notes: notes ?? old.notes,
      completed: completed ?? old.completed,
    );
    notifyListeners();
    await _saveLocal();

    if (_auth.isLoggedIn) {
      try {
        await _api.updatePlanItem(
          itemId,
          notes: _items[idx].notes,
          completed: _items[idx].completed,
        );
      } catch (_) {
        // Revert
        _items[idx] = old;
        notifyListeners();
        await _saveLocal();
      }
    }
  }

  Future<void> reorder(List<PlanItem> newOrder) async {
    _items = newOrder;
    notifyListeners();
    await _saveLocal();

    if (_auth.isLoggedIn) {
      try {
        await _api.reorderPlan(newOrder.map((i) => i.id).toList());
      } catch (_) {
        // Sync will fix order on next load
      }
    }
  }

  void onAuthChanged() {
    if (_auth.isLoggedIn) {
      syncWithServer();
    }
  }
}
