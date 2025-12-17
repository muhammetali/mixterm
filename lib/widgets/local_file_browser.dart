import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';

class LocalFileBrowser extends StatefulWidget {
  final String? initialPath;
  final Function(String path)? onPathChanged;
  final Function(List<String> paths)? onFilesSelected;

  const LocalFileBrowser({
    super.key,
    this.initialPath,
    this.onPathChanged,
    this.onFilesSelected,
  });

  @override
  State<LocalFileBrowser> createState() => _LocalFileBrowserState();
}

class _LocalFileBrowserState extends State<LocalFileBrowser> {
  String _currentPath = '/';
  List<FileSystemEntity> _items = [];
  bool _isLoading = true;
  String? _error;
  Set<String> _selectedPaths = {};
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  Future<void> _initPath() async {
    if (widget.initialPath != null) {
      _currentPath = widget.initialPath!;
    } else {
      final homeDir = Platform.environment['HOME'] ?? '/';
      _currentPath = homeDir;
    }
    await _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedPaths.clear();
    });

    try {
      final dir = Directory(_currentPath);
      if (!await dir.exists()) {
        throw Exception('Directory does not exist');
      }

      final entities = await dir.list().toList();
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      setState(() {
        _items = entities;
        _isLoading = false;
      });

      widget.onPathChanged?.call(_currentPath);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateTo(String path) {
    _currentPath = path;
    _loadDirectory();
  }

  void _navigateUp() {
    final parent = Directory(_currentPath).parent;
    _navigateTo(parent.path);
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
      widget.onFilesSelected?.call(_selectedPaths.toList());
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildPathBar(),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.computer, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Text(
            'Local Files',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            tooltip: 'Go Up',
            onPressed: _currentPath != '/' ? _navigateUp : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh',
            onPressed: _loadDirectory,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.home, size: 18),
            tooltip: 'Home',
            onPressed: () {
              final homeDir = Platform.environment['HOME'] ?? '/';
              _navigateTo(homeDir);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPathBar() {
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _navigateTo('/'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.folder, size: 16, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: parts.length,
              itemBuilder: (context, index) {
                final path = '/${parts.sublist(0, index + 1).join('/')}';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    InkWell(
                      onTap: () => _navigateTo(path),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          parts[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: index == parts.length - 1
                                ? AppTheme.textColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Error loading directory',
              style: const TextStyle(color: AppTheme.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDirectory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
          ],
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _buildFileItem(item);
        },
      ),
    );
  }

  Widget _buildFileItem(FileSystemEntity item) {
    final isDirectory = item is Directory;
    final name = item.path.split('/').last;
    final isSelected = _selectedPaths.contains(item.path);

    return Draggable<String>(
      data: item.path,
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
                isDirectory ? Icons.folder : Icons.insert_drive_file,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      child: InkWell(
        onTap: () {
          if (isDirectory) {
            _navigateTo(item.path);
          } else {
            _toggleSelection(item.path);
          }
        },
        onSecondaryTap: () => _showContextMenu(context, item),
        child: Container(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                isDirectory ? Icons.folder : _getFileIcon(name),
                size: 20,
                color: isDirectory
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textColor,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    FutureBuilder<FileStat>(
                      future: item.stat(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        final stat = snapshot.data!;
                        return Text(
                          isDirectory
                              ? _formatDate(stat.modified)
                              : '${_formatSize(stat.size)} - ${_formatDate(stat.modified)}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'txt':
      case 'md':
      case 'log':
        return Icons.description;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'svg':
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
        return Icons.folder_zip;
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'java':
      case 'cpp':
      case 'c':
      case 'h':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _showContextMenu(BuildContext context, FileSystemEntity item) {
    final isDirectory = item is Directory;
    final name = item.path.split('/').last;

    showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
        0,
        0,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem<dynamic>(
          child: Row(
            children: [
              Icon(
                isDirectory ? Icons.folder_open : Icons.open_in_new,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(isDirectory ? 'Open' : 'Open File'),
            ],
          ),
          onTap: () {
            if (isDirectory) {
              _navigateTo(item.path);
            }
          },
        ),
        const PopupMenuItem<dynamic>(
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 18),
              SizedBox(width: 8),
              Text('Copy Path'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<dynamic>(
          child: Row(
            children: [
              const Icon(Icons.delete, size: 18, color: AppTheme.errorColor),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ],
          ),
          onTap: () => _confirmDelete(item, name),
        ),
      ],
    );
  }

  void _confirmDelete(FileSystemEntity item, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await item.delete(recursive: true);
                _loadDirectory();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
