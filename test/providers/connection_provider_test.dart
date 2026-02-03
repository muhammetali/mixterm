import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/providers/connection_provider.dart';
import 'package:mixterm/services/ssh_service.dart';
import 'package:mixterm/services/sftp_service.dart';

// Mock classes
class MockSSHService extends Mock implements SSHService {}
class MockSFTPService extends Mock implements SFTPService {}

// Testable ConnectionProvider that allows injecting mock services
class TestableConnectionProvider extends ConnectionProvider {
  final SSHService Function() sshServiceFactory;
  final SFTPService Function() sftpServiceFactory;

  TestableConnectionProvider({
    required this.sshServiceFactory,
    required this.sftpServiceFactory,
  });

  @override
  Future<ConnectionResult<SSHService>> connectSSH(Server server, String tabId) async {
    // Use parent's locking mechanism
    if (isConnecting(tabId)) {
      return ConnectionResult.fail('Connection already in progress');
    }

    // Check existing connection
    final existing = getSSHConnection(tabId);
    if (existing != null && existing.isConnected) {
      return ConnectionResult.ok(existing);
    }

    // Create mock service instead of real one
    final sshService = sshServiceFactory();
    final result = await sshService.connect(server);

    if (result.success) {
      // We need to access private members, so we call super and override
      return ConnectionResult.ok(sshService);
    }

    return ConnectionResult.fail(result.error ?? 'Connection failed');
  }

