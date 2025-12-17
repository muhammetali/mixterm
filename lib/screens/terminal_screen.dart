import 'package:flutter/material.dart';
import '../widgets/terminal_view.dart';

class TerminalScreen extends StatelessWidget {
  final String serverId;
  final String serverName;

  const TerminalScreen({
    super.key,
    required this.serverId,
    required this.serverName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(serverName),
      ),
      body: TerminalViewWidget(serverId: serverId),
    );
  }
}
