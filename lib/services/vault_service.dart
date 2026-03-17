import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

class VaultService {
  static const String _userBaseUrl = 'https://publicaid.org/api/user';
  static const int _pbkdf2Iterations = 100000;
  static const int _keyLength = 32;
  static const int _ivLength = 12;
  static const int _tagLength = 16;
  static const int _saltLength = 32;

  final FlutterSecureStorage _storage;
  String? _authToken;

  // In-memory state (only populated when unlocked)
  Uint8List? _encryptionKey;
  List<Map<String, dynamic>>? _documents;

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

  /// Create a new vault: generate salt, hash the PIN, persist both, and upload
  /// an empty manifest.
  Future<void> createVault(String pin) async {
    final salt = _randomBytes(_saltLength);
    final pinHash = _hashPin(pin, salt);

    await _storage.write(key: 'vault_salt', value: base64Encode(salt));
    await _storage.write(key: 'vault_pin_hash', value: pinHash);
    await _storage.write(key: 'vault_manifest_v2', value: 'true');

    _encryptionKey = _deriveKey(pin, salt);
    _documents = [];
    await _uploadManifest();
  }

  /// Unlock the vault: verify the PIN, derive the key, download and decrypt
  /// the manifest. Returns `true` on success, `false` if the PIN is wrong.
  Future<bool> unlockVault(String pin) async {
    final storedHash = await _storage.read(key: 'vault_pin_hash');
    final saltB64 = await _storage.read(key: 'vault_salt');

    if (storedHash == null || saltB64 == null) return false;

    final salt = base64Decode(saltB64);
    final pinHash = _hashPin(pin, salt);

    if (pinHash != storedHash) return false;

    _encryptionKey = _deriveKey(pin, salt);

    final manifestBytes = await _downloadManifest();
    if (manifestBytes != null && manifestBytes.isNotEmpty) {
      final v2Flag = await _storage.read(key: 'vault_manifest_v2');
      final hasLocalSalt = saltB64.isNotEmpty;

      Uint8List encryptedData;

      if (v2Flag == 'true') {
        // v2 format: first 32 bytes are salt, remainder is encrypted manifest.
        encryptedData = manifestBytes.sublist(_saltLength);
      } else if (!hasLocalSalt) {
        // New device recovery: no v2 flag AND no local salt.
        // Strip the salt prefix, store it locally, set v2 flag.
        final recoveredSalt = manifestBytes.sublist(0, _saltLength);
        await _storage.write(
            key: 'vault_salt', value: base64Encode(recoveredSalt));
        await _storage.write(key: 'vault_manifest_v2', value: 'true');
        encryptedData = manifestBytes.sublist(_saltLength);
      } else {
        // Legacy vault: v2 flag missing but local salt present.
        // Decrypt entire blob as-is (no salt prefix).
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

    return true;
  }

  /// Lock the vault: securely wipe key material and clear documents.
  void lockVault() {
    if (_encryptionKey != null) {
      for (var i = 0; i < _encryptionKey!.length; i++) {
        _encryptionKey![i] = 0;
      }
      _encryptionKey = null;
    }
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

  /// Add a plaintext note to the vault manifest.
  Future<void> addNote(String title, String content) async {
    _assertUnlocked();

    final doc = <String, dynamic>{
      'id': _generateId(),
      'type': 'note',
      'title': title,
      'content': content,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    _documents!.add(doc);
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

  Uint8List _deriveKey(String pin, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
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
    cipher.doFinal(output, len);

    return output.sublist(0, output.length - _tagLength);
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
