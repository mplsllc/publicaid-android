import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/export.dart';

class VaultService {
  static const String _userBaseUrl = 'https://publicaid.org/api/user';
  static const int _passwordIterations = 600000;
  static const int _pinIterations = 100000;
  static const int _keyLength = 32;
  static const int _ivLength = 12;
  static const int _tagLength = 16;
  static const int _saltLength = 32;

  final FlutterSecureStorage _storage;
  String? _authToken;

  // In-memory state (only populated when unlocked)
  Uint8List? _encryptionKey;
  List<Map<String, dynamic>>? _documents;
  String? _temporaryPassword; // held between unlockWithPassword and setPin
  String? _currentPassword; // held while vault is unlocked (for biometric setup)

  final LocalAuthentication _localAuth = LocalAuthentication();

  VaultService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Check if a vault PIN has been set up.
  Future<bool> hasVault() async {
    final hash = await _storage.read(key: 'vault_pin_hash');
    return hash != null && hash.isNotEmpty;
  }

  /// Provide the auth token for authenticated API calls.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Whether the user is currently authenticated (token present).
  bool get isAuthenticated => _authToken != null;

  /// Whether a vault has ever been created on this or another device
  /// (vault_salt is written by [createVault] and never deleted).
  Future<bool> hasSalt() async =>
      (await _storage.read(key: 'vault_salt')) != null;


  /// Clear all local vault data from secure storage.
  /// Called on logout so a different user doesn't inherit stale vault keys.
  Future<void> clearLocal() async {
    // deleteAll clears the entire Android Keystore for this app,
    // which is necessary because individual key deletes don't always
    // work and Keystore entries can survive app uninstalls.
    await _storage.deleteAll();
    _encryptionKey = null;
    _currentPassword = null;
    _temporaryPassword = null;
    _documents = null;
  }

  // ---------------------------------------------------------------------------
  // Backup codes
  // ---------------------------------------------------------------------------

  /// Generate 8 one-time backup codes in XXXX-XXXX format.
  /// Pure — does not write to storage. Call [saveBackupCodes] after vault creation.
  List<String> generateBackupCodes() {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final bytes = _randomBytes(64); // one byte per character position
    final codes = <String>[];
    for (var i = 0; i < 8; i++) {
      final a = String.fromCharCodes(
        bytes.sublist(i * 8, i * 8 + 4).map((b) => charset.codeUnitAt(b % charset.length)),
      );
      final b = String.fromCharCodes(
        bytes.sublist(i * 8 + 4, i * 8 + 8).map((b) => charset.codeUnitAt(b % charset.length)),
      );
      codes.add('$a-$b');
    }
    return codes;
  }

  /// Persist backup codes encrypted under the vault password.
  /// Must be called after [createVault] (requires vault_salt in secure storage).
  Future<void> saveBackupCodes(List<String> codes, String vaultPassword) async {
    final vaultSaltB64 = await _storage.read(key: 'vault_salt');
    if (vaultSaltB64 == null) {
      throw VaultException(0, 'No vault salt — call createVault first');
    }
    final vaultSalt = base64Decode(vaultSaltB64);

    for (var i = 0; i < codes.length; i++) {
      final normalized = codes[i].replaceAll('-', '').toUpperCase();

      // Store hash for verification
      final hash = sha256.convert(utf8.encode(normalized)).toString();
      await _storage.write(key: 'backup_code_${i}_hash', value: hash);

      // Derive key from code + vault salt, encrypt vault password
      // _encryptWithKey prepends a random 12-byte IV — format: IV(12) + ciphertext + tag(16)
      final codeKey = _derivePinKey(normalized, vaultSalt);
      final encBlob = _encryptWithKey(Uint8List.fromList(utf8.encode(vaultPassword)), codeKey);
      await _storage.write(key: 'backup_code_${i}_enc', value: base64Encode(encBlob));
    }

    await _storage.write(
      key: 'backup_codes_remaining',
      value: List.generate(codes.length, (i) => '$i').join(','),
    );
  }

  /// Returns true if at least one backup code has not yet been used.
  Future<bool> hasBackupCodes() async {
    final remaining = await _storage.read(key: 'backup_codes_remaining');
    return remaining != null && remaining.isNotEmpty;
  }

