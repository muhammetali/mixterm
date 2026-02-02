import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/services/crypto_service.dart';

void main() {
  group('CryptoService', () {
    group('generateSalt', () {
      test('generates a non-empty salt', () {
        final salt = CryptoService.generateSalt();
        expect(salt, isNotEmpty);
      });

      test('generates unique salts on each call', () {
        final salt1 = CryptoService.generateSalt();
        final salt2 = CryptoService.generateSalt();
        expect(salt1, isNot(equals(salt2)));
      });

      test('generates valid base64 encoded salt', () {
        final salt = CryptoService.generateSalt();
        expect(() => base64.decode(salt), returnsNormally);
      });

      test('generates salt of correct length (16 bytes)', () {
        final salt = CryptoService.generateSalt();
        final decoded = base64.decode(salt);
        expect(decoded.length, equals(16));
      });
    });

    group('encryptWithKey/decryptWithKey', () {
      late Uint8List testKey;

      setUp(() {
        // Generate a 32-byte key for AES-256
        testKey = Uint8List.fromList(List.generate(32, (i) => i));
      });

      test('encrypts and decrypts plaintext correctly', () {
        const plainText = 'Hello, World!';

        final encrypted = CryptoService.encryptWithKey(plainText, testKey);
        final decrypted = CryptoService.decryptWithKey(encrypted, testKey);

        expect(decrypted, equals(plainText));
      });

      test('encrypts and decrypts JSON data correctly', () {
        final jsonData = json.encode({
          'servers': [
            {'name': 'Server 1', 'host': '192.168.1.1'},
            {'name': 'Server 2', 'host': '192.168.1.2'},
          ]
        });

        final encrypted = CryptoService.encryptWithKey(jsonData, testKey);
        final decrypted = CryptoService.decryptWithKey(encrypted, testKey);

        expect(decrypted, equals(jsonData));
        expect(json.decode(decrypted!), isA<Map>());
      });

      test('encrypts and decrypts unicode text correctly', () {
        const plainText = 'Merhaba Dünya! 你好世界 🌍';

        final encrypted = CryptoService.encryptWithKey(plainText, testKey);
        final decrypted = CryptoService.decryptWithKey(encrypted, testKey);

        expect(decrypted, equals(plainText));
      });

      test('produces different ciphertext for same plaintext (due to random IV)', () {
        const plainText = 'Same text';

        final encrypted1 = CryptoService.encryptWithKey(plainText, testKey);
        final encrypted2 = CryptoService.encryptWithKey(plainText, testKey);

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('returns null for invalid ciphertext format', () {
        final decrypted = CryptoService.decryptWithKey('invalid-data', testKey);
        expect(decrypted, isNull);
      });

      test('returns null when decrypting with wrong key', () {
        const plainText = 'Secret message';
        final encrypted = CryptoService.encryptWithKey(plainText, testKey);

        final wrongKey = Uint8List.fromList(List.generate(32, (i) => i + 100));
        final decrypted = CryptoService.decryptWithKey(encrypted, wrongKey);

        expect(decrypted, isNull);
      });

      test('handles empty string', () {
        const plainText = '';

        final encrypted = CryptoService.encryptWithKey(plainText, testKey);
        final decrypted = CryptoService.decryptWithKey(encrypted, testKey);

        expect(decrypted, equals(plainText));
      });

      test('handles large data', () {
        final largeData = 'A' * 100000; // 100KB of data

        final encrypted = CryptoService.encryptWithKey(largeData, testKey);
        final decrypted = CryptoService.decryptWithKey(encrypted, testKey);

        expect(decrypted, equals(largeData));
      });
    });

    group('legacy encrypt/decrypt methods', () {
      test('encrypts and decrypts with password and salt', () {
        const plainText = 'Test message';
        const password = 'my_secure_password';
        final salt = CryptoService.generateSalt();

        final encrypted = CryptoService.encrypt(plainText, password, salt);
        final decrypted = CryptoService.decrypt(encrypted, password, salt);

        expect(decrypted, equals(plainText));
      });

      test('returns null when decrypting with wrong password', () {
        const plainText = 'Test message';
        const password = 'correct_password';
        final salt = CryptoService.generateSalt();

        final encrypted = CryptoService.encrypt(plainText, password, salt);
        final decrypted = CryptoService.decrypt(encrypted, 'wrong_password', salt);

        expect(decrypted, isNull);
      });

      test('returns null when decrypting with wrong salt', () {
        const plainText = 'Test message';
        const password = 'my_password';
        final salt1 = CryptoService.generateSalt();
        final salt2 = CryptoService.generateSalt();

        final encrypted = CryptoService.encrypt(plainText, password, salt1);
        final decrypted = CryptoService.decrypt(encrypted, password, salt2);

        expect(decrypted, isNull);
      });
    });

    group('deriveKeyFromGoogleId', () {
      test('derives consistent key for same input', () {
        const googleUserId = 'google_user_123';
        final salt = CryptoService.generateSalt();

        final key1 = CryptoService.deriveKeyFromGoogleId(googleUserId, salt);
        final key2 = CryptoService.deriveKeyFromGoogleId(googleUserId, salt);

        expect(key1, equals(key2));
      });

      test('derives different keys for different user IDs', () {
        const userId1 = 'user_1';
        const userId2 = 'user_2';
        final salt = CryptoService.generateSalt();

        final key1 = CryptoService.deriveKeyFromGoogleId(userId1, salt);
        final key2 = CryptoService.deriveKeyFromGoogleId(userId2, salt);

        expect(key1, isNot(equals(key2)));
      });

      test('derives different keys for different salts', () {
        const googleUserId = 'same_user';
        final salt1 = CryptoService.generateSalt();
        final salt2 = CryptoService.generateSalt();

        final key1 = CryptoService.deriveKeyFromGoogleId(googleUserId, salt1);
        final key2 = CryptoService.deriveKeyFromGoogleId(googleUserId, salt2);

        expect(key1, isNot(equals(key2)));
      });

      test('derives key of correct length (32 bytes)', () {
        const googleUserId = 'test_user';
        final salt = CryptoService.generateSalt();

        final key = CryptoService.deriveKeyFromGoogleId(googleUserId, salt);

        expect(key.length, equals(32));
      });

      test('derived key can be used for encryption/decryption', () {
        const googleUserId = 'test_user';
        final salt = CryptoService.generateSalt();
        const plainText = 'Secret data';

        final key = CryptoService.deriveKeyFromGoogleId(googleUserId, salt);
        final encrypted = CryptoService.encryptWithKey(plainText, key);
        final decrypted = CryptoService.decryptWithKey(encrypted, key);

        expect(decrypted, equals(plainText));
      });
    });

    group('hashData', () {
      test('produces consistent hash for same input', () {
        const data = 'test data';

        final hash1 = CryptoService.hashData(data);
        final hash2 = CryptoService.hashData(data);

        expect(hash1, equals(hash2));
      });

      test('produces different hash for different input', () {
        final hash1 = CryptoService.hashData('data1');
        final hash2 = CryptoService.hashData('data2');

        expect(hash1, isNot(equals(hash2)));
      });

      test('produces hash of expected length (SHA-256 = 64 hex chars)', () {
        final hash = CryptoService.hashData('test');
        expect(hash.length, equals(64));
      });

      test('produces valid hex string', () {
        final hash = CryptoService.hashData('test');
        final hexRegex = RegExp(r'^[a-f0-9]+$');
        expect(hexRegex.hasMatch(hash), isTrue);
      });
    });
  });
}
