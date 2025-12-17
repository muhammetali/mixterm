import 'package:flutter/foundation.dart';
import '../models/server.dart';
import '../services/ssh_service.dart';
import '../services/sftp_service.dart';

class ConnectionResult<T> {
  final bool success;
  final T? service;
  final String? error;

  ConnectionResult({required this.success, this.service, this.error});

  factory ConnectionResult.ok(T service) =>
      ConnectionResult(success: true, service: service);

  factory ConnectionResult.fail(String error) =>
      ConnectionResult(success: false, error: error);
}

class ConnectionProvider extends ChangeNotifier {
  final Map<String, SSHService> _sshConnections = {};
  final Map<String, SFTPService> _sftpConnections = {};
  String? _activeServerId;
  String? _activeConnectionType;

  String? get activeServerId => _activeServerId;
  String? get activeConnectionType => _activeConnectionType;

  SSHService? getSSHConnection(String serverId) => _sshConnections[serverId];
  SFTPService? getSFTPConnection(String serverId) => _sftpConnections[serverId];

  bool isSSHConnected(String serverId) =>
      _sshConnections[serverId]?.isConnected ?? false;

  bool isSFTPConnected(String serverId) =>
      _sftpConnections[serverId]?.isConnected ?? false;

  Future<ConnectionResult<SSHService>> connectSSH(Server server) async {
    if (_sshConnections.containsKey(server.id)) {
      final existing = _sshConnections[server.id]!;
      if (existing.isConnected) {
        _activeServerId = server.id;
        _activeConnectionType = 'ssh';
        notifyListeners();
        return ConnectionResult.ok(existing);
      }
    }

    final sshService = SSHService();
    final result = await sshService.connect(server);

    if (result.success) {
      _sshConnections[server.id] = sshService;
      _activeServerId = server.id;
      _activeConnectionType = 'ssh';
      notifyListeners();
      return ConnectionResult.ok(sshService);
    }

    return ConnectionResult.fail(result.error ?? 'Connection failed');
  }

  Future<ConnectionResult<SFTPService>> connectSFTP(Server server) async {
    if (_sftpConnections.containsKey(server.id)) {
      final existing = _sftpConnections[server.id]!;
      if (existing.isConnected) {
        _activeServerId = server.id;
        _activeConnectionType = 'sftp';
        notifyListeners();
        return ConnectionResult.ok(existing);
      }
    }

    final sftpService = SFTPService();
    final result = await sftpService.connect(server);

    if (result.success) {
      _sftpConnections[server.id] = sftpService;
      _activeServerId = server.id;
      _activeConnectionType = 'sftp';
      notifyListeners();
      return ConnectionResult.ok(sftpService);
    }

    return ConnectionResult.fail(result.error ?? 'Connection failed');
  }

  void setActive(String serverId, String type) {
    _activeServerId = serverId;
    _activeConnectionType = type;
    notifyListeners();
  }

  Future<void> disconnectSSH(String serverId) async {
    final service = _sshConnections[serverId];
    if (service != null) {
      await service.disconnect();
      _sshConnections.remove(serverId);

      if (_activeServerId == serverId && _activeConnectionType == 'ssh') {
        _activeServerId = null;
        _activeConnectionType = null;
      }
      notifyListeners();
    }
  }

  Future<void> disconnectSFTP(String serverId) async {
    final service = _sftpConnections[serverId];
    if (service != null) {
      await service.disconnect();
      _sftpConnections.remove(serverId);

      if (_activeServerId == serverId && _activeConnectionType == 'sftp') {
        _activeServerId = null;
        _activeConnectionType = null;
      }
      notifyListeners();
    }
  }

  Future<void> disconnectAll(String serverId) async {
    await disconnectSSH(serverId);
    await disconnectSFTP(serverId);
  }

  List<String> get activeSSHConnections => _sshConnections.entries
      .where((e) => e.value.isConnected)
      .map((e) => e.key)
      .toList();

  List<String> get activeSFTPConnections => _sftpConnections.entries
      .where((e) => e.value.isConnected)
      .map((e) => e.key)
      .toList();

  void dispose() {
    for (final service in _sshConnections.values) {
      service.dispose();
    }
    for (final service in _sftpConnections.values) {
      service.disconnect();
    }
    super.dispose();
  }
}
