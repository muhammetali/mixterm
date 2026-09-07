import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server.dart';
import '../models/tab_session.dart';
import '../providers/server_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/tab_provider.dart';
import '../utils/design_tokens.dart';
import '../utils/theme.dart';
import 'dialogs/add_server_dialog.dart';

/// The `SSH` / `SFTP` markers on a connected server row.
///
/// Both use the accent rather than one accent and one success green: they
/// answer the same question (which protocols are live), so giving them
/// different hues would imply a difference that isn't there. The row's
/// connected-versus-idle state is already carried by the icon well.
class _ProtocolBadge extends StatelessWidget {
  final String label;

  const _ProtocolBadge(this.label);

  static const ssh = _ProtocolBadge('SSH');
  static const sftp = _ProtocolBadge('SFTP');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSubtle,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.accent),
      ),
    );
  }
}

class ServerTile extends StatefulWidget {
  final Server server;
  final bool isCollapsed;

  const ServerTile({
    super.key,
    required this.server,
    this.isCollapsed = false,
  });

  @override
  State<ServerTile> createState() => _ServerTileState();
}

class _ServerTileState extends State<ServerTile> {
  bool _isHovered = false;

  Server get server => widget.server;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connectionProvider, _) {
        // Check if any tab has a connection to this server
        final isSSHConnected = connectionProvider.hasAnySSHConnectionForServer(server.id);
        final isSFTPConnected = connectionProvider.hasAnySFTPConnectionForServer(server.id);
        final isConnected = isSSHConnected || isSFTPConnected;

        if (widget.isCollapsed) {
          return _buildCollapsedTile(context, isConnected);
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: () => _showConnectionOptions(context),
            onSecondaryTap: _showContextMenu,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                // 1.45:1 against the sidebar — above the 1.5:1-in-grayscale
                // floor once the accent well below is counted, so the row
                // under the pointer is still identifiable without hue.
                color: _isHovered ? AppColors.hover : Colors.transparent,
                borderRadius: AppRadius.mdAll,
              ),
              child: Row(
                children: [
                  // Connection state is carried on three channels that do
                  // not depend on each other: the well's fill, the glyph's
                  // colour, and the badges on the right. Any one of them
                  // going missing still leaves the state readable.
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppColors.accentSubtle
                          : (_isHovered ? AppColors.selected : AppColors.raised),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Icon(
                      Icons.dns_outlined,
                      size: AppIconSize.md,
                      color: isConnected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          server.name,
                          style: AppTypography.bodyStrong,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${server.username}@${server.host}:${server.port}',
                          style: AppTypography.secondary,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSSHConnected) _ProtocolBadge.ssh,
                  if (isSFTPConnected) ...[
                    if (isSSHConnected) SizedBox(width: AppSpacing.xs),
                    _ProtocolBadge.sftp,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedTile(BuildContext context, bool isConnected) {
    return Tooltip(
      message: '${server.name}\n${server.username}@${server.host}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () => _showConnectionOptions(context),
          onSecondaryTap: _showContextMenu,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.accentSubtle
                      : (_isHovered ? AppColors.hover : AppColors.raised),
                  borderRadius: AppRadius.mdAll,
                  // The collapsed rail has no room for badges, so the
                  // border takes over as the second, hue-independent
                  // channel for connected-ness.
                  border: isConnected
                      ? Border.all(color: AppColors.accent, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    server.name.isNotEmpty
                        ? server.name[0].toUpperCase()
                        : 'S',
                    style: AppTypography.bodyStrong.copyWith(
                      color: isConnected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showConnectionOptions(BuildContext context) {
    final connectionProvider = context.read<ConnectionProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(server.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text('SSH Terminal'),
              subtitle: Text(
                connectionProvider.hasAnySSHConnectionForServer(server.id)
                    ? 'Open new tab (new connection)'
                    : 'Click to connect',
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                _connectSSH(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('SFTP File Browser'),
              subtitle: Text(
                connectionProvider.hasAnySFTPConnectionForServer(server.id)
                    ? 'Open new tab (new connection)'
                    : 'Click to connect',
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                _connectSFTP(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectSSH(BuildContext context) async {
    final connectionProvider = context.read<ConnectionProvider>();
    final tabProvider = context.read<TabProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Create a new tab first
    final tabId = tabProvider.addTab(
      type: TabType.ssh,
      serverId: server.id,
      title: '${server.name} - SSH',
    );

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Connecting...')),
    );

    // Each tab gets its own independent connection
    final result = await connectionProvider.connectSSH(server, tabId);

    if (!context.mounted) return;
    scaffoldMessenger.hideCurrentSnackBar();

    if (result.success) {
      tabProvider.updateTabConnection(tabId, true);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Connected'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      // Remove tab on failed connection
      tabProvider.removeTab(tabId);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Connection failed'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _connectSFTP(BuildContext context) async {
    final connectionProvider = context.read<ConnectionProvider>();
    final tabProvider = context.read<TabProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Create a new tab first
    final tabId = tabProvider.addTab(
      type: TabType.sftp,
      serverId: server.id,
      title: '${server.name} - SFTP',
    );

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Connecting...')),
    );

    // Each tab gets its own independent connection
    final result = await connectionProvider.connectSFTP(server, tabId);

    if (!context.mounted) return;
    scaffoldMessenger.hideCurrentSnackBar();

    if (result.success) {
      tabProvider.updateTabConnection(tabId, true);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Connected'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      // Remove tab on failed connection
      tabProvider.removeTab(tabId);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Connection failed'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Takes no context parameter on purpose: it uses the State's own, so the
  /// `mounted` check below actually guards the context being used.
  Future<void> _showContextMenu() async {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + renderBox.size.width,
        offset.dy,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
            ],
          ),
        ),
      ],
    );

    // The menu is awaited, so this tile may have been removed from the tree
    // while it was open.
    if (!mounted) return;

    if (value == 'edit') {
      _editServer(context);
    } else if (value == 'duplicate') {
      _duplicateServer(context);
    } else if (value == 'delete') {
      _deleteServer(context);
    }
  }

  void _editServer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddServerDialog(server: server),
    );
  }

  void _duplicateServer(BuildContext context) {
    final serverProvider = context.read<ServerProvider>();
    final newServer = Server(
      name: '${server.name} (Copy)',
      host: server.host,
      port: server.port,
      username: server.username,
      password: server.password,
      privateKey: server.privateKey,
      passphrase: server.passphrase,
      authType: server.authType,
      group: server.group,
    );
    serverProvider.addServer(newServer);
  }

  void _deleteServer(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Server'),
        content: Text('Are you sure you want to delete "${server.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final serverProvider = context.read<ServerProvider>();
              final connectionProvider = context.read<ConnectionProvider>();
              connectionProvider.disconnectAllForServer(server.id);
              serverProvider.deleteServer(server.id);
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
