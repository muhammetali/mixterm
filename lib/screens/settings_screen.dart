import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/server_provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/export_import_service.dart';
import '../utils/terminal_themes.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                'Terminal',
                [
                  _buildSwitchTile(
                    'Copy on select',
                    'Automatically copy selected text to clipboard',
                    settings.copyOnSelect,
                    (value) => settings.setCopyOnSelect(value),
                  ),
                  _buildSwitchTile(
                    'Paste on right-click',
                    'Paste clipboard content when right-clicking',
                    settings.pasteOnRightClick,
                    (value) => settings.setPasteOnRightClick(value),
                  ),
                  _buildSwitchTile(
                    'Show scrollbar',
                    'Display scrollbar in terminal',
                    settings.showScrollbar,
                    (value) => settings.setShowScrollbar(value),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                'Appearance',
                [
                  _buildDropdownTile<String>(
                    'Font family',
                    settings.fontFamily,
                    AppConstants.fontFamilies,
                    (value) => settings.setFontFamily(value!),
                  ),
                  _buildDropdownTile<String>(
                    'Font weight',
                    settings.fontWeight,
                    AppConstants.fontWeights,
                    (value) => settings.setFontWeight(value!),
                  ),
                  _buildDropdownTile<String>(
                    'Terminal theme',
                    settings.terminalTheme,
                    AppTerminalThemes.themes.map((t) => t.name).toList(),
                    (value) => settings.setTerminalTheme(value!),
                  ),
                  _buildDropdownTile<String>(
                    'Text color',
                    settings.terminalForegroundColor,
                    AppTerminalThemes.foregroundColors.map((c) => c.name).toList(),
                    (value) => settings.setTerminalForegroundColor(value!),
                  ),
                  _buildSliderTile(
                    'Font size',
                    settings.fontSize,
                    AppConstants.minFontSize.toDouble(),
                    AppConstants.maxFontSize.toDouble(),
                    (value) => settings.setFontSize(value.round()),
                  ),
                  _buildSliderTile(
                    'Terminal opacity',
                    (settings.terminalOpacity * 100).round(),
                    50,
                    100,
                    (value) => settings.setTerminalOpacity(value / 100),
                  ),
                  _buildSliderTile(
                    'Scrollback lines',
                    settings.scrollbackLines,
                    AppConstants.minScrollbackLines.toDouble(),
                    AppConstants.maxScrollbackLines.toDouble(),
                    (value) => settings.setScrollbackLines(value.round()),
                    divisions: 99,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                'Interface',
                [
                  _buildSwitchTile(
                    'Collapse sidebar',
                    'Show sidebar in collapsed mode (icons only)',
                    settings.sidebarCollapsed,
                    (value) => settings.setSidebarCollapsed(value),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                'Cloud Sync',
                [
                  _GoogleAccountTile(),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                'Data',
                [
                  _ExportImportTile(),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                'About',
                [
                  ListTile(
                    title: const Text('Version'),
                    subtitle: Text(AppConstants.appVersion),
                  ),
                  const ListTile(
                    title: Text('MixTerm'),
                    subtitle: Text('Professional SSH/SFTP client for Linux, macOS and Windows'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
    );
  }

  Widget _buildSliderTile(
    String title,
    num value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value.toString(),
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Slider(
        value: value.toDouble().clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildDropdownTile<T>(
    String title,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString()),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: AppTheme.surfaceColor,
        style: const TextStyle(color: AppTheme.primaryColor),
      ),
    );
  }
}

class _GoogleAccountTile extends StatefulWidget {
  @override
  State<_GoogleAccountTile> createState() => _GoogleAccountTileState();
}

class _GoogleAccountTileState extends State<_GoogleAccountTile> {
  bool _isLoading = false;
  bool _isSyncing = false;

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      final storage = context.read<StorageService>();
      final serverProvider = context.read<ServerProvider>();

      final success = await auth.signIn();
      if (success && auth.userId != null) {
        // Switch to Google-based encryption
        await storage.switchToGoogleEncryption(auth.userId!);

        // Sync to cloud
        await serverProvider.performSmartSync();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed in and synced successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in failed'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Your servers will remain on this device but will no longer sync to the cloud. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      final storage = context.read<StorageService>();

      // Switch back to device-based encryption
      await storage.switchToDeviceEncryption();

      // Sign out
      await auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);

    try {
      final serverProvider = context.read<ServerProvider>();
      final result = await serverProvider.performSmartSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor:
                result.success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.isSignedIn) {
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: auth.userPhoto != null
                      ? NetworkImage(auth.userPhoto!)
                      : null,
                  child: auth.userPhoto == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(auth.userName ?? 'Unknown'),
                subtitle: Text(auth.userEmail ?? ''),
                trailing: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _handleSignOut,
                        child: const Text('Sign out'),
                      ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync Now'),
                subtitle: Consumer<ServerProvider>(
                  builder: (context, serverProvider, _) {
                    final storage = context.read<StorageService>();
                    final lastSync = storage.getLastSyncTimestamp();
                    if (lastSync == 0) {
                      return const Text('Never synced');
                    }
                    final date = DateTime.fromMillisecondsSinceEpoch(lastSync);
                    return Text('Last sync: ${_formatDate(date)}');
                  },
                ),
                trailing: _isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.sync),
                        onPressed: _handleSync,
                      ),
              ),
            ],
          );
        }

        return ListTile(
          leading: const Icon(Icons.cloud_off),
          title: const Text('Not signed in'),
          subtitle: const Text('Sign in to sync servers across devices'),
          trailing: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : ElevatedButton.icon(
                  onPressed: _handleSignIn,
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Sign in with Google'),
                ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _ExportImportTile extends StatefulWidget {
  @override
  State<_ExportImportTile> createState() => _ExportImportTileState();
}

class _ExportImportTileState extends State<_ExportImportTile> {
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _handleExport() async {
    final serverProvider = context.read<ServerProvider>();
    final servers = serverProvider.servers;

    if (servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No servers to export'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // Show format selection dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ExportOptionsDialog(serverCount: servers.length),
    );

    if (result == null) return;

    final format = result['format'] as ExportFormat;
    final includeSecrets = result['includeSecrets'] as bool;

    // Get save location
    final extension = format == ExportFormat.json ? 'json' :
                      format == ExportFormat.csv ? 'csv' : 'config';

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Servers',
      fileName: 'mixterm_servers.$extension',
      type: FileType.custom,
      allowedExtensions: [extension],
    );

    if (outputPath == null) return;

    setState(() => _isExporting = true);

    try {
      final exportResult = await ExportImportService.exportToFile(
        servers,
        outputPath,
        format,
        includeSecrets: includeSecrets,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exportResult.message),
            backgroundColor: exportResult.success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleImport() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Servers',
      type: FileType.custom,
      allowedExtensions: ['json', 'csv', 'config', 'txt'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    setState(() => _isImporting = true);

    try {
      final importResult = await ExportImportService.importFromFile(filePath);

      if (!importResult.success || importResult.servers == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.message),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      // Show confirmation dialog
      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Servers'),
          content: Text(
            'Found ${importResult.servers!.length} servers.\n\n'
            'How would you like to import them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Merge'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace All'),
            ),
          ],
        ),
      );

      if (confirm == null || !mounted) return;

      final serverProvider = context.read<ServerProvider>();

      if (confirm) {
        // Replace all - clear existing and add new
        for (final server in serverProvider.servers.toList()) {
          await serverProvider.deleteServer(server.id);
        }
      }

      // Add imported servers
      int addedCount = 0;
      for (final server in importResult.servers!) {
        final success = await serverProvider.addServer(server);
        if (success) addedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $addedCount servers successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('Export Servers'),
          subtitle: const Text('Save servers to JSON, CSV, or SSH config'),
          trailing: _isExporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isExporting ? null : _handleExport,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Import Servers'),
          subtitle: const Text('Load servers from file (auto-detects format)'),
          trailing: _isImporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isImporting ? null : _handleImport,
        ),
      ],
    );
  }
}

class _ExportOptionsDialog extends StatefulWidget {
  final int serverCount;

  const _ExportOptionsDialog({required this.serverCount});

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  ExportFormat _selectedFormat = ExportFormat.json;
  bool _includeSecrets = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exporting ${widget.serverCount} servers'),
          const SizedBox(height: 16),
          const Text('Format:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildFormatOption(
            ExportFormat.json,
            'JSON',
            'Universal format, compatible with Termius',
          ),
          _buildFormatOption(
            ExportFormat.csv,
            'CSV',
            'Spreadsheet format, for Excel/Sheets',
          ),
          _buildFormatOption(
            ExportFormat.sshConfig,
            'SSH Config',
            'OpenSSH format (~/.ssh/config)',
          ),
          const SizedBox(height: 16),
          if (_selectedFormat != ExportFormat.sshConfig) ...[
            CheckboxListTile(
              title: const Text('Include passwords & keys'),
              subtitle: Text(
                _includeSecrets
                    ? 'Sensitive data will be included'
                    : 'Only server info (safer for sharing)',
                style: TextStyle(
                  fontSize: 12,
                  color: _includeSecrets ? AppTheme.warningColor : AppTheme.textSecondary,
                ),
              ),
              value: _includeSecrets,
              onChanged: (value) => setState(() => _includeSecrets = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.warningColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SSH config format cannot include passwords (security by design)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'format': _selectedFormat,
            'includeSecrets': _includeSecrets && _selectedFormat != ExportFormat.sshConfig,
          }),
          child: const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildFormatOption(ExportFormat format, String title, String subtitle) {
    return RadioListTile<ExportFormat>(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: format,
      groupValue: _selectedFormat,
      onChanged: (value) => setState(() => _selectedFormat = value!),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

