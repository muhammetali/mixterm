import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tab_session.dart';
import '../providers/tab_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/server_provider.dart';
import '../utils/theme.dart';

class SessionTabBar extends StatelessWidget {
  const SessionTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TabProvider>(
      builder: (context, tabProvider, _) {
        return Container(
          height: 36,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              bottom: BorderSide(color: AppTheme.borderColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  itemCount: tabProvider.tabs.length,
                  onReorder: tabProvider.reorderTabs,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 4,
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final tab = tabProvider.tabs[index];
                    final isActive = tab.id == tabProvider.activeTabId;
                    final connectionProvider = context.read<ConnectionProvider>();

                    void closeTab() {
                      // Disconnect this tab's specific connection (keyed by tabId)
                      if (tab.type == TabType.ssh) {
                        connectionProvider.disconnectSSH(tab.id);
                      } else {
                        connectionProvider.disconnectSFTP(tab.id);
                      }
                      tabProvider.removeTab(tab.id);
                    }

                    Future<void> duplicateTab() async {
                      if (tab.serverId != null) {
                        final serverProvider = context.read<ServerProvider>();
                        final server = serverProvider.getServer(tab.serverId!);
                        if (server == null) return;

                        // Create a new tab with the same server and type
                        final newTabId = tabProvider.addTab(
                          type: tab.type,
                          serverId: tab.serverId,
                          title: '${tab.title} (copy)',
                        );
                        tabProvider.setActiveTab(newTabId);

                        // Start a new independent connection for the new tab
                        if (tab.type == TabType.ssh) {
                          await connectionProvider.connectSSH(server, newTabId);
                        } else {
                          await connectionProvider.connectSFTP(server, newTabId);
                        }
                      }
                    }

                    return ReorderableDragStartListener(
                      key: ValueKey(tab.id),
                      index: index,
                      child: _TabItem(
                        tab: tab,
                        isActive: isActive,
                        onTap: () => tabProvider.setActiveTab(tab.id),
                        onClose: closeTab,
                        onMiddleClick: closeTab,
                        onDuplicate: tab.serverId != null ? duplicateTab : null,
                      ),
                    );
                  },
                ),
              ),
              _buildActions(context, tabProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, TabProvider tabProvider) {
    // No additional actions needed - tabs are self-contained
    return const SizedBox(width: 8);
  }
}

class _TabItem extends StatelessWidget {
  final TabSession tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onMiddleClick;
  final VoidCallback? onDuplicate;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.onMiddleClick,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        // Middle mouse button
        if (event.buttons == 4) {
          onMiddleClick();
        }
      },
      child: GestureDetector(
        onTap: onTap,
        onSecondaryTapDown: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 120,
            maxWidth: 200,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.cardColor : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
              right: const BorderSide(color: AppTheme.borderColor, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getTabIcon(),
                size: 14,
                color: tab.isConnected
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tab.title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? AppTheme.textColor : AppTheme.textSecondary,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTabIcon() {
    switch (tab.type) {
      case TabType.ssh:
        return Icons.terminal;
      case TabType.sftp:
        return Icons.folder;
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: <PopupMenuEntry<String>>[
        if (onDuplicate != null)
          const PopupMenuItem<String>(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(Icons.copy, size: 18),
                SizedBox(width: 8),
                Text('Duplicate'),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'close',
          child: Row(
            children: [
              Icon(Icons.close, size: 18),
              SizedBox(width: 8),
              Text('Close'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'duplicate' && onDuplicate != null) {
        onDuplicate!();
      } else if (value == 'close') {
        onClose();
      }
    });
  }
}
