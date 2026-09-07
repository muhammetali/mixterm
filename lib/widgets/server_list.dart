import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server.dart';
import '../providers/server_provider.dart';
import '../utils/design_tokens.dart';
import 'server_tile.dart';

/// Marker row used by [ServerList]'s flattened, groupable list; never
/// rendered directly, just used to tell a group-header row apart from a
/// [Server] row inside a mixed `List<Object>`.
class _GroupHeader {
  final String title;
  const _GroupHeader(this.title);
}

class ServerList extends StatelessWidget {
  final VoidCallback onAddServer;
  final bool isCollapsed;

  const ServerList({
    super.key,
    required this.onAddServer,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(
      builder: (context, serverProvider, _) {
        if (serverProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (serverProvider.servers.isEmpty) {
          return _buildEmptyState(isCollapsed);
        }

        if (isCollapsed) {
          return _buildCollapsedList(serverProvider);
        }

        return Column(
          children: [
            _buildSearchAndAdd(context),
            const Divider(height: 1),
            Expanded(
              child: _buildServerListView(serverProvider),
            ),
          ],
        );
      },
    );
  }

  /// Renders servers grouped under a header for each distinct
  /// [Server.group] value, ungrouped servers first, when at least one
  /// server has a group set. Falls back to a plain flat list otherwise, so
  /// users who never use groups see no extra chrome.
  Widget _buildServerListView(ServerProvider serverProvider) {
    final groups = serverProvider.groups;

    if (groups.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: serverProvider.servers.length,
        itemBuilder: (context, index) {
          return ServerTile(server: serverProvider.servers[index]);
        },
      );
    }

    // Flatten (header, server*)* into one list so ListView.builder can
    // still virtualize rows instead of building everything eagerly.
    final rows = <Object>[];
    final ungrouped = serverProvider.getServersByGroup(null);
    if (ungrouped.isNotEmpty) {
      rows.add(_GroupHeader('Ungrouped'));
      rows.addAll(ungrouped);
    }
    for (final group in groups) {
      rows.add(_GroupHeader(group));
      rows.addAll(serverProvider.getServersByGroup(group));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is _GroupHeader) {
          return _buildGroupHeader(row.title);
        }
        return ServerTile(server: row as Server);
      },
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCollapsedList(ServerProvider serverProvider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: serverProvider.servers.length,
      itemBuilder: (context, index) {
        return ServerTile(
          server: serverProvider.servers[index],
          isCollapsed: true,
        );
      },
    );
  }

  Widget _buildSearchAndAdd(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search servers...',
                  prefixIcon: const Icon(Icons.search, size: AppIconSize.md),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                style: AppTypography.body,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: ElevatedButton.icon(
              onPressed: onAddServer,
              icon: const Icon(Icons.add, size: AppIconSize.md),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool collapsed) {
    if (collapsed) {
      // Collapsed mode: show only icon button
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dns_outlined,
              size: AppIconSize.lg,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.sm),
            Tooltip(
              message: 'Add Server',
              child: IconButton(
                onPressed: onAddServer,
                icon: const Icon(Icons.add, size: AppIconSize.lg),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Expanded mode: show full empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The illustration is the one place an icon is the subject
          // rather than a label, so it gets its own well instead of
          // floating as a bare grey glyph.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.raised,
              borderRadius: AppRadius.lgAll,
            ),
            child: const Icon(
              Icons.dns_outlined,
              size: AppIconSize.display,
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Text('No servers yet', style: AppTypography.bodyStrong),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Add one to get started',
            style: AppTypography.secondary,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onAddServer,
            icon: const Icon(Icons.add, size: AppIconSize.md),
            label: const Text('Add Server'),
          ),
        ],
      ),
    );
  }
}
