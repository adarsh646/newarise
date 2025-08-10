import 'package:arise/login_screen.dart';
import 'package:flutter/material.dart';
import 'register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/splash.jpeg',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Text(
              'Arise',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFCCFF00),
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}