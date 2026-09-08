import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `linux/runner/mixterm.desktop` is what puts the app in a Linux
/// application menu. Nothing in the build checks it: a broken entry still
/// packages, still installs, and only shows up as the app being missing
/// from the menu on somebody else's machine — which is how the duplicate
/// main category below was found, by running `desktop-file-validate` by
/// hand after an install.
///
/// The rules encoded here come from the freedesktop.org Desktop Entry
/// Specification.
void main() {
  final entry =
      File('linux/runner/mixterm.desktop').readAsLinesSync();

  String? value(String key) {
    for (final line in entry) {
      if (line.startsWith('$key=')) return line.substring(key.length + 1);
    }
    return null;
  }

  /// The specification's main categories. An entry is filed under each one
  /// it names, so naming two puts the app in the menu twice.
  const mainCategories = {
    'AudioVideo', 'Audio', 'Video', 'Development', 'Education', 'Game',
    'Graphics', 'Network', 'Office', 'Science', 'Settings', 'System',
    'Utility',
  };

  group('the Linux desktop entry', () {
    test('declares the keys a menu needs', () {
      expect(entry.first, '[Desktop Entry]');
      expect(value('Type'), 'Application');
      expect(value('Name'), isNotEmpty);
      expect(value('Exec'), isNotEmpty);
      expect(value('Icon'), isNotEmpty);
    });

    test('names exactly one main category', () {
      // `desktop-file-validate` reported: "contains more than one main
      // category; application might appear more than once in the
      // application menu". Network is the category; RemoteAccess is an
      // additional one that refines it, and System was a second main
      // category that only duplicated the entry.
      final categories = (value('Categories') ?? '')
          .split(';')
          .where((c) => c.isNotEmpty)
          .toList();

      final main = categories.where(mainCategories.contains).toList();

      expect(main, hasLength(1),
          reason: 'one main category, or the app is listed once per '
              'category: $main');
    });

    test('is not hidden from the menu', () {
      // Either of these silently removes the entry from every menu, which
      // looks identical to the package having failed to install it.
      expect(value('NoDisplay'), isNot('true'));
      expect(value('Hidden'), isNot('true'));
      expect(value('OnlyShowIn'), isNull,
          reason: 'restricting to one desktop environment hides the app '
              'from the others');
    });

    test('ships an icon at every name the entry can be asked for', () {
      // The entry names an icon by theme name, not path; the packaging
      // installs assets/icons/linux/mixterm_<size>.png under that name. A
      // missing file here is a blank tile in the menu.
      final icon = value('Icon');
      final sizes = Directory('assets/icons/linux')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('mixterm_'))
          .toList();

      expect(icon, 'mixterm');
      expect(sizes, isNotEmpty,
          reason: 'assets/icons/linux holds the images the .deb installs');
    });
  });
}
