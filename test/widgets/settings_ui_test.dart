import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:mixterm/providers/settings_provider.dart';
import 'package:mixterm/providers/server_provider.dart';
import 'package:mixterm/services/auth_service.dart';
import 'package:mixterm/services/storage_service.dart';
import 'package:mixterm/services/sync_service.dart';
import 'package:mixterm/screens/settings_screen.dart';

// Mocks
class MockSettingsProvider extends Mock implements SettingsProvider {}
class MockServerProvider extends Mock implements ServerProvider {}
class MockAuthService extends Mock implements AuthService {}
class MockStorageService extends Mock implements StorageService {}
class MockSyncService extends Mock implements SyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsProvider mockSettingsProvider;
  late MockServerProvider mockServerProvider;
  late MockAuthService mockAuthService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockSettingsProvider = MockSettingsProvider();
    mockServerProvider = MockServerProvider();
    mockAuthService = MockAuthService();
    mockStorageService = MockStorageService();

    // Default settings
    when(() => mockSettingsProvider.copyOnSelect).thenReturn(true);
    when(() => mockSettingsProvider.pasteOnRightClick).thenReturn(true);
    when(() => mockSettingsProvider.showScrollbar).thenReturn(true);
    when(() => mockSettingsProvider.fontFamily).thenReturn('JetBrainsMono');
    when(() => mockSettingsProvider.terminalTheme).thenReturn('Default Dark');
    when(() => mockSettingsProvider.terminalForegroundColor).thenReturn('Default');
    when(() => mockSettingsProvider.fontSize).thenReturn(14);
    when(() => mockSettingsProvider.terminalOpacity).thenReturn(1.0);
    when(() => mockSettingsProvider.scrollbackLines).thenReturn(10000);
    when(() => mockSettingsProvider.sidebarCollapsed).thenReturn(false);

    when(() => mockAuthService.isSignedIn).thenReturn(false);
    when(() => mockStorageService.getLastSyncTimestamp()).thenReturn(0);
  });

  Widget createSettingsScreen({Size size = const Size(800, 1200)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
            ChangeNotifierProvider<ServerProvider>.value(value: mockServerProvider),
            ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
            Provider<StorageService>.value(value: mockStorageService),
          ],
          child: const SettingsScreen(),
        ),
      ),
    );
  }

  group('Settings Screen UI Tests', () {
    testWidgets('displays top setting sections (Terminal, Appearance)', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Top sections should always be visible
      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('displays terminal settings', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Copy on select'), findsOneWidget);
      expect(find.text('Paste on right-click'), findsOneWidget);
      expect(find.text('Show scrollbar'), findsOneWidget);
    });

    testWidgets('displays appearance settings', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Font family'), findsOneWidget);
      expect(find.text('Terminal theme'), findsOneWidget);
      expect(find.text('Text color'), findsOneWidget);
      expect(find.text('Font size'), findsOneWidget);
      expect(find.text('Terminal opacity'), findsOneWidget);
      expect(find.text('Scrollback lines'), findsOneWidget);
    });

    testWidgets('displays text color dropdown with options', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Find the text color dropdown
      final textColorFinder = find.text('Text color');
      expect(textColorFinder, findsOneWidget);

      // Check that 'Default' is shown as current value
      expect(find.text('Default'), findsWidgets);
    });

    testWidgets('displays terminal theme dropdown', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Default Dark'), findsWidgets);
    });

    testWidgets('copy on select switch works', (tester) async {
      when(() => mockSettingsProvider.setCopyOnSelect(any())).thenAnswer((_) async {});

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch).first;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      verify(() => mockSettingsProvider.setCopyOnSelect(any())).called(1);
    });

    testWidgets('has back button in app bar', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays Settings title in app bar', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('can scroll to lower sections', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Scroll to find Interface section
      await tester.scrollUntilVisible(
        find.text('Interface'),
        500.0,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Interface'), findsOneWidget);
      expect(find.text('Collapse sidebar'), findsOneWidget);
    });

    testWidgets('can scroll to Cloud Sync section', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Scroll to find Cloud Sync section
      await tester.scrollUntilVisible(
        find.text('Cloud Sync'),
        500.0,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Cloud Sync'), findsOneWidget);
    });

    testWidgets('can scroll to About section', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Scroll to find About section
      await tester.scrollUntilVisible(
        find.text('About'),
        500.0,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('About'), findsOneWidget);
    });
  });

  group('Google Account UI Tests', () {
    testWidgets('shows sign in button when not signed in', (tester) async {
      when(() => mockAuthService.isSignedIn).thenReturn(false);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Scroll to Cloud Sync section
      await tester.scrollUntilVisible(
        find.text('Cloud Sync'),
        500.0,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Not signed in'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('Cloud Sync section renders correctly', (tester) async {
      when(() => mockAuthService.isSignedIn).thenReturn(false);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Scroll to Cloud Sync section
      await tester.scrollUntilVisible(
        find.text('Cloud Sync'),
        500.0,
        scrollable: find.byType(Scrollable).first,
      );

      // Cloud Sync section should be visible
      expect(find.text('Cloud Sync'), findsOneWidget);
    });
  });
}
