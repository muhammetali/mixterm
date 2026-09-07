import '../widgets/status_message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tab_session.dart';
import '../providers/server_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tab_provider.dart';
import '../services/auth_service.dart';
import '../widgets/server_list.dart';
import '../widgets/terminal_view.dart';
import '../widgets/sftp_browser.dart';
import '../widgets/session_tab_bar.dart';
import '../widgets/dialogs/add_server_dialog.dart';
import '../widgets/transfer_indicator.dart';
import '../utils/design_tokens.dart';
import '../utils/theme.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  final Map<String, Widget> _tabWidgetCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final serverProvider = context.read<ServerProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final authService = context.read<AuthService>();

    // Load auth first (needed for sync decision)
    await authService.init();

    // Load servers and settings in parallel (they're independent)
    await Future.wait([
      serverProvider.loadServers(),
      settingsProvider.loadSettings(),
    ]);

    // Automatic robust smart sync if signed in
    if (authService.isSignedIn) {
      await serverProvider.performSmartSync();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showAddServerDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddServerDialog(),
    );

    if (result == true && mounted) {
      showStatusMessage(
        context,
        'Server added',
        kind: StatusKind.success,
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
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (!authService.isSignedIn) {
      final success = await authService.signIn();
      if (!success) {
        showStatusMessageOn(
          scaffoldMessenger,
          'Failed to sign in to Google',
          kind: StatusKind.error,
        );
        return;
      }
    }

    final result = await serverProvider.performSmartSync();

    showStatusMessageOn(
      scaffoldMessenger,
      result.message,
      kind: result.success ? StatusKind.success : StatusKind.error,
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
      body: Stack(
        children: [
          Row(
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  final isCollapsed = settings.sidebarCollapsed;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: isCollapsed ? 60 : 280,
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceColor,
                      border: Border(
                        right: BorderSide(color: AppTheme.borderColor),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildHeader(isCollapsed),
                        const Divider(height: 1),
                        Expanded(
                          child: ServerList(
                            onAddServer: _showAddServerDialog,
                            isCollapsed: isCollapsed,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: Column(
                  children: [
                    const SessionTabBar(),
                    Expanded(
                      child: _buildMainContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const TransferIndicator(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<TabProvider>(
      builder: (context, tabProvider, _) {
        if (tabProvider.tabs.isEmpty) {
          _tabWidgetCache.clear();
          return _buildEmptyState();
        }

        // Clean up cache for removed tabs
        final tabIds = tabProvider.tabs.map((t) => t.id).toSet();
        _tabWidgetCache.removeWhere((key, _) => !tabIds.contains(key));

        // Use Stack with Offstage to keep all tabs alive but only show active
        return Stack(
          children: tabProvider.tabs.map((tab) {
            final isActive = tab.id == tabProvider.activeTabId;
            return Offstage(
              offstage: !isActive,
              child: _getOrCreateTabWidget(tab, tabProvider),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _getOrCreateTabWidget(TabSession tab, TabProvider tabProvider) {
    if (!_tabWidgetCache.containsKey(tab.id)) {
      _tabWidgetCache[tab.id] = _buildTabContent(tab, tabProvider);
    }
    return _tabWidgetCache[tab.id]!;
  }

  Widget _buildTabContent(TabSession tab, TabProvider tabProvider) {
    switch (tab.type) {
      case TabType.ssh:
        return TerminalViewWidget(
          key: ValueKey('terminal_${tab.id}'),
          serverId: tab.serverId!,
          tabId: tab.id,
        );
      case TabType.sftp:
        return SFTPBrowser(
          key: ValueKey('sftp_${tab.id}'),
          serverId: tab.serverId!,
          tabId: tab.id,
        );
    }
  }

  Widget _buildHeader(bool isCollapsed) {
    const collapsedButtonConstraints = BoxConstraints(minWidth: 40, minHeight: 40);

    return Container(
      padding: EdgeInsets.all(isCollapsed ? 8 : 12),
      child: isCollapsed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, size: AppIconSize.lg),
                  tooltip: 'Expand sidebar',
                  onPressed: () => context.read<SettingsProvider>().toggleSidebar(),
                  constraints: collapsedButtonConstraints,
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: AppIconSize.lg),
                  tooltip: 'Add server',
                  onPressed: _showAddServerDialog,
                  constraints: collapsedButtonConstraints,
                  padding: EdgeInsets.zero,
                ),
                Consumer<AuthService>(
                  builder: (context, auth, _) {
                    return IconButton(
                      icon: Icon(
                        auth.isSignedIn
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        size: AppIconSize.lg,
                      ),
                      tooltip: auth.isSignedIn ? 'Sync' : 'Sign in',
                      onPressed: _syncData,
                      constraints: collapsedButtonConstraints,
                      padding: EdgeInsets.zero,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: AppIconSize.lg),
                  tooltip: 'Settings',
                  onPressed: _openSettings,
                  constraints: collapsedButtonConstraints,
                  padding: EdgeInsets.zero,
                ),
              ],
            )
          : Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_open, size: AppIconSize.lg),
                  tooltip: 'Collapse sidebar',
                  onPressed: () => context.read<SettingsProvider>().toggleSidebar(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.terminal,
                  color: AppColors.accent,
                  size: AppIconSize.lg,
                ),
                SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'MixTerm',
                    style: AppTypography.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Consumer<AuthService>(
                  builder: (context, auth, _) {
                    return IconButton(
                      icon: Icon(
                        auth.isSignedIn
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        size: AppIconSize.lg,
                      ),
                      tooltip: auth.isSignedIn ? 'Sync to cloud' : 'Sign in to sync',
                      onPressed: _syncData,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: AppIconSize.lg),
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
          // Empty states are the screen's hero when they are showing, so
          // the glyph gets a surface of its own rather than floating as a
          // bare grey shape on the terminal ground.
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.dns_outlined,
              size: AppIconSize.display,
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          const Text('No active connection', style: AppTypography.title),
          SizedBox(height: AppSpacing.xs),
          const Text(
            'Select a server from the list to connect',
            style: AppTypography.secondary,
          ),
        ],
      ),
    );
  }
}
