import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server.dart';
import '../models/settings.dart';
import 'crypto_service.dart';

class StorageService {
  static const String _serversKey = 'servers';
  static const String _backupServersKey = 'servers_backup';
  static const String _settingsKey = 'settings';
  static const String _masterPasswordHashKey = 'master_password_hash';
  static const String _saltKey = 'encryption_salt';
  static const String _googleUserKey = 'google_user';
  static const String _lastSyncKey = 'last_sync_timestamp';

  final SharedPreferences _prefs;
  String? _masterPassword;
  String? _salt;

  StorageService(this._prefs);

  Future<void> init() async {
    _salt = _prefs.getString(_saltKey);
    if (_salt == null) {
      _salt = CryptoService.generateSalt();
      await _prefs.setString(_saltKey, _salt!);
    }
  }

  bool get hasMasterPassword =>
      _prefs.getString(_masterPasswordHashKey) != null;

  bool get isUnlocked => _masterPassword != null;

  Future<bool> setMasterPassword(String password) async {
    final hash = CryptoService.hashPassword(password);
    await _prefs.setString(_masterPasswordHashKey, hash);
    _masterPassword = password;
    return true;
  }

  bool verifyMasterPassword(String password) {
    final storedHash = _prefs.getString(_masterPasswordHashKey);
    if (storedHash == null) return false;

    if (CryptoService.verifyPassword(password, storedHash)) {
      _masterPassword = password;
      return true;
    }
    return false;
  }

  void lock() {
    _masterPassword = null;
  }

  Future<List<Server>> loadServers({bool useBackup = false}) async {
    if (_masterPassword == null || _salt == null) return [];

    final key = useBackup ? _backupServersKey : _serversKey;
    final encryptedData = _prefs.getString(key);
    if (encryptedData == null) {
      if (!useBackup) return loadServers(useBackup: true);
      return [];
    }

    final decrypted =
        CryptoService.decrypt(encryptedData, _masterPassword!, _salt!);
    
    if (decrypted == null) {
      if (!useBackup) {
        debugPrint('Decryption failed for primary storage, trying backup...');
        return loadServers(useBackup: true);
      }
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(decrypted);
      return jsonList.map((e) => Server.fromJson(e)).toList();
    } catch (e) {
      debugPrint('JSON decode failed for $key: $e');
      if (!useBackup) return loadServers(useBackup: true);
      return [];
    }
  }

  Future<bool> saveServers(List<Server> servers, {bool createBackup = true}) async {
    if (_masterPassword == null || _salt == null) return false;

    try {
      // Create backup of current state before overwriting
      if (createBackup) {
        final currentData = _prefs.getString(_serversKey);
        if (currentData != null) {
          await _prefs.setString(_backupServersKey, currentData);
        }
      }

      final jsonString = json.encode(servers.map((e) => e.toJson()).toList());
      final encrypted =
          CryptoService.encrypt(jsonString, _masterPassword!, _salt!);
      await _prefs.setString(_serversKey, encrypted);
      return true;
    } catch (e) {
      debugPrint('Failed to save servers: $e');
      return false;
    }
  }

  Future<void> saveLastSyncTimestamp(int timestamp) async {
    await _prefs.setInt(_lastSyncKey, timestamp);
  }

  int getLastSyncTimestamp() {
    return _prefs.getInt(_lastSyncKey) ?? 0;
  }

  Future<AppSettings> loadSettings() async {
    final jsonString = _prefs.getString(_settingsKey);
    if (jsonString == null) return const AppSettings();

    try {
      return AppSettings.fromJson(json.decode(jsonString));
    } catch (e) {
      return const AppSettings();
    }
  }

  Future<bool> saveSettings(AppSettings settings) async {
    final jsonString = json.encode(settings.toJson());
    await _prefs.setString(_settingsKey, jsonString);
    return true;
  }

  Future<void> saveGoogleUser(String? email) async {
    if (email == null) {
      await _prefs.remove(_googleUserKey);
    } else {
      await _prefs.setString(_googleUserKey, email);
    }
  }

  String? getGoogleUser() {
    return _prefs.getString(_googleUserKey);
  }

  String? get salt => _salt;
  String? get masterPassword => _masterPassword;

  Future<String?> getEncryptedServersData() async {
    return _prefs.getString(_serversKey);
  }

  Future<void> setEncryptedServersData(String data) async {
    await _prefs.setString(_serversKey, data);
  }
}
