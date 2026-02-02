import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../models/tab_session.dart';

class TabProvider extends ChangeNotifier {
  final List<TabSession> _tabs = [];
  String? _activeTabId;

  // Terminal instances stored by tab ID
  final Map<String, Terminal> _terminals = {};
  final Map<String, TerminalController> _terminalControllers = {};

  List<TabSession> get tabs => List.unmodifiable(_tabs);
  String? get activeTabId => _activeTabId;
  TabSession? get activeTab =>
      _tabs.where((t) => t.id == _activeTabId).firstOrNull;

  TabSession? getTab(String tabId) {
    return _tabs.where((t) => t.id == tabId).firstOrNull;
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
    _activeTabId = tab.id;
    notifyListeners();
    return tab.id;
  }

  void removeTab(String tabId) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    _tabs.removeAt(index);

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
    if (_tabs.any((t) => t.id == tabId)) {
      _activeTabId = tabId;
      notifyListeners();
    }
  }

  void updateTabTitle(String tabId, String title) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index != -1) {
      _tabs[index] = _tabs[index].copyWith(title: title);
      notifyListeners();
    }
  }

  void updateTabConnection(String tabId, bool isConnected) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index != -1) {
      _tabs[index] = _tabs[index].copyWith(isConnected: isConnected);
      notifyListeners();
    }
  }

  void updateTabPath(String tabId, String path) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index != -1) {
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
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in _terminalControllers.values) {
      controller.dispose();
    }
    _terminalControllers.clear();
    _terminals.clear();
    super.dispose();
  }
}
