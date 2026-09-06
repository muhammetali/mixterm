import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:mixterm/services/sftp_service.dart';
import 'package:mixterm/models/server.dart';

class MockSftpClient extends Mock implements SftpClient {}
class MockSftpFile extends Mock implements SftpFile {}

// Raw POSIX mode bits (see dartssh2's SftpFileMode/_ModeFlags): S_IFDIR and
// S_IFREG. Used to build directory/file SftpFileAttrs for tests.
const _directoryMode = SftpFileMode.value(0x4000);
const _regularFileMode = SftpFileMode.value(0x8000);

SftpName _name(String filename, {bool isDirectory = false}) {
  return SftpName(
    filename: filename,
    longname: filename,
    attr: SftpFileAttrs(mode: isDirectory ? _directoryMode : _regularFileMode),
  );
}

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
      test('listDirectory fails with a descriptive error, not a silent empty list', () async {
        final result = await sftpService.listDirectory('/');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('getCurrentDirectory returns null', () async {
        final path = await sftpService.getCurrentDirectory();
        expect(path, isNull);
      });

      test('createDirectory fails with a descriptive error, not a silent false', () async {
        final result = await sftpService.createDirectory('/test');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('delete fails with a descriptive error, not a silent false', () async {
        final result = await sftpService.delete('/test');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('rename fails with a descriptive error, not a silent false', () async {
        final result = await sftpService.rename('/old', '/new');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('readFile fails with a descriptive error, not a silent null', () async {
        final result = await sftpService.readFile('/test');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('downloadFile fails with a descriptive error, not a silent false', () async {
        final result = await sftpService.downloadFile('/remote', '/local');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('uploadFile fails with a descriptive error, not a silent false', () async {
        final result = await sftpService.uploadFile('/local', '/remote');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
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

    group('operations against a connected (fake) SftpClient', () {
      // These exercise the actual post-connect logic — including real error
      // message propagation — without a network connection, via the
      // @visibleForTesting debugSftpClient seam.
      late MockSftpClient mockClient;

      setUp(() {
        mockClient = MockSftpClient();
        sftpService.debugSftpClient = mockClient;
      });

      group('listDirectory', () {
        test('filters "." / ".." and sorts directories before files, alphabetically', () async {
          when(() => mockClient.listdir('/home')).thenAnswer((_) async => [
                _name('file.txt'),
                _name('.', isDirectory: true),
                _name('..', isDirectory: true),
                _name('zdir', isDirectory: true),
                _name('adir', isDirectory: true),
              ]);

          final result = await sftpService.listDirectory('/home');

          expect(result.success, isTrue);
          expect(
            result.data!.map((e) => e.filename).toList(),
            ['adir', 'zdir', 'file.txt'],
          );
        });

        test('propagates the real error message instead of an empty list', () async {
          when(() => mockClient.listdir(any())).thenThrow(Exception('Permission denied'));

          final result = await sftpService.listDirectory('/root');

          expect(result.success, isFalse);
          expect(result.error, contains('Permission denied'));
          expect(result.error, contains('/root'));
        });
      });

      group('createDirectory', () {
        test('succeeds when mkdir succeeds', () async {
          when(() => mockClient.mkdir(any())).thenAnswer((_) async {});

          final result = await sftpService.createDirectory('/new');

          expect(result.success, isTrue);
          verify(() => mockClient.mkdir('/new')).called(1);
        });

        test('propagates the real error message instead of a silent false', () async {
          when(() => mockClient.mkdir(any())).thenThrow(Exception('File already exists'));

          final result = await sftpService.createDirectory('/existing');

          expect(result.success, isFalse);
          expect(result.error, contains('File already exists'));
        });
      });

      group('delete', () {
        test('removes a file via remove() by default', () async {
          when(() => mockClient.remove(any())).thenAnswer((_) async {});

          final result = await sftpService.delete('/file.txt');

          expect(result.success, isTrue);
          verify(() => mockClient.remove('/file.txt')).called(1);
          verifyNever(() => mockClient.rmdir(any()));
        });

        test('removes a directory via rmdir() when isDirectory is true', () async {
          when(() => mockClient.rmdir(any())).thenAnswer((_) async {});

          final result = await sftpService.delete('/dir', isDirectory: true);

          expect(result.success, isTrue);
          verify(() => mockClient.rmdir('/dir')).called(1);
          verifyNever(() => mockClient.remove(any()));
        });

        test('propagates the real error message instead of a silent false', () async {
          when(() => mockClient.remove(any())).thenThrow(Exception('No such file'));

          final result = await sftpService.delete('/missing.txt');

          expect(result.success, isFalse);
          expect(result.error, contains('No such file'));
        });
      });

      group('rename', () {
        test('succeeds when the underlying rename succeeds', () async {
          when(() => mockClient.rename(any(), any())).thenAnswer((_) async {});

          final result = await sftpService.rename('/old.txt', '/new.txt');

          expect(result.success, isTrue);
          verify(() => mockClient.rename('/old.txt', '/new.txt')).called(1);
        });

        test('propagates the real error message instead of a silent false', () async {
          when(() => mockClient.rename(any(), any())).thenThrow(Exception('Target exists'));

          final result = await sftpService.rename('/a', '/b');

          expect(result.success, isFalse);
          expect(result.error, contains('Target exists'));
        });
      });

      group('readFile', () {
        test('returns the file bytes on success', () async {
          final mockFile = MockSftpFile();
          final bytes = Uint8List.fromList([1, 2, 3, 4]);
          when(() => mockClient.open(any())).thenAnswer((_) async => mockFile);
          when(() => mockFile.readBytes()).thenAnswer((_) async => bytes);
          when(() => mockFile.close()).thenAnswer((_) async {});

          final result = await sftpService.readFile('/data.bin');

          expect(result.success, isTrue);
          expect(result.data, equals(bytes));
          verify(() => mockFile.close()).called(1);
        });

        test('propagates the real error message instead of a silent null', () async {
          when(() => mockClient.open(any())).thenThrow(Exception('Permission denied'));

          final result = await sftpService.readFile('/secret');

          expect(result.success, isFalse);
          expect(result.error, contains('Permission denied'));
          expect(result.error, contains('/secret'));
        });
      });
    });
  });
}
