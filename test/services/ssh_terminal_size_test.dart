import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/services/ssh_service.dart';

/// The remote shell draws against the width it was told at PTY allocation.
/// Get that wrong and everything still *works* — commands run, output
/// arrives — but every redraw that crosses the real edge of the window
/// lands in the wrong column. A tab completion is the most visible victim:
/// the completed text is delivered and then overwritten by a cursor moving
/// to a column that does not exist, so it reads as "tab did nothing".
///
/// Measured before the fix, with the window showing 100 columns:
///
///     PROBE_RESIZE=100x36 session=false   <- reported, then dropped
///     remote `stty size`  -> 24 80
///
/// The size arrived before the session did, and a `?.` on a null session
/// threw it away. Nothing logged, nothing failed.
void main() {
  group('terminal size bookkeeping', () {
    test('starts at the PTY default', () {
      // 80x24 because that is what a PTY gets when nobody says otherwise,
      // not because it is a reasonable guess about a window.
      expect(SSHService().terminalSize, (columns: 80, rows: 24));
    });

    test('remembers a size reported before there is a session', () {
      // This is the regression. The view lays out, reports its size, and
      // only later does a session exist to tell.
      final service = SSHService();

      service.resize(100, 36);

      expect(service.terminalSize, (columns: 100, rows: 36),
          reason: 'the size must survive until connect() can use it');
    });

    test('keeps the most recent size when several arrive before connect', () {
      final service = SSHService()
        ..resize(100, 36)
        ..resize(163, 38);

      expect(service.terminalSize, (columns: 163, rows: 38));
    });

    test('ignores a degenerate size', () {
      // A terminal reports 0x0 between construction and its first layout.
      // Passing that on would ask the remote for a zero-width window.
      final service = SSHService()..resize(120, 40);

      service.resize(0, 0);
      service.resize(-1, 30);

      expect(service.terminalSize, (columns: 120, rows: 40));
    });
  });
}
