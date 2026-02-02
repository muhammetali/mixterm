import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:path_provider/path_provider.dart';

class CryptoService {
  static const int _iterations = 100000;
  static const int _keyLength = 32;
  static const String _deviceKeyFileName = '.mixterm_device_key';

  /// Derives a key from input and salt using PBKDF2-like iteration
  static Uint8List _deriveKey(String input, Uint8List salt) {
    final inputBytes = utf8.encode(input);
    var key = Uint8List.fromList([...inputBytes, ...salt]);

    for (var i = 0; i < _iterations; i++) {
      key = Uint8List.fromList(sha256.convert(key).bytes);
    }

    return key.sublist(0, _keyLength);
  }

  /// Generates a random salt
  static String generateSalt() {
    final key = Key.fromSecureRandom(16);
    return base64.encode(key.bytes);
  }

  /// Gets or creates a device-specific key
  /// This key is stored locally and never synced
  static Future<String> getOrCreateDeviceKey() async {
    final directory = await getApplicationSupportDirectory();
    final keyFile = File('${directory.path}/$_deviceKeyFileName');

    if (await keyFile.exists()) {
      return await keyFile.readAsString();
    }

    // Generate a new device key
    final deviceKey = base64.encode(Key.fromSecureRandom(32).bytes);
    await keyFile.writeAsString(deviceKey);
    return deviceKey;
  }

  /// Derives encryption key from device key (for local-only mode)
  static Future<Uint8List> deriveKeyFromDevice(String salt) async {
    final deviceKey = await getOrCreateDeviceKey();
    final saltBytes = base64.decode(salt);
    return _deriveKey(deviceKey, saltBytes);
  }

  /// Derives encryption key from Google User ID (for sync mode)
  static Uint8List deriveKeyFromGoogleId(String googleUserId, String salt) {
    final saltBytes = base64.decode(salt);
    return _deriveKey(googleUserId, saltBytes);
  }

  /// Encrypts plaintext with the given key bytes
  static String encryptWithKey(String plainText, Uint8List keyBytes) {
    final key = Key(keyBytes);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

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

      final key = Key(keyBytes);
      final iv = IV(ivBytes);
      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

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
}
