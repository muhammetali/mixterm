import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// macOS and Linux each set the window's default and minimum size in their
/// own runner, in their own language. Until now the only thing keeping the
/// two in agreement was a comment in each file claiming it matched the other
/// — and they had already drifted: macOS opened at the 800x600 Flutter
/// template frame while Linux opened at 1280x720, for the same app on the
/// same stated reasoning.
///
/// These read the numbers back out of the runners, so the claim is checked
/// rather than asserted.

/// Pulls a single number out of a runner. Throws rather than calling
/// `expect`, so it can run while the file is being loaded.
int _number(String source, RegExp pattern, String what) {
  final match = pattern.firstMatch(source);
  if (match == null) {
    throw StateError(
        'could not find $what — the runner was reshaped, so update this '
        'test rather than deleting it');
  }
  return int.parse(match.group(1)!);
}

typedef _Size = ({int width, int height});

_Size _size(String source, String widthPattern, String heightPattern,
    String what) {
  return (
    width: _number(source, RegExp(widthPattern), '$what width'),
    height: _number(source, RegExp(heightPattern), '$what height'),
  );
}

void main() {
  final swift = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
  final gtk = File('linux/runner/my_application.cc').readAsStringSync();
  final xib = File('macos/Runner/Base.lproj/MainMenu.xib').readAsStringSync();

  // On macOS the first-run size is the nib's contentRect, not anything in
  // Swift: AppKit applies it before awakeFromNib runs, so code that sets a
  // size there measures correctly and is then overwritten.
  final macDefault = _size(
    xib,
    r'<rect key="contentRect"[^>]*width="(\d+)"',
    r'<rect key="contentRect"[^>]*height="(\d+)"',
    'the macOS default',
  );
  final linuxDefault = _size(
    gtk,
    r'gtk_window_set_default_size\(window,\s*(\d+)',
    r'gtk_window_set_default_size\(window,\s*\d+,\s*(\d+)\)',
    'the Linux default',
  );
  final macMin = _size(
    swift,
    r'contentMinSize\s*=\s*NSSize\(width:\s*(\d+)',
    r'contentMinSize\s*=\s*NSSize\(width:\s*\d+,\s*height:\s*(\d+)\)',
    'the macOS minimum',
  );
  final linuxMin = _size(
    gtk,
    r'geometry\.min_width\s*=\s*(\d+)',
    r'geometry\.min_height\s*=\s*(\d+)',
    'the Linux minimum',
  );

  group('window sizing agrees across platforms', () {
    test('both open at the same size', () {
      expect(linuxDefault, macDefault,
          reason: 'one derivation, two runners — they must state the same '
              'numbers, or the comment in each is a lie');
    });

    test('both refuse to shrink past the same point', () {
      expect(linuxMin, macMin);
    });

    test('the default leaves room for a terminal beside the sidebar', () {
      // HomeScreen.sidebarWidth is 280 and the terminal pads 8 a side. A
      // terminal cell is about 7.8pt wide at the default font size, so this
      // is roughly the column count the window opens with. 80 is the width
      // terminal output has assumed since the punch card; below it, ordinary
      // `ls -l` and `git log` output wraps on first launch.
      final columns = (macDefault.width - 280 - 16) / 7.8;
      expect(columns, greaterThanOrEqualTo(80),
          reason: 'opens at only ${columns.floor()} columns');
    });

    test('the default fits on a small laptop screen', () {
      // 1366x768 is still the floor for a cheap display. Opening wider than
      // the screen puts the window controls out of reach, which is a worse
      // first impression than a window that is too small. macOS clamps to
      // the visible frame at runtime as well; this keeps the stated number
      // honest for Linux, which does not.
      expect(macDefault.width, lessThanOrEqualTo(1366));
      expect(macDefault.height, lessThanOrEqualTo(768));
    });

    test('the default is bigger than the minimum', () {
      expect(macDefault.width, greaterThan(macMin.width));
      expect(macDefault.height, greaterThan(macMin.height));
    });

    test('the window remembers where the user left it', () {
      // A good default is a one-time courtesy; restoring the frame is the
      // part people actually notice. Without the autosave name every launch
      // reverts to the default.
      expect(swift, contains('setFrameAutosaveName'));
    });

    test('macOS state restoration stays out of the way', () {
      // The two mechanisms fight, and restoration acts last: it reapplied
      // its own frame ~700ms after launch and undid everything, including
      // any new default, for anyone who had run the app before. Opting the
      // window out is what makes the autosave name authoritative — remove
      // this line and the window silently goes back to whatever size it
      // happened to have in 2026.
      expect(swift, contains('isRestorable = false'));
    });

    test('the autosave key is versioned', () {
      // An unversioned key means a changed default reaches only people who
      // have never run the app. The suffix is how everyone else is given
      // the new size once, and only once.
      expect(swift, matches(RegExp(r'frameAutosaveName = "[^"]*\.v\d+"')));
    });
  });
}
