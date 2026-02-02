import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class NamedTerminalTheme {
  final String name;
  final TerminalTheme theme;

  const NamedTerminalTheme(this.name, this.theme);
}

/// Named foreground colors for terminal text
class NamedForegroundColor {
  final String name;
  final Color color;

  const NamedForegroundColor(this.name, this.color);
}

class AppTerminalThemes {
  static final List<NamedTerminalTheme> themes = [
    NamedTerminalTheme('Default Dark', _defaultDark),
    NamedTerminalTheme('Dracula', _dracula),
    NamedTerminalTheme('Solarized Dark', _solarizedDark),
    NamedTerminalTheme('Monokai', _monokai),
    NamedTerminalTheme('GitHub Light', _githubLight),
  ];

  /// Available foreground color options
  static final List<NamedForegroundColor> foregroundColors = [
    const NamedForegroundColor('Default', Color(0xFFE6EDF3)),
    const NamedForegroundColor('Soft White', Color(0xFFD4D4D4)),
    const NamedForegroundColor('Green', Color(0xFF00FF00)),
    const NamedForegroundColor('Amber', Color(0xFFFFB000)),
    const NamedForegroundColor('Cyan', Color(0xFF00FFFF)),
    const NamedForegroundColor('Light Blue', Color(0xFF87CEEB)),
    const NamedForegroundColor('Pink', Color(0xFFFF69B4)),
    const NamedForegroundColor('Lime', Color(0xFFBFFF00)),
  ];

  static TerminalTheme getTheme(String name, {String? foregroundColorName}) {
    final baseTheme = themes.firstWhere(
      (t) => t.name == name,
      orElse: () => themes.first,
    ).theme;

    // If a custom foreground color is specified, apply it
    if (foregroundColorName != null && foregroundColorName != 'Default') {
      final fgColor = foregroundColors.firstWhere(
        (c) => c.name == foregroundColorName,
        orElse: () => foregroundColors.first,
      ).color;

      return TerminalTheme(
        cursor: baseTheme.cursor,
        selection: baseTheme.selection,
        foreground: fgColor,
        background: baseTheme.background,
        black: baseTheme.black,
        red: baseTheme.red,
        green: baseTheme.green,
        yellow: baseTheme.yellow,
        blue: baseTheme.blue,
        magenta: baseTheme.magenta,
        cyan: baseTheme.cyan,
        white: baseTheme.white,
        brightBlack: baseTheme.brightBlack,
        brightRed: baseTheme.brightRed,
        brightGreen: baseTheme.brightGreen,
        brightYellow: baseTheme.brightYellow,
        brightBlue: baseTheme.brightBlue,
        brightMagenta: baseTheme.brightMagenta,
        brightCyan: baseTheme.brightCyan,
        brightWhite: baseTheme.brightWhite,
        searchHitBackground: baseTheme.searchHitBackground,
        searchHitBackgroundCurrent: baseTheme.searchHitBackgroundCurrent,
        searchHitForeground: baseTheme.searchHitForeground,
      );
    }

    return baseTheme;
  }

  static Color getForegroundColor(String name) {
    return foregroundColors.firstWhere(
      (c) => c.name == name,
      orElse: () => foregroundColors.first,
    ).color;
  }

  // --- Theme Definitions ---
  // Selection colors are now solid (not transparent) for better contrast

  static final _defaultDark = TerminalTheme(
    cursor: const Color(0xFF00D4AA),
    selection: const Color(0xFF264F78), // Solid blue for selection - high contrast
    foreground: const Color(0xFFE6EDF3),
    background: Colors.transparent,
    black: const Color(0xFF000000),
    red: const Color(0xFFCD3131),
    green: const Color(0xFF0DBC79),
    yellow: const Color(0xFFE5E510),
    blue: const Color(0xFF2472C8),
    magenta: const Color(0xFFBC3FBC),
    cyan: const Color(0xFF11A8CD),
    white: const Color(0xFFE5E5E5),
    brightBlack: const Color(0xFF666666),
    brightRed: const Color(0xFFF14C4C),
    brightGreen: const Color(0xFF23D18B),
    brightYellow: const Color(0xFFF5F543),
    brightBlue: const Color(0xFF3B8EEA),
    brightMagenta: const Color(0xFFD670D6),
    brightCyan: const Color(0xFF29B8DB),
    brightWhite: const Color(0xFFFFFFFF),
    searchHitBackground: const Color(0xFFFFFF00),
    searchHitBackgroundCurrent: const Color(0xFF00FF00),
    searchHitForeground: const Color(0xFF000000),
  );

