import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dartssh2/dartssh2.dart';
import '../providers/connection_provider.dart';
import '../providers/server_provider.dart';
import '../utils/theme.dart';

class SFTPBrowser extends StatefulWidget {
  final String serverId;

  const SFTPBrowser({super.key, required this.serverId});

  @override
  State<SFTPBrowser> createState() => _SFTPBrowserState();
}

class _SFTPBrowserState extends State<SFTPBrowser> {
  String _currentPath = '/';
  List<SftpName> _items = [];
  bool _isLoading = true;
  String? _error;

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

    if (sftpService == null) return;

    final downloadDir = await getDownloadsDirectory();
    if (downloadDir == null) return;

    final localPath = '${downloadDir.path}/$filename';
    final remotePath = _getFullPath(filename);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading $filename...')),
    );

    final success = await sftpService.downloadFile(remotePath, localPath);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Downloaded to $localPath' : 'Download failed',
        ),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final connectionProvider = context.read<ConnectionProvider>();
    final sftpService = connectionProvider.getSFTPConnection(widget.serverId);

    if (sftpService == null) return;

    final remotePath = _getFullPath(file.name);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Uploading ${file.name}...')),
    );

    final success = await sftpService.uploadFile(file.path!, remotePath);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Uploaded ${file.name}' : 'Upload failed',
        ),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );

    if (success) {
      _loadDirectory();
    }
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

    if (sftpService == null) return;

    final success = await sftpService.createDirectory(_getFullPath(name));

    if (success) {
      _loadDirectory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create directory'),
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

    if (sftpService == null) return;

    final success = await sftpService.delete(
      _getFullPath(filename),
      isDirectory: isDirectory,
    );

    if (success) {
      _loadDirectory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
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
          child: _buildContent(),
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
              connectionProvider.disconnectSFTP(widget.serverId);
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
        child: Text(
          'Empty directory',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isDir = item.attr.isDirectory;

        return ListTile(
          leading: Icon(
            isDir ? Icons.folder : _getFileIcon(item.filename),
            color: isDir ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
          title: Text(item.filename),
          subtitle: Text(
            _formatSize(item.attr.size ?? 0),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          onTap: () {
            if (isDir) {
              _navigateTo(_getFullPath(item.filename));
            }
          },
          trailing: PopupMenuButton(
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
                _downloadFile(item.filename);
              } else if (value == 'delete') {
                _deleteItem(item.filename, isDir);
              }
            },
          ),
        );
      },
    );
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
