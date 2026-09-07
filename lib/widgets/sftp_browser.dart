import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../providers/connection_provider.dart';
import '../providers/server_provider.dart';
import '../models/server.dart';
import '../providers/tab_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/sftp_service.dart';
import '../utils/design_tokens.dart';
import 'status_message.dart';

class SFTPBrowser extends StatefulWidget {
  final String serverId;
  final String tabId;

  const SFTPBrowser({
    super.key,
    required this.serverId,
    required this.tabId,
  });

  @override
  State<SFTPBrowser> createState() => _SFTPBrowserState();
}

class _SFTPBrowserState extends State<SFTPBrowser> {
  String _currentPath = '/';
  List<SftpName> _items = [];
  bool _isLoading = true;
  String? _error;
  bool _isDragging = false;
  bool _isFetching = false;
  SFTPService? _sftpService;
  String? _selectedItem; // Currently selected file/folder name

  /// When true the path bar shows the full path as editable, selectable
  /// text instead of breadcrumb segments. Breadcrumbs are quicker to
  /// navigate with but you cannot select text out of them, and a path is
  /// something people copy constantly — into an scp command, a message, a
  /// config file. Both modes exist because they answer different needs.
  bool _isEditingPath = false;
  final TextEditingController _pathController = TextEditingController();
  final FocusNode _pathFocusNode = FocusNode();

  @override
  void dispose() {
    _pathController.dispose();
    _pathFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectionAndLoad(provider: context.read<ConnectionProvider>());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkConnectionAndLoad(provider: context.watch<ConnectionProvider>());
  }

  void _checkConnectionAndLoad({ConnectionProvider? provider}) {
    final connectionProvider = provider ?? context.read<ConnectionProvider>();
    final newService = connectionProvider.getSFTPConnection(widget.tabId);

    // Update service reference if changed
    if (newService != _sftpService) {
      _sftpService = newService;
    }

    // Business Logic: If connected and we have no data, load it.
    // We ignore _isLoading state here because if we are connected but have no items,
    // we MUST attempt to load, even if the UI thinks it's already loading (stale state).
    if (_sftpService != null && _sftpService!.isConnected) {
      if (_items.isEmpty) {
        _loadDirectory();
      }
    } else if (_error == 'Not connected' && _sftpService != null && _sftpService!.isConnected) {
      // Recovery from error state
      _loadDirectory();
    }
  }

