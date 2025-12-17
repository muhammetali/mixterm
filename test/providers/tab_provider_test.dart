import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/models/tab_session.dart';
import 'package:mixterm/providers/tab_provider.dart';

void main() {
  group('TabProvider', () {
    late TabProvider tabProvider;

    setUp(() {
      tabProvider = TabProvider();
    });

    tearDown(() {
      tabProvider.dispose();
    });

    group('Initial State', () {
      test('starts with empty tabs list', () {
        expect(tabProvider.tabs, isEmpty);
      });

      test('starts with no active tab', () {
        expect(tabProvider.activeTabId, isNull);
        expect(tabProvider.activeTab, isNull);
      });

      test('starts with split view disabled', () {
        expect(tabProvider.isSplitView, false);
      });

      test('starts with default split position', () {
        expect(tabProvider.splitPosition, 0.5);
      });

      test('starts with no pane tabs', () {
        expect(tabProvider.leftPaneTabId, isNull);
        expect(tabProvider.rightPaneTabId, isNull);
      });
    });

    group('addTab', () {
      test('adds SSH tab', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
          title: 'SSH Tab',
        );

        expect(tabProvider.tabs.length, 1);
        expect(tabProvider.tabs.first.id, tabId);
        expect(tabProvider.tabs.first.type, TabType.ssh);
        expect(tabProvider.tabs.first.title, 'SSH Tab');
      });

      test('adds SFTP tab', () {
        final tabId = tabProvider.addTab(
          type: TabType.sftp,
          serverId: 'server-1',
          title: 'SFTP Tab',
        );

        expect(tabProvider.tabs.first.type, TabType.sftp);
      });

      test('adds local tab without serverId', () {
        final tabId = tabProvider.addTab(
          type: TabType.local,
          title: 'Local Files',
        );

        expect(tabProvider.tabs.first.type, TabType.local);
        expect(tabProvider.tabs.first.serverId, isNull);
      });

      test('sets new tab as active', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
        );

        expect(tabProvider.activeTabId, tabId);
      });

      test('sets first tab to left pane when not in split view', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
        );

        expect(tabProvider.leftPaneTabId, tabId);
      });

      test('adds multiple tabs', () {
        tabProvider.addTab(type: TabType.ssh, serverId: 'server-1');
        tabProvider.addTab(type: TabType.sftp, serverId: 'server-2');
        tabProvider.addTab(type: TabType.local);

        expect(tabProvider.tabs.length, 3);
      });

      test('returns unique tab ID', () {
        final id1 = tabProvider.addTab(type: TabType.local);
        final id2 = tabProvider.addTab(type: TabType.local);

        expect(id1, isNot(id2));
      });

      test('notifies listeners on add', () {
        var notified = false;
        tabProvider.addListener(() => notified = true);

        tabProvider.addTab(type: TabType.local);

        expect(notified, true);
      });
    });

    group('removeTab', () {
      test('removes existing tab', () {
        final tabId = tabProvider.addTab(type: TabType.local);
        tabProvider.removeTab(tabId);

        expect(tabProvider.tabs, isEmpty);
      });

      test('handles removing non-existent tab', () {
        tabProvider.removeTab('non-existent-id');

        expect(tabProvider.tabs, isEmpty);
      });

      test('updates active tab when removing active tab', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');

        expect(tabProvider.activeTabId, tab2);

        tabProvider.removeTab(tab2);

        expect(tabProvider.activeTabId, tab1);
      });

      test('sets active tab to null when removing last tab', () {
        final tabId = tabProvider.addTab(type: TabType.local);
        tabProvider.removeTab(tabId);

        expect(tabProvider.activeTabId, isNull);
      });

      test('updates left pane when removing left pane tab', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');

        tabProvider.removeTab(tab1);

        expect(tabProvider.leftPaneTabId, tab2);
      });

      test('disables split view when less than 2 tabs remain', () {
        final tab1 = tabProvider.addTab(type: TabType.local);
        final tab2 = tabProvider.addTab(type: TabType.local);
        tabProvider.toggleSplitView();

        expect(tabProvider.isSplitView, true);

        tabProvider.removeTab(tab2);

        expect(tabProvider.isSplitView, false);
      });

      test('cleans up terminal resources', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
        );

        // Create terminal for the tab
        tabProvider.getOrCreateTerminal(tabId);
        expect(tabProvider.getTerminalController(tabId), isNotNull);

        tabProvider.removeTab(tabId);

        expect(tabProvider.getTerminalController(tabId), isNull);
      });

      test('notifies listeners on remove', () {
        final tabId = tabProvider.addTab(type: TabType.local);
        var notified = false;
        tabProvider.addListener(() => notified = true);

        tabProvider.removeTab(tabId);

        expect(notified, true);
      });
    });

    group('setActiveTab', () {
      test('sets active tab ID', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');

        tabProvider.setActiveTab(tab1);

        expect(tabProvider.activeTabId, tab1);
      });

      test('ignores invalid tab ID', () {
        final tab1 = tabProvider.addTab(type: TabType.local);
        tabProvider.setActiveTab('invalid-id');

        expect(tabProvider.activeTabId, tab1);
      });

      test('notifies listeners', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');
        var notified = false;
        tabProvider.addListener(() => notified = true);

        tabProvider.setActiveTab(tab1);

        expect(notified, true);
      });
    });

    group('getTab', () {
      test('returns tab by ID', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
          title: 'Test Tab',
        );

        final tab = tabProvider.getTab(tabId);

        expect(tab, isNotNull);
        expect(tab!.title, 'Test Tab');
      });

      test('returns null for non-existent ID', () {
        final tab = tabProvider.getTab('non-existent');

        expect(tab, isNull);
      });
    });

    group('updateTabTitle', () {
      test('updates tab title', () {
        final tabId = tabProvider.addTab(
          type: TabType.local,
          title: 'Original',
        );

        tabProvider.updateTabTitle(tabId, 'Updated');

        expect(tabProvider.getTab(tabId)!.title, 'Updated');
      });

      test('ignores invalid tab ID', () {
        tabProvider.updateTabTitle('invalid', 'Title');
        // No error thrown
      });

      test('notifies listeners', () {
        final tabId = tabProvider.addTab(type: TabType.local);
        var notified = false;
        tabProvider.addListener(() => notified = true);

        tabProvider.updateTabTitle(tabId, 'New Title');

        expect(notified, true);
      });
    });

    group('updateTabConnection', () {
      test('updates connection status', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
        );

        tabProvider.updateTabConnection(tabId, true);

        expect(tabProvider.getTab(tabId)!.isConnected, true);
      });

      test('can set to disconnected', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
        );
        tabProvider.updateTabConnection(tabId, true);
        tabProvider.updateTabConnection(tabId, false);

        expect(tabProvider.getTab(tabId)!.isConnected, false);
      });
    });

    group('updateTabPath', () {
      test('updates current path', () {
        final tabId = tabProvider.addTab(type: TabType.local);

        tabProvider.updateTabPath(tabId, '/home/user');

        expect(tabProvider.getTab(tabId)!.currentPath, '/home/user');
      });
    });

    group('reorderTabs', () {
      test('moves tab forward', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');
        final tab3 = tabProvider.addTab(type: TabType.local, title: 'Tab 3');

        tabProvider.reorderTabs(0, 2);

        expect(tabProvider.tabs[0].id, tab2);
        expect(tabProvider.tabs[1].id, tab1);
        expect(tabProvider.tabs[2].id, tab3);
      });

      test('moves tab backward', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');
        final tab3 = tabProvider.addTab(type: TabType.local, title: 'Tab 3');

        tabProvider.reorderTabs(2, 0);

        expect(tabProvider.tabs[0].id, tab3);
        expect(tabProvider.tabs[1].id, tab1);
        expect(tabProvider.tabs[2].id, tab2);
      });

      test('notifies listeners', () {
        tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        tabProvider.addTab(type: TabType.local, title: 'Tab 2');
        var notified = false;
        tabProvider.addListener(() => notified = true);

        tabProvider.reorderTabs(0, 1);

        expect(notified, true);
      });
    });

    group('Split View', () {
      test('toggleSplitView enables split view', () {
        tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        tabProvider.addTab(type: TabType.local, title: 'Tab 2');

        tabProvider.toggleSplitView();

        expect(tabProvider.isSplitView, true);
      });

      test('toggleSplitView disables split view', () {
        tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        tabProvider.addTab(type: TabType.local, title: 'Tab 2');
        tabProvider.toggleSplitView();
        tabProvider.toggleSplitView();

        expect(tabProvider.isSplitView, false);
      });

      test('toggleSplitView requires at least 2 tabs', () {
        tabProvider.addTab(type: TabType.local);

        tabProvider.toggleSplitView();

        expect(tabProvider.isSplitView, false);
      });

      test('toggleSplitView sets pane tabs', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');

        tabProvider.toggleSplitView();

        expect(tabProvider.leftPaneTabId, tab1);
        expect(tabProvider.rightPaneTabId, tab2);
      });

      test('setSplitPosition updates position', () {
        tabProvider.setSplitPosition(0.3);

        expect(tabProvider.splitPosition, 0.3);
      });

      test('setSplitPosition clamps to valid range', () {
        tabProvider.setSplitPosition(0.1);
        expect(tabProvider.splitPosition, 0.2);

        tabProvider.setSplitPosition(0.9);
        expect(tabProvider.splitPosition, 0.8);
      });

      test('setLeftPaneTab updates left pane', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');
        final tab3 = tabProvider.addTab(type: TabType.local, title: 'Tab 3');

        tabProvider.setLeftPaneTab(tab3);

        expect(tabProvider.leftPaneTabId, tab3);
        expect(tabProvider.activeTabId, tab3);
      });

      test('setRightPaneTab updates right pane', () {
        final tab1 = tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');
        final tab3 = tabProvider.addTab(type: TabType.local, title: 'Tab 3');

        tabProvider.setRightPaneTab(tab1);

        expect(tabProvider.rightPaneTabId, tab1);
        expect(tabProvider.activeTabId, tab1);
      });
    });

    group('Terminal Management', () {
      test('getOrCreateTerminal creates terminal for new tab', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
        );

        final terminal = tabProvider.getOrCreateTerminal(tabId);

        expect(terminal, isNotNull);
      });

      test('getOrCreateTerminal returns same terminal for same tab', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
        );

        final terminal1 = tabProvider.getOrCreateTerminal(tabId);
        final terminal2 = tabProvider.getOrCreateTerminal(tabId);

        expect(identical(terminal1, terminal2), true);
      });

      test('getTerminalController returns controller for existing terminal', () {
        final tabId = tabProvider.addTab(
          type: TabType.ssh,
          serverId: 'server-1',
        );
        tabProvider.getOrCreateTerminal(tabId);

        final controller = tabProvider.getTerminalController(tabId);

        expect(controller, isNotNull);
      });

      test('getTerminalController returns null for non-existent tab', () {
        final controller = tabProvider.getTerminalController('non-existent');

        expect(controller, isNull);
      });
    });

    group('openLocalFileBrowser', () {
      test('creates local file browser tab', () {
        tabProvider.openLocalFileBrowser();

        expect(tabProvider.tabs.length, 1);
        expect(tabProvider.tabs.first.type, TabType.local);
        expect(tabProvider.tabs.first.title, 'Local Files');
      });
    });

    group('activeTab getter', () {
      test('returns active tab session', () {
        tabProvider.addTab(type: TabType.local, title: 'Tab 1');
        final tab2 = tabProvider.addTab(type: TabType.local, title: 'Tab 2');

        final activeTab = tabProvider.activeTab;

        expect(activeTab, isNotNull);
        expect(activeTab!.id, tab2);
      });

      test('returns null when no tabs', () {
        expect(tabProvider.activeTab, isNull);
      });
    });

    group('tabs list immutability', () {
      test('returns unmodifiable list', () {
        tabProvider.addTab(type: TabType.local);

        expect(
          () => tabProvider.tabs.add(TabSession(type: TabType.local)),
          throwsUnsupportedError,
        );
      });
    });
  });
}
