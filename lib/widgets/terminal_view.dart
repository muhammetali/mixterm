import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/server_provider.dart';
import '../services/ssh_service.dart';
import '../utils/theme.dart';

class TerminalViewWidget extends StatefulWidget {
  final String serverId;

  const TerminalViewWidget({super.key, required this.serverId});

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> {
  late Terminal _terminal;
  late TerminalController _terminalController;
  SSHService? _sshService;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );
    _terminalController = TerminalController();

    // Terminal girişini SSH'a gönder
    _terminal.onOutput = (data) {
      _sshService?.write(data);
    };

    // Terminal boyut değişikliğini SSH'a bildir
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _sshService?.resize(width, height);
    };

    _initConnection();
  }

  void _initConnection() {
    final connectionProvider = context.read<ConnectionProvider>();
    _sshService = connectionProvider.getSSHConnection(widget.serverId);

    if (_sshService != null && _sshService!.isConnected) {
      _isConnected = true;
      _sshService!.outputStream.listen((data) {
        _terminal.write(data);
      });
      _sshService!.stateStream.listen((state) {
        if (state == SSHConnectionState.disconnected) {
          setState(() {
            _isConnected = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final serverProvider = context.read<ServerProvider>();
    final server = serverProvider.getServer(widget.serverId);

    return Column(
      children: [
        _buildToolbar(server?.name ?? 'Terminal'),
        Expanded(
          child: Container(
            color: AppTheme.terminalBackground
                .withOpacity(settings.terminalOpacity),
            child: Listener(
              onPointerDown: (event) {
                if (event.buttons == 2 && settings.pasteOnRightClick) {
                  _pasteFromClipboard();
                }
              },
              child: TerminalView(
                _terminal,
                controller: _terminalController,
                theme: _buildTerminalTheme(),
                autofocus: true,
                textStyle: TerminalStyle(
                  fontSize: settings.fontSize.toDouble(),
                  fontFamily: settings.fontFamily,
                ),
                onSecondaryTapDown: (details, offset) {
                  if (settings.pasteOnRightClick) {
                    _pasteFromClipboard();
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboard?.text != null) {
      _sshService?.write(clipboard!.text!);
    }
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
          Icon(
            _isConnected ? Icons.check_circle : Icons.error,
            size: 16,
            color: _isConnected ? AppTheme.successColor : AppTheme.errorColor,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.content_paste, size: 18),
            tooltip: 'Paste',
            onPressed: _pasteFromClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Disconnect',
            onPressed: () {
              final connectionProvider = context.read<ConnectionProvider>();
              connectionProvider.disconnectSSH(widget.serverId);
            },
          ),
        ],
      ),
    );
  }

  TerminalTheme _buildTerminalTheme() {
    return TerminalTheme(
      cursor: AppTheme.terminalCursor,
      selection: AppTheme.terminalSelection,
      foreground: AppTheme.terminalForeground,
      background: AppTheme.terminalBackground,
      black: const Color(0xFF000000),
      red: const Color(0xFFCD3131),
      green: const Color(0xFF0DBC79),
      yellow: const Color(0xFFE5E510),
      blue: const Color(0xFF2472C8),
      magenta: const Color(0xFFBC3FBC),
      cyan: const Color(0xFF11A8CD),
      white: const Color(0xFFE5E5E5),
      brightBlack: const Color(0xFF666666),
      brightRed: const Color(0xFFF14C4C),
      brightGreen: const Color(0xFF23D18B),
      brightYellow: const Color(0xFFF5F543),
      brightBlue: const Color(0xFF3B8EEA),
      brightMagenta: const Color(0xFFD670D6),
      brightCyan: const Color(0xFF29B8DB),
      brightWhite: const Color(0xFFFFFFFF),
      searchHitBackground: const Color(0xFFFFDF5D),
      searchHitBackgroundCurrent: const Color(0xFFFF9632),
      searchHitForeground: const Color(0xFF000000),
    );
  }
}
