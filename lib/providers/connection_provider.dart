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

/// Connection provider that manages SSH/SFTP connections per tab.
/// Each tab has its own independent connection, allowing multiple
/// sessions to the same server.
class ConnectionProvider extends ChangeNotifier {
  // Connections keyed by tabId for independent sessions per tab
  final Map<String, SSHService> _sshConnections = {};
  final Map<String, SFTPService> _sftpConnections = {};

  // Track which server each tab is connected to (tabId -> serverId)
  final Map<String, String> _tabServerMap = {};

  // Race condition prevention for connections in progress
  final Set<String> _connectingTabs = {};

  String? _activeTabId;
  String? _activeConnectionType;

  String? get activeTabId => _activeTabId;
  String? get activeConnectionType => _activeConnectionType;

  /// Get SSH connection by tabId
  SSHService? getSSHConnection(String tabId) => _sshConnections[tabId];

  /// Get SFTP connection by tabId
  SFTPService? getSFTPConnection(String tabId) => _sftpConnections[tabId];

  /// Check if a tab has an active SSH connection
  bool isSSHConnected(String tabId) =>
      _sshConnections[tabId]?.isConnected ?? false;

  /// Check if a tab has an active SFTP connection
  bool isSFTPConnected(String tabId) =>
      _sftpConnections[tabId]?.isConnected ?? false;

  /// Get the serverId associated with a tab
  String? getServerIdForTab(String tabId) => _tabServerMap[tabId];

  /// Connect SSH for a specific tab - creates independent connection
  Future<ConnectionResult<SSHService>> connectSSH(Server server, String tabId) async {
    // Race condition prevention
    if (_connectingTabs.contains(tabId)) {
      return ConnectionResult.fail('Connection already in progress');
    }

    // Check if this tab already has a connection
    if (_sshConnections.containsKey(tabId)) {
      final existing = _sshConnections[tabId]!;
      if (existing.isConnected) {
        _activeTabId = tabId;
        _activeConnectionType = 'ssh';
        notifyListeners();
        return ConnectionResult.ok(existing);
      }
    }

    _connectingTabs.add(tabId);
    notifyListeners();

    try {
      final sshService = SSHService();
      final result = await sshService.connect(server);

      if (result.success) {
        _sshConnections[tabId] = sshService;
        _tabServerMap[tabId] = server.id;
        _activeTabId = tabId;
        _activeConnectionType = 'ssh';
        notifyListeners();
        return ConnectionResult.ok(sshService);
      }

      return ConnectionResult.fail(result.error ?? 'Connection failed');
    } finally {
      _connectingTabs.remove(tabId);
      notifyListeners();
    }
  }

  /// Connect SFTP for a specific tab - creates independent connection
  Future<ConnectionResult<SFTPService>> connectSFTP(Server server, String tabId) async {
    // Race condition prevention
    if (_connectingTabs.contains(tabId)) {
      return ConnectionResult.fail('Connection already in progress');
    }

    // Check if this tab already has a connection
    if (_sftpConnections.containsKey(tabId)) {
      final existing = _sftpConnections[tabId]!;
      if (existing.isConnected) {
        _activeTabId = tabId;
        _activeConnectionType = 'sftp';
        notifyListeners();
        return ConnectionResult.ok(existing);
      }
    }

    _connectingTabs.add(tabId);
    notifyListeners();

    try {
      final sftpService = SFTPService();
      final result = await sftpService.connect(server);

      if (result.success) {
        _sftpConnections[tabId] = sftpService;
        _tabServerMap[tabId] = server.id;
        _activeTabId = tabId;
        _activeConnectionType = 'sftp';
        notifyListeners();
        return ConnectionResult.ok(sftpService);
      }

      return ConnectionResult.fail(result.error ?? 'Connection failed');
    } finally {
      _connectingTabs.remove(tabId);
      notifyListeners();
    }
  }

  void setActive(String tabId, String type) {
    _activeTabId = tabId;
    _activeConnectionType = type;
    notifyListeners();
  }

  /// Disconnect SSH connection for a specific tab
  Future<void> disconnectSSH(String tabId) async {
    final service = _sshConnections[tabId];
    if (service != null) {
      await service.disconnect();
      _sshConnections.remove(tabId);
      _tabServerMap.remove(tabId);

      if (_activeTabId == tabId && _activeConnectionType == 'ssh') {
        _activeTabId = null;
        _activeConnectionType = null;
      }
      notifyListeners();
    }
  }

  /// Disconnect SFTP connection for a specific tab
  Future<void> disconnectSFTP(String tabId) async {
    final service = _sftpConnections[tabId];
    if (service != null) {
      await service.disconnect();
      _sftpConnections.remove(tabId);
      _tabServerMap.remove(tabId);

      if (_activeTabId == tabId && _activeConnectionType == 'sftp') {
        _activeTabId = null;
        _activeConnectionType = null;
      }
      notifyListeners();
    }
  }

  /// Disconnect all connections for a specific tab
  Future<void> disconnectTab(String tabId) async {
    await disconnectSSH(tabId);
    await disconnectSFTP(tabId);
  }

  /// Get list of tabIds with active SSH connections
  List<String> get activeSSHConnections => _sshConnections.entries
      .where((e) => e.value.isConnected)
      .map((e) => e.key)
      .toList();

  /// Get list of tabIds with active SFTP connections
  List<String> get activeSFTPConnections => _sftpConnections.entries
      .where((e) => e.value.isConnected)
      .map((e) => e.key)
      .toList();

  /// Check if connection is in progress for a tab
  bool isConnecting(String tabId) => _connectingTabs.contains(tabId);

  /// Check if any SSH connection exists for a given server (across all tabs)
  bool hasAnySSHConnectionForServer(String serverId) {
    return _sshConnections.entries.any((e) =>
      e.value.isConnected && _tabServerMap[e.key] == serverId
    );
  }

  /// Check if any SFTP connection exists for a given server (across all tabs)
  bool hasAnySFTPConnectionForServer(String serverId) {
    return _sftpConnections.entries.any((e) =>
      e.value.isConnected && _tabServerMap[e.key] == serverId
    );
  }

  /// Disconnect all connections for a given server (all tabs connected to it)
  Future<void> disconnectAllForServer(String serverId) async {
    // Find all tabs connected to this server
    final tabsToDisconnect = _tabServerMap.entries
        .where((e) => e.value == serverId)
        .map((e) => e.key)
        .toList();

    for (final tabId in tabsToDisconnect) {
      await disconnectSSH(tabId);
      await disconnectSFTP(tabId);
    }
  }

  @override
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
