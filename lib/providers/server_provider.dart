import 'package:flutter/foundation.dart';
import '../models/server.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class ServerProvider extends ChangeNotifier {
  final StorageService _storageService;
  final SyncService _syncService;

  List<Server> _servers = [];
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

  Future<bool> hasCloudData() async {
    return await _syncService.hasCloudData();
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
