import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../models/tab_session.dart';

class TabProvider extends ChangeNotifier {
  final List<TabSession> _tabs = [];
  // O(1) lookup index for tabs by ID
  final Map<String, int> _tabIndex = {};
  String? _activeTabId;

  // Terminal instances stored by tab ID
  final Map<String, Terminal> _terminals = {};
  final Map<String, TerminalController> _terminalControllers = {};

  List<TabSession> get tabs => List.unmodifiable(_tabs);
  String? get activeTabId => _activeTabId;

  /// O(1) lookup for active tab using index map
  TabSession? get activeTab {
    if (_activeTabId == null) return null;
    final index = _tabIndex[_activeTabId];
    return index != null ? _tabs[index] : null;
  }

  /// O(1) lookup for tab by ID using index map
  TabSession? getTab(String tabId) {
    final index = _tabIndex[tabId];
    return index != null ? _tabs[index] : null;
  }

  Terminal getOrCreateTerminal(String tabId) {
    if (!_terminals.containsKey(tabId)) {
      _terminals[tabId] = Terminal(maxLines: 10000);
      // Create controller with pointer input disabled for mouse events
      // This allows text selection to work even when terminal apps have mouse tracking
      // Only tap events go to terminal, drag events are used for selection
      _terminalControllers[tabId] = TerminalController(
        pointerInputs: const PointerInputs({}), // Disable all pointer forwarding to terminal
      );
    }
    return _terminals[tabId]!;
  }

  TerminalController? getTerminalController(String tabId) {
    return _terminalControllers[tabId];
  }

  String addTab({
    required TabType type,
    String? serverId,
    String? title,
  }) {
    final tab = TabSession(
      serverId: serverId,
      type: type,
      title: title,
    );
    _tabs.add(tab);
    _tabIndex[tab.id] = _tabs.length - 1; // O(1) index update
    _activeTabId = tab.id;
    notifyListeners();
    return tab.id;
  }

  void removeTab(String tabId) {
    final index = _tabIndex[tabId]; // O(1) lookup
    if (index == null) return;

    _tabs.removeAt(index);
    _tabIndex.remove(tabId);

    // Rebuild index for tabs after the removed one
    _rebuildIndexFrom(index);

    // Clean up terminal resources
    _terminals[tabId]?.buffer.clear();
    _terminals.remove(tabId);
    _terminalControllers[tabId]?.dispose();
    _terminalControllers.remove(tabId);

    // Update active tab
    if (_activeTabId == tabId) {
      if (_tabs.isNotEmpty) {
        final newIndex = index.clamp(0, _tabs.length - 1);
        _activeTabId = _tabs[newIndex].id;
      } else {
        _activeTabId = null;
      }
    }

    notifyListeners();
  }

  void setActiveTab(String tabId) {
    if (_tabIndex.containsKey(tabId)) { // O(1) check
      _activeTabId = tabId;
      notifyListeners();
    }
  }

  void updateTabTitle(String tabId, String title) {
    final index = _tabIndex[tabId]; // O(1) lookup
    if (index != null) {
      _tabs[index] = _tabs[index].copyWith(title: title);
      notifyListeners();
    }
  }

  void updateTabConnection(String tabId, bool isConnected) {
    final index = _tabIndex[tabId]; // O(1) lookup
    if (index != null) {
      _tabs[index] = _tabs[index].copyWith(isConnected: isConnected);
      notifyListeners();
    }
  }

  void updateTabPath(String tabId, String path) {
    final index = _tabIndex[tabId]; // O(1) lookup
    if (index != null) {
      _tabs[index] = _tabs[index].copyWith(currentPath: path);
      notifyListeners();
    }
  }

  void reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);
    // Rebuild index for affected range
    _rebuildIndexFrom(oldIndex < newIndex ? oldIndex : newIndex);
    notifyListeners();
  }

  /// Rebuild index map from a specific position
  void _rebuildIndexFrom(int fromIndex) {
    for (var i = fromIndex; i < _tabs.length; i++) {
      _tabIndex[_tabs[i].id] = i;
    }
  }

  @override
  void dispose() {
    for (final controller in _terminalControllers.values) {
      controller.dispose();
    }
    _terminalControllers.clear();
    _terminals.clear();
    _tabIndex.clear();
    super.dispose();
  }
}
