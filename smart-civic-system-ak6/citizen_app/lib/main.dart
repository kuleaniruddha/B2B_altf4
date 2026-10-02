import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/mpin_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_issue_screen.dart';
import 'screens/track_screen.dart';
import 'screens/my_issues_screen.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Adding a timeout to Firebase init to prevent full app hang if something is blocked
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    print("Firebase init error: $e");
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: const SmartCivicApp(),
    ),
  );
}

class SmartCivicApp extends StatelessWidget {
  const SmartCivicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Civic Mumbai',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/':           (context) => const SplashScreen(),
        '/login':      (context) => const LoginScreen(),
        '/signup':     (context) => const SignupScreen(),
        '/mpin-setup': (context) => const MpinSetupScreen(),
        '/home':       (context) => const HomeScreen(),
        '/report':     (context) => const ReportIssueScreen(),
        '/track':      (context) => const TrackScreen(),
        '/myIssues':   (context) => const MyIssuesScreen(),
        '/map':        (context) => const MapScreen(),
      },
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}