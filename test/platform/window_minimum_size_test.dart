import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the minimum window size on both desktop platforms.
///
/// **What this actually verifies:** that the platform source still contains
/// the call that sets a minimum, and that both platforms agree on the
/// number. It does not run the window code — a Dart test cannot. So this
/// catches the regression that actually happened (the constraint being
/// absent, and later someone changing one platform without the other) but
/// it would not catch the window manager ignoring the hint at runtime.
///
/// It is worth having anyway: the app shipped with no minimum at all, which
/// let the window be dragged to 200x300, where the sidebar alone was wider
/// than the content area and Flutter rendered "RIGHT OVERFLOWED BY 80
/// PIXELS" in place of the interface.
void main() {
  const expectedMinWidth = 640;
  const expectedMinHeight = 480;

  group('minimum window size', () {
    test('macOS sets contentMinSize', () {
      final source =
          File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();

      expect(
        source,
        contains('contentMinSize'),
        reason: 'the macOS window must refuse to shrink past a usable size',
      );
      expect(source, contains('width: $expectedMinWidth'));
      expect(source, contains('height: $expectedMinHeight'));
    });

    test('Linux sets a minimum geometry hint', () {
      final source =
          File('linux/runner/my_application.cc').readAsStringSync();

      expect(
        source,
        contains('gtk_window_set_geometry_hints'),
        reason: 'the GTK window must refuse to shrink past a usable size',
      );
      expect(source, contains('GDK_HINT_MIN_SIZE'));
      expect(source, contains('min_width = $expectedMinWidth'));
      expect(source, contains('min_height = $expectedMinHeight'));
    });

    test('both platforms agree on the same minimum', () {
      // A layout tuned against one minimum and shipped against another is
      // the same bug in a different place.
      final macos =
          File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
      final linux = File('linux/runner/my_application.cc').readAsStringSync();

      expect(macos.contains('$expectedMinWidth'), isTrue);
      expect(linux.contains('$expectedMinWidth'), isTrue);
      expect(macos.contains('$expectedMinHeight'), isTrue);
      expect(linux.contains('$expectedMinHeight'), isTrue);
    });
  });
}
