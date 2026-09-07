import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/server_provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/export_import_service.dart';
import '../utils/terminal_themes.dart';
import '../utils/design_tokens.dart';
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
            padding: EdgeInsets.all(AppSpacing.lg),
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
              SizedBox(height: AppSpacing.xxl),
              _buildSection(
                'Appearance',
                [
                  _buildFontFamilyTile(
                    settings.fontFamily,
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
              SizedBox(height: AppSpacing.xxl),
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
              SizedBox(height: AppSpacing.xxl),
              _buildSection(
                'Cloud Sync',
                [
                  _GoogleAccountTile(),
                ],
              ),
              SizedBox(height: AppSpacing.xxl),
              _buildSection(
                'Data',
                [
                  _ExportImportTile(),
                ],
              ),
              SizedBox(height: AppSpacing.xxl),
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
            style: AppTypography.caption.copyWith(
              color: AppColors.accent,
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
        style: AppTypography.secondary,
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.accent,
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
              color: AppColors.accent,
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
        activeColor: AppColors.accent,
      ),
    );
  }

  /// The font picker renders each option in the typeface it names.
  ///
  /// A list of family names tells you nothing about what you are choosing —
  /// the whole reason to prefer one monospace face over another is how its
  /// glyphs look, so the menu shows exactly that. The sample string is
  /// chosen for the characters that actually differ between coding faces:
  /// zero versus O, one versus l, and the punctuation that carries
  /// ligatures.
  Widget _buildFontFamilyTile(String value, ValueChanged<String?> onChanged) {
    return ListTile(
      title: const Text('Font family'),
      subtitle: Text(
        'Il1 O0 => != ~-',
        style: AppTypography.secondary.copyWith(
          fontFamily: value == 'System' ? null : value,
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: DropdownButton<String>(
        value: value,
        items: AppConstants.fontFamilies.map((family) {
          final isSystem = family == 'System';
          return DropdownMenuItem<String>(
            value: family,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.fontDisplayNames[family] ?? family,
                  style: AppTypography.body.copyWith(
                    color: family == value
                        ? AppColors.accent
                        : AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Text(
                  'Il1 O0',
                  style: TextStyle(
                    fontFamily: isSystem ? null : family,
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: AppColors.panel,
        style: const TextStyle(color: AppColors.accent),
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
        dropdownColor: AppColors.panel,
        style: const TextStyle(color: AppColors.accent),
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
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in failed'),
              backgroundColor: AppColors.danger,
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
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // The confirmation dialog is awaited, so this screen may already be gone.
    if (!mounted) return;

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
                result.success ? AppColors.success : AppColors.danger,
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
                      ? const Icon(Icons.person_outline)
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
          leading: const Icon(Icons.cloud_off_outlined),
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
                  icon: const Icon(Icons.login, size: AppIconSize.md),
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
          backgroundColor: AppColors.warning,
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
            backgroundColor: exportResult.success ? AppColors.success : AppColors.danger,
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
              backgroundColor: AppColors.danger,
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
            backgroundColor: AppColors.success,
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
              : const Icon(Icons.arrow_forward_ios, size: AppIconSize.md),
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
              : const Icon(Icons.arrow_forward_ios, size: AppIconSize.md),
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
          SizedBox(height: AppSpacing.lg),
          Text('Format:', style: AppTypography.label),
          SizedBox(height: AppSpacing.sm),
          // The group's value and its change handler live on the RadioGroup
          // ancestor rather than on each tile, which is what Flutter 3.32
          // moved to.
          RadioGroup<ExportFormat>(
            groupValue: _selectedFormat,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedFormat = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          if (_selectedFormat != ExportFormat.sshConfig) ...[
            CheckboxListTile(
              title: const Text('Include passwords & keys'),
              subtitle: Text(
                _includeSecrets
                    ? 'Sensitive data will be included'
                    : 'Only server info (safer for sharing)',
                style: AppTypography.secondary.copyWith(
                  color: _includeSecrets ? AppColors.warning : null,
                ),
              ),
              value: _includeSecrets,
              onChanged: (value) => setState(() => _includeSecrets = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: AppRadius.mdAll,
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: AppIconSize.md, color: AppColors.warning),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'SSH config format cannot include passwords (security by design)',
                      style: AppTypography.secondary,
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
      subtitle: Text(subtitle, style: AppTypography.secondary),
      value: format,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

