import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server.dart';
import '../models/settings.dart';
import 'crypto_service.dart';

class StorageService {
  static const String _serversKey = 'servers';
  static const String _settingsKey = 'settings';
  static const String _masterPasswordHashKey = 'master_password_hash';
  static const String _saltKey = 'encryption_salt';
  static const String _googleUserKey = 'google_user';

  late SharedPreferences _prefs;
  String? _masterPassword;
  String? _salt;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

  Future<List<Server>> loadServers() async {
    if (_masterPassword == null || _salt == null) return [];

    final encryptedData = _prefs.getString(_serversKey);
    if (encryptedData == null) return [];

    final decrypted =
        CryptoService.decrypt(encryptedData, _masterPassword!, _salt!);
    if (decrypted == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(decrypted);
      return jsonList.map((e) => Server.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveServers(List<Server> servers) async {
    if (_masterPassword == null || _salt == null) return false;

    final jsonString = json.encode(servers.map((e) => e.toJson()).toList());
    final encrypted =
        CryptoService.encrypt(jsonString, _masterPassword!, _salt!);
    await _prefs.setString(_serversKey, encrypted);
    return true;
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
