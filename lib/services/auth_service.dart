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

  Future<void> login(String email, String password) async {
    final response = await _api.login(email, password);
    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final userData = UserData.fromJson(data['user'] as Map<String, dynamic>);

    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'saved_email', value: email);
    await _storage.write(key: 'saved_password', value: password);

    _api.setAuthToken(token);
    _state = AuthState(isLoggedIn: true, token: token, user: userData);
    notifyListeners();
  }

  Future<void> register(String email, String password, String passwordConfirm,
      {String? altcha}) async {
    await _api.register(email, password, passwordConfirm, altcha: altcha);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    // Keep email/password for biometric re-auth
    _api.setAuthToken(null);
    _state = const AuthState();
    notifyListeners();
  }

  Future<bool> hasSavedCredentials() async {
    final email = await _storage.read(key: 'saved_email');
    final password = await _storage.read(key: 'saved_password');
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
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

    final email = await _storage.read(key: 'saved_email');
    final password = await _storage.read(key: 'saved_password');
    if (email == null || password == null) {
      throw Exception('No saved credentials found');
    }

    await login(email, password);
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
