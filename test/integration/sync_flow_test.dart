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
import 'package:mixterm/services/storage_service.dart';
import 'package:mixterm/services/sync_service.dart';
import 'package:mixterm/services/auth_service.dart';
import 'package:mixterm/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mocks
class MockStorageService extends Mock implements StorageService {}
class MockAuthService extends Mock implements AuthService {}
class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockStorageService mockStorageService;
  late MockAuthService mockAuthService;
  late MockSyncService mockSyncService;

  setUpAll(() {
    registerFallbackValue(const AppSettings());
    registerFallbackValue(Server(id: 'fallback', name: 'fallback', host: 'fallback', username: 'fallback'));
    registerFallbackValue(<Server>[]);
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    mockStorageService = MockStorageService();
    mockAuthService = MockAuthService();
    mockSyncService = MockSyncService();

    // Setup Storage
    when(() => mockStorageService.loadServers()).thenAnswer((_) async => []);
    when(() => mockStorageService.saveServers(any(), createBackup: any(named: 'createBackup'))).thenAnswer((_) async => true);
    when(() => mockStorageService.loadSettings()).thenAnswer((_) async => const AppSettings());
    when(() => mockStorageService.init()).thenAnswer((_) async {});
    when(() => mockStorageService.saveLastSyncTimestamp(any())).thenAnswer((_) async {});
    when(() => mockStorageService.getLastSyncTimestamp()).thenReturn(0);

    // Setup Auth
    when(() => mockAuthService.init()).thenAnswer((_) async {});
    when(() => mockAuthService.isSignedIn).thenReturn(true); // User is logged in
  });

  Widget createIntegrationApp({
    required ServerProvider serverProvider,
    required AuthService authService,
    required StorageService storageService,
  }) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider<ServerProvider>.value(value: serverProvider),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => TabProvider()),
        ChangeNotifierProvider(create: (_) => TransferProvider()),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  testWidgets('Sync Flow Integration: Auto Sync on App Start', (WidgetTester tester) async {
    // 1. Prepare Data
    final cloudServer = Server(
      id: 'cloud_1',
      name: 'Cloud Server',
      host: '8.8.8.8',
      username: 'clouduser',
      updatedAt: DateTime.now(),
    );

    // Mock SyncService to return this server during smart sync
    when(() => mockSyncService.syncFromCloud()).thenAnswer((_) async => SyncResult(
      success: true,
      message: 'Synced from cloud',
      servers: [cloudServer],
    ));
    
    when(() => mockSyncService.syncToCloud(any())).thenAnswer((_) async => SyncResult(
      success: true,
      message: 'Synced to cloud',
    ));

    final serverProvider = ServerProvider(mockStorageService, mockSyncService);

    // 2. Pump App
    await tester.pumpWidget(createIntegrationApp(
      serverProvider: serverProvider,
      authService: mockAuthService,
      storageService: mockStorageService,
    ));

    // Allow _loadData to complete (includes auth.init, server.load, settings.load AND server.performSmartSync)
    await tester.pumpAndSettle();

    // 3. Verify
    // syncFromCloud should have been called as part of performSmartSync
    verify(() => mockSyncService.syncFromCloud()).called(1);

    // The cloud server should now be visible in the UI
    expect(find.text('Cloud Server'), findsOneWidget);
  });
}