import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  static const String appName = 'MixTerm';

  /// The running build's version, as reported by the packaged metadata.
  ///
  /// Deliberately not a literal. This constant sat at `1.0.0` while
  /// `pubspec.yaml`, the macOS bundle and the git tag had all moved on, so
  /// Settings showed a version that had not shipped for two releases — and
  /// nothing failed, because a stale string is still a valid string. The
  /// same mistake had already been made in `snap/snapcraft.yaml`, which
  /// shipped 1.1.0 labelled 1.0.0.
  ///
  /// Reading it from the platform means there is exactly one place a
  /// version is written down — `pubspec.yaml` — and every packaging format
  /// derives from it.
  static String appVersion = unknownVersion;

  /// Shown when the platform metadata cannot be read: a widget test, or a
  /// build run before [loadVersion]. Says "not known" rather than naming a
  /// version that might be wrong.
  static const String unknownVersion = 'unknown';

  /// Reads the version out of the running package. Call once, before
  /// `runApp`; failure is not fatal, since a missing version in an About
  /// box is not a reason to refuse to start.
  static Future<void> loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isEmpty) return;
      appVersion = info.buildNumber.isEmpty
          ? info.version
          : '${info.version} (${info.buildNumber})';
    } catch (_) {
      // Leave [unknownVersion] in place.
    }
  }

  static const int defaultPort = 22;
  static const int connectionTimeout = 30;

  /// Interval at which dartssh2's [SSHClient] sends a
  /// `keepalive@openssh.com` global request to keep idle SSH/SFTP
  /// connections alive through NATs/firewalls that drop quiet sockets.
  static const int sshKeepAliveIntervalSeconds = 15;

  static const int minFontSize = 8;
  static const int maxFontSize = 32;
  static const int defaultFontSize = 14;

  /// Terminal typefaces offered in Settings, in the order they appear.
  ///
  /// All are monospaced and ship under an open licence (see
  /// `assets/fonts/LICENSES/`). The list leads with the two that hold up
  /// best at small sizes over long sessions, which is what a terminal font
  /// is actually judged on.
  static const List<String> fontFamilies = [
    'System',
    'JetBrainsMono',
    'GeistMono',
    'IBMPlexMono',
    'FiraCode',
    'SourceCodePro',
    'CascadiaMono',
    'UbuntuSansMono',
    'UbuntuMono',
  ];

  /// Human-readable names for [fontFamilies]. Kept separate from the family
  /// identifiers because those have to match `pubspec.yaml` exactly.
  static const Map<String, String> fontDisplayNames = {
    'System': 'System default',
    'JetBrainsMono': 'JetBrains Mono',
    'GeistMono': 'Geist Mono',
    'IBMPlexMono': 'IBM Plex Mono',
    'FiraCode': 'Fira Code',
    'SourceCodePro': 'Source Code Pro',
    'CascadiaMono': 'Cascadia Mono',
    'UbuntuSansMono': 'Ubuntu Sans Mono',
    'UbuntuMono': 'Ubuntu Mono',
  };

  static const List<String> fontWeights = [
    'Extra Light',
    'Light',
    'Normal',
    'Medium',
    'Bold',
  ];

  static const int minScrollbackLines = 1000;
  static const int maxScrollbackLines = 100000;
  static const int defaultScrollbackLines = 10000;
}
