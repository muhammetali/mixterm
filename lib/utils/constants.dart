class AppConstants {
  static const String appName = 'MixTerm';
  static const String appVersion = '1.0.0';

  static const int defaultPort = 22;
  static const int connectionTimeout = 30;

  static const int minFontSize = 8;
  static const int maxFontSize = 32;
  static const int defaultFontSize = 14;

  static const List<String> fontFamilies = [
    'System',
    'JetBrainsMono',
    'FiraCode',
    'SourceCodePro',
    'CascadiaMono',
    'UbuntuMono',
    'UbuntuSansMono',
  ];

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