  /// Attempt recovery with a backup code.
  /// On success, populates [_temporaryPassword] so the caller can invoke [setPin].
  /// Marks the used code as consumed (one-time use).
  /// Returns false if the code is invalid or all codes are exhausted.
  Future<bool> recoverWithBackupCode(String code) async {
    final remaining = await _storage.read(key: 'backup_codes_remaining');
    if (remaining == null || remaining.isEmpty) return false;

    final vaultSaltB64 = await _storage.read(key: 'vault_salt');
    if (vaultSaltB64 == null) return false;
    final vaultSalt = base64Decode(vaultSaltB64);

    final normalized = code.trim().replaceAll('-', '').toUpperCase();
    final inputHash = sha256.convert(utf8.encode(normalized)).toString();

    final indices = remaining.split(',').map(int.parse).toList();

    for (final i in indices) {
      final storedHash = await _storage.read(key: 'backup_code_${i}_hash');
      if (storedHash != inputHash) continue;

      // Hash matched — decrypt the vault password
      final encB64 = await _storage.read(key: 'backup_code_${i}_enc');
      if (encB64 == null) return false;

      try {
        final codeKey = _derivePinKey(normalized, vaultSalt);
        // _decryptWithKey splits first 12 bytes as IV, rest as ciphertext+tag
        final passwordBytes = _decryptWithKey(base64Decode(encB64), codeKey);
        _temporaryPassword = utf8.decode(passwordBytes);
      } catch (_) {
        return false;
      }

      // Mark code as used — delete its data and update remaining list
      await _storage.delete(key: 'backup_code_${i}_hash');
      await _storage.delete(key: 'backup_code_${i}_enc');
      indices.remove(i);
      await _storage.write(
        key: 'backup_codes_remaining',
        value: indices.join(','),
      );

      return true;
    }

    return false;
  }

  /// Create a new vault with a strong password (encrypts files on server)
  /// and a 6-digit PIN (protects the password on device).
  Future<void> createVault(String password, String pin) async {
    // Salt for password → AES key derivation
    final vaultSalt = _randomBytes(_saltLength);
    await _storage.write(key: 'vault_salt', value: base64Encode(vaultSalt));

    // Salt for PIN hashing & PIN key derivation
    final pinSalt = _randomBytes(_saltLength);
    await _storage.write(key: 'vault_pin_salt', value: base64Encode(pinSalt));

    // Hash PIN for quick verification
    final pinHash = _hashPin(pin, pinSalt);
    await _storage.write(key: 'vault_pin_hash', value: pinHash);

    // Derive PIN key and encrypt the password
    final pinKey = _derivePinKey(pin, pinSalt);
    final encryptedPassword = _encryptWithKey(
      Uint8List.fromList(utf8.encode(password)),
      pinKey,
    );
    await _storage.write(
      key: 'vault_encrypted_password',
      value: base64Encode(encryptedPassword),
    );

    await _storage.write(key: 'vault_manifest_v2', value: 'true');

    // Derive the real AES encryption key from the password
    _encryptionKey = _deriveKey(password, vaultSalt);
    _documents = [];
    await _uploadManifest();
  }

  /// Unlock the vault with a 6-digit PIN (daily use).
  /// PIN → verify → decrypt password → derive AES key → download manifest.
  Future<bool> unlockWithPin(String pin) async {
    final storedHash = await _storage.read(key: 'vault_pin_hash');
    final pinSaltB64 = await _storage.read(key: 'vault_pin_salt');
    final encPwdB64 = await _storage.read(key: 'vault_encrypted_password');
    final vaultSaltB64 = await _storage.read(key: 'vault_salt');

    if (storedHash == null ||
        pinSaltB64 == null ||
        encPwdB64 == null ||
        vaultSaltB64 == null) {
      return false;
    }

    final pinSalt = base64Decode(pinSaltB64);
    final pinHash = _hashPin(pin, pinSalt);
    if (pinHash != storedHash) return false;

    // Derive PIN key and decrypt the password
    final pinKey = _derivePinKey(pin, pinSalt);
    final String password;
    try {
      final decryptedBytes = _decryptWithKey(base64Decode(encPwdB64), pinKey);
      password = utf8.decode(decryptedBytes);
    } catch (_) {
      return false;
    }

    // Derive the real AES encryption key from the password
    final vaultSalt = base64Decode(vaultSaltB64);
    _encryptionKey = _deriveKey(password, vaultSalt);
    _currentPassword = password;

    try {
      await _downloadAndDecryptManifest(vaultSaltB64);
    } catch (e) {
      // Manifest decrypt failed — treat as wrong credentials
      _encryptionKey = null;
      _currentPassword = null;
      return false;
    }
    return true;
  }

