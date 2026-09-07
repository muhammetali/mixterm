import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import '../models/server.dart';
import '../utils/constants.dart';
import '../utils/result.dart';

class SFTPService {
  SSHClient? _client;
  SftpClient? _sftpClient;

  bool get isConnected => _sftpClient != null;

  /// Test-only seam: lets tests exercise the post-connect methods below
  /// against a fake [SftpClient] without a real network connection.
  @visibleForTesting
  set debugSftpClient(SftpClient? client) => _sftpClient = client;

  Future<VoidResult> connect(Server server) async {
    try {
      debugPrint('SFTP: Connecting to ${server.host}:${server.port}');

      final socket = await SSHSocket.connect(
        server.host,
        server.port,
        timeout: const Duration(seconds: AppConstants.connectionTimeout),
      );
      debugPrint('SFTP: Socket connected');

      if (server.authType == AuthType.password) {
        debugPrint('SFTP: Using password authentication');
        _client = SSHClient(
          socket,
          username: server.username,
          onPasswordRequest: () => server.password ?? '',
          keepAliveInterval:
              const Duration(seconds: AppConstants.sshKeepAliveIntervalSeconds),
        );
      } else {
        debugPrint('SFTP: Using key authentication');
        final privateKey = server.privateKey ?? '';
        if (privateKey.isEmpty) {
          return VoidResult.fail('Private key is empty');
        }

        try {
          final keyPairs = SSHKeyPair.fromPem(
            privateKey,
            server.passphrase,
          );
          debugPrint('SFTP: Parsed ${keyPairs.length} key pair(s)');

          if (keyPairs.isEmpty) {
            return VoidResult.fail('Failed to parse private key');
          }

          _client = SSHClient(
            socket,
            username: server.username,
            identities: keyPairs,
            keepAliveInterval: const Duration(
              seconds: AppConstants.sshKeepAliveIntervalSeconds,
            ),
          );
        } catch (e) {
          debugPrint('SFTP: Key parsing error: $e');
          return VoidResult.fail('Invalid private key format: $e');
        }
      }

      debugPrint('SFTP: Waiting for authentication...');
      await _client!.authenticated;
      debugPrint('SFTP: Authenticated successfully');

      _sftpClient = await _client!.sftp();
      debugPrint('SFTP: SFTP session started');
      return VoidResult.ok();
    } on SocketException catch (e) {
      debugPrint('SFTP: Socket error: $e');
      return VoidResult.fail('Could not connect to ${server.host}:${server.port}');
    } on SSHAuthFailError catch (e) {
      debugPrint('SFTP: Auth failed: $e');
      return VoidResult.fail('Authentication failed: Invalid credentials');
    } catch (e) {
      debugPrint('SFTP: General error: $e');
      return VoidResult.fail('$e');
    }
  }

  Future<Result<List<SftpName>>> listDirectory(String path) async {
    if (_sftpClient == null) return Result.fail('Not connected');

    try {
      final items = await _sftpClient!.listdir(path);
      final filtered = items.where((item) => item.filename != '.' && item.filename != '..').toList();
      filtered.sort((a, b) {
        if (a.attr.isDirectory && !b.attr.isDirectory) return -1;
        if (!a.attr.isDirectory && b.attr.isDirectory) return 1;
        return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      });
      return Result.ok(filtered);
    } catch (e) {
      debugPrint('SFTP: listDirectory error: $e');
      return Result.fail('Could not list "$path": $e');
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

  Future<VoidResult> downloadFile(
    String remotePath,
    String localPath, {
    Function(int received, int total)? onProgress,
    bool Function()? checkCancelled,
  }) async {
    if (_sftpClient == null) return VoidResult.fail('Not connected');

    SftpFile? file;
    IOSink? localFile;
    try {
      file = await _sftpClient!.open(remotePath);
      final stat = await file.stat();
      final totalBytes = stat.size ?? 0;
      localFile = File(localPath).openWrite();

      int receivedBytes = 0;

      await for (final chunk in file.read(length: totalBytes > 0 ? totalBytes : null)) {
        if (checkCancelled?.call() == true) {
          await localFile.close();
          await file.close();
          await File(localPath).delete();
          return VoidResult.fail('Download cancelled');
        }

        localFile.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null && totalBytes > 0) {
          onProgress(receivedBytes, totalBytes);
        }
      }

      await localFile.flush();
      await localFile.close();
      await file.close();
      return VoidResult.ok();
    } catch (e) {
      debugPrint('SFTP Download Error: $e');
      return VoidResult.fail('Could not download "$remotePath": $e');
    } finally {
      try {
        await localFile?.close();
      } catch (_) {}
      try {
        await file?.close();
      } catch (_) {}
    }
  }

  Future<VoidResult> uploadFile(
    String localPath,
    String remotePath, {
    Function(int sent, int total)? onProgress,
    bool Function()? checkCancelled,
  }) async {
    if (_sftpClient == null) return VoidResult.fail('Not connected');

    SftpFile? remoteFile;
    try {
      final localFile = File(localPath);
      final totalBytes = await localFile.length();
      remoteFile = await _sftpClient!.open(
        remotePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );

      final stream = localFile.openRead();
      int sentBytes = 0;
      bool cancelled = false;

      await for (final chunk in stream) {
        if (checkCancelled?.call() == true) {
          cancelled = true;
          break;
        }

        await remoteFile.writeBytes(Uint8List.fromList(chunk));
        sentBytes += chunk.length;
        if (onProgress != null) {
          onProgress(sentBytes, totalBytes);
        }
      }

      await remoteFile.close();
      return cancelled ? VoidResult.fail('Upload cancelled') : VoidResult.ok();
    } catch (e) {
      debugPrint('SFTP Upload Error: $e');
      return VoidResult.fail('Could not upload "$localPath": $e');
    } finally {
      try {
        await remoteFile?.close();
      } catch (_) {}
    }
  }

  Future<VoidResult> createDirectory(String path) async {
    if (_sftpClient == null) return VoidResult.fail('Not connected');

    try {
      await _sftpClient!.mkdir(path);
      return VoidResult.ok();
    } catch (e) {
      debugPrint('SFTP: createDirectory error: $e');
      return VoidResult.fail('Could not create directory "$path": $e');
    }
  }

  Future<VoidResult> delete(String path, {bool isDirectory = false}) async {
    if (_sftpClient == null) return VoidResult.fail('Not connected');

    try {
      if (isDirectory) {
        await _sftpClient!.rmdir(path);
      } else {
        await _sftpClient!.remove(path);
      }
      return VoidResult.ok();
    } catch (e) {
      debugPrint('SFTP: delete error: $e');
      return VoidResult.fail('Could not delete "$path": $e');
    }
  }

  Future<VoidResult> rename(String oldPath, String newPath) async {
    if (_sftpClient == null) return VoidResult.fail('Not connected');

    try {
      await _sftpClient!.rename(oldPath, newPath);
      return VoidResult.ok();
    } catch (e) {
      debugPrint('SFTP: rename error: $e');
      return VoidResult.fail('Could not rename "$oldPath" to "$newPath": $e');
    }
  }

  Future<Result<Uint8List>> readFile(String path) async {
    if (_sftpClient == null) return Result.fail('Not connected');

    SftpFile? file;
    try {
      file = await _sftpClient!.open(path);
      final bytes = await file.readBytes();
      return Result.ok(bytes);
    } catch (e) {
      debugPrint('SFTP: readFile error: $e');
      return Result.fail('Could not read "$path": $e');
    } finally {
      try {
        await file?.close();
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    _sftpClient?.close();
    _client?.close();
    _sftpClient = null;
    _client = null;
  }
}
