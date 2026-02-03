import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/tab_provider.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'utils/theme.dart';

class MixTermApp extends StatelessWidget {
  const MixTermApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'MixTerm',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          home: const AppWrapper(),
        );
      },
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> with WidgetsBindingObserver {
  bool _isLoading = true;
  ConnectionProvider? _connectionProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the provider reference for cleanup
    _connectionProvider ??= context.read<ConnectionProvider>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupConnections();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is being terminated
      _cleanupConnections();
    }
  }

  void _cleanupConnections() {
    // Close all SSH/SFTP connections when app closes
    _connectionProvider?.dispose();
  }

  Future<void> _initApp() async {
    final storage = context.read<StorageService>();
    final auth = context.read<AuthService>();

    // Initialize storage (this sets up device-based encryption)
    await storage.init();

    // Initialize auth service
    await auth.init();

    // If user was previously signed in with Google, re-init encryption with Google ID
    if (auth.isSignedIn && auth.userId != null) {
      await storage.initWithGoogleId(auth.userId!);
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return const HomeScreen();
  }
}
