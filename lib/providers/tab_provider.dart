import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../models/tab_session.dart';

class TabProvider extends ChangeNotifier {
  final List<TabSession> _tabs = [];
  String? _activeTabId;
  String? _leftPaneTabId;
  String? _rightPaneTabId;
  bool _isSplitView = false;
  double _splitPosition = 0.5;

  // Terminal instances stored by tab ID
  final Map<String, Terminal> _terminals = {};
  final Map<String, TerminalController> _terminalControllers = {};

  List<TabSession> get tabs => List.unmodifiable(_tabs);
  String? get activeTabId => _activeTabId;
  TabSession? get activeTab => _tabs.where((t) => t.id == _activeTabId).firstOrNull;

  bool get isSplitView => _isSplitView;
  double get splitPosition => _splitPosition;
  String? get leftPaneTabId => _leftPaneTabId;
  String? get rightPaneTabId => _rightPaneTabId;

  TabSession? getTab(String tabId) {
    return _tabs.where((t) => t.id == tabId).firstOrNull;
  }

  Terminal getOrCreateTerminal(String tabId) {
    if (!_terminals.containsKey(tabId)) {
      _terminals[tabId] = Terminal(maxLines: 10000);
      _terminalControllers[tabId] = TerminalController();
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

    // If split view is active and right pane is empty, add to right pane
    if (_isSplitView && _rightPaneTabId == null) {
      _rightPaneTabId = tab.id;
    } else if (!_isSplitView || _leftPaneTabId == null) {
      _leftPaneTabId = tab.id;
    }

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

    // Update pane references
    if (_leftPaneTabId == tabId) {
      _leftPaneTabId = _tabs.isNotEmpty ? _tabs.first.id : null;
    }
    if (_rightPaneTabId == tabId) {
      _rightPaneTabId = null;
      if (_tabs.length > 1) {
        _rightPaneTabId = _tabs.last.id;
      }
    }

    // Update active tab
    if (_activeTabId == tabId) {
      if (_tabs.isNotEmpty) {
        final newIndex = index.clamp(0, _tabs.length - 1);
        _activeTabId = _tabs[newIndex].id;
      } else {
        _activeTabId = null;
      }
    }

    // Disable split view if only one or zero tabs
    if (_tabs.length <= 1) {
      _isSplitView = false;
      _rightPaneTabId = null;
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

  // Split Pane Management
  void toggleSplitView() {
    if (_tabs.length < 2) return;

    _isSplitView = !_isSplitView;

    if (_isSplitView) {
      _leftPaneTabId = _tabs.first.id;
      _rightPaneTabId = _tabs.length > 1 ? _tabs[1].id : null;
    } else {
      _rightPaneTabId = null;
    }

    notifyListeners();
  }

  void setSplitPosition(double position) {
    _splitPosition = position.clamp(0.2, 0.8);
    notifyListeners();
  }

  void setLeftPaneTab(String tabId) {
    if (_tabs.any((t) => t.id == tabId)) {
      _leftPaneTabId = tabId;
      _activeTabId = tabId;
      notifyListeners();
    }
  }

  void setRightPaneTab(String tabId) {
    if (_tabs.any((t) => t.id == tabId)) {
      _rightPaneTabId = tabId;
      _activeTabId = tabId;
      notifyListeners();
    }
  }

  void openLocalFileBrowser() {
    addTab(type: TabType.local, title: 'Local Files');
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
