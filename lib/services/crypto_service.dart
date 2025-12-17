import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class CryptoService {
  static const int _iterations = 100000;
  static const int _keyLength = 32;

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    var key = Uint8List.fromList([...passwordBytes, ...salt]);

    for (var i = 0; i < _iterations; i++) {
      key = Uint8List.fromList(sha256.convert(key).bytes);
    }

    return key.sublist(0, _keyLength);
  }

  static String generateSalt() {
    final key = Key.fromSecureRandom(16);
    return base64.encode(key.bytes);
  }

  static String encrypt(String plainText, String masterPassword, String salt) {
    final saltBytes = base64.decode(salt);
    final keyBytes = _deriveKey(masterPassword, saltBytes);
    final key = Key(keyBytes);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final combined = '${base64.encode(iv.bytes)}:${encrypted.base64}';

    return combined;
  }

  static String? decrypt(
      String encryptedText, String masterPassword, String salt) {
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) return null;

      final ivBytes = base64.decode(parts[0]);
      final encryptedData = parts[1];

      final saltBytes = base64.decode(salt);
      final keyBytes = _deriveKey(masterPassword, saltBytes);
      final key = Key(keyBytes);
      final iv = IV(ivBytes);
      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

      return encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      return null;
    }
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }
}
