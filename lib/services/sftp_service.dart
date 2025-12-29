import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import '../models/server.dart';

class SFTPConnectResult {
  final bool success;
  final String? error;

  SFTPConnectResult({required this.success, this.error});

  factory SFTPConnectResult.ok() => SFTPConnectResult(success: true);
  factory SFTPConnectResult.fail(String error) =>
      SFTPConnectResult(success: false, error: error);
}

class SFTPService {
  SSHClient? _client;
  SftpClient? _sftpClient;

  bool get isConnected => _sftpClient != null;

  Future<SFTPConnectResult> connect(Server server) async {
    try {
      debugPrint('SFTP: Connecting to ${server.host}:${server.port}');

      final socket = await SSHSocket.connect(
        server.host,
        server.port,
        timeout: const Duration(seconds: 30),
      );
      debugPrint('SFTP: Socket connected');

      if (server.authType == AuthType.password) {
        debugPrint('SFTP: Using password authentication');
        _client = SSHClient(
          socket,
          username: server.username,
          onPasswordRequest: () => server.password ?? '',
        );
      } else {
        debugPrint('SFTP: Using key authentication');
        final privateKey = server.privateKey ?? '';
        if (privateKey.isEmpty) {
          return SFTPConnectResult.fail('Private key is empty');
        }

        try {
          final keyPairs = SSHKeyPair.fromPem(
            privateKey,
            server.passphrase,
          );
          debugPrint('SFTP: Parsed ${keyPairs.length} key pair(s)');

          if (keyPairs.isEmpty) {
            return SFTPConnectResult.fail('Failed to parse private key');
          }

          _client = SSHClient(
            socket,
            username: server.username,
            identities: keyPairs,
          );
        } catch (e) {
          debugPrint('SFTP: Key parsing error: $e');
          return SFTPConnectResult.fail('Invalid private key format: $e');
        }
      }

      debugPrint('SFTP: Waiting for authentication...');
      await _client!.authenticated;
      debugPrint('SFTP: Authenticated successfully');

      _sftpClient = await _client!.sftp();
      debugPrint('SFTP: SFTP session started');
      return SFTPConnectResult.ok();
    } on SocketException catch (e) {
      debugPrint('SFTP: Socket error: $e');
      return SFTPConnectResult.fail('Could not connect to ${server.host}:${server.port}');
    } on SSHAuthFailError catch (e) {
      debugPrint('SFTP: Auth failed: $e');
      return SFTPConnectResult.fail('Authentication failed: Invalid credentials');
    } catch (e) {
      debugPrint('SFTP: General error: $e');
      return SFTPConnectResult.fail('$e');
    }
  }

  Future<List<SftpName>> listDirectory(String path) async {
    if (_sftpClient == null) return [];

    try {
      final items = await _sftpClient!.listdir(path);
      final filtered = items.where((item) => item.filename != '.' && item.filename != '..').toList();
      filtered.sort((a, b) {
        if (a.attr.isDirectory && !b.attr.isDirectory) return -1;
        if (!a.attr.isDirectory && b.attr.isDirectory) return 1;
        return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      });
      return filtered;
    } catch (e) {
      return [];
    }
  }

  Future<String?> getCurrentDirectory() async {
    if (_sftpClient == null) return null;
    try {
      return await _sftpClient!.absolute('.');
    } catch (e) {
      return '/';
    }
  }

    Future<bool> downloadFile(
      String remotePath,
      String localPath, {
      Function(int received, int total)? onProgress,
      bool Function()? checkCancelled,
    }) async {
      if (_sftpClient == null) return false;
  
      try {
        final file = await _sftpClient!.open(remotePath);
        final stat = await file.stat();
        final totalBytes = stat.size ?? 0;
        final localFile = File(localPath).openWrite();
  
        int receivedBytes = 0;
  
        await for (final chunk in file.read(length: totalBytes > 0 ? totalBytes : null)) {
          if (checkCancelled?.call() == true) {
            await localFile.close();
            await File(localPath).delete(); // Cleanup partial file
            return false;
          }
          
          localFile.add(chunk);
          receivedBytes += chunk.length;
          if (onProgress != null && totalBytes > 0) {
            onProgress(receivedBytes, totalBytes);
          }
        }
  
        await localFile.flush();
        await localFile.close();
        return true;
      } catch (e) {
        debugPrint('SFTP Download Error: $e');
        return false;
      }
    }
    Future<bool> uploadFile(
      String localPath,
      String remotePath, {
      Function(int sent, int total)? onProgress,
      bool Function()? checkCancelled,
    }) async {
      if (_sftpClient == null) return false;
  
      try {
        final localFile = File(localPath);
        final totalBytes = await localFile.length();
        final remoteFile = await _sftpClient!.open(
          remotePath,
          mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
        );
  
        final stream = localFile.openRead();
        int sentBytes = 0;
  
        await for (final chunk in stream) {
          if (checkCancelled?.call() == true) {
            // We can't easily close the remote file handle gracefully here during a write loop 
            // without potentially stalling, but we stop sending.
            // Ideally we would close remoteFile, but let's just break.
             break; 
          }
  
          await remoteFile.writeBytes(Uint8List.fromList(chunk));
          sentBytes += chunk.length;
          if (onProgress != null) {
            onProgress(sentBytes, totalBytes);
          }
        }
        
        if (checkCancelled?.call() == true) {
           // Cleanup if possible?
           return false;
        }
  
        return true;
      } catch (e) {
        debugPrint('SFTP Upload Error: $e');
        return false;
      }
    }
  Future<bool> createDirectory(String path) async {
    if (_sftpClient == null) return false;

    try {
      await _sftpClient!.mkdir(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> delete(String path, {bool isDirectory = false}) async {
    if (_sftpClient == null) return false;

    try {
      if (isDirectory) {
        await _sftpClient!.rmdir(path);
      } else {
        await _sftpClient!.remove(path);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rename(String oldPath, String newPath) async {
    if (_sftpClient == null) return false;

    try {
      await _sftpClient!.rename(oldPath, newPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Uint8List?> readFile(String path) async {
    if (_sftpClient == null) return null;

    try {
      final file = await _sftpClient!.open(path);
      return await file.readBytes();
    } catch (e) {
      return null;
    }
  }

  Future<void> disconnect() async {
    _sftpClient?.close();
    _client?.close();
    _sftpClient = null;
    _client = null;
  }
}
