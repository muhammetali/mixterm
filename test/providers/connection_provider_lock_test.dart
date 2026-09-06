import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/providers/connection_provider.dart';
import 'package:mixterm/services/ssh_service.dart';
import 'package:mixterm/utils/result.dart';

class MockSSHService extends Mock implements SSHService {}

void main() {
  late Server testServer;

  setUpAll(() {
    registerFallbackValue(Server(
      id: 'fallback',
      name: 'Fallback',
      host: 'localhost',
      username: 'user',
    ));
  });

  setUp(() {
    testServer = Server(
      id: 'test_server_1',
      name: 'Test Server',
      host: '127.0.0.1',
      port: 22,
      username: 'test',
      password: 'password',
    );
  });

  /// Builds a provider whose SSHService.connect() never completes on its
  /// own, so tests can control exactly when a "connection attempt" resolves
  /// instead of racing against a real socket timeout.
  ({ConnectionProvider provider, Map<String, Completer<VoidResult>> gates})
      buildGatedProvider() {
    final gates = <String, Completer<VoidResult>>{};
    var callCount = 0;

    final provider = ConnectionProvider(
      createSSHService: () {
        final id = 'call_${callCount++}';
        final service = MockSSHService();
        final gate = Completer<VoidResult>();
        gates[id] = gate;
        when(() => service.connect(any())).thenAnswer((_) => gate.future);
        return service;
      },
    );

    return (provider: provider, gates: gates);
  }

  group('ConnectionProvider Concurrency Tests', () {
    test('Prevents simultaneous connection attempts to the same tab', () async {
      final built = buildGatedProvider();
      const tabId = 'tab_1';

      // Start the first connection attempt but don't await it yet — its
      // SSHService.connect() is gated and will not resolve until we say so.
      final future1 = built.provider.connectSSH(testServer, tabId);

      // Immediately try a second connection to the same tab.
      final result2 = await built.provider.connectSSH(testServer, tabId);

      // The second attempt is blocked immediately by the in-flight lock,
      // without ever calling SSHService.connect() a second time.
      expect(result2.success, false);
      expect(result2.error, 'Connection already in progress');
      expect(built.gates, hasLength(1));

      built.gates['call_0']!.complete(VoidResult.ok());
      await future1;
    });

    test('Allows connection to different tabs simultaneously', () async {
      final built = buildGatedProvider();
      final server2 = Server(
        id: 'test_server_2',
        name: 'Test Server 2',
        host: '127.0.0.1',
        port: 2222,
        username: 'test',
      );

      const tabId1 = 'tab_1';
      const tabId2 = 'tab_2';

      // Start connecting tab 1 (left in-flight, gated).
      final future1 = built.provider.connectSSH(testServer, tabId1);

      // Connecting tab 2 must not be blocked by tab 1's lock.
      final future2 = built.provider.connectSSH(server2, tabId2);
      built.gates['call_1']!.complete(VoidResult.ok());
      final result2 = await future2;

      expect(result2.error, isNot('Connection already in progress'));
      expect(result2.success, isTrue);

      built.gates['call_0']!.complete(VoidResult.ok());
      await future1;
    });

    test('Same server can have independent connections on different tabs', () async {
      final built = buildGatedProvider();
      const tabId1 = 'tab_1';
      const tabId2 = 'tab_2';

      final future1 = built.provider.connectSSH(testServer, tabId1);
      final future2 = built.provider.connectSSH(testServer, tabId2);
      built.gates['call_1']!.complete(VoidResult.ok());
      final result2 = await future2;

      expect(result2.error, isNot('Connection already in progress'));
      expect(result2.success, isTrue);
      expect(built.provider.getSSHConnection(tabId1), isNot(same(built.provider.getSSHConnection(tabId2))));

      built.gates['call_0']!.complete(VoidResult.ok());
      await future1;
    });

    test('Releases the lock once a connection attempt fails, allowing a retry', () async {
      final built = buildGatedProvider();
      const tabId = 'tab_1';

      final future1 = built.provider.connectSSH(testServer, tabId);
      built.gates['call_0']!.complete(VoidResult.fail('Auth failed'));
      final result1 = await future1;

      expect(result1.success, isFalse);
      expect(built.provider.isConnecting(tabId), isFalse);

      // A second attempt after the first one failed must be allowed
      // through, not rejected by a stuck lock.
      final future2 = built.provider.connectSSH(testServer, tabId);
      built.gates['call_1']!.complete(VoidResult.ok());
      final result2 = await future2;

      expect(result2.success, isTrue);
    });
  });
}
