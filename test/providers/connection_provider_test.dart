import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/providers/connection_provider.dart';
import 'package:mixterm/services/ssh_service.dart';
import 'package:mixterm/services/sftp_service.dart';
import 'package:mixterm/utils/result.dart';

// Mock classes
class MockSSHService extends Mock implements SSHService {}
class MockSFTPService extends Mock implements SFTPService {}

void main() {
  late Server testServer;
  late MockSSHService mockSSHService;
  late MockSFTPService mockSFTPService;

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
      id: 'server_1',
      name: 'Test Server',
      host: '192.168.1.1',
      port: 22,
      username: 'testuser',
      password: 'password123',
    );

    mockSSHService = MockSSHService();
    mockSFTPService = MockSFTPService();

    // Default successful connection behavior
    when(() => mockSSHService.connect(any())).thenAnswer(
      (_) async => VoidResult.ok(),
    );
    when(() => mockSSHService.isConnected).thenReturn(true);
    when(() => mockSSHService.disconnect()).thenAnswer((_) async {});
    when(() => mockSSHService.dispose()).thenAnswer((_) async {});
    when(() => mockSSHService.stateStream).thenAnswer(
      (_) => Stream.value(SSHConnectionState.connected),
    );
    when(() => mockSSHService.outputStream).thenAnswer((_) => const Stream.empty());

    when(() => mockSFTPService.connect(any())).thenAnswer(
      (_) async => VoidResult.ok(),
    );
    when(() => mockSFTPService.isConnected).thenReturn(true);
    when(() => mockSFTPService.disconnect()).thenAnswer((_) async {});
  });

  ConnectionProvider buildProvider() => ConnectionProvider(
        createSSHService: () => mockSSHService,
        createSFTPService: () => mockSFTPService,
      );

  group('ConnectionProvider Initial State', () {
    test('starts with no active tab', () {
      final provider = buildProvider();
      expect(provider.activeTabId, isNull);
      expect(provider.activeConnectionType, isNull);
    });

    test('starts with no connections', () {
      final provider = buildProvider();
      expect(provider.activeSSHConnections, isEmpty);
      expect(provider.activeSFTPConnections, isEmpty);
    });
  });

  group('ConnectionProvider SSH Connection', () {
    test('connectSSH creates new connection for tab using the injected factory', () async {
      final provider = buildProvider();

      final result = await provider.connectSSH(testServer, 'tab_1');

      expect(result.success, true);
      expect(result.data, same(mockSSHService));
      verify(() => mockSSHService.connect(testServer)).called(1);

      // The real connectSSH logic (not a hand-rolled test double) is what
      // ran here, so these must reflect actual provider state too.
      expect(provider.getSSHConnection('tab_1'), same(mockSSHService));
      expect(provider.isSSHConnected('tab_1'), isTrue);
      expect(provider.getServerIdForTab('tab_1'), testServer.id);
      expect(provider.activeTabId, 'tab_1');
      expect(provider.activeConnectionType, 'ssh');
    });

    test('connectSSH fails with error message on connection failure', () async {
      when(() => mockSSHService.connect(any())).thenAnswer(
        (_) async => VoidResult.fail('Auth failed'),
      );

      final provider = buildProvider();

      final result = await provider.connectSSH(testServer, 'tab_1');

      expect(result.success, false);
      expect(result.error, 'Auth failed');
      expect(provider.getSSHConnection('tab_1'), isNull);
    });

    test('reconnecting an already-connected tab reuses the existing service', () async {
      final provider = buildProvider();

      final first = await provider.connectSSH(testServer, 'tab_1');
      final second = await provider.connectSSH(testServer, 'tab_1');

      expect(first.data, same(second.data));
      // Only the first call should have actually opened a connection.
      verify(() => mockSSHService.connect(testServer)).called(1);
    });

    test('same server can have multiple independent SSH connections on different tabs', () async {
      final mockSSH1 = MockSSHService();
      final mockSSH2 = MockSSHService();
      var callCount = 0;

      when(() => mockSSH1.connect(any())).thenAnswer(
        (_) async => VoidResult.ok(),
      );
      when(() => mockSSH1.isConnected).thenReturn(true);

      when(() => mockSSH2.connect(any())).thenAnswer(
        (_) async => VoidResult.ok(),
      );
      when(() => mockSSH2.isConnected).thenReturn(true);

      final provider = ConnectionProvider(
        createSSHService: () {
          callCount++;
          return callCount == 1 ? mockSSH1 : mockSSH2;
        },
        createSFTPService: () => mockSFTPService,
      );

      final result1 = await provider.connectSSH(testServer, 'tab_1');
      final result2 = await provider.connectSSH(testServer, 'tab_2');

      expect(result1.success, true);
      expect(result2.success, true);
      // Two separate connections were made (to the same server)
      verify(() => mockSSH1.connect(testServer)).called(1);
      verify(() => mockSSH2.connect(testServer)).called(1);
      expect(provider.getSSHConnection('tab_1'), same(mockSSH1));
      expect(provider.getSSHConnection('tab_2'), same(mockSSH2));
    });

    test('rejects a second connectSSH call for the same tab while one is in flight', () async {
      final gate = Completer<VoidResult>();
      when(() => mockSSHService.connect(any())).thenAnswer((_) => gate.future);

      final provider = buildProvider();

      final first = provider.connectSSH(testServer, 'tab_1');
      final second = await provider.connectSSH(testServer, 'tab_1');

      expect(second.success, false);
      expect(second.error, 'Connection already in progress');

      gate.complete(VoidResult.ok());
      await first;
    });
  });

  group('ConnectionProvider SFTP Connection', () {
    test('connectSFTP creates new connection for tab', () async {
      final provider = buildProvider();

      final result = await provider.connectSFTP(testServer, 'tab_1');

      expect(result.success, true);
      expect(result.data, same(mockSFTPService));
      verify(() => mockSFTPService.connect(testServer)).called(1);
      expect(provider.getSFTPConnection('tab_1'), same(mockSFTPService));
    });

    test('connectSFTP fails with error message on connection failure', () async {
      when(() => mockSFTPService.connect(any())).thenAnswer(
        (_) async => VoidResult.fail('Connection refused'),
      );

      final provider = buildProvider();

      final result = await provider.connectSFTP(testServer, 'tab_1');

      expect(result.success, false);
      expect(result.error, 'Connection refused');
    });
  });

  group('ConnectionProvider Connection Queries', () {
    test('isSSHConnected returns false for non-existent tab', () {
      final provider = buildProvider();
      expect(provider.isSSHConnected('non_existent_tab'), false);
    });

    test('isSFTPConnected returns false for non-existent tab', () {
      final provider = buildProvider();
      expect(provider.isSFTPConnected('non_existent_tab'), false);
    });

    test('getSSHConnection returns null for non-existent tab', () {
      final provider = buildProvider();
      expect(provider.getSSHConnection('non_existent_tab'), isNull);
    });

    test('getSFTPConnection returns null for non-existent tab', () {
      final provider = buildProvider();
      expect(provider.getSFTPConnection('non_existent_tab'), isNull);
    });

    test('getServerIdForTab returns null for non-existent tab', () {
      final provider = buildProvider();
      expect(provider.getServerIdForTab('non_existent_tab'), isNull);
    });

    test('hasAnySSHConnectionForServer returns false when no connections', () {
      final provider = buildProvider();
      expect(provider.hasAnySSHConnectionForServer('server_1'), false);
    });

    test('hasAnySFTPConnectionForServer returns false when no connections', () {
      final provider = buildProvider();
      expect(provider.hasAnySFTPConnectionForServer('server_1'), false);
    });

    test('hasAnySSHConnectionForServer returns true once connected', () async {
      final provider = buildProvider();
      await provider.connectSSH(testServer, 'tab_1');
      expect(provider.hasAnySSHConnectionForServer(testServer.id), isTrue);
    });
  });

  group('ConnectionProvider setActive', () {
    test('setActive updates active tab and type', () {
      final provider = buildProvider();

      provider.setActive('tab_1', 'ssh');

      expect(provider.activeTabId, 'tab_1');
      expect(provider.activeConnectionType, 'ssh');
    });

    test('setActive notifies listeners', () {
      final provider = buildProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.setActive('tab_1', 'sftp');

      expect(notified, true);
    });
  });

  group('ConnectionProvider Disconnect', () {
    test('disconnectSSH handles non-existent tab gracefully', () async {
      final provider = buildProvider();

      // Should not throw
      await provider.disconnectSSH('non_existent_tab');
    });

    test('disconnectSFTP handles non-existent tab gracefully', () async {
      final provider = buildProvider();

      // Should not throw
      await provider.disconnectSFTP('non_existent_tab');
    });

    test('disconnectTab disconnects both SSH and SFTP for that tab', () async {
      final provider = buildProvider();
      await provider.connectSSH(testServer, 'tab_1');
      await provider.connectSFTP(testServer, 'tab_1');

      await provider.disconnectTab('tab_1');

      verify(() => mockSSHService.disconnect()).called(1);
      verify(() => mockSFTPService.disconnect()).called(1);
      expect(provider.getSSHConnection('tab_1'), isNull);
      expect(provider.getSFTPConnection('tab_1'), isNull);
    });

    test('disconnectAllForServer handles empty connections', () async {
      final provider = buildProvider();

      // Should not throw
      await provider.disconnectAllForServer('server_1');
    });
  });

  group('ConnectionProvider isConnecting', () {
    test('isConnecting returns false for non-connecting tab', () {
      final provider = buildProvider();
      expect(provider.isConnecting('tab_1'), false);
    });
  });

  group('ConnectionProvider Notification', () {
    test('setActive notifies listeners on state changes', () {
      var notificationCount = 0;
      final provider = buildProvider();

      provider.addListener(() => notificationCount++);

      provider.setActive('tab_1', 'ssh');

      // Should notify once on setActive
      expect(notificationCount, equals(1));
    });

    test('multiple setActive calls notify multiple times', () {
      var notificationCount = 0;
      final provider = buildProvider();

      provider.addListener(() => notificationCount++);

      provider.setActive('tab_1', 'ssh');
      provider.setActive('tab_2', 'sftp');
      provider.setActive('tab_1', 'ssh');

      expect(notificationCount, equals(3));
    });
  });
}
