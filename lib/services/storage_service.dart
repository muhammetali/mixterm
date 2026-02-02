import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server.dart';
import '../models/settings.dart';
import 'crypto_service.dart';

class StorageService {
  static const String _serversKey = 'servers';
  static const String _backupServersKey = 'servers_backup';
  static const String _settingsKey = 'settings';
  static const String _saltKey = 'encryption_salt';
  static const String _googleUserKey = 'google_user';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _encryptionModeKey = 'encryption_mode'; // 'device' or 'google'

  final SharedPreferences _prefs;
  String? _salt;
  Uint8List? _encryptionKey;
  String _encryptionMode = 'device'; // 'device' or 'google'

  StorageService(this._prefs);

  Future<void> init() async {
    _salt = _prefs.getString(_saltKey);
    if (_salt == null) {
      _salt = CryptoService.generateSalt();
      await _prefs.setString(_saltKey, _salt!);
    }

    _encryptionMode = _prefs.getString(_encryptionModeKey) ?? 'device';

    // Initialize with device key by default
    _encryptionKey = await CryptoService.deriveKeyFromDevice(_salt!);
  }

  /// Switches to Google-based encryption when user signs in
  Future<void> switchToGoogleEncryption(String googleUserId) async {
    if (_salt == null) return;

    final oldKey = _encryptionKey;
    final newKey = CryptoService.deriveKeyFromGoogleId(googleUserId, _salt!);

    // Re-encrypt existing data with new key
    await _reEncryptData(oldKey!, newKey);

    _encryptionKey = newKey;
    _encryptionMode = 'google';
    await _prefs.setString(_encryptionModeKey, 'google');
  }

  /// Switches back to device-based encryption when user signs out
  Future<void> switchToDeviceEncryption() async {
    if (_salt == null) return;

    final oldKey = _encryptionKey;
    final newKey = await CryptoService.deriveKeyFromDevice(_salt!);

    // Re-encrypt existing data with device key
    await _reEncryptData(oldKey!, newKey);

    _encryptionKey = newKey;
    _encryptionMode = 'device';
    await _prefs.setString(_encryptionModeKey, 'device');
  }

  /// Re-initializes encryption with Google ID (for when user was already signed in)
  Future<void> initWithGoogleId(String googleUserId) async {
    if (_salt == null) return;

    if (_encryptionMode == 'google') {
      _encryptionKey = CryptoService.deriveKeyFromGoogleId(googleUserId, _salt!);
    }
  }

  Future<void> _reEncryptData(Uint8List oldKey, Uint8List newKey) async {
    final encryptedData = _prefs.getString(_serversKey);
    if (encryptedData == null) return;

    // Decrypt with old key
    final decrypted = CryptoService.decryptWithKey(encryptedData, oldKey);
    if (decrypted == null) return;

    // Encrypt with new key
    final reEncrypted = CryptoService.encryptWithKey(decrypted, newKey);
    await _prefs.setString(_serversKey, reEncrypted);

    // Also re-encrypt backup if exists
    final backupData = _prefs.getString(_backupServersKey);
    if (backupData != null) {
      final decryptedBackup = CryptoService.decryptWithKey(backupData, oldKey);
      if (decryptedBackup != null) {
        final reEncryptedBackup = CryptoService.encryptWithKey(decryptedBackup, newKey);
        await _prefs.setString(_backupServersKey, reEncryptedBackup);
      }
    }
  }

  Future<List<Server>> loadServers({bool useBackup = false}) async {
    if (_encryptionKey == null || _salt == null) return [];

    final key = useBackup ? _backupServersKey : _serversKey;
    final encryptedData = _prefs.getString(key);
    if (encryptedData == null) {
      if (!useBackup) return loadServers(useBackup: true);
      return [];
    }

    final decrypted = CryptoService.decryptWithKey(encryptedData, _encryptionKey!);

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
    if (_encryptionKey == null || _salt == null) return false;

    try {
      // Create backup of current state before overwriting
      if (createBackup) {
        final currentData = _prefs.getString(_serversKey);
        if (currentData != null) {
          await _prefs.setString(_backupServersKey, currentData);
        }
      }

      final jsonString = json.encode(servers.map((e) => e.toJson()).toList());
      final encrypted = CryptoService.encryptWithKey(jsonString, _encryptionKey!);
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
  String get encryptionMode => _encryptionMode;
  Uint8List? get encryptionKey => _encryptionKey;

  Future<String?> getEncryptedServersData() async {
    return _prefs.getString(_serversKey);
  }

  Future<void> setEncryptedServersData(String data) async {
    await _prefs.setString(_serversKey, data);
  }
}
