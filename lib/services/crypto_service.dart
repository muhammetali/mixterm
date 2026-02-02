import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Parameters for key derivation in isolate
class _KeyDerivationParams {
  final String input;
  final Uint8List salt;
  final int iterations;
  final int keyLength;

  _KeyDerivationParams(this.input, this.salt, this.iterations, this.keyLength);
}

/// Key derivation function that runs in isolate
Uint8List _deriveKeyIsolate(_KeyDerivationParams params) {
  final inputBytes = utf8.encode(params.input);
  var key = Uint8List.fromList([...inputBytes, ...params.salt]);

  for (var i = 0; i < params.iterations; i++) {
    key = Uint8List.fromList(sha256.convert(key).bytes);
  }

  return key.sublist(0, params.keyLength);
}

class CryptoService {
  static const int _iterations = 100000;
  static const int _keyLength = 32;
  static const String _deviceKeyFileName = '.mixterm_device_key';

  /// For testing: allows injecting a mock device key
  static String? _testDeviceKey;

  /// Cached device key to avoid repeated file I/O
  static String? _cachedDeviceKey;

  /// Set a test device key for unit testing (bypasses file system)
  static void setTestDeviceKey(String? key) {
    _testDeviceKey = key;
    _cachedDeviceKey = key; // Also update cache for consistency
  }

  /// Derives a key from input and salt using PBKDF2-like iteration
  /// Runs on UI thread - use deriveKeyAsync for heavy operations
  static Uint8List _deriveKey(String input, Uint8List salt) {
    final inputBytes = utf8.encode(input);
    var key = Uint8List.fromList([...inputBytes, ...salt]);

    for (var i = 0; i < _iterations; i++) {
      key = Uint8List.fromList(sha256.convert(key).bytes);
    }

    return key.sublist(0, _keyLength);
  }

  /// Derives a key asynchronously using compute() to avoid UI freeze
  /// Use this for sync operations that run 100K iterations
  static Future<Uint8List> _deriveKeyAsync(String input, Uint8List salt) {
    return compute(
      _deriveKeyIsolate,
      _KeyDerivationParams(input, salt, _iterations, _keyLength),
    );
  }

  /// Generates a random salt
  static String generateSalt() {
    final key = encrypt_pkg.Key.fromSecureRandom(16);
    return base64.encode(key.bytes);
  }

  /// Gets or creates a device-specific key
  /// This key is stored locally and never synced
  /// Uses in-memory cache to avoid repeated file I/O
  static Future<String> getOrCreateDeviceKey() async {
    // For testing: return mock key if set
    if (_testDeviceKey != null) {
      return _testDeviceKey!;
    }

    // Return cached key if available
    if (_cachedDeviceKey != null) {
      return _cachedDeviceKey!;
    }

    final directory = await getApplicationSupportDirectory();
    final keyFile = File('${directory.path}/$_deviceKeyFileName');

    if (await keyFile.exists()) {
      _cachedDeviceKey = await keyFile.readAsString();
      return _cachedDeviceKey!;
    }

    // Generate a new device key
    final deviceKey = base64.encode(encrypt_pkg.Key.fromSecureRandom(32).bytes);
    await keyFile.writeAsString(deviceKey);
    _cachedDeviceKey = deviceKey; // Cache the new key
    return deviceKey;
  }

  /// Derives encryption key from device key (for local-only mode)
  static Future<Uint8List> deriveKeyFromDevice(String salt) async {
    final deviceKey = await getOrCreateDeviceKey();
    final saltBytes = base64.decode(salt);
    return _deriveKey(deviceKey, saltBytes);
  }

  /// Derives encryption key from Google User ID (for sync mode)
  /// Uses async computation to avoid UI freeze during sync operations
  static Future<Uint8List> deriveKeyFromGoogleIdAsync(String googleUserId, String salt) async {
    final saltBytes = base64.decode(salt);
    return _deriveKeyAsync(googleUserId, saltBytes);
  }

  /// Derives encryption key from Google User ID (for sync mode)
  /// Synchronous version - prefer deriveKeyFromGoogleIdAsync for UI responsiveness
  static Uint8List deriveKeyFromGoogleId(String googleUserId, String salt) {
    final saltBytes = base64.decode(salt);
    return _deriveKey(googleUserId, saltBytes);
  }

  /// Encrypts plaintext with the given key bytes
  static String encryptWithKey(String plainText, Uint8List keyBytes) {
    final key = encrypt_pkg.Key(keyBytes);
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.gcm));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final combined = '${base64.encode(iv.bytes)}:${encrypted.base64}';

    return combined;
  }

  /// Decrypts ciphertext with the given key bytes
  static String? decryptWithKey(String encryptedText, Uint8List keyBytes) {
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) return null;

      final ivBytes = base64.decode(parts[0]);
      final encryptedData = parts[1];

      final key = encrypt_pkg.Key(keyBytes);
      final iv = encrypt_pkg.IV(ivBytes);
      final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.gcm));

      return encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      return null;
    }
  }

  /// Legacy encrypt method for backward compatibility
  static String encrypt(String plainText, String password, String salt) {
    final saltBytes = base64.decode(salt);
    final keyBytes = _deriveKey(password, saltBytes);
    return encryptWithKey(plainText, keyBytes);
  }

  /// Legacy decrypt method for backward compatibility
  static String? decrypt(String encryptedText, String password, String salt) {
    try {
      final saltBytes = base64.decode(salt);
      final keyBytes = _deriveKey(password, saltBytes);
      return decryptWithKey(encryptedText, keyBytes);
    } catch (e) {
      return null;
    }
  }

  /// Computes SHA-256 hash (used for checksums)
  static String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Clear cached device key (useful for testing)
  static void clearCache() {
    _cachedDeviceKey = null;
  }
}