  Future<void> _loadDirectory([String? path]) async {
    // Mutual Exclusion: Prevent concurrent loads
    if (_isFetching) return;
    
    // Also respect manual refresh guard if we have items
    if (_isLoading && _items.isNotEmpty) return;

    _isFetching = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // The dialog above is awaited, so the tab may have been closed while it
    // was open; touching context after that throws.
    if (!mounted) return;

    final connectionProvider = context.read<ConnectionProvider>();
      final tabProvider = context.read<TabProvider>();
      final sftpService = _sftpService ?? connectionProvider.getSFTPConnection(widget.tabId);

      if (sftpService == null || !sftpService.isConnected) {
        if (mounted) {
           // Contract: If not connected, show specific error
           setState(() {
            _error = 'Not connected';
          });
        }
        return;
      }

      if (path != null) {
        _currentPath = path;
      } else {
        // If no path provided, verify current or get default
        final dir = await sftpService.getCurrentDirectory();
        if (dir != null) {
          _currentPath = dir;
        }
      }

      tabProvider.updateTabPath(widget.tabId, _currentPath);

      final result = await sftpService.listDirectory(_currentPath);

      if (mounted) {
        setState(() {
          if (result.success) {
            _items = result.data ?? [];
          } else {
            _error = result.error ?? 'Failed to list directory';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      _isFetching = false;
      // Robustness: Always ensure loading state is cleared
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateTo(String path) {
    setState(() {
      _selectedItem = null; // Clear selection when navigating
    });
    _loadDirectory(path);
  }

  void _navigateUp() {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/');
    parts.removeLast();
    final newPath = parts.isEmpty ? '/' : parts.join('/');
    _navigateTo(newPath.isEmpty ? '/' : newPath);
  }

  String _getFullPath(String filename) {
    if (_currentPath == '/') {
      return '/$filename';
    }
    return '$_currentPath/$filename';
  }

  Future<void> _downloadFile(String filename, {String? localPath}) async {
    // The dialog above is awaited, so the tab may have been closed while it
    // was open; touching context after that throws.
    if (!mounted) return;

    final connectionProvider = context.read<ConnectionProvider>();
    final transferProvider = context.read<TransferProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.tabId);

    if (sftpService == null) return;

    String? finalLocalPath = localPath;
    if (finalLocalPath == null) {
      final downloadDir = await getDownloadsDirectory();
      if (downloadDir == null) return;
      finalLocalPath = '${downloadDir.path}/$filename';
    }

    final remotePath = _getFullPath(filename);
    bool isCancelled = false;
    
    final taskId = transferProvider.startTransfer(
      filename, 
      TransferType.download,
      onCancel: () {
        isCancelled = true;
      },
    );

    final result = await sftpService.downloadFile(
      remotePath,
      finalLocalPath,
      onProgress: (received, total) {
        transferProvider.updateProgress(taskId, received, total);
      },
      checkCancelled: () => isCancelled,
    );

    if (result.success) {
      transferProvider.completeTransfer(taskId);
    } else {
      if (!isCancelled) {
        transferProvider.failTransfer(taskId, result.error ?? 'Download failed');
      }
    }
  }

  Future<void> _downloadFileAs(String filename) async {
    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Download $filename to...',
      fileName: filename,
    );

    if (outputFile != null) {
      await _downloadFile(filename, localPath: outputFile);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    await _uploadFiles(result.files.map((f) => f.path!).toList());
  }

  Future<void> _uploadFiles(List<String> filePaths) async {
    // The dialog above is awaited, so the tab may have been closed while it
    // was open; touching context after that throws.
    if (!mounted) return;

    final connectionProvider = context.read<ConnectionProvider>();
    final transferProvider = context.read<TransferProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.tabId);

    if (sftpService == null) return;

    for (final filePath in filePaths) {
      final fileName = filePath.split('/').last;
      final remotePath = _getFullPath(fileName);

            bool isCancelled = false;
      
            final taskId = transferProvider.startTransfer(
              fileName, 
              TransferType.upload,
              onCancel: () {
                isCancelled = true;
              },
            );
      
            final result = await sftpService.uploadFile(
              filePath,
              remotePath,
              onProgress: (sent, total) {
                transferProvider.updateProgress(taskId, sent, total);
              },
              checkCancelled: () => isCancelled,
            );

            if (result.success) {
              transferProvider.completeTransfer(taskId);
            } else {
               if (isCancelled) {
                  // Handled by provider
               } else {
                  transferProvider.failTransfer(taskId, result.error ?? 'Upload failed');
               }
            }    }

    if (!mounted) return;
    _loadDirectory();
  }

  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    final files = details.files;
    if (files.isEmpty) return;

    final filePaths = <String>[];
    for (final file in files) {
      filePaths.add(file.path);
    }

    await _uploadFiles(filePaths);
  }

  Future<void> _createDirectory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Directory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Directory name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    // The dialog above is awaited, so the tab may have been closed while it
    // was open; touching context after that throws.
    if (!mounted) return;

    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.tabId);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (sftpService == null) return;

    final result = await sftpService.createDirectory(_getFullPath(name));

    if (!mounted) return;

    if (result.success) {
      _loadDirectory();
    } else {
      showStatusMessageOn(
        scaffoldMessenger,
        result.error ?? 'Failed to create directory',
        kind: StatusKind.error,
      );
    }
  }

  Future<void> _renameItem(String oldName, bool isDirectory) async {
    final controller = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == oldName) return;

