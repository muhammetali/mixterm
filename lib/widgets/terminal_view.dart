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
    _terminal = tabProvider.getOrCreateTerminal(widget.tabId);
    _terminalController = tabProvider.getTerminalController(widget.tabId);

    // Initial connection check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectionState();
    });

    // Terminal callbacks
    _terminal!.onOutput = (data) {
      _sshService?.write(data);
    };

    _terminal!.onResize = (width, height, pixelWidth, pixelHeight) {
      _sshService?.resize(width, height);
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // React to provider changes without manual polling
    _checkConnectionState();
  }

  void _checkConnectionState() {
    final connectionProvider = context.watch<ConnectionProvider>();
    final newService = connectionProvider.getSSHConnection(widget.serverId);

    // If service changed or we are not initialized yet
    if (newService != _sshService) {
      _sshService = newService;
      _isInitialized = false;
      
      if (_sshService != null) {
        // New connection available
        _setupServiceListeners();
      } else {
        // Lost connection reference (maybe disconnected from provider)
         if (mounted) {
          setState(() {
            _connectionStatus = ConnectionStatus.disconnected;
            _statusMessage = 'Disconnected';
          });
        }
      }
    }
  }

  void _setupServiceListeners() {
    if (_sshService == null) return;

    // Listen to state changes from service
    _sshService!.stateStream.listen((state) {
      if (!mounted) return;
      
      setState(() {
        switch (state) {
          case SSHConnectionState.connecting:
            _connectionStatus = ConnectionStatus.connecting;
            _statusMessage = 'Connecting...';
            break;
          case SSHConnectionState.connected:
            _connectionStatus = ConnectionStatus.connected;
            _statusMessage = 'Connected';
            context.read<TabProvider>().updateTabConnection(widget.tabId, true);
            break;
          case SSHConnectionState.disconnected:
            _connectionStatus = ConnectionStatus.disconnected;
            _statusMessage = 'Disconnected';
            context.read<TabProvider>().updateTabConnection(widget.tabId, false);
            break;
          case SSHConnectionState.error:
            _connectionStatus = ConnectionStatus.error;
            _statusMessage = 'Connection failed';
            break;
        }
      });
    });

    // Setup output stream if not already listening
    if (!_isInitialized) {
       _sshService!.outputStream.listen((data) {
        _terminal?.write(data);
      });
      _isInitialized = true;
    }
    
    // Check initial state
    if (_sshService!.isConnected) {
       if (mounted) {
          setState(() {
            _connectionStatus = ConnectionStatus.connected;
            _statusMessage = 'Connected';
          });
       }
       context.read<TabProvider>().updateTabConnection(widget.tabId, true);
    }
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
              Container(
                color: AppTheme.terminalBackground.withValues(alpha: settings.terminalOpacity),
                child: Listener(
                  onPointerDown: (event) {
                    // Right click to paste
                    if (event.buttons == 2 && settings.pasteOnRightClick) {
                      _pasteFromClipboard();
                    }
                  },
                  child: TerminalView(
                    _terminal!,
                    controller: _terminalController,
                    theme: _buildTerminalTheme(context),
                    autofocus: true,
                    alwaysShowCursor: true,
                    textStyle: TerminalStyle(
                      fontSize: settings.fontSize.toDouble(),
                      fontFamily: settings.fontFamily,
                    ),
                    onSecondaryTapDown: (details, offset) {
                       if (settings.pasteOnRightClick) {
                        _pasteFromClipboard();
                      }
                    },
                    // Handle selection change for auto-copy
                    onSelectionChanged: (range, text) {
                      if (settings.copyOnSelect && text != null && text.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: text));
                      }
                    },
                  ),
                ),
              ),
              // Connection overlay
              if (_connectionStatus != ConnectionStatus.connected)
                _buildConnectionOverlay(server),
            ],
          ),
        ),
      ],
    );
  }

import '../utils/terminal_themes.dart';

// ... (existing imports)

  // ... (inside class)

  TerminalTheme _buildTerminalTheme(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return TerminalThemes.getTheme(settings.terminalTheme);
  }

  Widget _buildToolbar(String title) {
    final isConnected = _connectionStatus == ConnectionStatus.connected;
    
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          _buildStatusIcon(isConnected),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textColor),
              overflow: TextOverflow.ellipsis, // Fix RenderFlex overflow
            ),
          ),
          if (!isConnected)
             Padding(
               padding: const EdgeInsets.only(left: 8),
               child: Text(
                '($_statusMessage)',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
               ),
             ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy Selection',
            onPressed: _copySelection,
          ),
          IconButton(
            icon: const Icon(Icons.content_paste, size: 18),
            tooltip: 'Paste',
            onPressed: isConnected ? _pasteFromClipboard : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Disconnect',
            onPressed: () {
              context.read<ConnectionProvider>().disconnectSSH(widget.serverId);
              context.read<TabProvider>().removeTab(widget.tabId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isConnected) {
     if (_connectionStatus == ConnectionStatus.connecting) {
        return const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor)),
        );
     }
     return Icon(
       isConnected ? Icons.check_circle : Icons.error,
       size: 16,
       color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
     );
  }

  Widget _buildConnectionOverlay(server) {
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
                if (server != null) ...[
                  Text(
                    server.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${server.host}:${server.port}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
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

  Future<void> _reconnect() async {
    setState(() {
      _connectionStatus = ConnectionStatus.connecting;
      _statusMessage = 'Reconnecting...';
      _errorMessage = null;
    });
    
    final server = context.read<ServerProvider>().getServer(widget.serverId);
    if (server != null) {
      final result = await context.read<ConnectionProvider>().connectSSH(server);
      if (!result.success && mounted) {
        setState(() {
          _connectionStatus = ConnectionStatus.error;
          _statusMessage = 'Connection failed';
          _errorMessage = result.error;
        });
      }
    }
  }

  void _copySelection() {
    final selection = _terminalController?.selection;
    if (selection != null) {
      final text = _terminal?.buffer.getText(selection);
      if (text != null && text.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard'), duration: Duration(milliseconds: 500)),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(ClipboardData.kTextPlain);
    if (data?.text != null) {
      _sshService?.write(data!.text!);
    }
  }
}