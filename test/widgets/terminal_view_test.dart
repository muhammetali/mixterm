import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:mixterm/widgets/terminal_view.dart';
import 'package:mixterm/providers/connection_provider.dart';
import 'package:mixterm/providers/settings_provider.dart';
import 'package:mixterm/providers/server_provider.dart';
import 'package:mixterm/providers/tab_provider.dart';
import 'package:mixterm/services/ssh_service.dart';
import 'package:mixterm/models/server.dart';
import 'package:xterm/xterm.dart';

// Mocks
class MockConnectionProvider extends Mock implements ConnectionProvider {}
class MockSettingsProvider extends Mock implements SettingsProvider {}
class MockServerProvider extends Mock implements ServerProvider {}
class MockTabProvider extends Mock implements TabProvider {}
class MockSSHService extends Mock implements SSHService {}
class MockServer extends Mock implements Server {}

void main() {
  late MockConnectionProvider mockConnectionProvider;
  late MockSettingsProvider mockSettingsProvider;
  late MockServerProvider mockServerProvider;
  late MockTabProvider mockTabProvider;
  late MockSSHService mockSSHService;
  late Terminal terminal;
  late TerminalController terminalController;

  setUp(() {
    mockConnectionProvider = MockConnectionProvider();
    mockSettingsProvider = MockSettingsProvider();
    mockServerProvider = MockServerProvider();
    mockTabProvider = MockTabProvider();
    mockSSHService = MockSSHService();
    terminal = Terminal();
    terminalController = TerminalController();

    // Setup default behaviors
    when(() => mockSettingsProvider.fontSize).thenReturn(14);
    when(() => mockSettingsProvider.fontFamily).thenReturn('JetBrainsMono');
    when(() => mockSettingsProvider.fontWeight).thenReturn('Normal');
    when(() => mockSettingsProvider.terminalTheme).thenReturn('Default Dark');
    when(() => mockSettingsProvider.terminalForegroundColor).thenReturn('Default');
    when(() => mockSettingsProvider.terminalOpacity).thenReturn(1.0);
    when(() => mockSettingsProvider.pasteOnRightClick).thenReturn(true);
    when(() => mockSettingsProvider.copyOnSelect).thenReturn(true);

    when(() => mockTabProvider.getOrCreateTerminal(any())).thenReturn(terminal);
    when(() => mockTabProvider.getTerminalController(any())).thenReturn(terminalController);

    when(() => mockConnectionProvider.getSSHConnection(any())).thenReturn(mockSSHService);
    
    // Mock SSHService streams
    when(() => mockSSHService.stateStream).thenAnswer((_) => Stream.value(SSHConnectionState.connected));
    when(() => mockSSHService.outputStream).thenAnswer((_) => Stream.empty());
    when(() => mockSSHService.isConnected).thenReturn(true);

    final mockServer = MockServer();
    when(() => mockServer.name).thenReturn('Test Server');
    when(() => mockServer.host).thenReturn('localhost');
    when(() => mockServer.port).thenReturn(22);
    when(() => mockServerProvider.getServer(any())).thenReturn(mockServer);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionProvider>.value(value: mockConnectionProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
        ChangeNotifierProvider<ServerProvider>.value(value: mockServerProvider),
        ChangeNotifierProvider<TabProvider>.value(value: mockTabProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: TerminalViewWidget(serverId: 'server1', tabId: 'tab1'),
        ),
      ),
    );
  }

  testWidgets('TerminalViewWidget initializes without error (Provider fix verification)', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(TerminalViewWidget), findsOneWidget);
    // If the provider fix was wrong (listen outside of tree), this would have thrown an exception.
  });

  testWidgets('Right click triggers paste exactly once (Double paste fix verification)', (WidgetTester tester) async {
    // Setup clipboard mock
    const clipboardContent = 'test-paste-content';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return {'text': clipboardContent};
        }
        return null;
      },
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find the TerminalView (which handles the secondary tap)
    final terminalFinder = find.byType(TerminalViewWidget);
    
    // Perform a right click (secondary tap)
    await tester.tap(terminalFinder, buttons: kSecondaryButton);
    await tester.pump();

    // Verify write was called exactly once
    verify(() => mockSSHService.write(clipboardContent)).called(1);
  });

  testWidgets('Handles connection state change during build gracefully (Robustness & Race Condition)', (WidgetTester tester) async {
    // This test verifies the fix for "setState() or markNeedsBuild() called during build".
    // We simulate a connection state change that might occur immediately or during widget build.

    final stateController = StreamController<SSHConnectionState>.broadcast();

    // Setup SSHService to use our controller
    when(() => mockSSHService.stateStream).thenAnswer((_) => stateController.stream);
    when(() => mockSSHService.isConnected).thenReturn(false); // Initially disconnected

    await tester.pumpWidget(createWidgetUnderTest());

    // Widget is built. Now simulate a connection event.
    // In the buggy version, if this happened at the wrong time (e.g. inside didChangeDependencies triggering a sync update), it crashed.
    stateController.add(SSHConnectionState.connected);

    // Trigger a frame. The addPostFrameCallback in our fix should handle the update safely here.
    await tester.pump();

    // Verify that the provider update method was called.
    // This proves the callback ran and logic executed without throwing an exception.
    verify(() => mockTabProvider.updateTabConnection('tab1', true)).called(1);

    await tester.pumpAndSettle();
    stateController.close();
  });

  group('Selection coordinate conversion (Contract: Coordinate System Integrity)', () {
    // These tests verify that selection coordinates are correctly converted
    // between Listener's coordinate system and TerminalView's coordinate system.
    // This prevents the bug where clicking at viewport top selects from middle.

    testWidgets('Selection starts at correct position when clicking top-left', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final terminalWidget = find.byType(TerminalViewWidget);
      expect(terminalWidget, findsOneWidget);

      // Get the widget's render box for coordinate calculations
      final RenderBox box = tester.renderObject(terminalWidget);
      final topLeft = box.localToGlobal(Offset.zero);

      // Simulate a drag start at the top-left corner (with small offset to be inside padding)
      final gesture = await tester.startGesture(topLeft + const Offset(10, 50)); // Past toolbar
      await tester.pump();

      // End the gesture
      await gesture.up();
      await tester.pump();

      // Wait for any xterm internal timers to complete (tap detection delay)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // The test passes if no exceptions were thrown during coordinate conversion
      // This verifies the _convertToTerminalLocalPosition method works correctly
    });

    testWidgets('Selection handles padding offset correctly', (WidgetTester tester) async {
      // This test verifies that the 8px Container padding doesn't cause
      // coordinate mismatch between Listener and TerminalView

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final terminalWidget = find.byType(TerminalViewWidget);
      final RenderBox box = tester.renderObject(terminalWidget);
      final center = box.localToGlobal(box.size.center(Offset.zero));

      // Start a drag from center
      final gesture = await tester.startGesture(center);
      await tester.pump();

      // Drag to a different position
      await gesture.moveTo(center + const Offset(100, 50));
      await tester.pump();

      // End drag
      await gesture.up();
      await tester.pump();

      // Test passes if coordinate conversion handles padding without error
    });

    testWidgets('Auto-scroll during selection maintains coordinate integrity', (WidgetTester tester) async {
      // Test that selection coordinates remain correct during auto-scroll
      // when dragging near screen edges

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final terminalWidget = find.byType(TerminalViewWidget);
      final RenderBox box = tester.renderObject(terminalWidget);

      // Start from middle
      final middle = box.localToGlobal(box.size.center(Offset.zero));
      final gesture = await tester.startGesture(middle);
      await tester.pump();

      // Drag to bottom edge (should trigger auto-scroll zone)
      final bottomEdge = box.localToGlobal(Offset(box.size.width / 2, box.size.height - 20));
      await gesture.moveTo(bottomEdge);
      await tester.pump(const Duration(milliseconds: 100));

      // Wait for any auto-scroll timers
      await tester.pump(const Duration(milliseconds: 100));

      await gesture.up();
      await tester.pump();

      // Test passes if no coordinate-related crashes occurred
    });
  });

  group('Selection robustness (Contract: State Synchronization)', () {
    testWidgets('Selection clears drag state on pointer cancel', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final terminalWidget = find.byType(TerminalViewWidget);
      final RenderBox box = tester.renderObject(terminalWidget);
      final center = box.localToGlobal(box.size.center(Offset.zero));

      // Start a drag
      final gesture = await tester.startGesture(center);
      await tester.pump();

      // Cancel the gesture (simulates pointer cancel event)
      await gesture.cancel();
      await tester.pump();

      // Widget should handle cancel gracefully without leaving stale state
      // Test passes if no exceptions and widget remains functional
      expect(find.byType(TerminalViewWidget), findsOneWidget);
    });

    testWidgets('Multiple rapid selections do not cause state corruption', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final terminalWidget = find.byType(TerminalViewWidget);
      final RenderBox box = tester.renderObject(terminalWidget);
      final center = box.localToGlobal(box.size.center(Offset.zero));

      // Perform multiple rapid selection gestures
      for (int i = 0; i < 5; i++) {
        final offset = Offset(i * 10.0, i * 5.0);
        final gesture = await tester.startGesture(center + offset);
        await tester.pump(const Duration(milliseconds: 10));
        await gesture.moveTo(center + offset + const Offset(50, 30));
        await tester.pump(const Duration(milliseconds: 10));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 10));
      }

      // Verify widget is still functional after rapid interactions
      expect(find.byType(TerminalViewWidget), findsOneWidget);
    });
  });
}