  /// Unlock the vault with the full password (recovery on new device).
  /// After success, caller should prompt for a new PIN via [setPin].
  Future<bool> unlockWithPassword(String password) async {
    String? vaultSaltB64 = await _storage.read(key: 'vault_salt');

    // If no local salt, try to extract it from the remote manifest.
    Uint8List? manifestBytes;
    if (vaultSaltB64 == null || vaultSaltB64.isEmpty) {
      manifestBytes = await _downloadManifest();
      if (manifestBytes == null || manifestBytes.length < _saltLength) {
        return false;
      }
      final recoveredSalt = manifestBytes.sublist(0, _saltLength);
      vaultSaltB64 = base64Encode(recoveredSalt);
      await _storage.write(key: 'vault_salt', value: vaultSaltB64);
      await _storage.write(key: 'vault_manifest_v2', value: 'true');
    }

    final vaultSalt = base64Decode(vaultSaltB64);
    _encryptionKey = _deriveKey(password, vaultSalt);

    // Try to download and decrypt — if decryption fails, wrong password.
    try {
      await _downloadAndDecryptManifest(vaultSaltB64,
          prefetchedManifest: manifestBytes);
    } catch (_) {
      _encryptionKey = null;
      return false;
    }

    // Hold the password temporarily so setPin can encrypt it.
    _temporaryPassword = password;
    _currentPassword = password;
    return true;
  }

  /// Set or change the 6-digit PIN after a password-based unlock.
  /// Encrypts the password with the new PIN key and stores it locally.
  Future<void> setPin(String pin) async {
    if (_temporaryPassword == null && !isUnlocked) {
      throw VaultException(0, 'No password available — unlock first');
    }

    // If called right after unlockWithPassword, use _temporaryPassword.
    // Otherwise this is a PIN change; caller must supply password separately.
    final password = _temporaryPassword!;

    final pinSalt = _randomBytes(_saltLength);
    await _storage.write(key: 'vault_pin_salt', value: base64Encode(pinSalt));

    final pinHash = _hashPin(pin, pinSalt);
    await _storage.write(key: 'vault_pin_hash', value: pinHash);

    final pinKey = _derivePinKey(pin, pinSalt);
    final encryptedPassword = _encryptWithKey(
      Uint8List.fromList(utf8.encode(password)),
      pinKey,
    );
    await _storage.write(
      key: 'vault_encrypted_password',
      value: base64Encode(encryptedPassword),
    );

    _temporaryPassword = null;
  }

