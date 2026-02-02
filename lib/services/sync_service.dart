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
      final salt = _storageService.salt;
      final googleUserId = _authService.userId;

      if (salt == null) {
        return SyncResult(success: false, message: 'Encryption not initialized');
      }

      if (googleUserId == null) {
        return SyncResult(success: false, message: 'Google User ID not available');
      }

      // Always use Google User ID + salt for cloud encryption
      // This ensures the same key can be derived on any device with the same Google account
      final cloudEncryptionKey = await CryptoService.deriveKeyFromGoogleIdAsync(googleUserId, salt);

      final jsonData = json.encode({
        'version': 2, // Bumped version for new encryption scheme
        'servers': servers.map((s) => s.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final encryptedData = CryptoService.encryptWithKey(jsonData, cloudEncryptionKey);

      final fileContent = json.encode({
        'salt': salt,
        'data': encryptedData,
        'checksum': CryptoService.hashData(jsonData),
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
      final encryptionKey = _storageService.encryptionKey;
      if (encryptionKey == null) {
        debugPrint('Sync: Encryption key not available');
        return SyncResult(success: false, message: 'Encryption not initialized');
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

      final encryptedData = cloudData['data'] as String;
      final cloudSalt = cloudData['salt'] as String?;

      debugPrint('Sync: Attempting to decrypt cloud data');

      // Use cloud salt + Google User ID to derive the correct decryption key
      // This ensures the same key is used across all devices
      String? decrypted;
      final googleUserId = _authService.userId;

      if (cloudSalt != null && googleUserId != null) {
        // Derive key using cloud salt (same key that was used to encrypt)
        final cloudKey = await CryptoService.deriveKeyFromGoogleIdAsync(googleUserId, cloudSalt);
        decrypted = CryptoService.decryptWithKey(encryptedData, cloudKey);
        debugPrint('Sync: Attempted decryption with Google ID + cloud salt');
      }

      // Fallback to local encryption key if above fails
      if (decrypted == null) {
        decrypted = CryptoService.decryptWithKey(encryptedData, encryptionKey);
        debugPrint('Sync: Fallback to local encryption key');
      }

      if (decrypted == null) {
        debugPrint('Sync: Decryption failed - encryption key mismatch');
        return SyncResult(
            success: false, message: 'Failed to decrypt cloud data. Make sure you are using the same Google account.');
      }

      final jsonData = json.decode(decrypted);
      final serversList = jsonData['servers'] as List;
      final servers = serversList.map((s) => Server.fromJson(s)).toList();

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

  /// Deletes cloud data - useful when encryption keys don't match
  Future<SyncResult> deleteCloudData() async {
    final driveApi = _authService.getDriveApi();
    if (driveApi == null) {
      return SyncResult(success: false, message: 'Not signed in to Google');
    }

    try {
      final folderId = await _getOrCreateFolder(driveApi);
      final fileId = await _findFile(driveApi, folderId);

      if (fileId == null) {
        return SyncResult(success: true, message: 'No cloud data to delete');
      }

      await driveApi.files.delete(fileId);
      debugPrint('Sync: Cloud data deleted successfully');

      return SyncResult(success: true, message: 'Cloud data deleted');
    } catch (e) {
      debugPrint('Sync: Error deleting cloud data: $e');
      return SyncResult(success: false, message: 'Failed to delete cloud data: $e');
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

