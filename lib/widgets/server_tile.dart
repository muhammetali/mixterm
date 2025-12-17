import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server.dart';
import '../models/tab_session.dart';
import '../providers/server_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/tab_provider.dart';
import '../utils/theme.dart';
import 'dialogs/add_server_dialog.dart';

class ServerTile extends StatelessWidget {
  final Server server;

  const ServerTile({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connectionProvider, _) {
        final isSSHConnected = connectionProvider.isSSHConnected(server.id);
        final isSFTPConnected = connectionProvider.isSFTPConnected(server.id);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showConnectionOptions(context),
              onSecondaryTap: () => _showContextMenu(context),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.dns,
                        size: 20,
                        color: isSSHConnected || isSFTPConnected
                            ? AppTheme.successColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            server.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${server.username}@${server.host}:${server.port}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSSHConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SSH',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isSFTPConnected) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SFTP',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
                connectionProvider.isSSHConnected(server.id)
                    ? 'Connected - Open new tab'
                    : 'Click to connect',
              ),
              onTap: () {
                Navigator.pop(dialogContext);
                _connectSSH(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('SFTP File Browser'),
              subtitle: Text(
                connectionProvider.isSFTPConnected(server.id)
                    ? 'Connected - Open new tab'
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

    if (connectionProvider.isSSHConnected(server.id)) {
      // Already connected, just update tab connection status
      tabProvider.updateTabConnection(tabId, true);
      return;
    }

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Connecting...')),
    );

    final result = await connectionProvider.connectSSH(server);

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

    if (connectionProvider.isSFTPConnected(server.id)) {
      // Already connected, just update tab connection status
      tabProvider.updateTabConnection(tabId, true);
      return;
    }

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Connecting...')),
    );

    final result = await connectionProvider.connectSFTP(server);

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

  void _showContextMenu(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu(
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
    ).then((value) {
      if (value == 'edit') {
        _editServer(context);
      } else if (value == 'duplicate') {
        _duplicateServer(context);
      } else if (value == 'delete') {
        _deleteServer(context);
      }
    });
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
              connectionProvider.disconnectAll(server.id);
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
