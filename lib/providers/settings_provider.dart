import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  AppSettings _settings = const AppSettings();

  SettingsProvider(this._storageService);

  AppSettings get settings => _settings;

  bool get copyOnSelect => _settings.copyOnSelect;
  bool get pasteOnRightClick => _settings.pasteOnRightClick;
  int get fontSize => _settings.fontSize;
  String get fontFamily => _settings.fontFamily;
  ThemeMode get themeMode => _settings.themeMode;
  double get terminalOpacity => _settings.terminalOpacity;
  bool get showScrollbar => _settings.showScrollbar;
  int get scrollbackLines => _settings.scrollbackLines;

  Future<void> loadSettings() async {
    _settings = await _storageService.loadSettings();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setCopyOnSelect(bool value) async {
    await updateSettings(_settings.copyWith(copyOnSelect: value));
  }

  Future<void> setPasteOnRightClick(bool value) async {
    await updateSettings(_settings.copyWith(pasteOnRightClick: value));
  }

  Future<void> setFontSize(int value) async {
    await updateSettings(_settings.copyWith(fontSize: value));
  }

  Future<void> setFontFamily(String value) async {
    await updateSettings(_settings.copyWith(fontFamily: value));
  }

  Future<void> setThemeMode(ThemeMode value) async {
    await updateSettings(_settings.copyWith(themeMode: value));
  }

  Future<void> setTerminalOpacity(double value) async {
    await updateSettings(_settings.copyWith(terminalOpacity: value));
  }

  Future<void> setShowScrollbar(bool value) async {
    await updateSettings(_settings.copyWith(showScrollbar: value));
  }

  Future<void> setScrollbackLines(int value) async {
    await updateSettings(_settings.copyWith(scrollbackLines: value));
  }
}
