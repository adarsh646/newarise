import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class TrainerProfilePage extends StatefulWidget {
  const TrainerProfilePage({super.key});

  @override
  State<TrainerProfilePage> createState() => _TrainerProfilePageState();
}

class _TrainerProfilePageState extends State<TrainerProfilePage> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final _formKey = GlobalKey<FormState>();

  // ✅ Switched to TextEditingControllers for better state management
  late TextEditingController _nameController;
  late TextEditingController _feeController;

  File? _imageFile;
  final picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _feeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;
    final ref = FirebaseStorage.instance.ref().child("profile_images/$uid.jpg");
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? imageUrl = await _uploadImage();
      final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

      // ✅ FIX: Using the correct field names 'name' and 'fee'
      final updateData = {
        "name": _nameController.text.trim(),
        "fee": _feeController.text.trim(),
      };

      if (imageUrl != null) {
        updateData["profileImage"] = imageUrl;
      }

      await userRef.update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Profile"),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      // ✅ Switched to StreamBuilder for real-time UI updates after saving
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No profile data found."));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;

          // Populate controllers with data from Firestore
          _nameController.text = userData["name"] ?? "";
          _feeController.text = userData["fee"]?.toString() ?? "";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (userData["profileImage"] != null
                                    ? NetworkImage(userData["profileImage"])
                                    : null)
                                as ImageProvider<Object>?,
                      child:
                          _imageFile == null &&
                              (userData["profileImage"] == null)
                          ? const Icon(Icons.camera_alt, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ FIX: Using controller and correct field 'name'
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Enter your name" : null,
                  ),
                  const SizedBox(height: 16),

                  // ✅ FIX: Using controller and correct field 'fee'
                  TextFormField(
                    controller: _feeController,
                    decoration: const InputDecoration(
                      labelText: "Fee per Month (₹)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) =>
                        val == null || val.isEmpty ? "Enter your fee" : null,
                  ),
                  const SizedBox(height: 16),

                  // Non-editable fields remain the same
                  TextFormField(
                    initialValue: userData["qualification"] ?? "N/A",
                    decoration: const InputDecoration(
                      labelText: "Qualification (Read-only)",
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: userData["specialization"] ?? "N/A",
                    decoration: const InputDecoration(
                      labelText: "Specialization (Read-only)",
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 30),

                  _isSaving
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.save),
                          label: const Text("Save Profile"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color.fromARGB(
                              255,
                              238,
                              255,
                              65,
                            ),
                            foregroundColor: Colors.black,
                          ),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
