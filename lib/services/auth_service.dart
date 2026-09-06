import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  // OAuth credentials from Google Cloud Console
  // Get your own credentials:
  // 1. Go to https://console.cloud.google.com/
  // 2. Create a project and enable Google Drive API
  // 3. Create OAuth 2.0 Client ID (Desktop app type)
  // 4. Optionally set GOOGLE_CLIENT_ID via --dart-define, or update the
  //    defaultValue below
  static const String _clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '449803261214-6p5oc4no7cav8gh7kj4am1qg9elvk55u.apps.googleusercontent.com',
  );

  // No client secret: Desktop-app OAuth clients are public clients per
  // Google's own guidance (a secret can't actually be kept confidential in
  // a distributed binary), and this flow already uses PKCE (see
  // googleapis_auth's AuthorizationCodeGrantServerFlow/createCodeVerifier)
  // for security instead. `String.fromEnvironment` returns '' rather than
  // null when GOOGLE_CLIENT_SECRET isn't provided, and googleapis_auth
  // only omits `client_secret` from the token request when ClientId.secret
  // is exactly null (not merely empty) — sending '' reads to Google as
  // "client_secret is missing" (HTTP 400) instead of "not sent". Route
  // through this getter so every build (not just ones passing
  // --dart-define=GOOGLE_CLIENT_SECRET=...) gets the correct, working,
  // secret-free flow.
  static const String _clientSecretEnv = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
  static String? get _clientSecret => _clientSecretEnv.isEmpty ? null : _clientSecretEnv;

  static const List<String> _scopes = [
    'email',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  static const String _credentialsKey = 'google_credentials';
  static const String _userInfoKey = 'google_user_info';

  AutoRefreshingAuthClient? _authClient;
  String? _userEmail;
  String? _userName;
  String? _userPhoto;
  String? _userId;

  bool get isSignedIn => _authClient != null;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userPhoto => _userPhoto;
  String? get userId => _userId;

  // Client identifier for OAuth — see _clientSecret's doc comment for why
  // this intentionally has no secret unless GOOGLE_CLIENT_SECRET is set.
  final _clientIdentifier = ClientId(_clientId, _clientSecret);

  @visibleForTesting
  ClientId get debugClientId => _clientIdentifier;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString(_credentialsKey);
      final userInfoJson = prefs.getString(_userInfoKey);

      if (credentialsJson != null) {
        final credentials = AccessCredentials.fromJson(json.decode(credentialsJson));

        if (credentials.accessToken.expiry.isBefore(DateTime.now())) {
          if (credentials.refreshToken != null) {
            final newCredentials = await refreshCredentials(
              _clientIdentifier,
              credentials,
              http.Client(),
            );
            await _saveCredentials(newCredentials);
            _authClient = autoRefreshingClient(
              _clientIdentifier,
              newCredentials,
              http.Client(),
            );
          }
        } else {
          _authClient = autoRefreshingClient(
            _clientIdentifier,
            credentials,
            http.Client(),
          );
        }

        if (userInfoJson != null) {
          final userInfo = json.decode(userInfoJson);
          _userEmail = userInfo['email'];
          _userName = userInfo['name'];
          _userPhoto = userInfo['picture'];
          _userId = userInfo['id'];
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Auth init error: $e');
      await signOut();
    }
  }

  Future<bool> signIn() async {
    try {
      final authClient = await clientViaUserConsent(
        _clientIdentifier,
        _scopes,
        _openUrl,
      );

      _authClient = authClient;
      await _saveCredentials(authClient.credentials);

      await _fetchUserInfo();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    }
  }

  void _openUrl(String url) {
    final uri = Uri.parse(url);
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _fetchUserInfo() async {
    if (_authClient == null) return;

    try {
      final response = await _authClient!.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      );

      if (response.statusCode == 200) {
        final userInfo = json.decode(response.body);
        _userEmail = userInfo['email'];
        _userName = userInfo['name'];
        _userPhoto = userInfo['picture'];
        _userId = userInfo['id'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userInfoKey, response.body);
      }
    } catch (e) {
      debugPrint('Fetch user info error: $e');
    }
  }

  Future<void> _saveCredentials(AccessCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_credentialsKey, json.encode(credentials.toJson()));
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_credentialsKey);
    await prefs.remove(_userInfoKey);

    _authClient?.close();
    _authClient = null;
    _userEmail = null;
    _userName = null;
    _userPhoto = null;
    _userId = null;

    notifyListeners();
  }

  drive.DriveApi? getDriveApi() {
    if (_authClient == null) return null;
    return drive.DriveApi(_authClient!);
  }
}
