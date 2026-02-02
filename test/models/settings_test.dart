import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/models/settings.dart';

void main() {
  group('AppSettings', () {
    group('default values', () {
      test('has correct default values', () {
        const settings = AppSettings();

        expect(settings.copyOnSelect, isTrue);
        expect(settings.pasteOnRightClick, isTrue);
        expect(settings.fontSize, equals(14));
        expect(settings.fontFamily, equals('JetBrainsMono'));
        expect(settings.themeMode, equals(ThemeMode.dark));
        expect(settings.terminalOpacity, equals(1.0));
        expect(settings.showScrollbar, isTrue);
        expect(settings.scrollbackLines, equals(10000));
        expect(settings.terminalTheme, equals('Default Dark'));
        expect(settings.sidebarCollapsed, isFalse);
        expect(settings.terminalForegroundColor, equals('Default'));
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        const original = AppSettings();
        final copied = original.copyWith(
          fontSize: 16,
          sidebarCollapsed: true,
          terminalForegroundColor: 'Green',
        );

        expect(copied.fontSize, equals(16));
        expect(copied.sidebarCollapsed, isTrue);
        expect(copied.terminalForegroundColor, equals('Green'));

        // Other values should remain the same
        expect(copied.copyOnSelect, equals(original.copyOnSelect));
        expect(copied.fontFamily, equals(original.fontFamily));
      });

      test('preserves original values when not specified', () {
        const original = AppSettings(
          fontSize: 18,
          sidebarCollapsed: true,
          terminalForegroundColor: 'Amber',
        );
        final copied = original.copyWith(copyOnSelect: false);

        expect(copied.copyOnSelect, isFalse);
        expect(copied.fontSize, equals(18));
        expect(copied.sidebarCollapsed, isTrue);
        expect(copied.terminalForegroundColor, equals('Amber'));
      });

      test('can copy all fields', () {
        const settings = AppSettings();
        final copied = settings.copyWith(
          copyOnSelect: false,
          pasteOnRightClick: false,
          fontSize: 20,
          fontFamily: 'Consolas',
          themeMode: ThemeMode.light,
          terminalOpacity: 0.8,
          showScrollbar: false,
          scrollbackLines: 5000,
          terminalTheme: 'Dracula',
          sidebarCollapsed: true,
          terminalForegroundColor: 'Cyan',
        );

        expect(copied.copyOnSelect, isFalse);
        expect(copied.pasteOnRightClick, isFalse);
        expect(copied.fontSize, equals(20));
        expect(copied.fontFamily, equals('Consolas'));
        expect(copied.themeMode, equals(ThemeMode.light));
        expect(copied.terminalOpacity, equals(0.8));
        expect(copied.showScrollbar, isFalse);
        expect(copied.scrollbackLines, equals(5000));
        expect(copied.terminalTheme, equals('Dracula'));
        expect(copied.sidebarCollapsed, isTrue);
        expect(copied.terminalForegroundColor, equals('Cyan'));
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        const settings = AppSettings(
          copyOnSelect: false,
          pasteOnRightClick: true,
          fontSize: 16,
          fontFamily: 'Fira Code',
          themeMode: ThemeMode.light,
          terminalOpacity: 0.9,
          showScrollbar: false,
          scrollbackLines: 8000,
          terminalTheme: 'Monokai',
          sidebarCollapsed: true,
          terminalForegroundColor: 'Pink',
        );

        final json = settings.toJson();

        expect(json['copyOnSelect'], isFalse);
        expect(json['pasteOnRightClick'], isTrue);
        expect(json['fontSize'], equals(16));
        expect(json['fontFamily'], equals('Fira Code'));
        expect(json['themeMode'], equals(ThemeMode.light.index));
        expect(json['terminalOpacity'], equals(0.9));
        expect(json['showScrollbar'], isFalse);
        expect(json['scrollbackLines'], equals(8000));
        expect(json['terminalTheme'], equals('Monokai'));
        expect(json['sidebarCollapsed'], isTrue);
        expect(json['terminalForegroundColor'], equals('Pink'));
      });

      test('serializes default settings correctly', () {
        const settings = AppSettings();
        final json = settings.toJson();

        expect(json['sidebarCollapsed'], isFalse);
        expect(json['terminalForegroundColor'], equals('Default'));
      });
    });

    group('fromJson', () {
      test('deserializes all fields correctly', () {
        final json = {
          'copyOnSelect': false,
          'pasteOnRightClick': true,
          'fontSize': 18,
          'fontFamily': 'Source Code Pro',
          'themeMode': ThemeMode.system.index,
          'terminalOpacity': 0.85,
          'showScrollbar': true,
          'scrollbackLines': 15000,
          'terminalTheme': 'Solarized Dark',
          'sidebarCollapsed': true,
          'terminalForegroundColor': 'Lime',
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.copyOnSelect, isFalse);
        expect(settings.pasteOnRightClick, isTrue);
        expect(settings.fontSize, equals(18));
        expect(settings.fontFamily, equals('Source Code Pro'));
        expect(settings.themeMode, equals(ThemeMode.system));
        expect(settings.terminalOpacity, equals(0.85));
        expect(settings.showScrollbar, isTrue);
        expect(settings.scrollbackLines, equals(15000));
        expect(settings.terminalTheme, equals('Solarized Dark'));
        expect(settings.sidebarCollapsed, isTrue);
        expect(settings.terminalForegroundColor, equals('Lime'));
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};
        final settings = AppSettings.fromJson(json);

        expect(settings.copyOnSelect, isTrue);
        expect(settings.fontSize, equals(14));
        expect(settings.sidebarCollapsed, isFalse);
        expect(settings.terminalForegroundColor, equals('Default'));
      });

      test('handles null values with defaults', () {
        final json = {
          'copyOnSelect': null,
          'fontSize': null,
          'sidebarCollapsed': null,
          'terminalForegroundColor': null,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.copyOnSelect, isTrue);
        expect(settings.fontSize, equals(14));
        expect(settings.sidebarCollapsed, isFalse);
        expect(settings.terminalForegroundColor, equals('Default'));
      });

      test('handles partial JSON', () {
        final json = {
          'fontSize': 20,
          'terminalForegroundColor': 'Green',
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.fontSize, equals(20));
        expect(settings.terminalForegroundColor, equals('Green'));
        expect(settings.copyOnSelect, isTrue); // default
        expect(settings.sidebarCollapsed, isFalse); // default
      });
    });

    group('roundtrip serialization', () {
      test('toJson -> fromJson preserves all values', () {
        const original = AppSettings(
          copyOnSelect: false,
          pasteOnRightClick: false,
          fontSize: 22,
          fontFamily: 'Monaco',
          themeMode: ThemeMode.light,
          terminalOpacity: 0.75,
          showScrollbar: false,
          scrollbackLines: 20000,
          terminalTheme: 'GitHub Light',
          sidebarCollapsed: true,
          terminalForegroundColor: 'Light Blue',
        );

        final json = original.toJson();
        final restored = AppSettings.fromJson(json);

        expect(restored.copyOnSelect, equals(original.copyOnSelect));
        expect(restored.pasteOnRightClick, equals(original.pasteOnRightClick));
        expect(restored.fontSize, equals(original.fontSize));
        expect(restored.fontFamily, equals(original.fontFamily));
        expect(restored.themeMode, equals(original.themeMode));
        expect(restored.terminalOpacity, equals(original.terminalOpacity));
        expect(restored.showScrollbar, equals(original.showScrollbar));
        expect(restored.scrollbackLines, equals(original.scrollbackLines));
        expect(restored.terminalTheme, equals(original.terminalTheme));
        expect(restored.sidebarCollapsed, equals(original.sidebarCollapsed));
        expect(restored.terminalForegroundColor, equals(original.terminalForegroundColor));
      });

      test('default settings survive roundtrip', () {
        const original = AppSettings();
        final json = original.toJson();
        final restored = AppSettings.fromJson(json);

        expect(restored.sidebarCollapsed, equals(original.sidebarCollapsed));
        expect(restored.terminalForegroundColor, equals(original.terminalForegroundColor));
      });
    });

    group('new fields', () {
      test('sidebarCollapsed can be set to true', () {
        const settings = AppSettings(sidebarCollapsed: true);
        expect(settings.sidebarCollapsed, isTrue);
      });

      test('terminalForegroundColor can be set to different values', () {
        const greenSettings = AppSettings(terminalForegroundColor: 'Green');
        expect(greenSettings.terminalForegroundColor, equals('Green'));

        const amberSettings = AppSettings(terminalForegroundColor: 'Amber');
        expect(amberSettings.terminalForegroundColor, equals('Amber'));
      });
    });
  });
}
