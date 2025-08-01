
// Use your real unit IDs!
// final bannerAdId = 'ca-app-pub-1318338562171737/6088592088';
// final nativeAdId = 'ca-app-pub-1318338562171737/6068410787';
// final rewardedInterstitialId = 'ca-app-pub-1318338562171737/2129165770';

// Use your TEST unit IDs!
import 'package:flutter/material.dart';
import 'package:reelrush/widgets/ad_manager.dart';
import 'package:reelrush/screens/splash_screen.dart';
import 'package:reelrush/screens/home_screen.dart';

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
            backgroundColor: const Color(0xFFF3722C),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
      },
      builder: (context, child) {
        // Add AdManager on top of everything, but inside MaterialApp
        return Stack(
          children: [
            if (child != null) child,
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AdManager(
                bannerAdUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test banner
                nativeAdUnitId: 'ca-app-pub-3940256099942544/2247696110', // Test native
                rewardedInterstitialAdUnitId: 'ca-app-pub-3940256099942544/5354046379', // Test rewarded interstitial
                bannerHeight: 50,
                // You can add a custom height for banner using bannerHeight param
              ),
            ),
          ],
        );
      },
    );
  }
}
