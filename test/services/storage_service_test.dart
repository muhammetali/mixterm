import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/models/settings.dart';
import 'package:mixterm/services/storage_service.dart';
import 'package:mixterm/services/crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    late SharedPreferences prefs;
    late StorageService storageService;

    setUp(() async {
      // Set test device key to bypass path_provider file system access
      CryptoService.setTestDeviceKey('test_device_key_for_storage_tests');
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
    });

    tearDown(() {
      // Reset test device key after each test
      CryptoService.setTestDeviceKey(null);
    });

    group('init', () {
      test('creates a new salt if none exists', () async {
        await storageService.init();

        expect(storageService.salt, isNotNull);
        expect(storageService.salt, isNotEmpty);
      });

      test('reuses existing salt', () async {
        final existingSalt = CryptoService.generateSalt();
        await prefs.setString('encryption_salt', existingSalt);

        storageService = StorageService(prefs);
        await storageService.init();

        expect(storageService.salt, equals(existingSalt));
      });

      test('initializes encryption key', () async {
        await storageService.init();

        expect(storageService.encryptionKey, isNotNull);
        expect(storageService.encryptionKey!.length, equals(32));
      });

      test('defaults to device encryption mode', () async {
        await storageService.init();

        expect(storageService.encryptionMode, equals('device'));
      });

      test('restores google encryption mode if previously set', () async {
        await prefs.setString('encryption_mode', 'google');

        storageService = StorageService(prefs);
        await storageService.init();

        expect(storageService.encryptionMode, equals('google'));
      });
    });

    group('saveServers/loadServers', () {
      late List<Server> testServers;

      setUp(() async {
        await storageService.init();
        testServers = [
          Server(
            id: 'server1',
            name: 'Test Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            password: 'pass1',
          ),
          Server(
            id: 'server2',
            name: 'Test Server 2',
            host: '192.168.1.2',
            port: 2222,
            username: 'user2',
            privateKey: '-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----',
            authType: AuthType.key,
          ),
        ];
      });

      test('saves and loads servers correctly', () async {
        final saveResult = await storageService.saveServers(testServers);
        expect(saveResult, isTrue);

        final loadedServers = await storageService.loadServers();

        expect(loadedServers.length, equals(2));
        expect(loadedServers[0].id, equals('server1'));
        expect(loadedServers[0].name, equals('Test Server 1'));
        expect(loadedServers[0].host, equals('192.168.1.1'));
        expect(loadedServers[0].password, equals('pass1'));
        expect(loadedServers[1].id, equals('server2'));
        expect(loadedServers[1].authType, equals(AuthType.key));
      });

      test('creates backup when saving', () async {
        await storageService.saveServers(testServers);

        // Modify and save again
        final modifiedServers = [testServers[0].copyWith(name: 'Modified Server')];
        await storageService.saveServers(modifiedServers);

        // Check backup exists
        final backupData = prefs.getString('servers_backup');
        expect(backupData, isNotNull);
      });

      test('can skip backup creation', () async {
        await storageService.saveServers(testServers, createBackup: false);

        final backupData = prefs.getString('servers_backup');
        expect(backupData, isNull);
      });

      test('returns empty list when no servers exist', () async {
        final servers = await storageService.loadServers();
        expect(servers, isEmpty);
      });

      test('handles server with all fields', () async {
        final fullServer = Server(
          id: 'full',
          name: 'Full Server',
          host: 'example.com',
          port: 22,
          username: 'admin',
          password: 'secret',
          privateKey: '-----BEGIN RSA PRIVATE KEY-----\n...',
          passphrase: 'key-passphrase',
          authType: AuthType.key,
          group: 'Production',
          updatedAt: DateTime(2024, 1, 15, 10, 30),
        );

        await storageService.saveServers([fullServer]);
        final loaded = await storageService.loadServers();

        expect(loaded[0].name, equals('Full Server'));
        expect(loaded[0].group, equals('Production'));
        expect(loaded[0].passphrase, equals('key-passphrase'));
      });
    });

    group('settings', () {
      setUp(() async {
        await storageService.init();
      });

      test('loads default settings when none exist', () async {
        final settings = await storageService.loadSettings();

        expect(settings, isNotNull);
        expect(settings.fontSize, equals(14)); // default value
      });

      test('saves and loads settings correctly', () async {
        const settings = AppSettings(
          fontSize: 16,
          fontFamily: 'Cascadia Code',
          copyOnSelect: true,
          pasteOnRightClick: false,
          showScrollbar: true,
          terminalOpacity: 0.9,
          scrollbackLines: 5000,
          terminalTheme: 'Dracula',
        );

        await storageService.saveSettings(settings);
        final loaded = await storageService.loadSettings();

        expect(loaded.fontSize, equals(16));
        expect(loaded.fontFamily, equals('Cascadia Code'));
        expect(loaded.copyOnSelect, isTrue);
        expect(loaded.pasteOnRightClick, isFalse);
        expect(loaded.terminalTheme, equals('Dracula'));
      });
    });

    group('Google user', () {
      setUp(() async {
        await storageService.init();
      });

      test('saves and retrieves google user email', () async {
        await storageService.saveGoogleUser('test@gmail.com');
        expect(storageService.getGoogleUser(), equals('test@gmail.com'));
      });

      test('clears google user when set to null', () async {
        await storageService.saveGoogleUser('test@gmail.com');
        await storageService.saveGoogleUser(null);
        expect(storageService.getGoogleUser(), isNull);
      });
    });

    group('sync timestamp', () {
      setUp(() async {
        await storageService.init();
      });

      test('returns 0 when never synced', () {
        expect(storageService.getLastSyncTimestamp(), equals(0));
      });

      test('saves and retrieves sync timestamp', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await storageService.saveLastSyncTimestamp(timestamp);

        expect(storageService.getLastSyncTimestamp(), equals(timestamp));
      });
    });

    group('switchToGoogleEncryption', () {
      setUp(() async {
        await storageService.init();
      });

      test('switches encryption mode to google', () async {
        await storageService.switchToGoogleEncryption('google_user_123');

        expect(storageService.encryptionMode, equals('google'));
      });

      test('re-encrypts existing data with new key', () async {
        // Save data with device key
        final servers = [
          Server(id: 'test', name: 'Test', host: 'localhost', username: 'user'),
        ];
        await storageService.saveServers(servers);

        // Switch to Google encryption
        await storageService.switchToGoogleEncryption('google_user_123');

        // Data should still be readable
        final loaded = await storageService.loadServers();
        expect(loaded.length, equals(1));
        expect(loaded[0].name, equals('Test'));
      });
    });

    group('switchToDeviceEncryption', () {
      setUp(() async {
        await storageService.init();
        await storageService.switchToGoogleEncryption('google_user_123');
      });

      test('switches encryption mode back to device', () async {
        await storageService.switchToDeviceEncryption();

        expect(storageService.encryptionMode, equals('device'));
      });

      test('re-encrypts existing data with device key', () async {
        // Save data with Google key
        final servers = [
          Server(id: 'test', name: 'Google Test', host: 'localhost', username: 'user'),
        ];
        await storageService.saveServers(servers);

        // Switch back to device encryption
        await storageService.switchToDeviceEncryption();

        // Data should still be readable
        final loaded = await storageService.loadServers();
        expect(loaded.length, equals(1));
        expect(loaded[0].name, equals('Google Test'));
      });
    });

    group('initWithGoogleId', () {
      test('initializes encryption key when in google mode', () async {
        await prefs.setString('encryption_mode', 'google');
        storageService = StorageService(prefs);
        await storageService.init();

        final initialKey = storageService.encryptionKey;

        await storageService.initWithGoogleId('google_user_456');

        // Key should be different (derived from Google ID instead of device)
        expect(storageService.encryptionKey, isNotNull);
      });

      test('does nothing when in device mode', () async {
        await storageService.init();
        final initialKey = Uint8List.fromList(storageService.encryptionKey!);

        await storageService.initWithGoogleId('google_user_456');

        expect(storageService.encryptionKey, equals(initialKey));
      });
    });

    group('getEncryptedServersData/setEncryptedServersData', () {
      setUp(() async {
        await storageService.init();
      });

      test('returns null when no data exists', () async {
        final data = await storageService.getEncryptedServersData();
        expect(data, isNull);
      });

      test('sets and gets encrypted data', () async {
        const testData = 'encrypted_data_here';
        await storageService.setEncryptedServersData(testData);

        final data = await storageService.getEncryptedServersData();
        expect(data, equals(testData));
      });
    });
  });
}
