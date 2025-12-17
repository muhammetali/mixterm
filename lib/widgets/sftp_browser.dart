import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../providers/connection_provider.dart';
import '../providers/server_provider.dart';
import '../providers/tab_provider.dart';
import '../utils/theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory([String? path]) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final connectionProvider = context.read<ConnectionProvider>();
    final tabProvider = context.read<TabProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.serverId);

    if (sftpService == null || !sftpService.isConnected) {
      setState(() {
        _error = 'Not connected';
        _isLoading = false;
      });
      return;
    }

    try {
      if (path != null) {
        _currentPath = path;
      } else {
        final dir = await sftpService.getCurrentDirectory();
        if (dir != null) {
          _currentPath = dir;
        }
      }

      tabProvider.updateTabPath(widget.tabId, _currentPath);

      final items = await sftpService.listDirectory(_currentPath);
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateTo(String path) {
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

  Future<void> _downloadFile(String filename) async {
    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.serverId);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (sftpService == null) return;

    final downloadDir = await getDownloadsDirectory();
    if (downloadDir == null) return;

    final localPath = '${downloadDir.path}/$filename';
    final remotePath = _getFullPath(filename);

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Downloading $filename...')),
    );

    final success = await sftpService.downloadFile(remotePath, localPath);

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Downloaded to $localPath' : 'Download failed',
        ),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    await _uploadFiles(result.files.map((f) => f.path!).toList());
  }

  Future<void> _uploadFiles(List<String> filePaths) async {
    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.serverId);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (sftpService == null) return;

    int successCount = 0;
    int failCount = 0;

    for (final filePath in filePaths) {
      final fileName = filePath.split('/').last;
      final remotePath = _getFullPath(fileName);

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Uploading $fileName...')),
      );

      final success = await sftpService.uploadFile(filePath, remotePath);
      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          failCount == 0
              ? 'Uploaded $successCount file(s)'
              : 'Uploaded $successCount, failed $failCount file(s)',
        ),
        backgroundColor: failCount == 0 ? AppTheme.successColor : AppTheme.warningColor,
      ),
    );

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

    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.serverId);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (sftpService == null) return;

    final success = await sftpService.createDirectory(_getFullPath(name));

    if (success) {
      _loadDirectory();
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to create directory'),
          backgroundColor: AppTheme.errorColor,
        ),
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

    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.serverId);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (sftpService == null) return;

    final success = await sftpService.rename(
      _getFullPath(oldName),
      _getFullPath(newName),
    );

    if (success) {
      _loadDirectory();
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to rename'),
          backgroundColor: AppTheme.errorColor,
        ),
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
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.serverId);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (sftpService == null) return;

    final success = await sftpService.delete(
      _getFullPath(filename),
      isDirectory: isDirectory,
    );

    if (success) {
      _loadDirectory();
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to delete'),
          backgroundColor: AppTheme.errorColor,
        ),
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
                if (_isDragging)
                  Container(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload,
                            size: 64,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Drop files here to upload',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(String title) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            '$title - SFTP',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder, size: 18),
            tooltip: 'Create directory',
            onPressed: _createDirectory,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, size: 18),
            tooltip: 'Upload file',
            onPressed: _uploadFile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh',
            onPressed: () => _loadDirectory(),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Disconnect',
            onPressed: () {
              final connectionProvider = context.read<ConnectionProvider>();
              final tabProvider = context.read<TabProvider>();
              connectionProvider.disconnectSFTP(widget.serverId);
              tabProvider.removeTab(widget.tabId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPathBar() {
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32),
            onPressed: _navigateUp,
            tooltip: 'Go up',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _navigateTo('/'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '/',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  for (var i = 0; i < parts.length; i++) ...[
                    const Text(' / ', style: TextStyle(color: AppTheme.textSecondary)),
                    InkWell(
                      onTap: () {
                        final path = '/${parts.sublist(0, i + 1).join('/')}';
                        _navigateTo(path);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          parts[i],
                          style: TextStyle(
                            color: i == parts.length - 1
                                ? AppTheme.textColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            const SizedBox(height: 16),
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
            Icon(Icons.folder_open, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'Empty directory',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              'Drop files here to upload',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDir ? Icons.folder : Icons.insert_drive_file,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                filename,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      child: InkWell(
        onTap: () {
          if (isDir) {
            _navigateTo(_getFullPath(filename));
          }
        },
        onSecondaryTapDown: (details) {
          _showContextMenu(context, item, details.globalPosition);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                isDir ? Icons.folder : _getFileIcon(filename),
                size: 20,
                color: isDir ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      style: const TextStyle(
                        color: AppTheme.textColor,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatSize(item.attr.size ?? 0),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, size: 18),
                itemBuilder: (context) => [
                  if (!isDir)
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 18),
                          SizedBox(width: 8),
                          Text('Download'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Rename'),
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
                onSelected: (value) {
                  if (value == 'download') {
                    _downloadFile(filename);
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
                Icon(Icons.folder_open, size: 18),
                SizedBox(width: 8),
                Text('Open'),
              ],
            ),
          ),
        if (!isDir)
          const PopupMenuItem<String>(
            value: 'download',
            child: Row(
              children: [
                Icon(Icons.download, size: 18),
                SizedBox(width: 8),
                Text('Download'),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
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
      if (value == 'open') {
        _navigateTo(_getFullPath(filename));
      } else if (value == 'download') {
        _downloadFile(filename);
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
