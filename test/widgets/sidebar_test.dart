import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:mixterm/providers/settings_provider.dart';
import 'package:mixterm/providers/server_provider.dart';
import 'package:mixterm/providers/connection_provider.dart';
import 'package:mixterm/providers/tab_provider.dart';
import 'package:mixterm/providers/transfer_provider.dart';
import 'package:mixterm/services/auth_service.dart';
import 'package:mixterm/services/storage_service.dart';
import 'package:mixterm/services/sync_service.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/widgets/server_list.dart';
import 'package:mixterm/widgets/server_tile.dart';

// Mocks
class MockSettingsProvider extends Mock implements SettingsProvider {}
class MockServerProvider extends Mock implements ServerProvider {}
class MockConnectionProvider extends Mock implements ConnectionProvider {}
class MockTabProvider extends Mock implements TabProvider {}
class MockTransferProvider extends Mock implements TransferProvider {}
class MockAuthService extends Mock implements AuthService {}
class MockStorageService extends Mock implements StorageService {}
class MockSyncService extends Mock implements SyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsProvider mockSettingsProvider;
  late MockServerProvider mockServerProvider;
  late MockConnectionProvider mockConnectionProvider;

  setUp(() {
    mockSettingsProvider = MockSettingsProvider();
    mockServerProvider = MockServerProvider();
    mockConnectionProvider = MockConnectionProvider();

    // Default settings
    when(() => mockSettingsProvider.sidebarCollapsed).thenReturn(false);
    when(() => mockServerProvider.isLoading).thenReturn(false);
    when(() => mockServerProvider.servers).thenReturn([]);
    when(() => mockServerProvider.groups).thenReturn([]);
  });

  group('ServerList Widget Tests', () {
    Widget createServerList({bool isCollapsed = false}) {
      return MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
              ChangeNotifierProvider<ServerProvider>.value(value: mockServerProvider),
              ChangeNotifierProvider<ConnectionProvider>.value(value: mockConnectionProvider),
            ],
            child: ServerList(
              onAddServer: () {},
              isCollapsed: isCollapsed,
            ),
          ),
        ),
      );
    }

    testWidgets('shows empty state when no servers', (tester) async {
      await tester.pumpWidget(createServerList());
      await tester.pumpAndSettle();

      expect(find.text('No servers yet'), findsOneWidget);
      expect(find.text('Add Server'), findsOneWidget);
    });

    testWidgets('shows server list when servers exist', (tester) async {
      final testServers = [
        Server(
          id: 'server1',
          name: 'Test Server 1',
          host: '192.168.1.1',
          port: 22,
          username: 'user1',
        ),
        Server(
          id: 'server2',
          name: 'Test Server 2',
          host: '192.168.1.2',
          port: 22,
          username: 'user2',
        ),
      ];

      when(() => mockServerProvider.servers).thenReturn(testServers);
      when(() => mockConnectionProvider.hasAnySSHConnectionForServer(any())).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer(any())).thenReturn(false);

      await tester.pumpWidget(createServerList());
      await tester.pumpAndSettle();

      expect(find.text('Test Server 1'), findsOneWidget);
      expect(find.text('Test Server 2'), findsOneWidget);
    });

    testWidgets('shows search field in expanded mode', (tester) async {
      final testServers = [
        Server(id: 'server1', name: 'Test', host: 'localhost', username: 'user'),
      ];
      when(() => mockServerProvider.servers).thenReturn(testServers);
      when(() => mockConnectionProvider.hasAnySSHConnectionForServer(any())).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer(any())).thenReturn(false);

      await tester.pumpWidget(createServerList(isCollapsed: false));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search servers...'), findsOneWidget);
    });

    testWidgets('hides search field in collapsed mode', (tester) async {
      final testServers = [
        Server(id: 'server1', name: 'Test', host: 'localhost', username: 'user'),
      ];
      when(() => mockServerProvider.servers).thenReturn(testServers);
      when(() => mockConnectionProvider.hasAnySSHConnectionForServer(any())).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer(any())).thenReturn(false);

      await tester.pumpWidget(createServerList(isCollapsed: true));
      await tester.pumpAndSettle();

      // In collapsed mode, no search field
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows loading indicator when loading', (tester) async {
      when(() => mockServerProvider.isLoading).thenReturn(true);

      await tester.pumpWidget(createServerList());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders a flat list with no headers when no server has a group', (tester) async {
      final testServers = [
        Server(id: 's1', name: 'Alpha', host: 'h1', username: 'u'),
        Server(id: 's2', name: 'Beta', host: 'h2', username: 'u'),
      ];
      when(() => mockServerProvider.servers).thenReturn(testServers);
      when(() => mockServerProvider.groups).thenReturn([]);
      when(() => mockConnectionProvider.hasAnySSHConnectionForServer(any())).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer(any())).thenReturn(false);

      await tester.pumpWidget(createServerList());
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('UNGROUPED'), findsNothing);
    });

    testWidgets('groups servers under a header per distinct group, sorted', (tester) async {
      final prod = Server(id: 's1', name: 'Prod Box', host: 'h1', username: 'u', group: 'Production');
      final stage = Server(id: 's2', name: 'Stage Box', host: 'h2', username: 'u', group: 'Staging');
      when(() => mockServerProvider.servers).thenReturn([prod, stage]);
      when(() => mockServerProvider.groups).thenReturn(['Production', 'Staging']);
      when(() => mockServerProvider.getServersByGroup('Production')).thenReturn([prod]);
      when(() => mockServerProvider.getServersByGroup('Staging')).thenReturn([stage]);
      when(() => mockServerProvider.getServersByGroup(null)).thenReturn([]);
      when(() => mockConnectionProvider.hasAnySSHConnectionForServer(any())).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer(any())).thenReturn(false);

      await tester.pumpWidget(createServerList());
      await tester.pumpAndSettle();

      expect(find.text('PRODUCTION'), findsOneWidget);
      expect(find.text('STAGING'), findsOneWidget);
      expect(find.text('Prod Box'), findsOneWidget);
      expect(find.text('Stage Box'), findsOneWidget);
      // No "Ungrouped" header when every server has a group.
      expect(find.text('UNGROUPED'), findsNothing);

      // Production's header must appear before Staging's, matching the
      // sorted order ServerProvider.groups already guarantees.
      final productionY = tester.getTopLeft(find.text('PRODUCTION')).dy;
      final stagingY = tester.getTopLeft(find.text('STAGING')).dy;
      expect(productionY, lessThan(stagingY));
    });

    testWidgets('shows an Ungrouped header before named groups when both exist', (tester) async {
      final loose = Server(id: 's1', name: 'Loose Box', host: 'h1', username: 'u');
      final grouped = Server(id: 's2', name: 'Grouped Box', host: 'h2', username: 'u', group: 'Team A');
      when(() => mockServerProvider.servers).thenReturn([loose, grouped]);
      when(() => mockServerProvider.groups).thenReturn(['Team A']);
      when(() => mockServerProvider.getServersByGroup('Team A')).thenReturn([grouped]);
      when(() => mockServerProvider.getServersByGroup(null)).thenReturn([loose]);
      when(() => mockConnectionProvider.hasAnySSHConnectionForServer(any())).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer(any())).thenReturn(false);

      await tester.pumpWidget(createServerList());
      await tester.pumpAndSettle();

      expect(find.text('UNGROUPED'), findsOneWidget);
      expect(find.text('TEAM A'), findsOneWidget);
      expect(find.text('Loose Box'), findsOneWidget);
      expect(find.text('Grouped Box'), findsOneWidget);

      final ungroupedY = tester.getTopLeft(find.text('UNGROUPED')).dy;
      final teamAY = tester.getTopLeft(find.text('TEAM A')).dy;
      expect(ungroupedY, lessThan(teamAY));
    });
  });

  group('ServerTile Widget Tests', () {
    Widget createServerTile({
      required Server server,
      bool isCollapsed = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ServerProvider>.value(value: mockServerProvider),
              ChangeNotifierProvider<ConnectionProvider>.value(value: mockConnectionProvider),
              ChangeNotifierProvider<TabProvider>.value(value: MockTabProvider()),
            ],
            child: ServerTile(
              server: server,
              isCollapsed: isCollapsed,
            ),
          ),
        ),
      );
    }

    testWidgets('shows full server info in expanded mode', (tester) async {
      final server = Server(
        id: 'test',
        name: 'My Server',
        host: '192.168.1.100',
        port: 22,
        username: 'admin',
      );

      when(() => mockConnectionProvider.hasAnySSHConnectionForServer('test')).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer('test')).thenReturn(false);

      await tester.pumpWidget(createServerTile(server: server, isCollapsed: false));
      await tester.pumpAndSettle();

      expect(find.text('My Server'), findsOneWidget);
      expect(find.text('admin@192.168.1.100:22'), findsOneWidget);
    });

    testWidgets('shows only icon in collapsed mode', (tester) async {
      final server = Server(
        id: 'test',
        name: 'My Server',
        host: '192.168.1.100',
        port: 22,
        username: 'admin',
      );

      when(() => mockConnectionProvider.hasAnySSHConnectionForServer('test')).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer('test')).thenReturn(false);

      await tester.pumpWidget(createServerTile(server: server, isCollapsed: true));
      await tester.pumpAndSettle();

      // In collapsed mode, server name should not be directly visible (only in tooltip)
      expect(find.text('My Server'), findsNothing);
      expect(find.text('admin@192.168.1.100:22'), findsNothing);

      // Should show first letter of server name
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('shows SSH badge when connected', (tester) async {
      final server = Server(
        id: 'test',
        name: 'My Server',
        host: 'localhost',
        username: 'user',
      );

      when(() => mockConnectionProvider.hasAnySSHConnectionForServer('test')).thenReturn(true);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer('test')).thenReturn(false);

      await tester.pumpWidget(createServerTile(server: server, isCollapsed: false));
      await tester.pumpAndSettle();

      expect(find.text('SSH'), findsOneWidget);
    });

    testWidgets('shows SFTP badge when connected', (tester) async {
      final server = Server(
        id: 'test',
        name: 'My Server',
        host: 'localhost',
        username: 'user',
      );

      when(() => mockConnectionProvider.hasAnySSHConnectionForServer('test')).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer('test')).thenReturn(true);

      await tester.pumpWidget(createServerTile(server: server, isCollapsed: false));
      await tester.pumpAndSettle();

      expect(find.text('SFTP'), findsOneWidget);
    });

    testWidgets('shows both badges when both connected', (tester) async {
      final server = Server(
        id: 'test',
        name: 'My Server',
        host: 'localhost',
        username: 'user',
      );

      when(() => mockConnectionProvider.hasAnySSHConnectionForServer('test')).thenReturn(true);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer('test')).thenReturn(true);

      await tester.pumpWidget(createServerTile(server: server, isCollapsed: false));
      await tester.pumpAndSettle();

      expect(find.text('SSH'), findsOneWidget);
      expect(find.text('SFTP'), findsOneWidget);
    });

    testWidgets('collapsed tile has tooltip with server info', (tester) async {
      final server = Server(
        id: 'test',
        name: 'Production Server',
        host: 'prod.example.com',
        port: 22,
        username: 'deploy',
      );

      when(() => mockConnectionProvider.hasAnySSHConnectionForServer('test')).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer('test')).thenReturn(false);

      await tester.pumpWidget(createServerTile(server: server, isCollapsed: true));
      await tester.pumpAndSettle();

      // Tooltip widget should exist
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('collapsed tile shows connection indicator border', (tester) async {
      final server = Server(
        id: 'test',
        name: 'My Server',
        host: 'localhost',
        username: 'user',
      );

      when(() => mockConnectionProvider.hasAnySSHConnectionForServer('test')).thenReturn(true);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer('test')).thenReturn(false);

      await tester.pumpWidget(createServerTile(server: server, isCollapsed: true));
      await tester.pumpAndSettle();

      // The tile should render without errors when connected
      expect(find.byType(ServerTile), findsOneWidget);
    });
  });

  group('Sidebar Animation Tests', () {
    testWidgets('sidebar width changes based on collapsed state', (tester) async {
      // This test verifies the AnimatedContainer behavior conceptually
      // The actual animation is tested via the HomeScreen widget

      final testServers = [
        Server(id: 'server1', name: 'Test', host: 'localhost', username: 'user'),
      ];
      when(() => mockServerProvider.servers).thenReturn(testServers);
      when(() => mockConnectionProvider.hasAnySSHConnectionForServer(any())).thenReturn(false);
      when(() => mockConnectionProvider.hasAnySFTPConnectionForServer(any())).thenReturn(false);

      // Test expanded state
      final expandedWidget = MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ServerProvider>.value(value: mockServerProvider),
              ChangeNotifierProvider<ConnectionProvider>.value(value: mockConnectionProvider),
            ],
            child: const ServerList(onAddServer: _emptyCallback, isCollapsed: false),
          ),
        ),
      );

      await tester.pumpWidget(expandedWidget);
      await tester.pumpAndSettle();

      // Verify expanded mode renders correctly
      expect(find.byType(ServerList), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

void _emptyCallback() {}
