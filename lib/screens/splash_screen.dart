import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/home');
    });
  }
  @override
  Widget build(BuildContext context) {
    // Wait 2 seconds, then move to login
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/home');
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, size: 80, color: Colors.redAccent),
            SizedBox(height: 20),
            Text(
  'ReelRush',
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
),
         SizedBox(height: 8),
    Text(
      'Rush In. Reel Out.',
      style: TextStyle(
        fontSize: 16,
        fontStyle: FontStyle.italic,
        color: Colors.grey[600],
      ),
    ),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
