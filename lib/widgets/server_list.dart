import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server.dart';
import '../providers/server_provider.dart';
import '../utils/theme.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppTheme.textSecondary.withValues(alpha: 0.7),
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
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search servers...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: onAddServer,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
            Icon(
              Icons.dns_outlined,
              size: 24,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Add Server',
              child: IconButton(
                onPressed: onAddServer,
                icon: const Icon(Icons.add, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
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
          Icon(
            Icons.dns_outlined,
            size: 48,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No servers yet',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onAddServer,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Server'),
          ),
        ],
      ),
    );
  }
}
