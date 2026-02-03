import 'package:flutter/material.dart';

class AppSettings {
  final bool copyOnSelect;
  final bool pasteOnRightClick;
  final int fontSize;
  final String fontFamily;
  final String fontWeight; // 'normal', 'medium', 'bold'
  final ThemeMode themeMode;
  final double terminalOpacity;
  final bool showScrollbar;
  final int scrollbackLines;
  final String terminalTheme;
  final bool sidebarCollapsed;
  final String terminalForegroundColor;

  const AppSettings({
    this.copyOnSelect = true,
    this.pasteOnRightClick = true,
    this.fontSize = 14,
    this.fontFamily = 'JetBrainsMono',
    this.fontWeight = 'Normal',
    this.themeMode = ThemeMode.dark,
    this.terminalOpacity = 1.0,
    this.showScrollbar = true,
    this.scrollbackLines = 10000,
    this.terminalTheme = 'Monokai',
    this.sidebarCollapsed = false,
    this.terminalForegroundColor = 'Default',
  });

  AppSettings copyWith({
    bool? copyOnSelect,
    bool? pasteOnRightClick,
    int? fontSize,
    String? fontFamily,
    String? fontWeight,
    ThemeMode? themeMode,
    double? terminalOpacity,
    bool? showScrollbar,
    int? scrollbackLines,
    String? terminalTheme,
    bool? sidebarCollapsed,
    String? terminalForegroundColor,
  }) {
    return AppSettings(
      copyOnSelect: copyOnSelect ?? this.copyOnSelect,
      pasteOnRightClick: pasteOnRightClick ?? this.pasteOnRightClick,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      themeMode: themeMode ?? this.themeMode,
      terminalOpacity: terminalOpacity ?? this.terminalOpacity,
      showScrollbar: showScrollbar ?? this.showScrollbar,
      scrollbackLines: scrollbackLines ?? this.scrollbackLines,
      terminalTheme: terminalTheme ?? this.terminalTheme,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      terminalForegroundColor: terminalForegroundColor ?? this.terminalForegroundColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'copyOnSelect': copyOnSelect,
      'pasteOnRightClick': pasteOnRightClick,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'fontWeight': fontWeight,
      'themeMode': themeMode.index,
      'terminalOpacity': terminalOpacity,
      'showScrollbar': showScrollbar,
      'scrollbackLines': scrollbackLines,
      'terminalTheme': terminalTheme,
      'sidebarCollapsed': sidebarCollapsed,
      'terminalForegroundColor': terminalForegroundColor,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      copyOnSelect: json['copyOnSelect'] as bool? ?? true,
      pasteOnRightClick: json['pasteOnRightClick'] as bool? ?? true,
      fontSize: json['fontSize'] as int? ?? 14,
      fontFamily: json['fontFamily'] as String? ?? 'JetBrainsMono',
      fontWeight: json['fontWeight'] as String? ?? 'Normal',
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 2],
      terminalOpacity: (json['terminalOpacity'] as num?)?.toDouble() ?? 1.0,
      showScrollbar: json['showScrollbar'] as bool? ?? true,
      scrollbackLines: json['scrollbackLines'] as int? ?? 10000,
      terminalTheme: json['terminalTheme'] as String? ?? 'Monokai',
      sidebarCollapsed: json['sidebarCollapsed'] as bool? ?? false,
      terminalForegroundColor: json['terminalForegroundColor'] as String? ?? 'Default',
    );
  }
}
