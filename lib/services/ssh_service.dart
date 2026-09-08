import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import '../models/server.dart';
import '../utils/constants.dart';
import '../utils/result.dart';

enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class SSHService {
  SSHClient? _client;
  SSHSession? _session;
  StreamSubscription<Uint8List>? _stdoutSubscription;
  StreamSubscription<Uint8List>? _stderrSubscription;
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final StreamController<SSHConnectionState> _stateController =
      StreamController<SSHConnectionState>.broadcast();

  /// The size the local terminal last reported, in character cells.
  ///
  /// Kept here rather than only forwarded, because the view learns its size
  /// during its first layout — which happens *before* the session exists.
  /// Forwarding that first measurement into a null session silently dropped
  /// it, so the remote PTY kept the 80x24 default while the window showed
  /// something else entirely. The shell then did its cursor arithmetic
  /// against the wrong width, and any redraw crossing the real column 80 —
  /// a tab completion, a long prompt, `less`, `vim` — landed in the wrong
  /// place.
  ///
  /// 80x24 remains the starting value because that is what a PTY gets when
  /// nobody says otherwise, not because it is a good guess.
  int _columns = 80;
  int _rows = 24;

  Stream<String> get outputStream => _outputController.stream;
  Stream<SSHConnectionState> get stateStream => _stateController.stream;

  bool get isConnected => _client != null && !_client!.isClosed;

  /// The terminal size this service will request, or has requested.
  @visibleForTesting
  ({int columns, int rows}) get terminalSize =>
      (columns: _columns, rows: _rows);

  Future<VoidResult> connect(Server server) async {
    try {
      _stateController.add(SSHConnectionState.connecting);
      debugPrint('SSH: Connecting to ${server.host}:${server.port}');

      final socket = await SSHSocket.connect(
        server.host,
        server.port,
        timeout: const Duration(seconds: AppConstants.connectionTimeout),
      );
      debugPrint('SSH: Socket connected');

      // dartssh2's SSHClient sends its own `keepalive@openssh.com` global
      // request on this interval once authenticated (see SSHKeepAlive),
      // which is what actually keeps idle sessions alive through
      // NATs/firewalls. Passed explicitly so the behavior is visible here
      // rather than relying on the library's implicit default.
      const keepAliveInterval =
          Duration(seconds: AppConstants.sshKeepAliveIntervalSeconds);

      if (server.authType == AuthType.password) {
        debugPrint('SSH: Using password authentication');
        _client = SSHClient(
          socket,
          username: server.username,
          onPasswordRequest: () => server.password ?? '',
          keepAliveInterval: keepAliveInterval,
        );
      } else {
        debugPrint('SSH: Using key authentication');
        final privateKey = server.privateKey ?? '';
        if (privateKey.isEmpty) {
          _stateController.add(SSHConnectionState.error);
          return VoidResult.fail('Private key is empty');
        }

        debugPrint('SSH: Using private key authentication');

        try {
          final keyPairs = SSHKeyPair.fromPem(
            privateKey,
            server.passphrase,
          );
          debugPrint('SSH: Parsed ${keyPairs.length} key pair(s)');

          if (keyPairs.isEmpty) {
            _stateController.add(SSHConnectionState.error);
            return VoidResult.fail('Failed to parse private key');
          }

          _client = SSHClient(
            socket,
            username: server.username,
            identities: keyPairs,
            keepAliveInterval: keepAliveInterval,
          );
        } catch (e) {
          debugPrint('SSH: Key parsing error: $e');
          _stateController.add(SSHConnectionState.error);
          return VoidResult.fail('Invalid private key format: $e');
        }
      }

      debugPrint('SSH: Waiting for authentication...');
      await _client!.authenticated;
      debugPrint('SSH: Authenticated successfully');

      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: _columns,
          height: _rows,
        ),
      );
      debugPrint('SSH: Shell session started at ${_columns}x$_rows');

      _stdoutSubscription = _session!.stdout.listen((data) {
        _outputController.add(utf8.decode(data, allowMalformed: true));
      });

      _stderrSubscription = _session!.stderr.listen((data) {
        _outputController.add(utf8.decode(data, allowMalformed: true));
      });

      _stateController.add(SSHConnectionState.connected);
      return VoidResult.ok();
    } on SocketException catch (e) {
      debugPrint('SSH: Socket error: $e');
      _stateController.add(SSHConnectionState.error);
      _outputController.add('Connection error: $e\n');
      return VoidResult.fail('Could not connect to ${server.host}:${server.port}');
    } on SSHAuthFailError catch (e) {
      debugPrint('SSH: Auth failed: $e');
      _stateController.add(SSHConnectionState.error);
      _outputController.add('Authentication failed: $e\n');
      return VoidResult.fail('Authentication failed: Invalid credentials');
    } catch (e) {
      debugPrint('SSH: General error: $e');
      _stateController.add(SSHConnectionState.error);
      _outputController.add('Connection error: $e\n');
      return VoidResult.fail('$e');
    }
  }

  void write(String data) {
    if (_session != null) {
      _session!.stdin.add(utf8.encode(data));
    }
  }

  void writeBytes(Uint8List data) {
    if (_session != null) {
      _session!.stdin.add(data);
    }
  }

  /// Records the terminal size and, if a session is already running, tells
  /// the remote about it.
  ///
  /// Safe to call before [connect]: the size is remembered and used for the
  /// PTY the shell is opened with, so the very first prompt is drawn against
  /// the right width.
  void resize(int width, int height) {
    if (width <= 0 || height <= 0) return;
    if (width == _columns && height == _rows) return;

    _columns = width;
    _rows = height;
    debugPrint('SSH: Terminal size now ${width}x$height');
    _session?.resizeTerminal(width, height);
  }

  Future<void> disconnect() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _session?.close();
    _client?.close();
    _session = null;
    _client = null;
    if (!_stateController.isClosed) {
      _stateController.add(SSHConnectionState.disconnected);
    }
  }

  void dispose() {
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _session?.close();
    _client?.close();
    _outputController.close();
    _stateController.close();
  }
}
