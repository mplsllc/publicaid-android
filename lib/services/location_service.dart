import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationData {
  final double latitude;
  final double longitude;

  const LocationData({required this.latitude, required this.longitude});
}

class LocationService extends ChangeNotifier {
  LocationData? _currentLocation;
  bool _permissionGranted = false;
  bool _loading = false;
  String? _locationName;

  LocationData? get currentLocation => _currentLocation;
  bool get permissionGranted => _permissionGranted;
  bool get loading => _loading;
  String? get locationName => _locationName;

  // Default to center of US if no location
  LocationData get effectiveLocation =>
      _currentLocation ?? const LocationData(latitude: 39.8283, longitude: -98.5795);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('last_lat');
    final lng = prefs.getDouble('last_lng');
    final name = prefs.getString('last_location_name');
    if (lat != null && lng != null) {
      _currentLocation = LocationData(latitude: lat, longitude: lng);
      _locationName = name;
      _permissionGranted = true;
      notifyListeners();
    }
  }

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _permissionGranted = false;
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _permissionGranted = false;
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _permissionGranted = false;
      notifyListeners();
      return false;
    }

    _permissionGranted = true;
    notifyListeners();
    return true;
  }

  Future<void> getCurrentPosition() async {
    _loading = true;
    notifyListeners();

    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        _loading = false;
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _currentLocation = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _permissionGranted = true;

      // Store in SharedPreferences as fallback
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);
    } catch (e) {
      if (kDebugMode) debugPrint('Location error: $e');
      // Fall back to stored location
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_lat');
      final lng = prefs.getDouble('last_lng');
      if (lat != null && lng != null) {
        _currentLocation = LocationData(latitude: lat, longitude: lng);
        _locationName = prefs.getString('last_location_name');
      }
      // If no stored location, effectiveLocation returns US center default
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setLocation(double lat, double lng, {String? name}) async {
    _currentLocation = LocationData(latitude: lat, longitude: lng);
    _locationName = name;
    _permissionGranted = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_lat', lat);
    await prefs.setDouble('last_lng', lng);
    if (name != null) await prefs.setString('last_location_name', name);

    notifyListeners();
  }
}
