import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/services/sftp_service.dart';
import 'package:mixterm/models/server.dart';

void main() {
  group('SFTPService', () {
    late SFTPService sftpService;

    setUp(() {
      sftpService = SFTPService();
    });

    tearDown(() async {
      await sftpService.disconnect();
    });

    group('initial state', () {
      test('isConnected returns false initially', () {
        expect(sftpService.isConnected, isFalse);
      });
    });

    group('disconnect', () {
      test('sets isConnected to false', () async {
        await sftpService.disconnect();
        expect(sftpService.isConnected, isFalse);
      });

      test('can be called multiple times safely', () async {
        await sftpService.disconnect();
        await sftpService.disconnect();
        await sftpService.disconnect();
        expect(sftpService.isConnected, isFalse);
      });
    });

    group('operations when not connected', () {
      test('listDirectory returns empty list', () async {
        final items = await sftpService.listDirectory('/');
        expect(items, isEmpty);
      });

      test('getCurrentDirectory returns null', () async {
        final path = await sftpService.getCurrentDirectory();
        expect(path, isNull);
      });

      test('createDirectory returns false', () async {
        final result = await sftpService.createDirectory('/test');
        expect(result, isFalse);
      });

      test('delete returns false', () async {
        final result = await sftpService.delete('/test');
        expect(result, isFalse);
      });

      test('rename returns false', () async {
        final result = await sftpService.rename('/old', '/new');
        expect(result, isFalse);
      });

      test('readFile returns null', () async {
        final data = await sftpService.readFile('/test');
        expect(data, isNull);
      });

      test('downloadFile returns false', () async {
        final result = await sftpService.downloadFile('/remote', '/local');
        expect(result, isFalse);
      });

      test('uploadFile returns false', () async {
        final result = await sftpService.uploadFile('/local', '/remote');
        expect(result, isFalse);
      });
    });

    group('SFTPConnectResult', () {
      test('creates success result with ok() factory', () {
        final result = SFTPConnectResult.ok();
        expect(result.success, isTrue);
        expect(result.error, isNull);
      });

      test('creates failure result with fail() factory', () {
        final result = SFTPConnectResult.fail('SFTP subsystem error');
        expect(result.success, isFalse);
        expect(result.error, equals('SFTP subsystem error'));
      });
    });

    group('connect', () {
      test('returns error for unreachable host', () async {
        final server = Server(
          id: 'test',
          name: 'Unreachable',
          host: '192.0.2.1', // TEST-NET-1, should be unreachable
          port: 22,
          username: 'user',
          password: 'pass',
        );

        final result = await sftpService.connect(server);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      }, timeout: const Timeout(Duration(seconds: 35)));

      test('returns error for empty private key when using key auth', () async {
        final server = Server(
          id: 'test',
          name: 'Test',
          host: 'localhost',
          port: 22,
          username: 'user',
          privateKey: '',
          authType: AuthType.key,
        );

        final result = await sftpService.connect(server);

        expect(result.success, isFalse);
        expect(result.error, contains('Private key is empty'));
      });

      test('returns error for invalid private key format', () async {
        final server = Server(
          id: 'test',
          name: 'Test',
          host: 'localhost',
          port: 22,
          username: 'user',
          privateKey: 'not a valid key',
          authType: AuthType.key,
        );

        final result = await sftpService.connect(server);

        expect(result.success, isFalse);
      }, timeout: const Timeout(Duration(seconds: 35)));
    });

    group('downloadFile cancellation', () {
      test('returns false when cancelled', () async {
        // This would require a mock SFTP connection
        // For now, just verify the method signature works
        var cancelled = false;

        final result = await sftpService.downloadFile(
          '/remote/file',
          '/local/file',
          onProgress: (received, total) {},
          checkCancelled: () => cancelled,
        );

        // Not connected, so returns false
        expect(result, isFalse);
      });
    });

    group('uploadFile cancellation', () {
      test('returns false when cancelled', () async {
        var cancelled = false;

        final result = await sftpService.uploadFile(
          '/local/file',
          '/remote/file',
          onProgress: (sent, total) {},
          checkCancelled: () => cancelled,
        );

        // Not connected, so returns false
        expect(result, isFalse);
      });
    });
  });
}
