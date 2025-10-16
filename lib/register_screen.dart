import 'dart:async'; // Import for Timer (debouncer)
import 'package:arise/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'trainer_register_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  // State for live email validation
  Timer? _debounce;
  String? _emailErrorText;
  bool _isCheckingEmail = false;

  // ✅ NEW: Regex for stricter email validation
  final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        "814375922264-ep3j6ckbdotdldleohfckr1bn8flcs4h.apps.googleusercontent.com",
  );

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    // ✅ NEW: Listener to re-validate confirm password when password changes
    _passwordController.addListener(() {
      if (_confirmPasswordController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
  }

  void _onEmailChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _checkEmailAvailability();
    });
  }

  Future<void> _checkEmailAvailability() async {
    final email = _emailController.text.trim();
    // ✅ MODIFIED: Use the regex for the initial check
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      setState(() {
        _emailErrorText = null;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
    });

    try {
      final collection = FirebaseFirestore.instance.collection('users');
      final querySnapshot = await collection
          .where('email', isEqualTo: email)
          .get();

      if (mounted) {
        setState(() {
          if (querySnapshot.docs.isNotEmpty) {
            _emailErrorText = "This email is already in use.";
          } else {
            _emailErrorText = null;
          }
        });
      }
    } catch (e) {
      print("Error checking email: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _emailErrorText != null) {
      Fluttertoast.showToast(msg: "Please fix the errors before proceeding.");
      return;
    }
    setState(() => _isLoading = true);
    // ... rest of the register function is the same
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });

      Fluttertoast.showToast(
        msg: "Registration Successful 🎉",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = "This email is already registered.";
          break;
        case 'invalid-email':
          errorMessage = "The email address is invalid.";
          break;
        case 'weak-password':
          errorMessage = "Password should be at least 6 characters.";
          break;
        default:
          errorMessage = e.message ?? "Registration failed.";
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

  Future<void> _signInWithGoogle() async {
    // ... Google Sign-In function is the same
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': user.displayName ?? "Google User",
          'email': user.email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        Fluttertoast.showToast(
          msg: "Google Sign-In Successful 🎉",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Google Sign-In Failed: ${e.toString()}",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _passwordController.dispose(); // ✅ Clean up new listener
    _debounce?.cancel();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    required String? Function(String?) validator,
    AutovalidateMode? autovalidateMode,
    String? errorText,
    Widget? suffixIcon,
  }) {
    // ... this helper function is the same
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          errorText: errorText,
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
              // ... Top Image & Logo ...
              SizedBox(
                height: 300,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/gym.jpg', fit: BoxFit.cover),
                    Container(color: Colors.black.withOpacity(0.4)),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/Logo.png', width: 90),
                          const SizedBox(height: 10),
                          const Text(
                            'Fitness',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      errorText: _emailErrorText,
                      suffixIcon: _isCheckingEmail
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                height: 10,
                                width: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : (_emailErrorText == null &&
                                _emailController.text.isNotEmpty &&
                                _emailRegex.hasMatch(_emailController.text))
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      validator: (value) {
                        // ✅ MODIFIED: Using regex for validation
                        if (value == null ||
                            value.isEmpty ||
                            !_emailRegex.hasMatch(value)) {
                          return "Enter a valid email (e.g., name@example.com)";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _usernameController,
                      label: "Username",
                      icon: Icons.person,
                      // ✅ MODIFIED: Added instant validation
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.length < 3) {
                          return "Username must be at least 3 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      icon: Icons.lock,
                      obscureText: true,
                      // ✅ MODIFIED: Added instant validation
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: "Confirm Password",
                      icon: Icons.lock,
                      obscureText: true,
                      // ✅ MODIFIED: Added instant validation
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // ... Register Button and the rest of the UI ...
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _register,
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
                                "Register",
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // ... Social and other buttons ...
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
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrainerRegisterScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Register as Trainer",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text.rich(
                    TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(color: Colors.white70),
                      children: [
                        TextSpan(
                          text: "Login",
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
