import 'package:flutter/foundation.dart';
import '../models/server.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class ServerProvider extends ChangeNotifier {
  final StorageService _storageService;
  final SyncService _syncService;

  List<Server> _servers = [];
  bool _isLoading = false;
  String? _error;

  ServerProvider(this._storageService, this._syncService);

  List<Server> get servers => _servers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadServers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _servers = await _storageService.loadServers();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addServer(Server server) async {
    _servers.add(server);
    notifyListeners();

    final success = await _storageService.saveServers(_servers);
    if (!success) {
      _servers.remove(server);
      notifyListeners();
    }
    return success;
  }

  Future<bool> updateServer(Server server) async {
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index == -1) return false;

    final oldServer = _servers[index];
    _servers[index] = server;
    notifyListeners();

    final success = await _storageService.saveServers(_servers);
    if (!success) {
      _servers[index] = oldServer;
      notifyListeners();
    }
    return success;
  }

  Future<bool> deleteServer(String id) async {
    final index = _servers.indexWhere((s) => s.id == id);
    if (index == -1) return false;

    final server = _servers.removeAt(index);
    notifyListeners();

    final success = await _storageService.saveServers(_servers);
    if (!success) {
      _servers.insert(index, server);
      notifyListeners();
    }
    return success;
  }

  Server? getServer(String id) {
    try {
      return _servers.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<SyncResult> syncToCloud() async {
    return await _syncService.syncToCloud(_servers);
  }

  Future<SyncResult> syncFromCloud() async {
    final result = await _syncService.syncFromCloud();
    if (result.success && result.servers != null) {
      _servers = result.servers!;
      notifyListeners();
    }
    return result;
  }

  List<String> get groups {
    final groupSet = <String>{};
    for (final server in _servers) {
      if (server.group != null && server.group!.isNotEmpty) {
        groupSet.add(server.group!);
      }
    }
    return groupSet.toList()..sort();
  }

  List<Server> getServersByGroup(String? group) {
    if (group == null) {
      return _servers.where((s) => s.group == null || s.group!.isEmpty).toList();
    }
    return _servers.where((s) => s.group == group).toList();
  }
}
