import 'package:flutter/foundation.dart';
import '../models/server.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class ServerProvider extends ChangeNotifier {
  final StorageService _storageService;
  final SyncService _syncService;

  List<Server> _servers = [];
  // O(1) lookup index for servers by ID
  Map<String, int> _serverIndex = {};
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  ServerProvider(this._storageService, this._syncService);

  List<Server> get servers => _servers;
  bool get isLoading => _isLoading || _isSyncing;
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  Future<void> loadServers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _servers = await _storageService.loadServers();
      _rebuildIndex(); // Build index after loading
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<SyncResult> performSmartSync() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('SmartSync: Starting synchronization process...');

      // 1. Fetch cloud data
      final cloudResult = await _syncService.syncFromCloud();

      if (!cloudResult.success && cloudResult.message != 'No cloud data found') {
        return cloudResult;
      }

      final cloudServers = cloudResult.servers ?? [];

      // 2. Perform Intelligent Merge
      final mergedServers = _mergeServers(_servers, cloudServers);

      // 3. Save locally (with automatic backup in StorageService)
      final localSaveSuccess = await _storageService.saveServers(mergedServers);
      if (!localSaveSuccess) {
        return SyncResult(success: false, message: 'Failed to save merged data locally');
      }

      _servers = mergedServers;
      _rebuildIndex(); // Rebuild index after merge

      // 4. Update last sync timestamp
      await _storageService.saveLastSyncTimestamp(DateTime.now().millisecondsSinceEpoch);

      // 5. Push merged state back to cloud to ensure all devices converge
      final pushResult = await _syncService.syncToCloud(_servers);

      notifyListeners();
      return pushResult.success
          ? SyncResult(success: true, message: 'Smart Sync completed successfully', servers: _servers)
          : SyncResult(success: false, message: 'Data merged locally but cloud update failed: ${pushResult.message}');

    } catch (e) {
      debugPrint('SmartSync: Fatal error: $e');
      return SyncResult(success: false, message: 'Smart Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  List<Server> _mergeServers(List<Server> local, List<Server> cloud) {
    final Map<String, Server> masterMap = {};

    // First, add all local servers
    for (final s in local) {
      masterMap[s.id] = s;
    }

    // Then, merge cloud servers based on updatedAt timestamp
    for (final s in cloud) {
      if (!masterMap.containsKey(s.id)) {
        // New server from cloud
        masterMap[s.id] = s;
      } else {
        // Conflict detected - use the most recently updated one
        final existing = masterMap[s.id]!;
        if (s.updatedAt.isAfter(existing.updatedAt)) {
          masterMap[s.id] = s;
        }
      }
    }

    return masterMap.values.toList();
  }

  Future<bool> addServer(Server server) async {
    _servers.add(server);
    _serverIndex[server.id] = _servers.length - 1; // O(1) index update
    notifyListeners();

    final success = await _storageService.saveServers(_servers);
    if (!success) {
      _servers.remove(server);
      _serverIndex.remove(server.id);
      notifyListeners();
    }
    return success;
  }

  Future<bool> updateServer(Server server) async {
    final index = _serverIndex[server.id]; // O(1) lookup
    if (index == null) return false;

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
    final index = _serverIndex[id]; // O(1) lookup
    if (index == null) return false;

    final server = _servers.removeAt(index);
    _serverIndex.remove(id);
    _rebuildIndexFrom(index); // Rebuild only affected portion
    notifyListeners();

    final success = await _storageService.saveServers(_servers);
    if (!success) {
      _servers.insert(index, server);
      _rebuildIndex(); // Rebuild entire index on rollback
      notifyListeners();
    }
    return success;
  }

  /// O(1) lookup for server by ID
  Server? getServer(String id) {
    final index = _serverIndex[id];
    return index != null ? _servers[index] : null;
  }

  Future<SyncResult> syncToCloud() async {
    return await _syncService.syncToCloud(_servers);
  }

  Future<SyncResult> syncFromCloud() async {
    final result = await _syncService.syncFromCloud();
    if (result.success && result.servers != null) {
      _servers = result.servers!;
      _rebuildIndex(); // Rebuild index after sync
      notifyListeners();
    }
    return result;
  }

  Future<bool> hasCloudData() async {
    return await _syncService.hasCloudData();
  }

  /// Deletes cloud data - useful when encryption keys don't match
  Future<SyncResult> deleteCloudData() async {
    return await _syncService.deleteCloudData();
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

  /// Rebuild entire index map
  void _rebuildIndex() {
    _serverIndex = {
      for (var i = 0; i < _servers.length; i++) _servers[i].id: i
    };
  }

  /// Rebuild index map from a specific position
  void _rebuildIndexFrom(int fromIndex) {
    for (var i = fromIndex; i < _servers.length; i++) {
      _serverIndex[_servers[i].id] = i;
    }
  }
}
