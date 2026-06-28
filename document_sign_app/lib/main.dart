import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Додано імпорт Firebase

import 'core/services/notification_service.dart'; // Додано імпорт сервісу повідомлень
import 'core/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';

// Додано async, оскільки ініціалізація Firebase потребує await
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ініціалізація Firebase та сповіщень
  try {
    await Firebase.initializeApp();
    await NotificationService.init();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocSign',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
