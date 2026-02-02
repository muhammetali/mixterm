import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/server_provider.dart';
import '../models/server.dart';
import '../providers/tab_provider.dart';
import '../services/ssh_service.dart';
import '../utils/theme.dart';
import '../utils/terminal_themes.dart';

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
  
  // Stream subscriptions to prevent memory leaks and race conditions
  StreamSubscription<SSHConnectionState>? _connectionSubscription;
  StreamSubscription<String>? _outputSubscription;

  @override
  void initState() {
    super.initState();
    _initTerminal();
  }

  @override
  void dispose() {
    _terminalController?.removeListener(_handleSelectionChange);
    _cancelSubscriptions();
    super.dispose();
  }

  void _cancelSubscriptions() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _outputSubscription?.cancel();
    _outputSubscription = null;
  }

  void _initTerminal() {
    final tabProvider = context.read<TabProvider>();
    _terminal = tabProvider.getOrCreateTerminal(widget.tabId);
    _terminalController = tabProvider.getTerminalController(widget.tabId);

    // Initial connection check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkConnectionState(provider: context.read<ConnectionProvider>());
      }
    });

    // Handle auto-copy on selection change robustly
    _terminalController?.addListener(_handleSelectionChange);

    // Terminal callbacks
    _terminal!.onOutput = (data) {
      _sshService?.write(data);
    };

    _terminal!.onResize = (width, height, pixelWidth, pixelHeight) {
      _sshService?.resize(width, height);
    };
  }

  void _handleSelectionChange() {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    
    // Auto-copy on select if enabled
    if (settings.copyOnSelect) {
      final selection = _terminalController?.selection;
      // Fixed: In xterm 4.0.0, BufferRange has begin and end
      if (selection != null && selection.begin != selection.end) {
        // Selection is updated, copy it silently
        _copySelection(silent: true);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // React to provider changes without manual polling
    _checkConnectionState(provider: context.watch<ConnectionProvider>());
  }

  void _checkConnectionState({ConnectionProvider? provider}) {
    final connectionProvider = provider ?? context.read<ConnectionProvider>();
    final newService = connectionProvider.getSSHConnection(widget.serverId);

    // If service changed or we are not initialized yet
    if (newService != _sshService) {
      _cancelSubscriptions(); // Ensure old listeners are cleared
      _sshService = newService;
      _isInitialized = false;
      
      if (_sshService != null) {
        // New connection available
        _setupServiceListeners();
      } else {
        // Lost connection reference (maybe disconnected from provider)
         if (mounted) {
          // Defer setState if called during build
          if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
             setState(() {
              _connectionStatus = ConnectionStatus.disconnected;
              _statusMessage = 'Disconnected';
            });
          } else {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) {
                  setState(() {
                    _connectionStatus = ConnectionStatus.disconnected;
                    _statusMessage = 'Disconnected';
                  });
               }
             });
          }
        }
      }
    }
  }

  void _setupServiceListeners() {
    if (_sshService == null) return;

    // Listen to state changes from service
    _connectionSubscription = _sshService!.stateStream.listen((state) {
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
            // Defer provider update to avoid 'markNeedsBuild during build'
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.read<TabProvider>().updateTabConnection(widget.tabId, true);
            });
            break;
          case SSHConnectionState.disconnected:
            _connectionStatus = ConnectionStatus.disconnected;
            _statusMessage = 'Disconnected';
            // Defer provider update
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.read<TabProvider>().updateTabConnection(widget.tabId, false);
            });
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
       _outputSubscription = _sshService!.outputStream.listen((data) {
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
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.read<TabProvider>().updateTabConnection(widget.tabId, true);
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use select() to only rebuild when specific settings change
    final fontSize = context.select<SettingsProvider, int>((s) => s.fontSize);
    final fontFamily = context.select<SettingsProvider, String>((s) => s.fontFamily);
    final terminalOpacity = context.select<SettingsProvider, double>((s) => s.terminalOpacity);
    final pasteOnRightClick = context.select<SettingsProvider, bool>((s) => s.pasteOnRightClick);
    final terminalTheme = context.select<SettingsProvider, String>((s) => s.terminalTheme);
    final terminalForegroundColor = context.select<SettingsProvider, String>((s) => s.terminalForegroundColor);

    final serverProvider = context.read<ServerProvider>();
    final server = serverProvider.getServer(widget.serverId);

    if (_terminal == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = AppTerminalThemes.getTheme(
      terminalTheme,
      foregroundColorName: terminalForegroundColor,
    );

    return Column(
      children: [
        _buildToolbar(server?.name ?? 'Terminal'),
        Expanded(
          child: Stack(
            children: [
              KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: _handleKeyEvent,
                child: Container(
                  color: AppTheme.terminalBackground.withValues(alpha: terminalOpacity),
                  padding: const EdgeInsets.all(8), // Terminal padding
                  child: TerminalView(
                    _terminal!,
                    controller: _terminalController,
                    theme: theme,
                    autofocus: true,
                    alwaysShowCursor: true,
                    textStyle: TerminalStyle(
                      fontSize: fontSize.toDouble(),
                      fontFamily: fontFamily,
                    ),
                    onSecondaryTapDown: (details, offset) {
                      if (pasteOnRightClick) {
                        _pasteFromClipboard();
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

  // Theme is now built directly in build() method with select() for optimization

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
              overflow: TextOverflow.ellipsis,
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
            onPressed: () => _copySelection(),
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

  Widget _buildConnectionOverlay(Server? server) {
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
  
  Widget _buildConnectionProgress() {
    return const SizedBox(
      width: 48,
      height: 48,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildProgressSteps() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepDot(_connectionStatus == ConnectionStatus.connecting || _connectionStatus == ConnectionStatus.connected),
        const SizedBox(width: 8),
        _buildStepDot(_connectionStatus == ConnectionStatus.connected),
      ],
    );
  }

  Widget _buildStepDot(bool active) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppTheme.primaryColor : AppTheme.borderColor,
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

  void _copySelection({bool silent = false}) {
    final selection = _terminalController?.selection;
    if (selection != null && selection.begin != selection.end) {
      final text = _terminal?.buffer.getText(selection);
      if (text != null && text.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: text));
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _sshService?.write(data!.text!);
    }
  }

  /// Handle keyboard events for special key combinations
  /// Note: Shift+click to bypass mouse tracking is handled at the xterm level
  void _handleKeyEvent(KeyEvent event) {
    // Ctrl+Shift+C to copy
    if (event is KeyDownEvent) {
      final ctrl = HardwareKeyboard.instance.isControlPressed;
      final shift = HardwareKeyboard.instance.isShiftPressed;

      if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyC) {
        _copySelection();
      }
      // Ctrl+Shift+V to paste
      else if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyV) {
        _pasteFromClipboard();
      }
    }
  }
}