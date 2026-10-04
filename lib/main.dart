import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_manager.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlucoBuildApp());
}

class FlucoBuildApp extends StatefulWidget {
  const FlucoBuildApp({super.key});

  @override
  State<FlucoBuildApp> createState() => _FlucoBuildAppState();
}

class _FlucoBuildAppState extends State<FlucoBuildApp> {
  final _authManager = AuthManager();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _authManager.initialize().then((_) {
      if (mounted) setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _authManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluco Build',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: !_initialized
          ? const _SplashScreen()
          : AnimatedBuilder(
              animation: _authManager,
              builder: (context, _) {
                return _authManager.status == AuthStatus.loggedIn
                    ? HomeScreen(authManager: _authManager)
                    : LoginScreen(authManager: _authManager);
              },
            ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
    );
  }
}