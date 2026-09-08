import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'app.dart';
import 'utils/constants.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'providers/server_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/tab_provider.dart';
import 'providers/transfer_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// The bundled typefaces and the licence each one ships under.
///
/// The OFL requires the licence to accompany the font wherever it is
/// distributed, and these are compiled into the binary — so registering them
/// here is what actually satisfies it. It also means they show up in the
/// app's own licence page instead of sitting in a folder nobody opens.
const _fontLicences = <String, List<String>>{
  'assets/fonts/LICENSES/Inter-OFL.txt': ['Inter'],
  'assets/fonts/LICENSES/JetBrainsMono-OFL.txt': ['JetBrains Mono'],
  'assets/fonts/LICENSES/FiraCode-OFL.txt': ['Fira Code'],
  'assets/fonts/LICENSES/SourceCodePro-OFL.txt': ['Source Code Pro'],
  'assets/fonts/LICENSES/GeistMono-OFL.txt': ['Geist Mono'],
  'assets/fonts/LICENSES/IBMPlexMono-OFL.txt': ['IBM Plex Mono'],
  'assets/fonts/LICENSES/CascadiaMono-OFL.txt': ['Cascadia Mono'],
  'assets/fonts/LICENSES/UbuntuMono-LICENCE.txt': [
    'Ubuntu Mono',
    'Ubuntu Sans Mono',
  ],
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    for (final entry in _fontLicences.entries) {
      yield LicenseEntryWithLineBreaks(
        entry.value,
        await rootBundle.loadString(entry.key),
      );
    }
  });

  await AppConstants.loadVersion();

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);
  // Note: storage.init() is called in AppWrapper to properly sequence with auth

  final authService = AuthService();
  final syncService = SyncService(authService, storageService);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<AuthService>(create: (_) => authService),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(storageService),
        ),
        ChangeNotifierProvider<ServerProvider>(
          create: (_) => ServerProvider(storageService, syncService),
        ),
        ChangeNotifierProvider<ConnectionProvider>(
          create: (_) => ConnectionProvider(),
        ),
        ChangeNotifierProvider<TabProvider>(
          create: (_) => TabProvider(),
        ),
        ChangeNotifierProvider<TransferProvider>(
          create: (_) => TransferProvider(),
        ),
      ],
      child: const MixTermApp(),
    ),
  );
}
