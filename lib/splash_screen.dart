import 'package:arise/login_screen.dart';
import 'package:arise/admin_dashboard.dart';
import 'package:arise/trainer_dashboard.dart';
import 'package:arise/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final role = doc.data()?['role'] ?? 'user';
        Widget target;
        switch (role) {
          case 'admin':
            target = const AdminDashboard();
            break;
          case 'trainer':
            target = const TrainerDashboard();
            break;
          default:
            target = const HomeScreen();
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => target),
        );
      } catch (_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background cloudy image
          Image.asset(
            'assets/splash.jpeg', // <-- replace with your cloudy background image
            fit: BoxFit.cover,
          ),

          // Dark overlay for better text contrast
          Container(color: Colors.black.withOpacity(0.3)),

          // Centered content
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/Logo.png', height: 120),
                ),
                const SizedBox(height: 20),

                // App Name
                const Text(
                  'ARISE',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Color.fromARGB(255, 238, 255, 65),
                  ),
                ),

                const SizedBox(height: 40),

                // Loading Indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 238, 255, 65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
