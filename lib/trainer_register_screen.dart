import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import 'package:file_picker/file_picker.dart';

class TrainerRegisterScreen extends StatefulWidget {
  const TrainerRegisterScreen({super.key});

  @override
  State<TrainerRegisterScreen> createState() => _TrainerRegisterScreenState();
}

class _TrainerRegisterScreenState extends State<TrainerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _profileImage;
  File? _certificateFile;

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final ImagePicker _picker = ImagePicker();

  String? _verificationId;
  int? _resendToken;
  DateTime? _codeSentAt;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Handles the entire multi-step registration flow with phone verification.
  Future<void> _submitTrainerApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileImage == null || _certificateFile == null) {
      Fluttertoast.showToast(
        msg: "Please upload a profile image and certificate",
      );
      return;
    }

    setState(() => _isLoading = true);

    User? tempAuthUser;

    try {
      // Step 1: Create the user with email/password first
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      tempAuthUser = userCredential.user;
      if (tempAuthUser == null)
        throw Exception("Failed to create user account.");

      // Step 1.5: Send email verification link
      await tempAuthUser.sendEmailVerification();

      // Step 2: Begin phone number verification
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // This is for auto-retrieval on some Android devices.
          // The loader will still be on, which is fine.
          try {
            if (tempAuthUser == null) throw Exception('User not initialized');
            await tempAuthUser.linkWithCredential(credential);
            await _uploadFilesAndSaveData(tempAuthUser.uid);
          } catch (e) {
            if (mounted) setState(() => _isLoading = false);
            rethrow;
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          // Turn off loading and show error if phone verification fails
          if (mounted) setState(() => _isLoading = false);
          Fluttertoast.showToast(
            msg: "Phone verification failed: ${e.message}",
          );
          // Rethrow to trigger the cleanup in the main catch block
          throw e;
        },
        codeSent: (String verificationId, int? resendToken) async {
          // Step 3: Turn off the loader and show the OTP pop-up dialog
          if (mounted) setState(() => _isLoading = false);
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSentAt = DateTime.now();
          String? smsCode = await _showOtpDialog();

          if (smsCode != null && smsCode.isNotEmpty) {
            // Turn the loader back on for the final processing step
            if (mounted) setState(() => _isLoading = true);

            try {
              final vid = _verificationId;
              if (vid == null) throw Exception('Verification session unavailable. Please resend the code.');
              if (_codeSentAt != null && DateTime.now().difference(_codeSentAt!).inMinutes >= 5) {
                throw Exception('The verification code expired. Please tap Resend Code and try again.');
              }
              PhoneAuthCredential credential = PhoneAuthProvider.credential(
                verificationId: vid,
                smsCode: smsCode,
              );
              // Step 4: Link the phone number to the new account
              if (tempAuthUser == null) throw Exception('User not initialized');
              await tempAuthUser.linkWithCredential(credential);

              // Step 5: If successful, proceed to upload files and save data
              await _uploadFilesAndSaveData(tempAuthUser.uid);
            } catch (e) {
              // Rollback partially created user if linking/upload fails
              try {
                await tempAuthUser?.delete();
              } catch (_) {}
              Fluttertoast.showToast(
                msg: 'Verification failed: $e',
                backgroundColor: Colors.red,
              );
              if (mounted) setState(() => _isLoading = false);
            }
          } else {
            // User cancelled the dialog
            Fluttertoast.showToast(msg: 'OTP verification cancelled.');
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      // Critical Cleanup Step: If anything fails, delete the partially created user
      if (tempAuthUser != null) {
        await tempAuthUser.delete();
        print("Cleaned up partially created user account.");
      }

      String errorMessage = "An error occurred. Please try again.";
      if (e is FirebaseAuthException) {
        if (e.code == 'invalid-phone-number') {
          errorMessage = 'The phone number provided is not valid.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'An account already exists for that email.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      } else if (e is Exception) {
        errorMessage = e.toString().replaceFirst("Exception: ", "");
      }

      Fluttertoast.showToast(msg: errorMessage, backgroundColor: Colors.red);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Contains the logic for file uploads and saving data to Firestore.
  Future<void> _uploadFilesAndSaveData(String uid) async {
    try {
      final profileUrl = await _uploadFile(
        _profileImage!,
        "trainers/$uid/profile.jpg",
      );
      final certUrl = await _uploadFile(
        _certificateFile!,
        "trainers/$uid/certificate.pdf",
      );

      if (profileUrl == null || certUrl == null) {
        throw Exception("File upload failed.");
      }

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "phoneNumber": _phoneController.text.trim(),
        "qualification": _qualificationController.text.trim(),
        "experience": _experienceController.text.trim(),
        "role": "trainer",
        "status": "pending",
        "profileImage": profileUrl,
        "certificateUrl": certUrl,
        "createdAt": FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(
        msg: "Application Submitted! Awaiting admin approval.",
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_LONG,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows the pop-up dialog for OTP entry.
  Future<String?> _showOtpDialog() {
    final otpController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Verification Code"),
          content: TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: "6-digit code"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null), // Cancel
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(otpController.text.trim());
              },
              child: const Text("Verify"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  Future<void> _pickCertificate() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _certificateFile = File(result.files.single.path!));
    }
  }

  Future<String?> _uploadFile(File file, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      Fluttertoast.showToast(msg: "Upload failed: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Registration"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  child: _profileImage == null
                      ? Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Colors.grey[800],
                        )
                      : ClipOval(
                          child: Image.file(
                            _profileImage!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
                validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || !v.contains("@") ? "Enter valid email" : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone Number (e.g., +16505551234)",
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty || !v.startsWith('+')
                    ? "Enter a valid phone number with country code"
                    : null,
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                ),
                validator: (v) => v == null || v.length < 6
                    ? "Password must be at least 6 characters"
                    : null,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                ),
                validator: (v) => v != _passwordController.text
                    ? "Passwords do not match"
                    : null,
              ),
              TextFormField(
                controller: _qualificationController,
                decoration: const InputDecoration(labelText: "Qualification"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Enter qualification" : null,
              ),
              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(
                  labelText: "Experience (years)",
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? "Enter experience" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickCertificate,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _certificateFile == null
                      ? "Upload Certificate"
                      : "Certificate Selected",
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitTrainerApplication,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text("Submit Application"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
