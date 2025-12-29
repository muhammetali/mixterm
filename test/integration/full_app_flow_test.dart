import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/models/settings.dart';
import 'package:mixterm/providers/connection_provider.dart';
import 'package:mixterm/providers/server_provider.dart';
import 'package:mixterm/providers/settings_provider.dart';
import 'package:mixterm/providers/tab_provider.dart';
import 'package:mixterm/providers/transfer_provider.dart';
import 'package:mixterm/services/ssh_service.dart';
import 'package:mixterm/services/storage_service.dart';
import 'package:mixterm/services/sync_service.dart';
import 'package:mixterm/services/auth_service.dart';
import 'package:mixterm/screens/home_screen.dart';
import 'package:mixterm/widgets/terminal_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mocks
class MockSSHService extends Mock implements SSHService {}
class MockStorageService extends Mock implements StorageService {}
class MockSyncService extends Mock implements SyncService {}
class MockAuthService extends Mock implements AuthService {}

// Fake Providers
class FakeConnectionProvider extends ConnectionProvider {
  final SSHService _mockSSHService;
  
  FakeConnectionProvider(this._mockSSHService);

  @override
  SSHService? getSSHConnection(String serverId) {
    return _mockSSHService;
  }

  @override
  Future<ConnectionResult<SSHService>> connectSSH(Server server) async {
    await Future.delayed(const Duration(milliseconds: 10));
    notifyListeners(); 
    return ConnectionResult.ok(_mockSSHService);
  }
}

void main() {
  late MockSSHService mockSSHService;
  late MockStorageService mockStorageService;
  late MockSyncService mockSyncService;
  late MockAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(const AppSettings());
    registerFallbackValue(Server(id: 'fallback', name: 'fallback', host: 'fallback', username: 'fallback'));
    registerFallbackValue(<Server>[]);
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    
    mockSSHService = MockSSHService();
    mockStorageService = MockStorageService();
    mockSyncService = MockSyncService();
    mockAuthService = MockAuthService();

    // Default SSH behaviors
    when(() => mockSSHService.stateStream).thenAnswer((_) => Stream.value(SSHConnectionState.connected));
    when(() => mockSSHService.outputStream).thenAnswer((_) => Stream.empty());
    when(() => mockSSHService.isConnected).thenReturn(true);
    when(() => mockSSHService.dispose()).thenAnswer((_) async {});
    when(() => mockSSHService.resize(any(), any())).thenAnswer((_) async {});

    // Default Storage behaviors
    when(() => mockStorageService.loadServers()).thenAnswer((_) async => []);
    when(() => mockStorageService.saveServers(any())).thenAnswer((_) async => true);
    when(() => mockStorageService.loadSettings()).thenAnswer((_) async => const AppSettings());
    when(() => mockStorageService.saveSettings(any())).thenAnswer((_) async => true);

    // Default Auth behaviors
    when(() => mockAuthService.init()).thenAnswer((_) async {});
    when(() => mockAuthService.isSignedIn).thenReturn(false);
  });

  Widget createIntegrationApp({
    required ConnectionProvider connectionProvider,
    required ServerProvider serverProvider,
    required TabProvider tabProvider,
    required AuthService authService,
    required TransferProvider transferProvider,
    required SettingsProvider settingsProvider,
    required StorageService storageService,
  }) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ServerProvider>.value(value: serverProvider),
        ChangeNotifierProvider<ConnectionProvider>.value(value: connectionProvider),
        ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ChangeNotifierProvider<TransferProvider>.value(value: transferProvider),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  testWidgets('Full App Integration Test', (WidgetTester tester) async {
    // 1. Initialize REAL providers with MOCK services
    final settingsProvider = SettingsProvider(mockStorageService);
    final serverProvider = ServerProvider(mockStorageService, mockSyncService);
    final tabProvider = TabProvider();
    final transferProvider = TransferProvider();
    final connectionProvider = FakeConnectionProvider(mockSSHService);

    final testServer = Server(
      id: 'server_1',
      name: 'Integration Test Server',
      host: '127.0.0.1',
      username: 'test',
      port: 22,
    );
    
    // Ensure mock storage returns this server when loadServers is called
    when(() => mockStorageService.loadServers()).thenAnswer((_) async => [testServer]);
    
    // We can also add it manually to be safe
    await serverProvider.addServer(testServer);

    // 2. Pump the App with all required providers
    await tester.pumpWidget(createIntegrationApp(
      connectionProvider: connectionProvider,
      serverProvider: serverProvider,
      tabProvider: tabProvider,
      authService: mockAuthService,
      transferProvider: transferProvider,
      settingsProvider: settingsProvider,
      storageService: mockStorageService,
    ));
    
    // Allow HomeScreen._loadData (which calls loadServers) to complete
    await tester.pumpAndSettle();

    // 3. Verify Initial UI
    expect(find.text('Integration Test Server'), findsOneWidget);

    // 5. User Interaction: Tap the server
    await tester.tap(find.text('Integration Test Server'));
    await tester.pumpAndSettle(); // Wait for Dialog to appear

    // 6. Tap "SSH Terminal" in the options dialog
    expect(find.text('SSH Terminal'), findsOneWidget);
    await tester.tap(find.text('SSH Terminal'));
    await tester.pump(); // Trigger connection logic
    
    // Allow for async connection simulation
    await tester.pump(const Duration(milliseconds: 50)); 
    await tester.pumpAndSettle();

    // 7. Verify Terminal is visible
    expect(find.byType(TerminalViewWidget), findsOneWidget);
    
    // 8. Verify tab status in TabProvider (Real logic)
    expect(tabProvider.tabs.length, 1);
    expect(tabProvider.activeTab?.isConnected, isTrue);
    
    // 7. Verify NO crash occurred during build
    // If the fix for setState during build wasn't there, 
    // the test would have failed by now with the exception we saw in logs.
  });
}