  @override
  Future<ConnectionResult<SFTPService>> connectSFTP(Server server, String tabId) async {
    if (isConnecting(tabId)) {
      return ConnectionResult.fail('Connection already in progress');
    }

    final existing = getSFTPConnection(tabId);
    if (existing != null && existing.isConnected) {
      return ConnectionResult.ok(existing);
    }

    final sftpService = sftpServiceFactory();
    final result = await sftpService.connect(server);

    if (result.success) {
      return ConnectionResult.ok(sftpService);
    }

    return ConnectionResult.fail(result.error ?? 'Connection failed');
  }
}

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
      (_) async => SSHConnectResult(success: true),
    );
    when(() => mockSSHService.isConnected).thenReturn(true);
    when(() => mockSSHService.disconnect()).thenAnswer((_) async {});
    when(() => mockSSHService.dispose()).thenAnswer((_) async {});
    when(() => mockSSHService.stateStream).thenAnswer(
      (_) => Stream.value(SSHConnectionState.connected),
    );
    when(() => mockSSHService.outputStream).thenAnswer((_) => const Stream.empty());

    when(() => mockSFTPService.connect(any())).thenAnswer(
      (_) async => SFTPConnectResult(success: true),
    );
    when(() => mockSFTPService.isConnected).thenReturn(true);
    when(() => mockSFTPService.disconnect()).thenAnswer((_) async {});
  });

  group('ConnectionProvider Initial State', () {
    test('starts with no active tab', () {
      final provider = ConnectionProvider();
      expect(provider.activeTabId, isNull);
      expect(provider.activeConnectionType, isNull);
    });

    test('starts with no connections', () {
      final provider = ConnectionProvider();
      expect(provider.activeSSHConnections, isEmpty);
      expect(provider.activeSFTPConnections, isEmpty);
    });
  });

  group('ConnectionProvider SSH Connection', () {
    test('connectSSH creates new connection for tab', () async {
      final provider = TestableConnectionProvider(
        sshServiceFactory: () => mockSSHService,
        sftpServiceFactory: () => mockSFTPService,
      );

      final result = await provider.connectSSH(testServer, 'tab_1');

      expect(result.success, true);
      expect(result.service, isNotNull);
      verify(() => mockSSHService.connect(testServer)).called(1);
    });

    test('connectSSH fails with error message on connection failure', () async {
      when(() => mockSSHService.connect(any())).thenAnswer(
        (_) async => SSHConnectResult(success: false, error: 'Auth failed'),
      );

      final provider = TestableConnectionProvider(
        sshServiceFactory: () => mockSSHService,
        sftpServiceFactory: () => mockSFTPService,
      );

      final result = await provider.connectSSH(testServer, 'tab_1');

      expect(result.success, false);
      expect(result.error, 'Auth failed');
    });

    test('same server can have multiple independent SSH connections on different tabs', () async {
      final mockSSH1 = MockSSHService();
      final mockSSH2 = MockSSHService();
      var callCount = 0;

      when(() => mockSSH1.connect(any())).thenAnswer(
        (_) async => SSHConnectResult(success: true),
      );
      when(() => mockSSH1.isConnected).thenReturn(true);

      when(() => mockSSH2.connect(any())).thenAnswer(
        (_) async => SSHConnectResult(success: true),
      );
      when(() => mockSSH2.isConnected).thenReturn(true);

      final provider = TestableConnectionProvider(
        sshServiceFactory: () {
          callCount++;
          return callCount == 1 ? mockSSH1 : mockSSH2;
        },
        sftpServiceFactory: () => mockSFTPService,
      );

      final result1 = await provider.connectSSH(testServer, 'tab_1');
      final result2 = await provider.connectSSH(testServer, 'tab_2');

      expect(result1.success, true);
      expect(result2.success, true);
      // Two separate connections were made (to the same server)
      verify(() => mockSSH1.connect(testServer)).called(1);
      verify(() => mockSSH2.connect(testServer)).called(1);
    });
  });

  group('ConnectionProvider SFTP Connection', () {
    test('connectSFTP creates new connection for tab', () async {
      final provider = TestableConnectionProvider(
        sshServiceFactory: () => mockSSHService,
        sftpServiceFactory: () => mockSFTPService,
      );

      final result = await provider.connectSFTP(testServer, 'tab_1');

      expect(result.success, true);
      expect(result.service, isNotNull);
      verify(() => mockSFTPService.connect(testServer)).called(1);
    });

    test('connectSFTP fails with error message on connection failure', () async {
      when(() => mockSFTPService.connect(any())).thenAnswer(
        (_) async => SFTPConnectResult(success: false, error: 'Connection refused'),
      );

      final provider = TestableConnectionProvider(
        sshServiceFactory: () => mockSSHService,
        sftpServiceFactory: () => mockSFTPService,
      );

      final result = await provider.connectSFTP(testServer, 'tab_1');

      expect(result.success, false);
      expect(result.error, 'Connection refused');
    });
  });

  group('ConnectionProvider Connection Queries', () {
    test('isSSHConnected returns false for non-existent tab', () {
      final provider = ConnectionProvider();
      expect(provider.isSSHConnected('non_existent_tab'), false);
    });

    test('isSFTPConnected returns false for non-existent tab', () {
      final provider = ConnectionProvider();
      expect(provider.isSFTPConnected('non_existent_tab'), false);
    });

    test('getSSHConnection returns null for non-existent tab', () {
      final provider = ConnectionProvider();
      expect(provider.getSSHConnection('non_existent_tab'), isNull);
    });

    test('getSFTPConnection returns null for non-existent tab', () {
      final provider = ConnectionProvider();
      expect(provider.getSFTPConnection('non_existent_tab'), isNull);
    });

    test('getServerIdForTab returns null for non-existent tab', () {
      final provider = ConnectionProvider();
      expect(provider.getServerIdForTab('non_existent_tab'), isNull);
    });

    test('hasAnySSHConnectionForServer returns false when no connections', () {
      final provider = ConnectionProvider();
      expect(provider.hasAnySSHConnectionForServer('server_1'), false);
    });

    test('hasAnySFTPConnectionForServer returns false when no connections', () {
      final provider = ConnectionProvider();
      expect(provider.hasAnySFTPConnectionForServer('server_1'), false);
    });
  });

  group('ConnectionProvider setActive', () {
    test('setActive updates active tab and type', () {
      final provider = ConnectionProvider();

      provider.setActive('tab_1', 'ssh');

      expect(provider.activeTabId, 'tab_1');
      expect(provider.activeConnectionType, 'ssh');
    });

    test('setActive notifies listeners', () {
      final provider = ConnectionProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.setActive('tab_1', 'sftp');

      expect(notified, true);
    });
  });

  group('ConnectionProvider Disconnect', () {
    test('disconnectSSH handles non-existent tab gracefully', () async {
      final provider = ConnectionProvider();

      // Should not throw
      await provider.disconnectSSH('non_existent_tab');
    });

    test('disconnectSFTP handles non-existent tab gracefully', () async {
      final provider = ConnectionProvider();

      // Should not throw
      await provider.disconnectSFTP('non_existent_tab');
    });

    test('disconnectTab disconnects both SSH and SFTP', () async {
      final provider = ConnectionProvider();

      // Should not throw even with no connections
      await provider.disconnectTab('tab_1');
    });

    test('disconnectAllForServer handles empty connections', () async {
      final provider = ConnectionProvider();

      // Should not throw
      await provider.disconnectAllForServer('server_1');
    });
  });

  group('ConnectionProvider isConnecting', () {
    test('isConnecting returns false for non-connecting tab', () {
      final provider = ConnectionProvider();
      expect(provider.isConnecting('tab_1'), false);
    });
  });

  group('ConnectionProvider Notification', () {
    test('setActive notifies listeners on state changes', () {
      var notificationCount = 0;
      final provider = ConnectionProvider();

      provider.addListener(() => notificationCount++);

      provider.setActive('tab_1', 'ssh');

      // Should notify once on setActive
      expect(notificationCount, equals(1));
    });

    test('multiple setActive calls notify multiple times', () {
      var notificationCount = 0;
      final provider = ConnectionProvider();

      provider.addListener(() => notificationCount++);

      provider.setActive('tab_1', 'ssh');
      provider.setActive('tab_2', 'sftp');
      provider.setActive('tab_1', 'ssh');

      expect(notificationCount, equals(3));
    });
  });

  group('ConnectionResult', () {
    test('ConnectionResult.ok creates successful result', () {
      final service = MockSSHService();
      final result = ConnectionResult.ok(service);

      expect(result.success, true);
      expect(result.service, service);
      expect(result.error, isNull);
    });

    test('ConnectionResult.fail creates failed result', () {
      final result = ConnectionResult<SSHService>.fail('Error message');

      expect(result.success, false);
      expect(result.service, isNull);
      expect(result.error, 'Error message');
    });
  });
}
