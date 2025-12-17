import 'package:dartssh2/dartssh2.dart';

enum ConnectionType { ssh, sftp }

enum ConnectionStatus { disconnected, connecting, connected, error }

class Connection {
  final String serverId;
  final ConnectionType type;
  ConnectionStatus status;
  SSHClient? sshClient;
  SftpClient? sftpClient;
  String? errorMessage;
  final DateTime connectedAt;

  Connection({
    required this.serverId,
    required this.type,
    this.status = ConnectionStatus.disconnected,
    this.sshClient,
    this.sftpClient,
    this.errorMessage,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  bool get isConnected => status == ConnectionStatus.connected;

  void disconnect() {
    sftpClient?.close();
    sshClient?.close();
    sshClient = null;
    sftpClient = null;
    status = ConnectionStatus.disconnected;
  }
}
