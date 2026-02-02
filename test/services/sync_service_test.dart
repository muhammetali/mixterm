import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/services/auth_service.dart';
import 'package:mixterm/services/storage_service.dart';
import 'package:mixterm/services/sync_service.dart';
import 'package:mixterm/services/crypto_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService', () {
    late MockAuthService mockAuthService;
    late MockStorageService mockStorageService;
    late SyncService syncService;
    late Uint8List testEncryptionKey;
    late String testSalt;

    setUpAll(() {
      registerFallbackValue(<Server>[]);
    });

    setUp(() {
      mockAuthService = MockAuthService();
      mockStorageService = MockStorageService();
      syncService = SyncService(mockAuthService, mockStorageService);

      // Setup test encryption key and salt
      testSalt = CryptoService.generateSalt();
      testEncryptionKey = CryptoService.deriveKeyFromGoogleId('test_user', testSalt);
    });

    group('syncToCloud', () {
      test('returns failure when not signed in', () async {
        when(() => mockAuthService.getDriveApi()).thenReturn(null);

        final result = await syncService.syncToCloud([]);

        expect(result.success, isFalse);
        expect(result.message, equals('Not signed in to Google'));
      });

      test('returns failure when encryption not initialized', () async {
        when(() => mockAuthService.getDriveApi()).thenReturn(null);
        when(() => mockStorageService.encryptionKey).thenReturn(null);
        when(() => mockStorageService.salt).thenReturn(null);

        final result = await syncService.syncToCloud([]);

        expect(result.success, isFalse);
      });
    });

    group('syncFromCloud', () {
      test('returns failure when not signed in', () async {
        when(() => mockAuthService.getDriveApi()).thenReturn(null);

        final result = await syncService.syncFromCloud();

        expect(result.success, isFalse);
        expect(result.message, equals('Not signed in to Google'));
      });

      test('returns failure when encryption not initialized', () async {
        when(() => mockAuthService.getDriveApi()).thenReturn(null);
        when(() => mockStorageService.encryptionKey).thenReturn(null);

        final result = await syncService.syncFromCloud();

        expect(result.success, isFalse);
      });
    });

    group('hasCloudData', () {
      test('returns false when not signed in', () async {
        when(() => mockAuthService.getDriveApi()).thenReturn(null);

        final result = await syncService.hasCloudData();

        expect(result, isFalse);
      });
    });

    group('SyncResult', () {
      test('creates success result', () {
        final result = SyncResult(
          success: true,
          message: 'Sync completed',
          servers: [
            Server(id: '1', name: 'Server 1', host: 'localhost', username: 'user'),
          ],
        );

        expect(result.success, isTrue);
        expect(result.message, equals('Sync completed'));
        expect(result.servers?.length, equals(1));
      });

      test('creates failure result', () {
        final result = SyncResult(
          success: false,
          message: 'Network error',
        );

        expect(result.success, isFalse);
        expect(result.message, equals('Network error'));
        expect(result.servers, isNull);
      });

      test('handles empty server list', () {
        final result = SyncResult(
          success: true,
          message: 'No cloud data found',
          servers: [],
        );

        expect(result.success, isTrue);
        expect(result.servers, isEmpty);
      });
    });
  });
}
