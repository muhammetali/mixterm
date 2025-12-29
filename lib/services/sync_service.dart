import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'auth_service.dart';
import 'storage_service.dart';
import 'crypto_service.dart';
import '../models/server.dart';

class SyncService {
  static const String _fileName = 'mixterm_data.enc';
  static const String _folderName = 'MixTerm';

  final AuthService _authService;
  final StorageService _storageService;

  SyncService(this._authService, this._storageService);

  Future<SyncResult> syncToCloud(List<Server> servers) async {
    final driveApi = _authService.getDriveApi();
    if (driveApi == null) {
      return SyncResult(success: false, message: 'Not signed in to Google');
    }

    try {
      final masterPassword = _storageService.masterPassword;
      final salt = _storageService.salt;

      if (masterPassword == null || salt == null) {
        return SyncResult(success: false, message: 'Master password not set');
      }

      final jsonData = json.encode({
        'version': 1,
        'servers': servers.map((s) => s.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final encryptedData =
          CryptoService.encrypt(jsonData, masterPassword, salt);

      final fileContent = json.encode({
        'salt': salt,
        'data': encryptedData,
        'checksum': CryptoService.hashPassword(jsonData),
      });

      final folderId = await _getOrCreateFolder(driveApi);
      final existingFileId = await _findFile(driveApi, folderId);

      final media = drive.Media(
        Stream.value(utf8.encode(fileContent)),
        utf8.encode(fileContent).length,
      );

      if (existingFileId != null) {
        await driveApi.files.update(
          drive.File(),
          existingFileId,
          uploadMedia: media,
        );
      } else {
        final file = drive.File()
          ..name = _fileName
          ..parents = [folderId];
        await driveApi.files.create(file, uploadMedia: media);
      }

      return SyncResult(success: true, message: 'Synced successfully');
    } catch (e) {
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }

  Future<SyncResult> syncFromCloud() async {
    final driveApi = _authService.getDriveApi();
    if (driveApi == null) {
      debugPrint('Sync: Drive API not available');
      return SyncResult(success: false, message: 'Not signed in to Google');
    }

    try {
      final masterPassword = _storageService.masterPassword;
      if (masterPassword == null) {
        debugPrint('Sync: Master password not set');
        return SyncResult(success: false, message: 'Master password not set');
      }

      final folderId = await _getOrCreateFolder(driveApi);
      final fileId = await _findFile(driveApi, folderId);

      if (fileId == null) {
        debugPrint('Sync: No cloud file found in appDataFolder');
        return SyncResult(
            success: true, message: 'No cloud data found', servers: []);
      }

      debugPrint('Sync: Found cloud file, downloading...');
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await response.stream.expand((e) => e).toList();
      final content = utf8.decode(bytes);
      final cloudData = json.decode(content);

      final cloudSalt = cloudData['salt'] as String;
      final encryptedData = cloudData['data'] as String;

      debugPrint('Sync: Attempting to decrypt cloud data with provided salt');
      final decrypted =
          CryptoService.decrypt(encryptedData, masterPassword, cloudSalt);

      if (decrypted == null) {
        debugPrint('Sync: Decryption failed - possible master password mismatch');
        return SyncResult(
            success: false, message: 'Failed to decrypt cloud data');
      }

      final jsonData = json.decode(decrypted);
      final serversList = jsonData['servers'] as List;
      final servers =
          serversList.map((s) => Server.fromJson(s)).toList();

      debugPrint('Sync: Successfully decrypted ${servers.length} servers');
      await _storageService.saveServers(servers);

      return SyncResult(
          success: true, message: 'Synced from cloud', servers: servers);
    } catch (e) {
      debugPrint('Sync: Error during syncFromCloud: $e');
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }

  Future<String> _getOrCreateFolder(drive.DriveApi driveApi) async {
    try {
      debugPrint('Sync: Looking for folder "$_folderName" in appDataFolder');
      // We use 'appDataFolder' space which is private to the app and more reliable
      final query = "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final result = await driveApi.files.list(q: query, spaces: 'appDataFolder');

      if (result.files != null && result.files!.isNotEmpty) {
        debugPrint('Sync: Found existing folder: ${result.files!.first.id}');
        return result.files!.first.id!;
      }

      debugPrint('Sync: Folder not found, creating new one');
      final folder = drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = ['appDataFolder'];

      final created = await driveApi.files.create(folder);
      debugPrint('Sync: Created folder with ID: ${created.id}');
      return created.id!;
    } catch (e) {
      debugPrint('Error getting/creating folder: $e');
      rethrow;
    }
  }

  Future<String?> _findFile(drive.DriveApi driveApi, String folderId) async {
    try {
      debugPrint('Sync: Searching for file "$_fileName" in folder $folderId');
      final query = "name='$_fileName' and '$folderId' in parents and trashed=false";
      final result = await driveApi.files.list(q: query, spaces: 'appDataFolder');

      if (result.files != null && result.files!.isNotEmpty) {
        debugPrint('Sync: Found cloud file: ${result.files!.first.id}');
        return result.files!.first.id;
      }
      debugPrint('Sync: Cloud file not found');
      return null;
    } catch (e) {
      debugPrint('Sync: Error finding sync file: $e');
      return null;
    }
  }

  Future<bool> hasCloudData() async {
    final driveApi = _authService.getDriveApi();
    if (driveApi == null) return false;

    try {
      final folderId = await _getOrCreateFolder(driveApi);
      final fileId = await _findFile(driveApi, folderId);
      return fileId != null;
    } catch (e) {
      return false;
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final List<Server>? servers;

  SyncResult({
    required this.success,
    required this.message,
    this.servers,
  });
}