  /// Check if a vault manifest exists on the server (for recovery detection).
  Future<bool> hasRemoteVault() async {
    try {
      final uri = Uri.parse('$_userBaseUrl/vault/manifest');
      final response = await http.get(uri, headers: _authHeaders);
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Lock the vault: securely wipe key material and clear documents.
  void lockVault() {
    if (_encryptionKey != null) {
      for (var i = 0; i < _encryptionKey!.length; i++) {
        _encryptionKey![i] = 0;
      }
      _encryptionKey = null;
    }
    _temporaryPassword = null;
    _currentPassword = null;
    _documents = null;
  }

  /// Whether the vault is currently unlocked and ready.
  bool get isUnlocked => _encryptionKey != null && _documents != null;

  /// Return a copy of the current documents list.
  List<Map<String, dynamic>> getDocuments() {
    _assertUnlocked();
    return List<Map<String, dynamic>>.from(
        _documents!.map((d) => Map<String, dynamic>.from(d)));
  }

  /// Return documents filtered by section. Used by identity/insurance/general screens.
  /// Documents without a section field default to "general".
  List<Map<String, dynamic>> getDocumentsBySection(String section) {
    _assertUnlocked();
    return _documents!
        .where((d) => (d['section'] as String? ?? 'general') == section)
        .map((d) => Map<String, dynamic>.from(d))
        .toList();
  }

  /// Add a plaintext note to the vault manifest.
  Future<void> addNote(String title, String content, {String? section}) async {
    _assertUnlocked();

    final doc = <String, dynamic>{
      'id': _generateId(),
      'type': 'note',
      'title': title,
      'content': content,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (section != null) doc['section'] = section;
    _documents!.add(doc);
    await _uploadManifest();
  }

  // ---------------------------------------------------------------------------
  // Emergency data helpers
  // ---------------------------------------------------------------------------

  /// Get emergency contacts from the manifest.
  List<Map<String, dynamic>> getEmergencyContacts() {
    _assertUnlocked();
    final doc = _documents!.firstWhere(
      (d) => d['type'] == 'emergency_contacts',
      orElse: () => <String, dynamic>{},
    );
    if (doc.isEmpty) return [];
    final contacts = doc['contacts'] as List<dynamic>? ?? [];
    return contacts.map((c) => Map<String, dynamic>.from(c as Map)).toList();
  }

  /// Save emergency contacts to the manifest.
  Future<void> saveEmergencyContacts(List<Map<String, dynamic>> contacts) async {
    _assertUnlocked();
    final index = _documents!.indexWhere((d) => d['type'] == 'emergency_contacts');
    final doc = <String, dynamic>{
      'id': index >= 0 ? _documents![index]['id'] as String : _generateId(),
      'type': 'emergency_contacts',
      'contacts': contacts,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (index >= 0) {
      _documents![index] = doc;
    } else {
      _documents!.add(doc);
    }
    await _uploadManifest();
  }

  /// Get emergency medical info from the manifest.
  Map<String, dynamic>? getEmergencyMedical() {
    _assertUnlocked();
    final doc = _documents!.firstWhere(
      (d) => d['type'] == 'emergency_medical',
      orElse: () => <String, dynamic>{},
    );
    if (doc.isEmpty) return null;
    return Map<String, dynamic>.from(doc);
  }

  /// Save emergency medical info to the manifest.
  Future<void> saveEmergencyMedical(Map<String, dynamic> data) async {
    _assertUnlocked();
    final index = _documents!.indexWhere((d) => d['type'] == 'emergency_medical');
    final doc = <String, dynamic>{
      'id': index >= 0 ? _documents![index]['id'] as String : _generateId(),
      'type': 'emergency_medical',
      ...data,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (index >= 0) {
      _documents![index] = doc;
    } else {
      _documents!.add(doc);
    }
    await _uploadManifest();
  }

  /// Get notes with section == 'emergency'.
  List<Map<String, dynamic>> getEmergencyNotes() {
    _assertUnlocked();
    return _documents!
        .where((d) => d['type'] == 'note' && d['section'] == 'emergency')
        .map((d) => Map<String, dynamic>.from(d))
        .toList();
  }

  /// Check if any emergency data exists (for the ● indicator on home screen).
  bool hasEmergencyData() {
    _assertUnlocked();
    return _documents!.any((d) =>
      d['type'] == 'emergency_contacts' ||
      d['type'] == 'emergency_medical' ||
      d['type'] == 'emergency_bookmarks' ||
      (d['type'] == 'note' && d['section'] == 'emergency'));
  }

  /// Get emergency bookmarks snapshot from the manifest.
  List<Map<String, dynamic>> getEmergencyBookmarks() {
    _assertUnlocked();
    final doc = _documents!.firstWhere(
      (d) => d['type'] == 'emergency_bookmarks',
      orElse: () => <String, dynamic>{},
    );
    if (doc.isEmpty) return [];
    final items = doc['bookmarks'] as List<dynamic>? ?? [];
    return items.map((b) => Map<String, dynamic>.from(b as Map)).toList();
  }

  /// Save emergency bookmarks snapshot to the manifest.
  Future<void> saveEmergencyBookmarks(List<Map<String, dynamic>> bookmarks) async {
    _assertUnlocked();
    final index = _documents!.indexWhere((d) => d['type'] == 'emergency_bookmarks');
    final doc = <String, dynamic>{
      'id': index >= 0 ? _documents![index]['id'] as String : _generateId(),
      'type': 'emergency_bookmarks',
      'bookmarks': bookmarks,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (index >= 0) {
      _documents![index] = doc;
    } else {
      _documents!.add(doc);
    }
    await _uploadManifest();
  }

  /// Encrypt a file, upload it to R2, then record it in the manifest.
  Future<void> addFile(String title, Uint8List fileBytes) async {
    _assertUnlocked();

    final encrypted = _encrypt(fileBytes);
    final uploadResponse = await _uploadFile(encrypted);
    final fileId = uploadResponse['id'] as String;
    final sizeBytes = uploadResponse['size_bytes'] as int;

    final doc = <String, dynamic>{
      'id': fileId,
      'type': 'file',
      'title': title,
      'sizeBytes': sizeBytes,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    _documents!.add(doc);
    await _uploadManifest();
  }

  /// Encrypt a file, upload it to R2, record in manifest with section and description.
  Future<void> addFileToSection(String title, Uint8List fileBytes, {required String section, required String description}) async {
    _assertUnlocked();
    final encrypted = _encrypt(fileBytes);
    final uploadResponse = await _uploadFile(encrypted);
    final fileId = uploadResponse['id'] as String;
    final sizeBytes = uploadResponse['size_bytes'] as int;
    final doc = <String, dynamic>{
      'id': fileId,
      'type': 'file',
      'section': section,
      'title': title,
      'description': description,
      'sizeBytes': sizeBytes,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    _documents!.add(doc);
    await _uploadManifest();
  }

  /// Download and decrypt a file from R2.
  Future<Uint8List> downloadFile(String fileId) async {
    _assertUnlocked();

    final uri = Uri.parse('$_userBaseUrl/vault/$fileId');
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode == 200) {
      return _decrypt(response.bodyBytes);
    }
    throw VaultException(
        response.statusCode, 'Failed to download file: ${response.statusCode}');
  }

  /// Decrypt a file and write it to a temporary path. Returns the full path.
  Future<String> decryptToTempFile(String fileId) async {
    _assertUnlocked();

    // Look up the document to get the original filename / title.
    final doc = _documents!.firstWhere(
      (d) => d['id'] == fileId,
      orElse: () => throw VaultException(404, 'Document not found'),
    );

    final decryptedBytes = await downloadFile(fileId);
    final title = doc['title'] as String? ?? 'file';

    // Extract extension from the title (e.g. "photo.jpg" → "jpg").
    final dotIndex = title.lastIndexOf('.');
    final ext = dotIndex != -1 && dotIndex < title.length - 1
        ? title.substring(dotIndex + 1)
        : 'bin';

    // Generate a short random ID for the temp filename.
    final rng = Random.secure();
    final randomId =
        List.generate(8, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();

    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/vault_temp_$randomId.$ext';

    await File(tempPath).writeAsBytes(decryptedBytes);
    return tempPath;
  }

  /// Update an existing note in the manifest.
  Future<void> updateNote(String id, String title, String content) async {
    _assertUnlocked();

    final index = _documents!.indexWhere((d) => d['id'] == id);
    if (index == -1) throw VaultException(404, 'Document not found');

    _documents![index]['title'] = title;
    _documents![index]['content'] = content;
    await _uploadManifest();
  }

  /// Delete a document. If it is a file, also delete from R2.
  Future<void> deleteDocument(String id) async {
    _assertUnlocked();

    final index = _documents!.indexWhere((d) => d['id'] == id);
    if (index == -1) throw VaultException(404, 'Document not found');

    final doc = _documents![index];
    if (doc['type'] == 'file') {
      await _deleteFile(id);
    }

    _documents!.removeAt(index);
    await _uploadManifest();
  }

  /// Get storage usage from the server.
  Future<Map<String, dynamic>> getUsage() async {
    final uri = Uri.parse('$_userBaseUrl/vault/usage');
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw VaultException(response.statusCode, 'Failed to get usage');
  }

  // ---------------------------------------------------------------------------
  // Biometric unlock
  // ---------------------------------------------------------------------------

  /// Check if device supports biometric.
  Future<bool> canUseBiometric() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return isAvailable || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Check if biometric unlock is enabled for the vault.
  Future<bool> isBiometricEnabled() async {
    final flag = await _storage.read(key: 'vault_biometric_enabled');
    return flag == 'true';
  }

  /// Enable biometric unlock. Reads password from in-memory state, prompts
  /// biometric to confirm, stores password in secure storage on success.
  /// Returns true on success, false if biometric prompt failed/cancelled.
  Future<bool> enableBiometric() async {
    if (_currentPassword == null) return false;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to enable fingerprint unlock',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (!authenticated) return false;
      await _storage.write(key: 'vault_bio_password', value: _currentPassword!);
      await _storage.write(key: 'vault_biometric_enabled', value: 'true');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Disable biometric unlock.
  Future<void> disableBiometric() async {
    await _storage.delete(key: 'vault_bio_password');
    await _storage.delete(key: 'vault_biometric_enabled');
  }

  /// Unlock vault using biometric. Prompts local_auth, reads stored password,
  /// derives AES key, decrypts manifest.
  Future<bool> unlockWithBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your document vault',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (!authenticated) return false;

      final password = await _storage.read(key: 'vault_bio_password');
      if (password == null) return false;

      final saltB64 = await _storage.read(key: 'vault_salt');
      if (saltB64 == null) return false;

      final salt = base64Decode(saltB64);
      _encryptionKey = _deriveKey(password, salt);
      _currentPassword = password;

      // Download and decrypt manifest (same logic as unlockWithPin)
      await _downloadAndDecryptManifest(saltB64);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — auth
  // ---------------------------------------------------------------------------

  Map<String, String> get _authHeaders {
    final headers = <String, String>{};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // Private helpers — PIN hashing
  // ---------------------------------------------------------------------------

  String _hashPin(String pin, Uint8List salt) {
    final input = Uint8List.fromList([...salt, ...utf8.encode(pin)]);
    return sha256.convert(input).toString();
  }

  // ---------------------------------------------------------------------------
  // Private helpers — key derivation
  // ---------------------------------------------------------------------------

  /// Derive the main AES-256 encryption key from the user's password.
  Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _passwordIterations, _keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Derive a key from the 6-digit PIN (used to encrypt the password locally).
  Uint8List _derivePinKey(String pin, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pinIterations, _keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(pin)));
  }

  // ---------------------------------------------------------------------------
  // Private helpers — encryption / decryption
  // ---------------------------------------------------------------------------

  Uint8List _encrypt(Uint8List plaintext) {
    final iv = _randomBytes(_ivLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(_encryptionKey!),
          _tagLength * 8,
          iv,
          Uint8List(0),
        ),
      );

    final output = Uint8List(cipher.getOutputSize(plaintext.length));
    final len = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
    cipher.doFinal(output, len);

    // Format: IV (12) + ciphertext + GCM tag (16)
    return Uint8List.fromList([...iv, ...output]);
  }

  Uint8List _decrypt(Uint8List data) {
    if (data.length < _ivLength + _tagLength) {
      throw VaultException(0, 'Encrypted data too short');
    }

    final iv = data.sublist(0, _ivLength);
    final ciphertextWithTag = data.sublist(_ivLength);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_encryptionKey!),
          _tagLength * 8,
          iv,
          Uint8List(0),
        ),
      );

    final output = Uint8List(cipher.getOutputSize(ciphertextWithTag.length));
    final len = cipher.processBytes(
        ciphertextWithTag, 0, ciphertextWithTag.length, output, 0);
    final finalLen = cipher.doFinal(output, len);

    return output.sublist(0, len + finalLen);
  }

  /// Encrypt arbitrary data with a given key (used for PIN-key encryption).
  Uint8List _encryptWithKey(Uint8List plaintext, Uint8List key) {
    final iv = _randomBytes(_ivLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          _tagLength * 8,
          iv,
          Uint8List(0),
        ),
      );

    final output = Uint8List(cipher.getOutputSize(plaintext.length));
    final len = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
    cipher.doFinal(output, len);

    return Uint8List.fromList([...iv, ...output]);
  }

  /// Decrypt arbitrary data with a given key (used for PIN-key decryption).
  Uint8List _decryptWithKey(Uint8List data, Uint8List key) {
    if (data.length < _ivLength + _tagLength) {
      throw VaultException(0, 'Encrypted data too short');
    }

    final iv = data.sublist(0, _ivLength);
    final ciphertextWithTag = data.sublist(_ivLength);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          _tagLength * 8,
          iv,
          Uint8List(0),
        ),
      );

    final output = Uint8List(cipher.getOutputSize(ciphertextWithTag.length));
    final len = cipher.processBytes(
        ciphertextWithTag, 0, ciphertextWithTag.length, output, 0);
    final finalLen = cipher.doFinal(output, len);

    return output.sublist(0, len + finalLen);
  }

  /// Download the remote manifest and decrypt it into [_documents].
  /// Handles v2 salt-prefix format and legacy migration.
  Future<void> _downloadAndDecryptManifest(
    String vaultSaltB64, {
    Uint8List? prefetchedManifest,
  }) async {
    final manifestBytes = prefetchedManifest ?? await _downloadManifest();
    if (manifestBytes != null && manifestBytes.isNotEmpty) {
      final v2Flag = await _storage.read(key: 'vault_manifest_v2');

      Uint8List encryptedData;

      if (v2Flag == 'true') {
        encryptedData = manifestBytes.sublist(_saltLength);
      } else if (vaultSaltB64.isEmpty) {
        final recoveredSalt = manifestBytes.sublist(0, _saltLength);
        await _storage.write(
            key: 'vault_salt', value: base64Encode(recoveredSalt));
        await _storage.write(key: 'vault_manifest_v2', value: 'true');
        encryptedData = manifestBytes.sublist(_saltLength);
      } else {
        encryptedData = manifestBytes;
      }

      final decrypted = _decrypt(encryptedData);
      final manifestJson =
          json.decode(utf8.decode(decrypted)) as Map<String, dynamic>;
      final rawDocs = manifestJson['documents'] as List<dynamic>? ?? [];
      _documents = rawDocs
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _documents = [];
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — manifest network operations
  // ---------------------------------------------------------------------------

  Future<void> _uploadManifest() async {
    final manifest = json.encode({'documents': _documents});
    final encrypted = _encrypt(Uint8List.fromList(utf8.encode(manifest)));

    // Read the salt and prepend it to the encrypted data (v2 format).
    final saltB64 = await _storage.read(key: 'vault_salt');
    final salt = base64Decode(saltB64!);
    final payload = Uint8List.fromList([...salt, ...encrypted]);

    final uri = Uri.parse('$_userBaseUrl/vault/manifest');
    final response = await http.put(
      uri,
      headers: {
        ..._authHeaders,
        'Content-Type': 'application/octet-stream',
      },
      body: payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VaultException(
          response.statusCode, 'Failed to upload manifest');
    }

    // Mark this device as using the v2 salt-prefixed manifest format.
    await _storage.write(key: 'vault_manifest_v2', value: 'true');
  }

  Future<Uint8List?> _downloadManifest() async {
    final uri = Uri.parse('$_userBaseUrl/vault/manifest');
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode == 404) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw VaultException(
        response.statusCode, 'Failed to download manifest');
  }

  // ---------------------------------------------------------------------------
  // Private helpers — file network operations
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _uploadFile(Uint8List encryptedBytes) async {
    final uri = Uri.parse('$_userBaseUrl/vault/upload');
    final response = await http.post(
      uri,
      headers: {
        ..._authHeaders,
        'Content-Type': 'application/octet-stream',
      },
      body: encryptedBytes,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw VaultException(response.statusCode, 'Failed to upload file');
  }

  Future<void> _deleteFile(String fileId) async {
    final uri = Uri.parse('$_userBaseUrl/vault/$fileId');
    final response = await http.delete(uri, headers: _authHeaders);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VaultException(response.statusCode, 'Failed to delete file');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — utilities
  // ---------------------------------------------------------------------------

  void _assertUnlocked() {
    if (!isUnlocked) {
      throw VaultException(0, 'Vault is locked');
    }
  }

  Uint8List _randomBytes(int length) {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom.nextBytes(length);
  }

  String _generateId() {
    final bytes = _randomBytes(16);
    // Set version 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}

class VaultException implements Exception {
  final int statusCode;
  final String message;

  VaultException(this.statusCode, this.message);

  @override
  String toString() => 'VaultException($statusCode): $message';
}
