import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'providers/server_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/tab_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

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
      ],
      child: const MixTermApp(),
    ),
  );
}
