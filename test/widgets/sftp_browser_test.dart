import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:mixterm/widgets/sftp_browser.dart';
import 'package:mixterm/providers/connection_provider.dart';
import 'package:mixterm/providers/server_provider.dart';
import 'package:mixterm/providers/tab_provider.dart';
import 'package:mixterm/providers/transfer_provider.dart';
import 'package:mixterm/services/sftp_service.dart';
import 'package:mixterm/models/server.dart';
import 'package:dartssh2/dartssh2.dart';

// Mocks
class MockConnectionProvider extends Mock implements ConnectionProvider {}
class MockServerProvider extends Mock implements ServerProvider {}
class MockTabProvider extends Mock implements TabProvider {}
class MockTransferProvider extends Mock implements TransferProvider {}
class MockSFTPService extends Mock implements SFTPService {}
class MockServer extends Mock implements Server {}
class MockSftpName extends Mock implements SftpName {}
class MockSftpFileAttrs extends Mock implements SftpFileAttrs {}

void main() {
  late MockConnectionProvider mockConnectionProvider;
  late MockServerProvider mockServerProvider;
  late MockTabProvider mockTabProvider;
  late MockTransferProvider mockTransferProvider;
  late MockSFTPService mockSFTPService;
  late MockServer mockServer;

  setUp(() {
    mockConnectionProvider = MockConnectionProvider();
    mockServerProvider = MockServerProvider();
    mockTabProvider = MockTabProvider();
    mockTransferProvider = MockTransferProvider();
    mockSFTPService = MockSFTPService();
    mockServer = MockServer();

    // Setup Server
    when(() => mockServer.name).thenReturn('Test Server');
    when(() => mockServer.host).thenReturn('localhost');
    when(() => mockServer.port).thenReturn(22);
    when(() => mockServerProvider.getServer(any())).thenReturn(mockServer);

    // Setup Connection Provider
    when(() => mockConnectionProvider.getSFTPConnection(any())).thenReturn(mockSFTPService);

    // Setup SFTP Service - Default to connected
    when(() => mockSFTPService.isConnected).thenReturn(true);
    when(() => mockSFTPService.getCurrentDirectory()).thenAnswer((_) async => '/home/test');
    
    // Setup Tab Provider
    when(() => mockTabProvider.updateTabPath(any(), any())).thenReturn(null);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionProvider>.value(value: mockConnectionProvider),
        ChangeNotifierProvider<ServerProvider>.value(value: mockServerProvider),
        ChangeNotifierProvider<TabProvider>.value(value: mockTabProvider),
        ChangeNotifierProvider<TransferProvider>.value(value: mockTransferProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SFTPBrowser(serverId: 'server1', tabId: 'tab1'),
        ),
      ),
    );
  }

  testWidgets('SFTPBrowser loads directory on init when connected (Fix verification)', (WidgetTester tester) async {
    // Arrange
    final mockItem = MockSftpName();
    final mockAttr = MockSftpFileAttrs();
    when(() => mockItem.filename).thenReturn('test_file.txt');
    when(() => mockItem.attr).thenReturn(mockAttr);
    when(() => mockAttr.isDirectory).thenReturn(false);
    when(() => mockAttr.size).thenReturn(1024);

    when(() => mockSFTPService.listDirectory(any())).thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 100)); // Simulate network delay
      return [mockItem];
    });

    // Act
    await tester.pumpWidget(createWidgetUnderTest());
    
    // Initially should show loading spinner (built-in init state is loading=true)
    // Both _buildContent and _buildConnectionOverlay show a spinner, so we expect widgets.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Wait for the async load to complete
    await tester.pumpAndSettle();

    // Assert
    // Verify listDirectory was called. If the fix didn't work, this would fail 
    // because the initial isLoading=true would block the call.
    verify(() => mockSFTPService.listDirectory(any())).called(1);
    
    // Verify items are shown
    expect(find.text('test_file.txt'), findsOneWidget);
    
    // Verify spinner is gone
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('SFTPBrowser handles error gracefully and stops spinner (Robustness verification)', (WidgetTester tester) async {
    // Arrange
    when(() => mockSFTPService.listDirectory(any())).thenThrow('Connection lost');

    // Act
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Assert
    // Verify error message is shown
    expect(find.text('Connection lost'), findsOneWidget);
    
    // Verify spinner is gone (thanks to finally block)
    expect(find.byType(CircularProgressIndicator), findsNothing);
    
    // Verify Retry button exists
    expect(find.text('Retry'), findsOneWidget);
  });
}
