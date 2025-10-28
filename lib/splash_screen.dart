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
      try {
        final user = FirebaseAuth.instance.currentUser;
        debugPrint('Splash: Current user = $user');

        if (user == null) {
          if (!mounted) return;
          debugPrint('Splash: No user, navigating to login');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        }

        try {
          debugPrint('Splash: Fetching user role for ${user.uid}');
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final role = doc.data()?['role'] ?? 'user';
          debugPrint('Splash: User role = $role');

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
          debugPrint('Splash: Navigating to ${target.runtimeType}');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => target),
          );
        } catch (e) {
          debugPrint('Splash: Error fetching user role: $e');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } catch (e) {
        debugPrint('Splash: Unexpected error in initState: $e');
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
          // Background with error handling
          Container(
            color: const Color(0xFF1a1a2e),
            child: Image.asset(
              'assets/splash.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Failed to load splash image: $error');
                return Container(color: const Color(0xFF1a1a2e));
              },
            ),
          ),

          // Dark overlay for better text contrast
          Container(color: Colors.black.withOpacity(0.3)),

          // Centered content
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo with error handling
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/Logo.png',
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Failed to load logo: $error');
                      return Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 238, 255, 65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
