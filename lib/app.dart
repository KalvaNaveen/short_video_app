import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReelRush',
      theme: ThemeData(
  primaryColor: const Color(0xFFE63946),
  colorScheme: ColorScheme.fromSwatch().copyWith(
    secondary: const Color(0xFFF3722C),
  ),
  scaffoldBackgroundColor: const Color(0xFFF4F4F9),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF264653)),
    bodyMedium: TextStyle(color: Color(0xFF264653)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFE63946),
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFFF3722C),
      foregroundColor: Colors.white,
    ),
  ),
),

      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
