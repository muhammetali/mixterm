import 'package:flutter/material.dart';
import '../widgets/sftp_browser.dart';

class SFTPScreen extends StatelessWidget {
  final String serverId;
  final String serverName;

  const SFTPScreen({
    super.key,
    required this.serverId,
    required this.serverName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$serverName - SFTP'),
      ),
      body: SFTPBrowser(serverId: serverId),
    );
  }
}
