import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/providers/server_provider.dart';
import 'package:mixterm/services/sync_service.dart';
import 'package:mixterm/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncService extends Mock implements SyncService {}

void main() {
  late ServerProvider serverProvider;
  late MockSyncService mockSyncService;
  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    await storageService.init();
    // Encryption is now automatically initialized with device key

    mockSyncService = MockSyncService();
    serverProvider = ServerProvider(storageService, mockSyncService);

    // Register fallback for mocktail
    registerFallbackValue(<Server>[]);
  });

  group('Smart Sync Robustness Tests (Mocktail)', () {
    test('Smart Merge: Cloud with newer timestamp should update local server', () async {
      final serverId = 'test-id';
      final localServer = Server(
        id: serverId,
        name: 'Local Version',
        host: '1.1.1.1',
        username: 'user',
        updatedAt: DateTime(2025, 1, 1, 10, 0),
      );

      final cloudServer = Server(
        id: serverId,
        name: 'Cloud Version',
        host: '1.1.1.1',
        username: 'user',
        updatedAt: DateTime(2025, 1, 1, 10, 30),
      );

      // Add local server
      await serverProvider.addServer(localServer);

      // Mock cloud response
      when(() => mockSyncService.syncFromCloud()).thenAnswer((_) async => SyncResult(
            success: true,
            message: 'Cloud data found',
            servers: [cloudServer],
          ));

      when(() => mockSyncService.syncToCloud(any())).thenAnswer((_) async => SyncResult(
            success: true,
            message: 'Synced to cloud',
          ));

      // Perform sync
      await serverProvider.performSmartSync();

      // Verify local server is now the cloud version (newer)
      expect(serverProvider.servers.first.name, 'Cloud Version');
      expect(serverProvider.servers.first.updatedAt, cloudServer.updatedAt);
    });

    test('Mutual Exclusion: Multiple concurrent sync calls should be locked', () async {
      when(() => mockSyncService.syncFromCloud()).thenAnswer((_) async {
        // Add a delay to simulate network latency
        await Future.delayed(const Duration(milliseconds: 100));
        return SyncResult(success: true, message: 'Success', servers: []);
      });

      when(() => mockSyncService.syncToCloud(any())).thenAnswer((_) async =>
          SyncResult(success: true, message: 'Success'));

      // Start first sync
      final firstSync = serverProvider.performSmartSync();

      // Start second sync immediately
      final secondSync = serverProvider.performSmartSync();

      final results = await Future.wait([firstSync, secondSync]);

      expect(results[0].success, true);
      expect(results[1].success, false);
      expect(results[1].message, 'Sync already in progress');
    });

    test('Atomic Safety: Decryption failure should NOT corrupt local data', () async {
      final localServer = Server(name: 'Safe Local', host: '1.1.1.1', username: 'user');
      await serverProvider.addServer(localServer);

      // Mock a decryption failure
      when(() => mockSyncService.syncFromCloud()).thenAnswer((_) async => SyncResult(
            success: false,
            message: 'Failed to decrypt cloud data',
          ));

      final result = await serverProvider.performSmartSync();

      expect(result.success, false);
      // Local data must still exist and be intact
      expect(serverProvider.servers.length, 1);
      expect(serverProvider.servers.first.name, 'Safe Local');
    });
  });
}
