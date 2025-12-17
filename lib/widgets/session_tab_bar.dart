import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tab_session.dart';
import '../providers/tab_provider.dart';
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

                    return ReorderableDragStartListener(
                      key: ValueKey(tab.id),
                      index: index,
                      child: _TabItem(
                        tab: tab,
                        isActive: isActive,
                        onTap: () => tabProvider.setActiveTab(tab.id),
                        onClose: () => tabProvider.removeTab(tab.id),
                        onMiddleClick: () => tabProvider.removeTab(tab.id),
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

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.onMiddleClick,
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
}
