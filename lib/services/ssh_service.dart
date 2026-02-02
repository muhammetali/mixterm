import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import '../models/server.dart';

enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class SSHConnectResult {
  final bool success;
  final String? error;

  SSHConnectResult({required this.success, this.error});

  factory SSHConnectResult.ok() => SSHConnectResult(success: true);
  factory SSHConnectResult.fail(String error) =>
      SSHConnectResult(success: false, error: error);
}

class SSHService {
  SSHClient? _client;
  SSHSession? _session;
  Timer? _keepAliveTimer;
  StreamSubscription<Uint8List>? _stdoutSubscription;
  StreamSubscription<Uint8List>? _stderrSubscription;
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final StreamController<SSHConnectionState> _stateController =
      StreamController<SSHConnectionState>.broadcast();

  Stream<String> get outputStream => _outputController.stream;
  Stream<SSHConnectionState> get stateStream => _stateController.stream;

  bool get isConnected => _client != null && !_client!.isClosed;

  Future<SSHConnectResult> connect(Server server) async {
    try {
      _stateController.add(SSHConnectionState.connecting);
      debugPrint('SSH: Connecting to ${server.host}:${server.port}');

      final socket = await SSHSocket.connect(
        server.host,
        server.port,
        timeout: const Duration(seconds: 30),
      );
      debugPrint('SSH: Socket connected');

      if (server.authType == AuthType.password) {
        debugPrint('SSH: Using password authentication');
        _client = SSHClient(
          socket,
          username: server.username,
          onPasswordRequest: () => server.password ?? '',
        );
      } else {
        debugPrint('SSH: Using key authentication');
        final privateKey = server.privateKey ?? '';
        if (privateKey.isEmpty) {
          _stateController.add(SSHConnectionState.error);
          return SSHConnectResult.fail('Private key is empty');
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
            return SSHConnectResult.fail('Failed to parse private key');
          }

          _client = SSHClient(
            socket,
            username: server.username,
            identities: keyPairs,
          );
        } catch (e) {
          debugPrint('SSH: Key parsing error: $e');
          _stateController.add(SSHConnectionState.error);
          return SSHConnectResult.fail('Invalid private key format: $e');
        }
      }

      debugPrint('SSH: Waiting for authentication...');
      await _client!.authenticated;
      debugPrint('SSH: Authenticated successfully');

      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: 80,
          height: 24,
        ),
      );
      debugPrint('SSH: Shell session started');

      _stdoutSubscription = _session!.stdout.listen((data) {
        _outputController.add(utf8.decode(data, allowMalformed: true));
      });

      _stderrSubscription = _session!.stderr.listen((data) {
        _outputController.add(utf8.decode(data, allowMalformed: true));
      });

      _stateController.add(SSHConnectionState.connected);
      _startKeepAlive();
      return SSHConnectResult.ok();
    } on SocketException catch (e) {
      debugPrint('SSH: Socket error: $e');
      _stateController.add(SSHConnectionState.error);
      _outputController.add('Connection error: $e\n');
      return SSHConnectResult.fail('Could not connect to ${server.host}:${server.port}');
    } on SSHAuthFailError catch (e) {
      debugPrint('SSH: Auth failed: $e');
      _stateController.add(SSHConnectionState.error);
      _outputController.add('Authentication failed: $e\n');
      return SSHConnectResult.fail('Authentication failed: Invalid credentials');
    } catch (e) {
      debugPrint('SSH: General error: $e');
      _stateController.add(SSHConnectionState.error);
      _outputController.add('Connection error: $e\n');
      return SSHConnectResult.fail('$e');
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

  void resize(int width, int height) {
    debugPrint('SSH: Resizing terminal to ${width}x$height');
    _session?.resizeTerminal(width, height);
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected) {
        // TODO: Find correct method for keep-alive in dartssh2
        // _client?.sendGlobalRequest('keepalive@openssh.com');
      }
    });
  }

  Future<void> disconnect() async {
    _keepAliveTimer?.cancel();
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
    _keepAliveTimer?.cancel();
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _session?.close();
    _client?.close();
    _outputController.close();
    _stateController.close();
  }
}
