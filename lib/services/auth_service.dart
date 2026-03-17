import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../models/auth.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthState _state = const AuthState();
  AuthState get state => _state;

  bool get isLoggedIn => _state.isLoggedIn;
  UserData? get user => _state.user;
  String? get token => _state.token;

  AuthService(this._api);

  Future<void> init() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      _api.setAuthToken(token);
      try {
        final user = await _api.getMe();
        _state = AuthState(isLoggedIn: true, token: token, user: user);
      } catch (_) {
        // Token expired or invalid, keep stored credentials for biometric
        _state = const AuthState();
        _api.setAuthToken(null);
      }
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login(String email, String password,
      {String? altcha, String? totpCode}) async {
    final response =
        await _api.login(email, password, altcha: altcha, totpCode: totpCode);
    final data = response['data'] as Map<String, dynamic>;

    // Check if 2FA is required
    if (data['totp_required'] == true) {
      return data;
    }

    final token = data['token'] as String;
    final userData = UserData.fromJson(data['user'] as Map<String, dynamic>);

    await _storage.write(key: 'auth_token', value: token);
    // Store email for display only — never store passwords
    await _storage.write(key: 'saved_email', value: email);

    _api.setAuthToken(token);
    _state = AuthState(isLoggedIn: true, token: token, user: userData);
    notifyListeners();
    return data;
  }

  Future<void> register(String email, String password, String passwordConfirm,
      {String? altcha}) async {
    await _api.register(email, password, passwordConfirm, altcha: altcha);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'saved_password'); // Clean up legacy key
    _api.setAuthToken(null);
    _state = const AuthState();
    notifyListeners();
  }

  /// Biometric login requires a stored token (not password).
  Future<bool> hasSavedCredentials() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && token.isNotEmpty;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isAvailable && !isDeviceSupported) return false;
      final hasCreds = await hasSavedCredentials();
      return hasCreds;
    } catch (_) {
      return false;
    }
  }

  Future<void> biometricLogin() async {
    final authenticated = await _localAuth.authenticate(
      localizedReason: 'Sign in to Publicaid',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
    if (!authenticated) {
      throw Exception('Biometric authentication failed');
    }

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('No saved session found');
    }

    // Validate the stored token against the server
    _api.setAuthToken(token);
    try {
      final user = await _api.getMe();
      _state = AuthState(isLoggedIn: true, token: token, user: user);
      notifyListeners();
    } catch (_) {
      // Token expired or revoked — clear it
      await _storage.delete(key: 'auth_token');
      _api.setAuthToken(null);
      throw Exception('Session expired. Please sign in again.');
    }
  }

  Future<void> refreshUser() async {
    if (!isLoggedIn) return;
    try {
      final user = await _api.getMe();
      _state = _state.copyWith(user: user);
      notifyListeners();
    } catch (_) {
      // Silently fail
    }
  }
}
