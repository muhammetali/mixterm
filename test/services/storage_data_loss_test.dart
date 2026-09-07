import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/services/crypto_service.dart';
import 'package:mixterm/services/storage_service.dart';

/// Tests for the paths where the vault can be lost rather than merely
/// mis-read.
///
/// These are separated from `storage_service_test.dart` because they are not
/// about whether a feature works — they are about whether a failure somewhere
/// else takes the user's saved servers with it. Each one describes a way the
/// credentials could have become permanently unreadable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late StorageService storage;

  final server = Server(
    id: 's1',
    name: 'Production',
    host: 'prod.example.com',
    port: 22,
    username: 'deploy',
    password: 'secret',
    authType: AuthType.password,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    CryptoService.setTestDeviceKey('test_device_key_for_data_loss_tests');
    storage = StorageService(prefs);
    await storage.init();
  });

  tearDown(() => CryptoService.setTestDeviceKey(null));

  group('switching encryption key', () {
    test('moves existing servers across to the new key', () async {
      await storage.saveServers([server]);

      await storage.switchToGoogleEncryption('google-user-1');

      final loaded = await storage.loadServers();
      expect(loaded.map((s) => s.id), ['s1'],
          reason: 'the vault must still open after a successful switch');
      expect(loaded.first.password, 'secret');
    });

    test('refuses to adopt the new key when the vault cannot be re-encrypted',
        () async {
      // The regression this exists for: `_reEncryptData` returned void and
      // bailed out silently when decryption failed, but the caller adopted
      // the new key regardless. The stored bytes were still sealed with the
      // old key, so the vault became permanently unreadable — signing in to
      // Google could destroy every saved credential.
      await storage.saveServers([server]);
      final keyBefore = storage.encryptionKey;

      // Corrupt the stored blob so it cannot be decrypted with any key.
      await prefs.setString('servers', 'not-actually-encrypted-data');

      await storage.switchToGoogleEncryption('google-user-1');

      expect(
        storage.encryptionKey,
        equals(keyBefore),
        reason: 'the active key must not move ahead of the data it unseals',
      );
      expect(prefs.getString('encryption_mode'), isNot('google'),
          reason: 'the recorded mode must not claim a switch that failed');
    });

    test('switching back to device encryption is equally guarded', () async {
      await storage.saveServers([server]);
      await storage.switchToGoogleEncryption('google-user-1');
      final keyBefore = storage.encryptionKey;

      await prefs.setString('servers', 'corrupted');
      await storage.switchToDeviceEncryption();

      expect(storage.encryptionKey, equals(keyBefore));
    });

    test('an empty vault switches cleanly', () async {
      // Nothing stored is not a failure: a user who signs in before adding
      // any server must still end up on the Google key.
      final keyBefore = storage.encryptionKey;

      await storage.switchToGoogleEncryption('google-user-1');

      expect(storage.encryptionKey, isNot(equals(keyBefore)));
      expect(prefs.getString('encryption_mode'), 'google');
    });
  });

  group('backup recovery', () {
    test('a corrupted primary vault falls back to the backup', () async {
      // `loadServers` has three separate fallbacks to the backup copy and
      // none of them was exercised: the backup was written and never once
      // read, so it could have been silently broken for any number of
      // releases.
      await storage.saveServers([server]);
      await storage.saveServers([server]); // second save populates the backup

      expect(prefs.getString('servers_backup'), isNotNull,
          reason: 'the backup must exist before this test means anything');

      await prefs.setString('servers', 'corrupted-beyond-decryption');

      final loaded = await storage.loadServers();
      expect(loaded.map((s) => s.id), ['s1'],
          reason: 'a corrupted primary must not lose the vault');
    });

    test('returns empty rather than throwing when both copies are corrupt',
        () async {
      await storage.saveServers([server]);
      await storage.saveServers([server]);

      await prefs.setString('servers', 'corrupted');
      await prefs.setString('servers_backup', 'also-corrupted');

      // The app must still start. Losing the list is bad; crashing on launch
      // with no way back in is worse.
      expect(await storage.loadServers(), isEmpty);
    });
  });
}
