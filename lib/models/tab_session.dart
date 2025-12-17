import 'package:uuid/uuid.dart';

enum TabType { ssh, sftp, local }

class TabSession {
  final String id;
  final String? serverId;
  final TabType type;
  final DateTime createdAt;
  String title;
  String currentPath;
  bool isConnected;

  TabSession({
    String? id,
    this.serverId,
    required this.type,
    String? title,
    this.currentPath = '/',
    this.isConnected = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = DateTime.now(),
        title = title ?? _generateTitle(type, serverId);

  static String _generateTitle(TabType type, String? serverId) {
    switch (type) {
      case TabType.ssh:
        return 'SSH Terminal';
      case TabType.sftp:
        return 'SFTP Browser';
      case TabType.local:
        return 'Local Files';
    }
  }

  TabSession copyWith({
    String? title,
    String? currentPath,
    bool? isConnected,
  }) {
    return TabSession(
      id: id,
      serverId: serverId,
      type: type,
      title: title ?? this.title,
      currentPath: currentPath ?? this.currentPath,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverId': serverId,
      'type': type.index,
      'title': title,
      'currentPath': currentPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TabSession.fromJson(Map<String, dynamic> json) {
    return TabSession(
      id: json['id'] as String,
      serverId: json['serverId'] as String?,
      type: TabType.values[json['type'] as int],
      title: json['title'] as String?,
      currentPath: json['currentPath'] as String? ?? '/',
    );
  }
}
