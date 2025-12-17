import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../widgets/server_list.dart';
import '../widgets/terminal_view.dart';
import '../widgets/sftp_browser.dart';
import '../widgets/dialogs/add_server_dialog.dart';
import '../utils/theme.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final serverProvider = context.read<ServerProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final authService = context.read<AuthService>();

    await authService.init();
    await serverProvider.loadServers();
    await settingsProvider.loadSettings();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showAddServerDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddServerDialog(),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server added successfully')),
      );
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _syncData() async {
    final serverProvider = context.read<ServerProvider>();
    final authService = context.read<AuthService>();

    if (!authService.isSignedIn) {
      final user = await authService.signIn();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign in to Google')),
        );
        return;
      }
    }

    final result = await serverProvider.syncToCloud();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                right: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                Expanded(
                  child: ServerList(
                    onAddServer: _showAddServerDialog,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<ConnectionProvider>(
              builder: (context, connectionProvider, _) {
                if (connectionProvider.activeServerId == null) {
                  return _buildEmptyState();
                }

                if (connectionProvider.activeConnectionType == 'sftp') {
                  return SFTPBrowser(
                    serverId: connectionProvider.activeServerId!,
                  );
                }

                return TerminalViewWidget(
                  serverId: connectionProvider.activeServerId!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(
            Icons.terminal,
            color: AppTheme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text(
            'MixTerm',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const Spacer(),
          Consumer<AuthService>(
            builder: (context, auth, _) {
              return IconButton(
                icon: Icon(
                  auth.isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                  size: 20,
                ),
                tooltip: auth.isSignedIn ? 'Sync to cloud' : 'Sign in to sync',
                onPressed: _syncData,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No active connection',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a server from the list to connect',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
