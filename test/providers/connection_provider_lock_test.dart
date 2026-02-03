import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/providers/connection_provider.dart';

void main() {
  late ConnectionProvider provider;
  late Server testServer;

  setUp(() {
    provider = ConnectionProvider();
    testServer = Server(
      id: 'test_server_1',
      name: 'Test Server',
      host: '127.0.0.1',
      port: 22,
      username: 'test',
      password: 'password',
    );
  });

  group('ConnectionProvider Concurrency Tests', () {
    test('Prevents simultaneous connection attempts to the same tab', () async {
      const tabId = 'tab_1';

      // Start the first connection attempt but don't await it yet.
      // Since SSHService.connect is async and real, it will eventually fail or timeout,
      // but we only care about the immediate locking mechanism here.
      final future1 = provider.connectSSH(testServer, tabId);

      // Immediately try a second connection to the same tab
      final result2 = await provider.connectSSH(testServer, tabId);

      // The second attempt should be blocked immediately by the lock
      expect(result2.success, false);
      expect(result2.error, 'Connection already in progress');

      // Clean up: wait for the first future (it will likely fail due to no real SSH server)
      try {
        await future1;
      } catch (_) {}
    });

    test('Allows connection to different tabs simultaneously', () async {
      final server2 = Server(
        id: 'test_server_2',
        name: 'Test Server 2',
        host: '127.0.0.1',
        port: 2222,
        username: 'test',
      );

      const tabId1 = 'tab_1';
      const tabId2 = 'tab_2';

      // Start connecting to tab 1
      final future1 = provider.connectSSH(testServer, tabId1);

      // Attempt to connect to tab 2 (should NOT be blocked by tab 1's lock)
      // Note: It will still fail due to network, but the error message should NOT be "Connection already in progress"
      final result2 = await provider.connectSSH(server2, tabId2);

      // Verify it didn't hit the lock
      expect(result2.error, isNot('Connection already in progress'));

      try {
        await future1;
      } catch (_) {}
    });

    test('Same server can have independent connections on different tabs', () async {
      const tabId1 = 'tab_1';
      const tabId2 = 'tab_2';

      // Start connecting to same server on tab 1
      final future1 = provider.connectSSH(testServer, tabId1);

      // Attempt to connect same server on tab 2 (should NOT be blocked)
      final result2 = await provider.connectSSH(testServer, tabId2);

      // Verify it didn't hit the lock (different tabs = independent connections)
      expect(result2.error, isNot('Connection already in progress'));

      try {
        await future1;
      } catch (_) {}
    });
  });
}
