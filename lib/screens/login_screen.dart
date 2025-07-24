import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String _authStatus = 'Please authenticate to continue.';

  Future<void> _authenticate() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Use fingerprint or face to unlock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _authStatus = 'Authentication failed';
        });
      }
    } catch (e) {
      setState(() {
        _authStatus = 'Biometric unavailable';
      });
    }
  }

  @override
  void initState() {
    super.initState(); // Check biometric capabilities
    _authenticate(); // Automatically try when screen loads
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_authStatus, style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text('Retry Biometric Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
