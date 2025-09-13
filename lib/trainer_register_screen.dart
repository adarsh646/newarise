import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();

  File? _profileImage;
  File? _certificateFile;

  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

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
      Fluttertoast.showToast(
        msg: "Upload failed: $e",
        backgroundColor: Colors.red,
      );
      return null;
    }
  }

  Future<void> _submitTrainerApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileImage == null) {
      Fluttertoast.showToast(msg: "Please upload a profile image");
      return;
    }
    if (_certificateFile == null) {
      Fluttertoast.showToast(msg: "Please upload a certificate");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔹 Upload profile image
      final profileUrl = await _uploadFile(
        _profileImage!,
        "trainers/profile_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      // 🔹 Upload certificate
      final certUrl = await _uploadFile(
        _certificateFile!,
        "trainers/certificate_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );

      // 🔹 Save to Firestore "users"
      await FirebaseFirestore.instance.collection("users").add({
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "qualification": _qualificationController.text.trim(),
        "experience": _experienceController.text.trim(),
        "role": "trainer",
        "status": "pending", // admin will approve/reject
        "profileImage": profileUrl,
        "certificateUrl": certUrl,
        "createdAt": FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(
        msg: "Application Submitted ✅ Awaiting Admin Approval",
        backgroundColor: Colors.green,
      );

      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error submitting application: $e",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Registration"),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 🔹 Profile Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : null,
                  child: _profileImage == null
                      ? const Icon(Icons.camera_alt, size: 40)
                      : null,
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
                validator: (v) =>
                    v == null || !v.contains("@") ? "Enter valid email" : null,
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
                validator: (v) =>
                    v == null || v.isEmpty ? "Enter experience" : null,
              ),
              const SizedBox(height: 20),

              // 🔹 Certificate Upload
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
