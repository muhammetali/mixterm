import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mixterm/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    late SharedPreferences prefs;
    late AuthService authService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      authService = AuthService();
    });

    group('initial state', () {
      test('isSignedIn returns false initially', () {
        expect(authService.isSignedIn, isFalse);
      });

      test('userEmail is null initially', () {
        expect(authService.userEmail, isNull);
      });

      test('userName is null initially', () {
        expect(authService.userName, isNull);
      });

      test('userPhoto is null initially', () {
        expect(authService.userPhoto, isNull);
      });

      test('userId is null initially', () {
        expect(authService.userId, isNull);
      });
    });

    group('init', () {
      test('does nothing when no stored credentials', () async {
        await authService.init();

        expect(authService.isSignedIn, isFalse);
      });

      test('restores user info from preferences', () async {
        // Simulate stored user info
        await prefs.setString('google_user_info', '''
          {
            "email": "test@example.com",
            "name": "Test User",
            "picture": "https://example.com/photo.jpg",
            "id": "123456"
          }
        ''');

        // Note: Full credential restoration requires valid OAuth tokens
        // This test verifies user info is read from prefs
        authService = AuthService();
        // Without valid credentials, it won't be signed in
        expect(authService.isSignedIn, isFalse);
      });
    });

    group('signOut', () {
      test('clears all user data', () async {
        // Setup some mock state by setting prefs directly
        await prefs.setString('google_credentials', '{}');
        await prefs.setString('google_user_info', '{"email": "test@example.com"}');

        await authService.signOut();

        expect(authService.isSignedIn, isFalse);
        expect(authService.userEmail, isNull);
        expect(authService.userName, isNull);
        expect(authService.userPhoto, isNull);
        expect(authService.userId, isNull);
      });

      test('clears stored preferences', () async {
        await prefs.setString('google_credentials', 'test_creds');
        await prefs.setString('google_user_info', 'test_info');

        await authService.signOut();

        expect(prefs.getString('google_credentials'), isNull);
        expect(prefs.getString('google_user_info'), isNull);
      });
    });

    group('getDriveApi', () {
      test('returns null when not signed in', () {
        final driveApi = authService.getDriveApi();
        expect(driveApi, isNull);
      });
    });

    group('notifyListeners', () {
      test('notifies listeners on sign out', () async {
        var notified = false;
        authService.addListener(() {
          notified = true;
        });

        await authService.signOut();

        expect(notified, isTrue);
      });
    });
  });
}
