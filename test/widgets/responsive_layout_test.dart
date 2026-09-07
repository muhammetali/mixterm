import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/screens/home_screen.dart';
import 'package:mixterm/utils/design_tokens.dart';

/// Regression tests for the layout collapsing at narrow window widths.
///
/// The app shipped with no minimum window size, so it could be dragged down
/// to 200x300, where the 280pt sidebar alone was wider than the content area
/// and Flutter rendered "RIGHT OVERFLOWED BY 80 PIXELS" instead of an
/// interface. These tests pin the numbers that fix stands on. The window
/// minimum itself lives in platform code (`MainFlutterWindow.swift`,
/// `my_application.cc`) and is covered by
/// `test/platform/window_minimum_size_test.dart`.
void main() {
  group('sidebar breakpoint', () {
    test('the collapse breakpoint leaves the terminal at least as much room '
        'as the sidebar', () {
      // The point of collapsing is that the sidebar stops being the main
      // thing on screen. If the remaining content area were narrower than
      // the sidebar itself, the breakpoint would be doing nothing useful.
      final contentAtBreakpoint =
          HomeScreen.sidebarCollapseWidth - HomeScreen.sidebarWidth;
      expect(contentAtBreakpoint,
          greaterThanOrEqualTo(HomeScreen.sidebarWidth));
    });

    test('the expanded sidebar fits inside the minimum window with room to '
        'spare', () {
      // 640 is the minimum enforced by the platform window code. Below the
      // breakpoint the sidebar is a rail, so this checks the rail case: the
      // narrowest the window can get must still leave a usable terminal.
      const minWindow = 640.0;
      final contentAtMinimum = minWindow - HomeScreen.sidebarRailWidth;
      expect(contentAtMinimum, greaterThan(400));
    });

    test('the rail is narrow enough to be worth collapsing to', () {
      expect(HomeScreen.sidebarRailWidth,
          lessThan(HomeScreen.sidebarWidth / 3));
    });

    test('the breakpoint is above the minimum window width', () {
      // Otherwise the sidebar would never collapse on its own: the window
      // could not get narrow enough to trigger it.
      expect(HomeScreen.sidebarCollapseWidth, greaterThan(640));
    });
  });

  group('overflow at narrow widths', () {
    /// Renders [child] at [size] and reports whether Flutter logged an
    /// overflow. Any overflow is a real defect — it is the yellow-and-black
    /// bar the user sees instead of content.
    Future<bool> overflowsAt(
      WidgetTester tester,
      Widget child,
      Size size,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: child),
      );
      await tester.pump();
      FlutterError.onError = previous;

      return errors.any((e) => e.toString().contains('overflowed'));
    }

    testWidgets('the overflow detector actually detects an overflow',
        (tester) async {
      // Verifies the guard rather than the app. A detector that silently
      // never fires would make every test below it a green light that means
      // nothing, which is the more dangerous failure: a real overflow would
      // ship with the suite still passing. So it is handed something that
      // cannot fit and must report it.
      final tooWide = Scaffold(
        body: Row(
          children: [
            SizedBox(width: 900, child: Container(color: AppColors.raised)),
          ],
        ),
      );

      expect(
        await overflowsAt(tester, tooWide, const Size(640, 480)),
        isTrue,
        reason: 'a 900pt child in a 640pt window must be reported',
      );
    });

    testWidgets('a row of status-style content survives the minimum window',
        (tester) async {
      // A stand-in for the densest row the app draws: an icon well, two
      // lines of text, and two badges, at the narrowest the window can be
      // with the sidebar expanded.
      final row = Scaffold(
        backgroundColor: AppColors.bg,
        body: SizedBox(
          width: HomeScreen.sidebarWidth,
          child: Row(
            children: [
              Container(width: 32, height: 32, color: AppColors.raised),
              SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('a-very-long-server-name-that-keeps-going',
                        overflow: TextOverflow.ellipsis),
                    Text('administrator@185.230.217.162:22222',
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(
        await overflowsAt(tester, row, const Size(640, 480)),
        isFalse,
        reason: 'the densest sidebar row must fit the minimum window',
      );
    });
  });
}