  static final _dracula = TerminalTheme(
    cursor: const Color(0xFFF8F8F2),
    selection: const Color(0xFF44475A), // Dracula selection color - solid
    foreground: const Color(0xFFF8F8F2),
    background: Colors.transparent,
    black: const Color(0xFF21222C),
    red: const Color(0xFFFF5555),
    green: const Color(0xFF50FA7B),
    yellow: const Color(0xFFF1FA8C),
    blue: const Color(0xFFBD93F9),
    magenta: const Color(0xFFFF79C6),
    cyan: const Color(0xFF8BE9FD),
    white: const Color(0xFFF8F8F2),
    brightBlack: const Color(0xFF6272A4),
    brightRed: const Color(0xFFFF6E6E),
    brightGreen: const Color(0xFF69FF94),
    brightYellow: const Color(0xFFFFFFA5),
    brightBlue: const Color(0xFFD6ACFF),
    brightMagenta: const Color(0xFFFF92DF),
    brightCyan: const Color(0xFFA4FFFF),
    brightWhite: const Color(0xFFFFFFFF),
    searchHitBackground: const Color(0xFFFFFF00),
    searchHitBackgroundCurrent: const Color(0xFF00FF00),
    searchHitForeground: const Color(0xFF000000),
  );

  static final _solarizedDark = TerminalTheme(
    cursor: const Color(0xFF839496),
    selection: const Color(0xFF073642), // Solarized base02 - solid
    foreground: const Color(0xFF839496),
    background: Colors.transparent,
    black: const Color(0xFF073642),
    red: const Color(0xFFDC322F),
    green: const Color(0xFF859900),
    yellow: const Color(0xFFB58900),
    blue: const Color(0xFF268BD2),
    magenta: const Color(0xFFD33682),
    cyan: const Color(0xFF2AA198),
    white: const Color(0xFFEEE8D5),
    brightBlack: const Color(0xFF002B36),
    brightRed: const Color(0xFFCB4B16),
    brightGreen: const Color(0xFF586E75),
    brightYellow: const Color(0xFF657B83),
    brightBlue: const Color(0xFF839496),
    brightMagenta: const Color(0xFF6C71C4),
    brightCyan: const Color(0xFF93A1A1),
    brightWhite: const Color(0xFFFDF6E3),
    searchHitBackground: const Color(0xFFFFFF00),
    searchHitBackgroundCurrent: const Color(0xFF00FF00),
    searchHitForeground: const Color(0xFF000000),
  );

  static final _monokai = TerminalTheme(
    cursor: const Color(0xFFF8F8F2),
    selection: const Color(0xFF49483E), // Monokai selection - solid
    foreground: const Color(0xFFF8F8F2),
    background: Colors.transparent,
    black: const Color(0xFF272822),
    red: const Color(0xFFF92672),
    green: const Color(0xFFA6E22E),
    yellow: const Color(0xFFF4BF75),
    blue: const Color(0xFF66D9EF),
    magenta: const Color(0xFFAE81FF),
    cyan: const Color(0xFFA1EFE4),
    white: const Color(0xFFF8F8F2),
    brightBlack: const Color(0xFF75715E),
    brightRed: const Color(0xFFF92672),
    brightGreen: const Color(0xFFA6E22E),
    brightYellow: const Color(0xFFF4BF75),
    brightBlue: const Color(0xFF66D9EF),
    brightMagenta: const Color(0xFFAE81FF),
    brightCyan: const Color(0xFFA1EFE4),
    brightWhite: const Color(0xFFF9F8F5),
    searchHitBackground: const Color(0xFFFFFF00),
    searchHitBackgroundCurrent: const Color(0xFF00FF00),
    searchHitForeground: const Color(0xFF000000),
  );

  static final _githubLight = TerminalTheme(
    cursor: const Color(0xFF044289),
    selection: const Color(0xFFCCEAE7), // Light blue for light theme - solid
    foreground: const Color(0xFF24292E),
    background: Colors.transparent,
    black: const Color(0xFF24292E),
    red: const Color(0xFFD73A49),
    green: const Color(0xFF28A745),
    yellow: const Color(0xFFDBAB09),
    blue: const Color(0xFF0366D6),
    magenta: const Color(0xFF5A32A3),
    cyan: const Color(0xFF0598BC),
    white: const Color(0xFF6A737D),
    brightBlack: const Color(0xFF959DA5),
    brightRed: const Color(0xFFCB2431),
    brightGreen: const Color(0xFF22863A),
    brightYellow: const Color(0xFFB08800),
    brightBlue: const Color(0xFF005CC5),
    brightMagenta: const Color(0xFF5A32A3),
    brightCyan: const Color(0xFF3192AA),
    brightWhite: const Color(0xFFD1D5DA),
    searchHitBackground: const Color(0xFFFFFF00),
    searchHitBackgroundCurrent: const Color(0xFF00FF00),
    searchHitForeground: const Color(0xFF000000),
  );
}
