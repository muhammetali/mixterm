import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/services/ssh_service.dart';
import 'package:mixterm/models/server.dart';

void main() {
  group('SSHService', () {
    late SSHService sshService;

    setUp(() {
      sshService = SSHService();
    });

    tearDown(() async {
      await sshService.disconnect();
    });

    group('initial state', () {
      test('isConnected returns false initially', () {
        expect(sshService.isConnected, isFalse);
      });
    });

    group('streams', () {
      test('outputStream is broadcast stream', () {
        expect(sshService.outputStream.isBroadcast, isTrue);
      });

      test('stateStream is broadcast stream', () {
        expect(sshService.stateStream.isBroadcast, isTrue);
      });

      test('stateStream emits disconnected initially after disconnect', () async {
        final states = <SSHConnectionState>[];
        final subscription = sshService.stateStream.listen(states.add);

        await sshService.disconnect();

        await Future.delayed(const Duration(milliseconds: 100));
        expect(states, contains(SSHConnectionState.disconnected));

        await subscription.cancel();
      });
    });

    group('disconnect', () {
      test('sets isConnected to false', () async {
        await sshService.disconnect();
        expect(sshService.isConnected, isFalse);
      });

      test('can be called multiple times safely', () async {
        await sshService.disconnect();
        await sshService.disconnect();
        await sshService.disconnect();
        expect(sshService.isConnected, isFalse);
      });
    });

    group('write', () {
      test('does nothing when not connected', () {
        // Should not throw
        sshService.write('test');
      });
    });

    group('resize', () {
      test('does nothing when not connected', () {
        // Should not throw
        sshService.resize(80, 24);
      });
    });

    group('SSHConnectResult', () {
      test('creates success result with ok() factory', () {
        final result = SSHConnectResult.ok();
        expect(result.success, isTrue);
        expect(result.error, isNull);
      });

      test('creates failure result with fail() factory', () {
        final result = SSHConnectResult.fail('Connection timeout');
        expect(result.success, isFalse);
        expect(result.error, equals('Connection timeout'));
      });
    });

    group('SSHConnectionState', () {
      test('has correct enum values', () {
        expect(SSHConnectionState.values, contains(SSHConnectionState.disconnected));
        expect(SSHConnectionState.values, contains(SSHConnectionState.connecting));
        expect(SSHConnectionState.values, contains(SSHConnectionState.connected));
        expect(SSHConnectionState.values, contains(SSHConnectionState.error));
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

        final result = await sshService.connect(server);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      }, timeout: const Timeout(Duration(seconds: 35)));

      test('emits connecting state when starting connection', () async {
        final states = <SSHConnectionState>[];
        final subscription = sshService.stateStream.listen(states.add);

        final server = Server(
          id: 'test',
          name: 'Test',
          host: '192.0.2.1',
          port: 22,
          username: 'user',
          password: 'pass',
        );

        // Start connection (will fail but should emit connecting state)
        unawaited(sshService.connect(server));

        await Future.delayed(const Duration(milliseconds: 100));
        expect(states, contains(SSHConnectionState.connecting));

        await subscription.cancel();
        await sshService.disconnect();
      });

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

        final result = await sshService.connect(server);

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
          privateKey: 'invalid key format',
          authType: AuthType.key,
        );

        final result = await sshService.connect(server);

        expect(result.success, isFalse);
        // Will fail either on key parsing or connection
      }, timeout: const Timeout(Duration(seconds: 35)));
    });
  });
}
