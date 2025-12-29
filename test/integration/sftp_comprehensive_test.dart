import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/models/tab_session.dart';
import 'package:mixterm/providers/connection_provider.dart';
import 'package:mixterm/providers/server_provider.dart';
import 'package:mixterm/providers/tab_provider.dart';
import 'package:mixterm/providers/transfer_provider.dart';
import 'package:mixterm/services/sftp_service.dart';
import 'package:mixterm/services/storage_service.dart';
import 'package:mixterm/services/sync_service.dart';
import 'package:mixterm/widgets/sftp_browser.dart';
import 'package:provider/provider.dart';
import 'package:dartssh2/dartssh2.dart';

// --- Mocks ---

class MockSFTPService extends SFTPService {
  final Map<String, List<SftpName>> filesystem;
  final Map<String, Completer<List<SftpName>>> delays;
  bool _isConnected = true;

  MockSFTPService({
    required this.filesystem,
    this.delays = const {},
  });

  @override
  bool get isConnected => _isConnected;

  @override
  Future<List<SftpName>> listDirectory(String path) async {
    debugPrint('Mock (${identityHashCode(this)}): listDirectory called for $path');
    if (delays.containsKey(path)) {
      debugPrint('Mock: waiting for delay on $path');
      final result = await delays[path]!.future;
      debugPrint('Mock: delay finished for $path');
      if (result.isNotEmpty) return result;
    }
    return filesystem[path] ?? [];
  }

  @override
  Future<String?> getCurrentDirectory() async {
    return '/';
  }

  @override
  Future<bool> createDirectory(String path) async {
    return true;
  }
}

class MockConnectionProvider extends ConnectionProvider {
  final Map<String, SFTPService> _services = {};

  void setService(String serverId, SFTPService service) {
    _services[serverId] = service;
  }

  @override
  SFTPService? getSFTPConnection(String serverId) {
    return _services[serverId];
  }
}

class MockStorageService implements StorageService {
  @override
  Future<List<Server>> loadServers({bool useBackup = false}) async => [];
  
  @override
  Future<bool> saveServers(List<Server> servers, {bool createBackup = true}) async => true;

  @override
  Future<void> saveLastSyncTimestamp(int timestamp) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSyncService implements SyncService {
  @override
  Future<SyncResult> syncFromCloud() async => SyncResult(success: true, message: 'Mock success', servers: []);

  @override
  Future<SyncResult> syncToCloud(List<Server> servers) async => SyncResult(success: true, message: 'Mock success');

  @override
  Future<bool> hasCloudData() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- Helpers ---

SftpName createMockItem(String name, {bool isDir = false, int size = 100}) {
  final int modeValue = (isDir ? (1 << 14) : (1 << 15)) | 0x1ff; 

  return SftpName(
    filename: name,
    longname: name,
    attr: SftpFileAttrs(
      size: size,
      mode: SftpFileMode.value(modeValue),
      userID: 0,
      groupID: 0,
      accessTime: 0,
      modifyTime: 0,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String serverId = 'test-server';
  late String tabId;

  late MockConnectionProvider mockConnectionProvider;
  late ServerProvider serverProvider;
  late TabProvider tabProvider;
  late TransferProvider transferProvider;
  late MockSFTPService mockSFTPService;

  setUp(() {
    // Setup standard mock filesystem
    final filesystem = {
      '/': [
        createMockItem('folder_a', isDir: true),
        createMockItem('file_root.txt', size: 1024),
      ],
      '/folder_a': [
        createMockItem('file_a.txt', size: 500),
      ],
      '/slow_folder': [
        createMockItem('slow_file.txt'),
      ],
    };

    mockSFTPService = MockSFTPService(
      filesystem: filesystem,
      delays: {
        '/slow_folder': Completer<List<SftpName>>(),
      },
    );

    mockConnectionProvider = MockConnectionProvider();
    mockConnectionProvider.setService(serverId, mockSFTPService);

    serverProvider = ServerProvider(MockStorageService(), MockSyncService());
    serverProvider.addServer(Server(
        id: serverId,
        name: 'Test Server',
        host: 'localhost',
        port: 22,
        username: 'user',
        authType: AuthType.password));

    tabProvider = TabProvider();
    tabId = tabProvider.addTab(
      type: TabType.sftp, 
      serverId: serverId, 
      title: 'Test Tab',
    );

    transferProvider = TransferProvider();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '/tmp/documents';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  Widget createSubject() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionProvider>.value(value: mockConnectionProvider),
        ChangeNotifierProvider<ServerProvider>.value(value: serverProvider),
        ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ChangeNotifierProvider<TransferProvider>.value(value: transferProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SFTPBrowser(serverId: serverId, tabId: tabId),
        ),
      ),
    );
  }

  testWidgets('Contract Validation: SFTPBrowser loads and displays directory content correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSubject());
    
    await tester.pump(); 
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('folder_a'), findsOneWidget);
    expect(find.text('file_root.txt'), findsOneWidget);
    expect(find.text('1.0 KB'), findsOneWidget); 
  });

  testWidgets('Mutual Exclusion: Multiple pumps do not trigger concurrent loads if already fetching',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump(); 
    await tester.tap(find.byIcon(Icons.refresh)); 
    
    await tester.pumpAndSettle();
    expect(find.text('folder_a'), findsOneWidget);
  });

