import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/utils/terminal_themes.dart';

void main() {
  group('AppTerminalThemes', () {
    group('themes list', () {
      test('contains expected themes', () {
        final themeNames = AppTerminalThemes.themes.map((t) => t.name).toList();

        expect(themeNames, contains('Default Dark'));
        expect(themeNames, contains('Dracula'));
        expect(themeNames, contains('Solarized Dark'));
        expect(themeNames, contains('Monokai'));
        expect(themeNames, contains('GitHub Light'));
      });

      test('has at least 5 themes', () {
        expect(AppTerminalThemes.themes.length, greaterThanOrEqualTo(5));
      });

      test('all themes have valid colors', () {
        for (final namedTheme in AppTerminalThemes.themes) {
          expect(namedTheme.theme.foreground, isNotNull);
          expect(namedTheme.theme.cursor, isNotNull);
          expect(namedTheme.theme.selection, isNotNull);
        }
      });
    });

    group('foregroundColors list', () {
      test('contains expected colors', () {
        final colorNames = AppTerminalThemes.foregroundColors.map((c) => c.name).toList();

        expect(colorNames, contains('Default'));
        expect(colorNames, contains('Soft White'));
        expect(colorNames, contains('Green'));
        expect(colorNames, contains('Amber'));
        expect(colorNames, contains('Cyan'));
        expect(colorNames, contains('Light Blue'));
        expect(colorNames, contains('Pink'));
        expect(colorNames, contains('Lime'));
      });

      test('has 8 foreground color options', () {
        expect(AppTerminalThemes.foregroundColors.length, equals(8));
      });

      test('all colors are valid', () {
        for (final namedColor in AppTerminalThemes.foregroundColors) {
          expect(namedColor.color, isA<Color>());
          expect(namedColor.name, isNotEmpty);
        }
      });

      test('Default color is first in list', () {
        expect(AppTerminalThemes.foregroundColors.first.name, equals('Default'));
      });
    });

    group('getTheme', () {
      test('returns correct theme by name', () {
        final draculaTheme = AppTerminalThemes.getTheme('Dracula');
        expect(draculaTheme.foreground, equals(const Color(0xFFF8F8F2)));
      });

      test('returns default theme for unknown name', () {
        final unknownTheme = AppTerminalThemes.getTheme('NonExistent Theme');
        final defaultTheme = AppTerminalThemes.getTheme('Default Dark');

        expect(unknownTheme.foreground, equals(defaultTheme.foreground));
      });

      test('applies custom foreground color when specified', () {
        final greenTheme = AppTerminalThemes.getTheme(
          'Default Dark',
          foregroundColorName: 'Green',
        );

        expect(greenTheme.foreground, equals(const Color(0xFF00FF00)));
      });

      test('keeps original foreground when Default is specified', () {
        final defaultFgTheme = AppTerminalThemes.getTheme(
          'Default Dark',
          foregroundColorName: 'Default',
        );
        final originalTheme = AppTerminalThemes.getTheme('Default Dark');

        expect(defaultFgTheme.foreground, equals(originalTheme.foreground));
      });

      test('preserves other theme colors when applying custom foreground', () {
        final customFgTheme = AppTerminalThemes.getTheme(
          'Dracula',
          foregroundColorName: 'Amber',
        );
        final originalTheme = AppTerminalThemes.getTheme('Dracula');

        // Foreground should be different (custom)
        expect(customFgTheme.foreground, equals(const Color(0xFFFFB000)));

        // Other colors should be the same
        expect(customFgTheme.cursor, equals(originalTheme.cursor));
        expect(customFgTheme.selection, equals(originalTheme.selection));
        expect(customFgTheme.red, equals(originalTheme.red));
        expect(customFgTheme.green, equals(originalTheme.green));
        expect(customFgTheme.blue, equals(originalTheme.blue));
      });

      test('applies custom foreground to all themes', () {
        for (final namedTheme in AppTerminalThemes.themes) {
          final customTheme = AppTerminalThemes.getTheme(
            namedTheme.name,
            foregroundColorName: 'Cyan',
          );

          expect(customTheme.foreground, equals(const Color(0xFF00FFFF)));
        }
      });
    });

    group('getForegroundColor', () {
      test('returns correct color by name', () {
        expect(
          AppTerminalThemes.getForegroundColor('Green'),
          equals(const Color(0xFF00FF00)),
        );
        expect(
          AppTerminalThemes.getForegroundColor('Amber'),
          equals(const Color(0xFFFFB000)),
        );
        expect(
          AppTerminalThemes.getForegroundColor('Cyan'),
          equals(const Color(0xFF00FFFF)),
        );
      });

      test('returns default color for unknown name', () {
        final unknownColor = AppTerminalThemes.getForegroundColor('NonExistent');
        final defaultColor = AppTerminalThemes.getForegroundColor('Default');

        expect(unknownColor, equals(defaultColor));
      });
    });

    group('selection colors', () {
      test('all themes have solid (non-transparent) selection colors', () {
        for (final namedTheme in AppTerminalThemes.themes) {
          final selectionColor = namedTheme.theme.selection;
          // Selection color should not be fully transparent
          expect(selectionColor.a, greaterThan(0.5));
        }
      });

      test('selection colors provide good contrast', () {
        // Default Dark theme
        final defaultDark = AppTerminalThemes.getTheme('Default Dark');
        expect(defaultDark.selection, equals(const Color(0xFF264F78)));

        // Dracula theme
        final dracula = AppTerminalThemes.getTheme('Dracula');
        expect(dracula.selection, equals(const Color(0xFF44475A)));
      });
    });

    group('theme color consistency', () {
      test('all themes have transparent background for overlay support', () {
        for (final namedTheme in AppTerminalThemes.themes) {
          expect(namedTheme.theme.background, equals(Colors.transparent));
        }
      });

      test('all themes have search hit colors defined', () {
        for (final namedTheme in AppTerminalThemes.themes) {
          expect(namedTheme.theme.searchHitBackground, isNotNull);
          expect(namedTheme.theme.searchHitBackgroundCurrent, isNotNull);
          expect(namedTheme.theme.searchHitForeground, isNotNull);
        }
      });

      test('all themes have 16 ANSI colors defined', () {
        for (final namedTheme in AppTerminalThemes.themes) {
          final theme = namedTheme.theme;
          expect(theme.black, isNotNull);
          expect(theme.red, isNotNull);
          expect(theme.green, isNotNull);
          expect(theme.yellow, isNotNull);
          expect(theme.blue, isNotNull);
          expect(theme.magenta, isNotNull);
          expect(theme.cyan, isNotNull);
          expect(theme.white, isNotNull);
          expect(theme.brightBlack, isNotNull);
          expect(theme.brightRed, isNotNull);
          expect(theme.brightGreen, isNotNull);
          expect(theme.brightYellow, isNotNull);
          expect(theme.brightBlue, isNotNull);
          expect(theme.brightMagenta, isNotNull);
          expect(theme.brightCyan, isNotNull);
          expect(theme.brightWhite, isNotNull);
        }
      });
    });
  });

  group('NamedTerminalTheme', () {
    test('stores name and theme correctly', () {
      final theme = NamedTerminalTheme(
        'Test Theme',
        AppTerminalThemes.themes.first.theme,
      );

      expect(theme.name, equals('Test Theme'));
      expect(theme.theme, isNotNull);
    });
  });

  group('NamedForegroundColor', () {
    test('stores name and color correctly', () {
      const color = NamedForegroundColor('Test Color', Color(0xFFFF0000));

      expect(color.name, equals('Test Color'));
      expect(color.color, equals(const Color(0xFFFF0000)));
    });
  });
}