    // The dialog above is awaited, so the tab may have been closed while it
    // was open; touching context after that throws.
    if (!mounted) return;

    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.tabId);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (sftpService == null) return;

    final result = await sftpService.rename(
      _getFullPath(oldName),
      _getFullPath(newName),
    );

    if (!mounted) return;

    if (result.success) {
      _loadDirectory();
    } else {
      showStatusMessageOn(
        scaffoldMessenger,
        result.error ?? 'Failed to rename',
        kind: StatusKind.error,
      );
    }
  }

  Future<void> _deleteItem(String filename, bool isDirectory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "$filename"?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // The dialog above is awaited, so the tab may have been closed while it
    // was open; touching context after that throws.
    if (!mounted) return;

    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.tabId);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (sftpService == null) return;

    final result = await sftpService.delete(
      _getFullPath(filename),
      isDirectory: isDirectory,
    );

    if (!mounted) return;

    if (result.success) {
      _loadDirectory();
    } else {
      showStatusMessageOn(
        scaffoldMessenger,
        result.error ?? 'Failed to delete',
        kind: StatusKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.read<ServerProvider>();
    final server = serverProvider.getServer(widget.serverId);

    return Column(
      children: [
        _buildToolbar(server?.name ?? 'SFTP'),
        _buildPathBar(),
        Expanded(
          child: DropTarget(
            onDragEntered: (details) {
              setState(() => _isDragging = true);
            },
            onDragExited: (details) {
              setState(() => _isDragging = false);
            },
            onDragDone: (details) {
              setState(() => _isDragging = false);
              _handleDroppedFiles(details);
            },
            child: Stack(
              children: [
                _buildContent(),
                if (_isLoading && _items.isEmpty && _error == null)
                  _buildConnectionOverlay(server),
                if (_isDragging)
                  _buildDragOverlay(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionOverlay(Server? server) {
    return Container(
      color: AppColors.bg.withValues(alpha: 0.9),
      child: Center(
        child: Card(
          color: AppColors.panel,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (server != null) ...[
                  Text(
                    server.name,
                    style: AppTypography.display.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    '${server.host}:${server.port}',
                    style: AppTypography.secondary,
                  ),
                  SizedBox(height: AppSpacing.xxl),
                ],
                const CircularProgressIndicator(),
                SizedBox(height: AppSpacing.xxl),
                const Text('Connecting to SFTP...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragOverlay() {
    return Container(
      color: AppColors.accentSubtle,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload,
              size: AppIconSize.display,
              color: AppColors.accent,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Drop files here to upload',
              style: AppTypography.title.copyWith(
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(String title) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: AppIconSize.md, color: AppColors.accent),
          SizedBox(width: AppSpacing.sm),
          Text(
            '$title - SFTP',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder, size: AppIconSize.md),
            tooltip: 'Create directory',
            onPressed: _createDirectory,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, size: AppIconSize.md),
            tooltip: 'Upload file',
            onPressed: _uploadFile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: AppIconSize.md),
            tooltip: 'Refresh',
            onPressed: () => _loadDirectory(),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: AppIconSize.md),
            tooltip: 'Disconnect',
            onPressed: () {
              // The dialog above is awaited, so the tab may have been closed while it
    // was open; touching context after that throws.
    if (!mounted) return;

    final connectionProvider = context.read<ConnectionProvider>();
              final tabProvider = context.read<TabProvider>();
              connectionProvider.disconnectTab(widget.tabId);
              tabProvider.removeTab(widget.tabId);
            },
          ),
        ],
      ),
    );
  }

  void _beginEditingPath() {
    _pathController.text = _currentPath;
    _pathController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _currentPath.length,
    );
    setState(() => _isEditingPath = true);
    _pathFocusNode.requestFocus();
  }

  void _commitEditedPath() {
    final typed = _pathController.text.trim();
    setState(() => _isEditingPath = false);
    if (typed.isEmpty || typed == _currentPath) return;
    _navigateTo(typed.startsWith('/') ? typed : '/$typed');
  }

  Future<void> _copyCurrentPath() async {
    await Clipboard.setData(ClipboardData(text: _currentPath));
    if (!mounted) return;
    showStatusMessage(context, 'Path copied', kind: StatusKind.success);
  }

  Widget _buildPathBar() {
    return Container(
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.raised,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: AppIconSize.md),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            onPressed: _navigateUp,
            tooltip: 'Go up',
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _isEditingPath ? _buildPathField() : _buildBreadcrumb(),
          ),
          SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: Icon(
              _isEditingPath ? Icons.check : Icons.edit_outlined,
              size: AppIconSize.md,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            onPressed: _isEditingPath ? _commitEditedPath : _beginEditingPath,
            tooltip: _isEditingPath ? 'Go to path' : 'Edit path',
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: AppIconSize.md),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            onPressed: _copyCurrentPath,
            tooltip: 'Copy path',
          ),
        ],
      ),
    );
  }

  /// The full path as selectable, editable text. Enter navigates, Escape
  /// puts the breadcrumb back.
  Widget _buildPathField() {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              setState(() => _isEditingPath = false);
              return null;
            },
          ),
        },
        child: TextField(
          controller: _pathController,
          focusNode: _pathFocusNode,
          style: AppTypography.body,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.bg,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs + 2,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
          onSubmitted: (_) => _commitEditedPath(),
        ),
      ),
    );
  }

  /// Clickable path segments.
  ///
  /// The leading `/` is the root segment *and* the separator before the
  /// first name — emitting both is what produced the doubled `/ /` at the
  /// start of every path.
  Widget _buildBreadcrumb() {
    final entries = breadcrumbSegments(_currentPath);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            // Root already reads as a separator, so one is only needed
            // between the names that follow it.
            if (i > 1)
              Text(
                '/',
                style: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            _BreadcrumbSegment(
              label: entries[i].label,
              isCurrent: i == entries.length - 1,
              onTap: () => _navigateTo(entries[i].path),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final server = context.read<ServerProvider>().getServer(widget.serverId);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (server != null) ...[
               Text(
                server.name,
                style: AppTypography.title.copyWith(
                  color: AppColors.accent,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                '${server.host}:${server.port}',
                style: AppTypography.secondary,
              ),
              SizedBox(height: AppSpacing.xxl),
            ],
            const Icon(Icons.error_outline, size: AppIconSize.display, color: AppColors.danger),
            SizedBox(height: AppSpacing.lg),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => _loadDirectory(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: AppIconSize.display, color: AppColors.textSecondary),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Empty directory',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Drop files here to upload',
              style: AppTypography.secondary,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildFileItem(item);
      },
    );
  }

  Widget _buildFileItem(SftpName item) {
    final isDir = item.attr.isDirectory;
    final filename = item.filename;
    final isSelected = _selectedItem == filename;

    return Draggable<Map<String, dynamic>>(
      data: {
        'type': 'sftp',
        'serverId': widget.serverId,
        'path': _getFullPath(filename),
        'filename': filename,
        'isDirectory': isDir,
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.9),
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDir ? Icons.folder_outlined : Icons.insert_drive_file,
                size: AppIconSize.md,
                color: Colors.white,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                filename,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          // Single tap: select item
          setState(() {
            _selectedItem = filename;
          });
        },
        onDoubleTap: () {
          // Double tap: open directory or download file
          if (isDir) {
            _navigateTo(_getFullPath(filename));
          } else {
            _downloadFile(filename);
          }
        },
        onSecondaryTapDown: (details) {
          // Right click: select and show context menu
          setState(() {
            _selectedItem = filename;
          });
          _showContextMenu(context, item, details.globalPosition);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.2)
                : null,
            border: isSelected
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.5))
                : null,
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            children: [
              Icon(
                isDir ? Icons.folder_outlined : _getFileIcon(filename),
                size: AppIconSize.lg,
                color: isDir ? AppColors.accent : AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      style: (isSelected
                              ? AppTypography.bodyStrong
                              : AppTypography.body)
                          .copyWith(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatSize(item.attr.size ?? 0),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, size: AppIconSize.md),
                onOpened: () {
                  // Select item when menu opens
                  setState(() {
                    _selectedItem = filename;
                  });
                },
                itemBuilder: (context) => [
                  if (!isDir) ...[
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: AppIconSize.md),
                          SizedBox(width: AppSpacing.sm),
                          Text('Download'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'download_as',
                      child: Row(
                        children: [
                          Icon(Icons.download_for_offline, size: AppIconSize.md),
                          SizedBox(width: AppSpacing.sm),
                          Text('Download As...'),
                        ],
                      ),
                    ),
                  ],
                  if (isDir)
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.folder_open, size: AppIconSize.md),
                          SizedBox(width: AppSpacing.sm),
                          Text('Open'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: AppIconSize.md),
                        SizedBox(width: AppSpacing.sm),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: AppIconSize.md, color: AppColors.danger),
                        SizedBox(width: AppSpacing.sm),
                        Text('Delete', style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'open') {
                    _navigateTo(_getFullPath(filename));
                  } else if (value == 'download') {
                    _downloadFile(filename);
                  } else if (value == 'download_as') {
                    _downloadFileAs(filename);
                  } else if (value == 'rename') {
                    _renameItem(filename, isDir);
                  } else if (value == 'delete') {
                    _deleteItem(filename, isDir);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, SftpName item, Offset position) {
    final isDir = item.attr.isDirectory;
    final filename = item.filename;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: <PopupMenuEntry<String>>[
        if (isDir)
          const PopupMenuItem<String>(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.folder_open, size: AppIconSize.md),
                SizedBox(width: AppSpacing.sm),
                Text('Open'),
              ],
            ),
          ),
        if (!isDir) ...[
          const PopupMenuItem<String>(
            value: 'download',
            child: Row(
              children: [
                Icon(Icons.download, size: AppIconSize.md),
                SizedBox(width: AppSpacing.sm),
                Text('Download'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'download_as',
            child: Row(
              children: [
                Icon(Icons.download_for_offline, size: AppIconSize.md),
                SizedBox(width: AppSpacing.sm),
                Text('Download As...'),
              ],
            ),
          ),
        ],
        const PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: AppIconSize.md),
              SizedBox(width: AppSpacing.sm),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: AppIconSize.md, color: AppColors.danger),
              SizedBox(width: AppSpacing.sm),
              Text('Delete', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'open') {
        _navigateTo(_getFullPath(filename));
      } else if (value == 'download') {
        _downloadFile(filename);
      } else if (value == 'download_as') {
        _downloadFileAs(filename);
      } else if (value == 'rename') {
        _renameItem(filename, isDir);
      } else if (value == 'delete') {
        _deleteItem(filename, isDir);
      }
    });
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'txt':
      case 'md':
      case 'log':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'mp4':
      case 'mkv':
      case 'avi':
        return Icons.video_file;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
        return Icons.archive;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'c':
      case 'cpp':
      case 'h':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}


