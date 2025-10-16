import 'package:arise/home_screen.dart';
import 'package:arise/admin_dashboard.dart';
import 'package:arise/trainer_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // ✅ Regex for stricter email validation
  final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  // 🔹 Google Sign-In (use Web Client ID)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        "814375922264-ep3j6ckbdotdldleohfckr1bn8flcs4h.apps.googleusercontent.com",
  );

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final uid = userCredential.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        Fluttertoast.showToast(
          msg: "No user record found in Firestore ❌",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        // It's good practice to sign out if the Firestore record is missing
        await FirebaseAuth.instance.signOut();
        return;
      }

      final role = doc['role'] ?? 'user';

      Fluttertoast.showToast(
        msg: "Login Successful 🎉 ($role)",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      Widget targetScreen;
      switch (role) {
        case 'admin':
          targetScreen = const AdminDashboard();
          break;
        case 'trainer':
          targetScreen = const TrainerDashboard();
          break;
        default:
          targetScreen = const HomeScreen();
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => targetScreen),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential': // Catches both wrong email and password in newer SDKs
          errorMessage = "Invalid email or password.";
          break;
        case 'wrong-password':
          errorMessage = "Invalid password.";
          break;
        default:
          errorMessage = e.message ?? "Login failed.";
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Unexpected error: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔹 Google Sign-In Function
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // user cancelled
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        // For login, it's better to check if a user exists first
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!doc.exists) {
          // If they don't exist from a previous Google sign-up, create them
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'username': user.displayName ?? "Google User",
                'email': user.email,
                'role': 'user',
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }

        Fluttertoast.showToast(
          msg: "Google Sign-In Successful 🎉",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Google Sign-In Failed: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ Helper function updated to accept autovalidateMode
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    required String? Function(String?) validator,
    AutovalidateMode? autovalidateMode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        // ✅ Apply the autovalidateMode
        autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.black],
            ),
          ),
          child: ListView(
            children: [
              // 🔹 Top Image & Logo
              SizedBox(
                height: 280,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/gym.jpg', fit: BoxFit.cover),
                    Container(color: Colors.black.withOpacity(0.4)),
                    const Center(
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 🔹 Login Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ✅ Email field with instant validation
                    _buildTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        // ✅ Use the improved regex for validation
                        if (value == null ||
                            value.isEmpty ||
                            !_emailRegex.hasMatch(value)) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    // ✅ Password field with instant validation
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      icon: Icons.lock,
                      obscureText: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Password is required";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 🔹 Login Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  238,
                                  255,
                                  65,
                                  1,
                                ),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                "Login",
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Google Sign-in Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      FaIcon(
                        FontAwesomeIcons.google,
                        size: 30,
                        color: Colors.red,
                      ),
                      SizedBox(width: 20),
                      Text(
                        "Continue with Google",
                        style: TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 🔹 Register Redirect
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text.rich(
                    TextSpan(
                      text: "Don’t have an account? ",
                      style: TextStyle(color: Colors.white70),
                      children: [
                        TextSpan(
                          text: "Register",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
