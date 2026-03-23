import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MotorGuardianApp());
}

class MotorGuardianApp extends StatelessWidget {
  const MotorGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppBrand.appName,
      theme: AppTheme.build(),
      home: const SplashScreen(),
    );
  }
}
