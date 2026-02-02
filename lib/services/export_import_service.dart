import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/server.dart';

const _uuid = Uuid();

/// Supported export/import formats
enum ExportFormat {
  /// OpenSSH config format (~/.ssh/config)
  /// Compatible with: Termius, PuTTY, OpenSSH, most SSH clients
  sshConfig,

  /// JSON format - MixTerm native with full details
  /// Compatible with: Termius, Termix, and other modern clients
  json,

  /// CSV format for spreadsheet compatibility
  csv,
}

/// Result of export/import operations
class ExportImportResult {
  final bool success;
  final String message;
  final String? filePath;
  final List<Server>? servers;
  final int? count;

  ExportImportResult({
    required this.success,
    required this.message,
    this.filePath,
    this.servers,
    this.count,
  });
}

/// Service for exporting and importing server configurations
class ExportImportService {
  /// Export servers to OpenSSH config format
  /// Note: Passwords cannot be stored in SSH config (security by design)
  /// Private keys are referenced by path, not embedded
  static String toSSHConfig(List<Server> servers) {
    final buffer = StringBuffer();
    buffer.writeln('# MixTerm SSH Config Export');
    buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# Servers: ${servers.length}');
    buffer.writeln();

    for (final server in servers) {
      // Use server name as Host alias (sanitize for SSH config)
      final hostAlias = _sanitizeHostAlias(server.name);

      buffer.writeln('Host $hostAlias');
      buffer.writeln('    HostName ${server.host}');
      buffer.writeln('    User ${server.username}');

      if (server.port != 22) {
        buffer.writeln('    Port ${server.port}');
      }

      if (server.authType == AuthType.key && server.privateKey != null) {
        // Note: SSH config expects a file path, not the key content
        // We'll add a comment indicating key-based auth is needed
        buffer.writeln('    # Authentication: SSH Key (import key manually)');
        buffer.writeln('    # IdentityFile ~/.ssh/${hostAlias}_key');
      }

      if (server.group != null && server.group!.isNotEmpty) {
        buffer.writeln('    # Group: ${server.group}');
      }

      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Export servers to JSON format (Termius/Termix compatible)
  /// includeSecrets: if true, includes passwords/keys (for backup)
  /// if false, exports without sensitive data (for sharing)
  static String toJSON(List<Server> servers, {bool includeSecrets = false}) {
    final exportData = {
      'version': 1,
      'generator': 'MixTerm',
      'exportedAt': DateTime.now().toIso8601String(),
      'hosts': servers.map((server) {
        final host = <String, dynamic>{
          'name': server.name,
          'ip': server.host,
          'hostname': server.host,
          'port': server.port,
          'username': server.username,
          'authType': server.authType == AuthType.key ? 'key' : 'password',
        };

        if (server.group != null && server.group!.isNotEmpty) {
          host['group'] = server.group;
          host['folder'] = server.group; // Termius compatibility
        }

        if (includeSecrets) {
          if (server.authType == AuthType.password && server.password != null) {
            host['password'] = server.password;
          }
          if (server.authType == AuthType.key) {
            if (server.privateKey != null) {
              host['privateKey'] = server.privateKey;
            }
            if (server.passphrase != null) {
              host['passphrase'] = server.passphrase;
            }
          }
        }

        return host;
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Export servers to CSV format
  static String toCSV(List<Server> servers, {bool includeSecrets = false}) {
    final buffer = StringBuffer();

    // Header row
    final headers = ['name', 'host', 'port', 'username', 'authType', 'group'];
    if (includeSecrets) {
      headers.addAll(['password', 'privateKey', 'passphrase']);
    }
    buffer.writeln(headers.join(','));

    // Data rows
    for (final server in servers) {
      final row = [
        _escapeCSV(server.name),
        _escapeCSV(server.host),
        server.port.toString(),
        _escapeCSV(server.username),
        server.authType,
        _escapeCSV(server.group ?? ''),
      ];

      if (includeSecrets) {
        row.addAll([
          _escapeCSV(server.password ?? ''),
          _escapeCSV(server.privateKey ?? ''),
          _escapeCSV(server.passphrase ?? ''),
        ]);
      }

      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  /// Export servers to file
  static Future<ExportImportResult> exportToFile(
    List<Server> servers,
    String filePath,
    ExportFormat format, {
    bool includeSecrets = false,
  }) async {
    try {
      String content;
      switch (format) {
        case ExportFormat.sshConfig:
          content = toSSHConfig(servers);
          break;
        case ExportFormat.json:
          content = toJSON(servers, includeSecrets: includeSecrets);
          break;
        case ExportFormat.csv:
          content = toCSV(servers, includeSecrets: includeSecrets);
          break;
      }

      final file = File(filePath);
      await file.writeAsString(content);

      return ExportImportResult(
        success: true,
        message: 'Exported ${servers.length} servers to $filePath',
        filePath: filePath,
        count: servers.length,
      );
    } catch (e) {
      debugPrint('Export error: $e');
      return ExportImportResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  /// Import servers from JSON format
  static List<Server> fromJSON(String content) {
    final data = json.decode(content);
    final List<dynamic> hosts;

    // Support both { "hosts": [...] } and direct array format
    if (data is List) {
      hosts = data;
    } else if (data is Map && data.containsKey('hosts')) {
      hosts = data['hosts'] as List;
    } else {
      throw FormatException('Invalid JSON format: expected "hosts" array');
    }

    return hosts.map((host) {
      // Support various field names for compatibility
      final hostname = host['hostname'] ?? host['ip'] ?? host['host'] ?? '';
      final name = host['name'] ?? host['label'] ?? hostname;
      final port = host['port'] ?? 22;
      final username = host['username'] ?? host['user'] ?? 'root';
      final authType = _parseAuthType(host['authType']);

      return Server(
        id: _uuid.v4(),
        name: name.toString(),
        host: hostname.toString(),
        port: port is int ? port : int.tryParse(port.toString()) ?? 22,
        username: username.toString(),
        authType: authType,
        password: host['password']?.toString(),
        privateKey: host['privateKey']?.toString(),
        passphrase: host['passphrase']?.toString(),
        group: host['group']?.toString() ?? host['folder']?.toString(),
      );
    }).toList();
  }

  /// Import servers from SSH config format
  static List<Server> fromSSHConfig(String content) {
    final servers = <Server>[];
    String? currentHost;
    String? hostname;
    String? user;
    int port = 22;
    String? identityFile;

    for (var line in content.split('\n')) {
      line = line.trim();

      // Skip comments and empty lines (but check for group comments)
      if (line.isEmpty) {
        // End of current host block
        if (currentHost != null && hostname != null) {
          servers.add(Server(
            id: _uuid.v4(),
            name: currentHost,
            host: hostname,
            port: port,
            username: user ?? 'root',
            authType: identityFile != null ? AuthType.key : AuthType.password,
          ));
        }
        // Reset for next host
        currentHost = null;
        hostname = null;
        user = null;
        port = 22;
        identityFile = null;
        continue;
      }

      if (line.startsWith('#')) continue;

      // Parse directives
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final directive = parts[0].toLowerCase();
      final value = parts.sublist(1).join(' ');

      switch (directive) {
        case 'host':
          // Save previous host if exists
          if (currentHost != null && hostname != null) {
            servers.add(Server(
              id: _uuid.v4(),
              name: currentHost,
              host: hostname,
              port: port,
              username: user ?? 'root',
              authType: identityFile != null ? AuthType.key : AuthType.password,
            ));
          }
          // Start new host
          currentHost = value;
          hostname = null;
          user = null;
          port = 22;
          identityFile = null;
          break;
        case 'hostname':
          hostname = value;
          break;
        case 'user':
          user = value;
          break;
        case 'port':
          port = int.tryParse(value) ?? 22;
          break;
        case 'identityfile':
          identityFile = value;
          break;
      }
    }

    // Don't forget the last host
    if (currentHost != null && hostname != null) {
      servers.add(Server(
        id: _uuid.v4(),
        name: currentHost,
        host: hostname,
        port: port,
        username: user ?? 'root',
        authType: identityFile != null ? AuthType.key : AuthType.password,
      ));
    }

    return servers;
  }

  /// Import servers from CSV format
  static List<Server> fromCSV(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    // Parse header to find column indices
    final header = _parseCSVRow(lines[0]);
    final nameIdx = _findColumnIndex(header, ['name', 'label', 'host']);
    final hostIdx = _findColumnIndex(header, ['host', 'hostname', 'ip', 'address']);
    final portIdx = _findColumnIndex(header, ['port']);
    final userIdx = _findColumnIndex(header, ['username', 'user', 'login']);
    final authIdx = _findColumnIndex(header, ['authtype', 'auth', 'authentication']);
    final groupIdx = _findColumnIndex(header, ['group', 'folder', 'category']);
    final passIdx = _findColumnIndex(header, ['password', 'pass']);
    final keyIdx = _findColumnIndex(header, ['privatekey', 'key', 'sshkey']);
    final phraseIdx = _findColumnIndex(header, ['passphrase']);

    return lines.skip(1).map((line) {
      final cols = _parseCSVRow(line);
      if (cols.length <= (hostIdx ?? 0)) return null;

      final host = hostIdx != null ? cols[hostIdx] : '';
      if (host.isEmpty) return null;

      return Server(
        id: _uuid.v4(),
        name: nameIdx != null && cols.length > nameIdx ? cols[nameIdx] : host,
        host: host,
        port: portIdx != null && cols.length > portIdx
            ? int.tryParse(cols[portIdx]) ?? 22
            : 22,
        username: userIdx != null && cols.length > userIdx ? cols[userIdx] : 'root',
        authType: authIdx != null && cols.length > authIdx
            ? _parseAuthType(cols[authIdx])
            : AuthType.password,
        group: groupIdx != null && cols.length > groupIdx && cols[groupIdx].isNotEmpty
            ? cols[groupIdx]
            : null,
        password: passIdx != null && cols.length > passIdx && cols[passIdx].isNotEmpty
            ? cols[passIdx]
            : null,
        privateKey: keyIdx != null && cols.length > keyIdx && cols[keyIdx].isNotEmpty
            ? cols[keyIdx]
            : null,
        passphrase: phraseIdx != null && cols.length > phraseIdx && cols[phraseIdx].isNotEmpty
            ? cols[phraseIdx]
            : null,
      );
    }).whereType<Server>().toList();
  }

  /// Import servers from file (auto-detect format)
  static Future<ExportImportResult> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ExportImportResult(
          success: false,
          message: 'File not found: $filePath',
        );
      }

      final content = await file.readAsString();
      final extension = filePath.split('.').last.toLowerCase();

      List<Server> servers;

      if (extension == 'json') {
        servers = fromJSON(content);
      } else if (extension == 'csv') {
        servers = fromCSV(content);
      } else if (extension == 'config' || content.trim().startsWith('Host ')) {
        servers = fromSSHConfig(content);
      } else {
        // Try to auto-detect format
        if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
          servers = fromJSON(content);
        } else if (content.contains(',') && content.split('\n')[0].contains('host')) {
          servers = fromCSV(content);
        } else {
          servers = fromSSHConfig(content);
        }
      }

      return ExportImportResult(
        success: true,
        message: 'Imported ${servers.length} servers from $filePath',
        filePath: filePath,
        servers: servers,
        count: servers.length,
      );
    } catch (e) {
      debugPrint('Import error: $e');
      return ExportImportResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }

  /// Import from string content with specified format
  static ExportImportResult importFromString(String content, ExportFormat format) {
    try {
      List<Server> servers;

      switch (format) {
        case ExportFormat.json:
          servers = fromJSON(content);
          break;
        case ExportFormat.csv:
          servers = fromCSV(content);
          break;
        case ExportFormat.sshConfig:
          servers = fromSSHConfig(content);
          break;
      }

      return ExportImportResult(
        success: true,
        message: 'Imported ${servers.length} servers',
        servers: servers,
        count: servers.length,
      );
    } catch (e) {
      return ExportImportResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }

  // Helper methods

  static String _sanitizeHostAlias(String name) {
    // SSH config host aliases should not contain spaces or special chars
    return name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static AuthType _parseAuthType(dynamic value) {
    if (value == null) return AuthType.password;
    final str = value.toString().toLowerCase();
    if (str.contains('key') || str == 'publickey') return AuthType.key;
    return AuthType.password;
  }

  static List<String> _parseCSVRow(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());

    return result;
  }

  static int? _findColumnIndex(List<String> header, List<String> candidates) {
    for (var i = 0; i < header.length; i++) {
      final col = header[i].toLowerCase().trim();
      if (candidates.any((c) => col == c || col.contains(c))) {
        return i;
      }
    }
    return null;
  }
}