/// One entry in the breadcrumb: what to show, and where clicking it goes.
class BreadcrumbEntry {
  final String label;
  final String path;

  const BreadcrumbEntry(this.label, this.path);

  @override
  bool operator ==(Object other) =>
      other is BreadcrumbEntry && other.label == label && other.path == path;

  @override
  int get hashCode => Object.hash(label, path);

  @override
  String toString() => 'BreadcrumbEntry($label -> $path)';
}

/// Splits an absolute path into the segments the path bar renders.
///
/// The first entry is always root. It is both the root segment *and* the
/// separator before the first name, which is what the original version got
/// wrong: it emitted a `/` for root and then another `/` before every
/// name including the first, so every path opened with a doubled `/ /`.
List<BreadcrumbEntry> breadcrumbSegments(String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  final entries = <BreadcrumbEntry>[const BreadcrumbEntry('/', '/')];
  for (var i = 0; i < parts.length; i++) {
    entries.add(
      BreadcrumbEntry(parts[i], '/${parts.sublist(0, i + 1).join('/')}'),
    );
  }
  return entries;
}

/// One clickable segment of the path bar.
///
/// The current directory is not a link — it is where you already are — so it
/// gets the primary text colour and no pointer affordance, while its
/// ancestors read as the links they are.
class _BreadcrumbSegment extends StatefulWidget {
  final String label;
  final bool isCurrent;
  final VoidCallback onTap;

  const _BreadcrumbSegment({
    required this.label,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  State<_BreadcrumbSegment> createState() => _BreadcrumbSegmentState();
}

class _BreadcrumbSegmentState extends State<_BreadcrumbSegment> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final text = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      child: Text(
        widget.label,
        style: AppTypography.body.copyWith(
          color: widget.isCurrent ? AppColors.textPrimary : AppColors.accent,
          fontWeight: widget.isCurrent ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    );

    if (widget.isCurrent) return text;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.hover : Colors.transparent,
            borderRadius: AppRadius.smAll,
          ),
          child: text,
        ),
      ),
    );
  }
}