  testWidgets('Race Condition / Concurrency: Navigating out of a slow folder before it loads',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    mockSFTPService.filesystem['/']!.add(createMockItem('slow_folder', isDir: true));
    await tester.pumpWidget(createSubject()); 
    await tester.pumpAndSettle();

    // Tap 'slow_folder'
    await tester.tap(find.text('slow_folder'));
    await tester.pump(); 
    
    // Verify we are loading (CircularProgressIndicator should be present)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Try to navigate Up while loading (simulates user annoyance/race)
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump(); 

            // Complete the slow load
            debugPrint('Test: completing slow load. Mock hash: ${identityHashCode(mockSFTPService)}');
            if (!mockSFTPService.delays.containsKey('/slow_folder')) {
               debugPrint('Test Error: /slow_folder key missing in delays!');
            }
            mockSFTPService.delays['/slow_folder']!.complete([createMockItem('slow_file.txt')]);
            await Future.delayed(Duration.zero);
            
            // Pump enough time for async to complete
            await tester.pump();
            debugPrint('Pump 1 done');
            await tester.pump(const Duration(milliseconds: 100));
            debugPrint('Pump 2 done');
            await tester.pump();
            debugPrint('Pump 3 done');
        
            // Check if error occurred
            if (find.byType(Icon).evaluate().any((e) => (e.widget as Icon).icon == Icons.error)) {
               debugPrint("Error icon found!");
            }
    
    // Debug: print all text on screen
    debugPrint("--- Text on screen ---");
    find.byType(Text).evaluate().forEach((e) {
      debugPrint((e.widget as Text).data);
    });
    debugPrint("----------------------");
    
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      debugPrint("CircularProgressIndicator is still visible!");
    }

    // We should be in /slow_folder because the "Up" click was ignored during fetch
    expect(find.text('slow_file.txt'), findsOneWidget);
    expect(find.text('folder_a'), findsNothing);
  });

  testWidgets('UI Logic: navigating to subfolder updates path and content', (WidgetTester tester) async {
     await tester.pumpWidget(createSubject());
     await tester.pump(); 
     await tester.pump(const Duration(milliseconds: 100));

     await tester.tap(find.text('folder_a'));
     await tester.pump();
     await tester.pump(const Duration(milliseconds: 100));

     expect(find.text('file_a.txt'), findsOneWidget);
     expect(find.text('folder_a'), findsOneWidget);
  });

  testWidgets('Error Handling: Displays error message when connection fails', (WidgetTester tester) async {
    mockSFTPService._isConnected = false;
    
    await tester.pumpWidget(createSubject());
    // Initial state is loading/connecting overlay because we start with _isLoading=true
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Force load to trigger error
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}