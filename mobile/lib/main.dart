import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  // Required before Firebase initialization
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SpeakWiseApp());
}

class SpeakWiseApp extends StatelessWidget {
  const SpeakWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          title: 'SpeakWise',

          // Light theme
          theme: AppTheme.lightTheme,

          // Dark theme
          darkTheme: AppTheme.darkTheme,

          // Controlled by ThemeController
          themeMode: themeMode,

          // Start with Splash Screen
          home: const SplashScreen(),
        );
      },
    );
  }
}
