import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/server_provider.dart';
import '../providers/tab_provider.dart';
import '../services/ssh_service.dart';
import '../utils/theme.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class TerminalViewWidget extends StatefulWidget {
  final String serverId;
  final String tabId;

  const TerminalViewWidget({
    super.key,
    required this.serverId,
    required this.tabId,
  });

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> {
  Terminal? _terminal;
  TerminalController? _terminalController;
  SSHService? _sshService;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String _statusMessage = 'Initializing...';
  String? _errorMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initTerminal();
  }

  void _initTerminal() {
    final tabProvider = context.read<TabProvider>();

    // Get or create terminal from TabProvider
    _terminal = tabProvider.getOrCreateTerminal(widget.tabId);
    _terminalController = tabProvider.getTerminalController(widget.tabId);

    // Set up terminal callbacks
    _terminal!.onOutput = (data) {
      _sshService?.write(data);
    };

    _terminal!.onResize = (width, height, pixelWidth, pixelHeight) {
      _sshService?.resize(width, height);
    };

    _checkConnection();
  }

  void _checkConnection() {
    final connectionProvider = context.read<ConnectionProvider>();
    _sshService = connectionProvider.getSSHConnection(widget.serverId);

    if (_sshService != null && _sshService!.isConnected) {
      _setupConnectedState();
    } else {
      // Listen for connection state changes
      _listenForConnection();
    }
  }

  void _listenForConnection() {
    final connectionProvider = context.read<ConnectionProvider>();

    // Check periodically for connection
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      _sshService = connectionProvider.getSSHConnection(widget.serverId);

      if (_sshService != null) {
        _setupConnectionListener();
      } else {
        _listenForConnection();
      }
    });
  }

  void _setupConnectionListener() {
    if (_sshService == null) return;

    _sshService!.stateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        switch (state) {
          case SSHConnectionState.connecting:
            _connectionStatus = ConnectionStatus.connecting;
            _statusMessage = 'Connecting to server...';
            break;
          case SSHConnectionState.connected:
            _connectionStatus = ConnectionStatus.connected;
            _statusMessage = 'Connected';
            _setupConnectedState();
            break;
          case SSHConnectionState.disconnected:
            _connectionStatus = ConnectionStatus.disconnected;
            _statusMessage = 'Disconnected';
            final tabProvider = context.read<TabProvider>();
            tabProvider.updateTabConnection(widget.tabId, false);
            break;
          case SSHConnectionState.error:
            _connectionStatus = ConnectionStatus.error;
            _statusMessage = 'Connection failed';
            break;
        }
      });
    });

    // If already connected, setup immediately
    if (_sshService!.isConnected) {
      _setupConnectedState();
    }
  }

  void _setupConnectedState() {
    if (!mounted || _sshService == null) return;

    setState(() {
      _connectionStatus = ConnectionStatus.connected;
      _statusMessage = 'Connected';
    });

    final tabProvider = context.read<TabProvider>();
    tabProvider.updateTabConnection(widget.tabId, true);

    if (!_isInitialized) {
      _sshService!.outputStream.listen((data) {
        _terminal?.write(data);
      });
      _isInitialized = true;
    }

    _sshService!.stateStream.listen((state) {
      if (state == SSHConnectionState.disconnected && mounted) {
        setState(() {
          _connectionStatus = ConnectionStatus.disconnected;
          _statusMessage = 'Disconnected';
        });
        tabProvider.updateTabConnection(widget.tabId, false);
      }
    });
  }

  @override
  void dispose() {
    // Don't dispose terminal controller - it's managed by TabProvider
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final serverProvider = context.read<ServerProvider>();
    final server = serverProvider.getServer(widget.serverId);

    if (_terminal == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildToolbar(server?.name ?? 'Terminal'),
        Expanded(
          child: Stack(
            children: [
              // Terminal view
              Container(
                color: AppTheme.terminalBackground
                    .withValues(alpha: settings.terminalOpacity),
                child: Listener(
                  onPointerDown: (event) {
                    if (event.buttons == 2 && settings.pasteOnRightClick) {
                      _pasteFromClipboard();
                    }
                  },
                  child: TerminalView(
                    _terminal!,
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
              // Connection overlay
              if (_connectionStatus != ConnectionStatus.connected)
                _buildConnectionOverlay(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionOverlay() {
    return Container(
      color: AppTheme.backgroundColor.withValues(alpha: 0.9),
      child: Center(
        child: Card(
          color: AppTheme.surfaceColor,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_connectionStatus == ConnectionStatus.error) ...[
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _reconnect,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ] else ...[
                  _buildConnectionProgress(),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProgressSteps(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionProgress() {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          Icon(
            _getStatusIcon(),
            size: 24,
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_connectionStatus) {
      case ConnectionStatus.connecting:
        return Icons.wifi;
      case ConnectionStatus.connected:
        return Icons.check;
      case ConnectionStatus.disconnected:
        return Icons.wifi_off;
      case ConnectionStatus.error:
        return Icons.error;
    }
  }

  Widget _buildProgressSteps() {
    final steps = [
      ('Connect', ConnectionStatus.connecting),
      ('Ready', ConnectionStatus.connected),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: steps.map((step) {
        final isActive = _connectionStatus.index >= step.$2.index;
        final isCurrent = _connectionStatus == step.$2;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.primaryColor : AppTheme.cardColor,
                  border: Border.all(
                    color: isCurrent ? AppTheme.primaryColor : AppTheme.borderColor,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: isActive
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                step.$1,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? AppTheme.textColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _reconnect() async {
    final connectionProvider = context.read<ConnectionProvider>();
    final serverProvider = context.read<ServerProvider>();
    final server = serverProvider.getServer(widget.serverId);

    if (server == null) return;

    setState(() {
      _connectionStatus = ConnectionStatus.connecting;
      _statusMessage = 'Reconnecting...';
      _errorMessage = null;
    });

    final result = await connectionProvider.connectSSH(server);

    if (!mounted) return;

    if (result.success) {
      _sshService = connectionProvider.getSSHConnection(widget.serverId);
      _setupConnectedState();
    } else {
      setState(() {
        _connectionStatus = ConnectionStatus.error;
        _statusMessage = 'Connection failed';
        _errorMessage = result.error;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboard?.text != null) {
      _sshService?.write(clipboard!.text!);
    }
  }

  Widget _buildToolbar(String title) {
    final isConnected = _connectionStatus == ConnectionStatus.connected;

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
          if (_connectionStatus == ConnectionStatus.connecting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          else
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              size: 16,
              color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
            ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
          ),
          if (!isConnected) ...[
            const SizedBox(width: 8),
            Text(
              '($_statusMessage)',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.content_paste, size: 18),
            tooltip: 'Paste',
            onPressed: isConnected ? _pasteFromClipboard : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Disconnect',
            onPressed: () {
              final connectionProvider = context.read<ConnectionProvider>();
              final tabProvider = context.read<TabProvider>();
              connectionProvider.disconnectSSH(widget.serverId);
              tabProvider.removeTab(widget.tabId);
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
