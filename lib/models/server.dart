import 'package:uuid/uuid.dart';

import '../utils/constants.dart';

enum AuthType {
  password,
  key;

  /// Parses loosely-formatted values (exact enum names, or free-form text
  /// like "publickey"/"private key") from imported/legacy data. Password is
  /// the safe fallback since it requires no key file to be present.
  static AuthType parse(dynamic value) {
    final str = value?.toString().toLowerCase().trim() ?? '';
    if (str == AuthType.key.name || str.contains('key')) {
      return AuthType.key;
    }
    return AuthType.password;
  }
}

class Server {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final AuthType authType;
  final String? group;
  final DateTime createdAt;
  final DateTime updatedAt;

  Server({
    String? id,
    required this.name,
    required this.host,
    this.port = AppConstants.defaultPort,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.authType = AuthType.password,
    this.group,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Server copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    String? passphrase,
    AuthType? authType,
    String? group,
  }) {
    return Server(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      authType: authType ?? this.authType,
      group: group ?? this.group,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
      'passphrase': passphrase,
      'authType': authType.name,
      'group': group,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? AppConstants.defaultPort,
      username: json['username'] as String,
      password: json['password'] as String?,
      privateKey: json['privateKey'] as String?,
      passphrase: json['passphrase'] as String?,
      authType: AuthType.parse(json['authType']),
      group: json['group'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() => 'Server($name, $host:$port)';
}
