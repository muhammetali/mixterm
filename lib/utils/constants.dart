class AppConstants {
  static const String appName = 'MixTerm';
  static const String appVersion = '1.0.0';

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
