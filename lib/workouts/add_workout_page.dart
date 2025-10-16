import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AddWorkoutPage extends StatefulWidget {
  final String category;
  final String? muscleGroup; // optional preselected muscle group for Strength

  const AddWorkoutPage({super.key, required this.category, this.muscleGroup});

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends State<AddWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _warningsController = TextEditingController();
  final _toolsController = TextEditingController();
  final _picker = ImagePicker();
  File? _gifFile;
  File? _videoFile;
  bool _isSaving = false;
  String? _selectedMuscleGroup;
  
  // Media validation constraints
  static const int maxGifMB = 10; // limit GIF size to 10MB
  static const int maxVideoMB = 100; // limit Video size to 100MB
  
  double _fileSizeMB(File f) => f.lengthSync() / (1024 * 1024);
  
  bool _isGif(File f) => f.path.toLowerCase().endsWith('.gif');
  bool _isVideo(File f) {
    final p = f.path.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.avi') || p.endsWith('.mkv');
  }
  
  Future<bool> _validateMediaFiles() async {
    if (_gifFile != null) {
      if (!_isGif(_gifFile!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected GIF must be a .gif file')),
          );
        }
        return false;
      }
      if (_fileSizeMB(_gifFile!) > maxGifMB) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GIF exceeds ${maxGifMB}MB limit')),
          );
        }
        return false;
      }
    }
    if (_videoFile != null) {
      if (!_isVideo(_videoFile!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video must be MP4/MOV/AVI/MKV')),
          );
        }
        return false;
      }
      if (_fileSizeMB(_videoFile!) > maxVideoMB) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video exceeds ${maxVideoMB}MB limit')),
          );
        }
        return false;
      }
    }
    return true;
  }

  static const List<String> strengthGroups = [
    'Chest', 'Back', 'Biceps', 'Triceps', 'Forearm', 'Shoulder', 'Abs', 'Leg'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _warningsController.dispose();
    _toolsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedMuscleGroup = widget.muscleGroup;
  }

  Future<void> _pickGif() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _gifFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadFile(File? file, String folderName) async {
    if (file == null) return null;
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final destination = '$folderName/$fileName';
      final ref = FirebaseStorage.instance.ref(destination);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to upload file: $e")));
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gifFile == null && _videoFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a GIF or a Video.')),
        );
      }
      return;
    }
    
    // Validate media file types and sizes
    final mediaOk = await _validateMediaFiles();
    if (!mediaOk) return;
    
    // Prevent duplicate workout name within same category (and muscle group for Strength)
    final String nameTrimmed = _nameController.text.trim();
    final String nameLower = nameTrimmed.toLowerCase();
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('workouts')
          .where('category', isEqualTo: widget.category);
      if (widget.category == 'Strength' && _selectedMuscleGroup != null) {
        q = q.where('muscleGroup', isEqualTo: _selectedMuscleGroup);
      }
      final existing = await q.get();
      final bool duplicate = existing.docs.any((d) {
        final data = d.data();
        final existingName = (data['name'] as String?)?.toLowerCase();
        final existingNameLower = (data['nameLower'] as String?);
        return (existingNameLower ?? existingName) == nameLower;
      });
      if (duplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A workout with this name already exists in this category.')),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check duplicates: $e')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? gifUrl = await _uploadFile(_gifFile, 'workout_gifs');
      String? videoUrl = await _uploadFile(_videoFile, 'workout_videos');
      final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final trainerName = userDoc.data()?['name'] ?? 'Unknown Trainer';

      final workoutData = {
        'name': nameTrimmed,
        'nameLower': nameLower,
        'instructions': _instructionsController.text.trim(),
        'warnings': _warningsController.text.trim(),
        'tools': _toolsController.text.trim(),
        'createdAt': Timestamp.now(),
        'trainerId': currentUserId,
        'trainerName': trainerName,
        'category': widget.category,
        if (widget.category == 'Strength' && _selectedMuscleGroup != null)
          'muscleGroup': _selectedMuscleGroup,
        if (gifUrl != null) 'gifUrl': gifUrl,
        if (videoUrl != null) 'videoUrl': videoUrl,
      };

      await FirebaseFirestore.instance.collection('workouts').add(workoutData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Workout Saved Successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to save workout: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add New ${widget.category} Workout" +
            (widget.muscleGroup != null ? " • ${widget.muscleGroup}" : "")),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.category == 'Strength') ...[
                  const Text(
                    'Muscle Group',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedMuscleGroup,
                    items: strengthGroups
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(g),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedMuscleGroup = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select a muscle group',
                    ),
                    validator: (val) {
                      if (widget.category == 'Strength' && (val == null || val.isEmpty)) {
                        return 'Please select a muscle group';
                      }
                      return null;
                    },
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Workout Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fitness_center),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter a workout name";
                }
                if (value.trim().length < 3) {
                  return "Name should be at least 3 characters";
                }
                if (value.trim().length > 60) {
                  return "Name should be at most 60 characters";
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickGif,
                    icon: const Icon(Icons.gif_box),
                    label: const Text("Select GIF"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.video_collection),
                    label: const Text("Select Video"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: "Instructions",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.integration_instructions),
              ),
              maxLines: 5,
              minLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide instructions';
                }
                if (value.trim().length > 1500) {
                  return 'Instructions should be at most 1500 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _warningsController,
              decoration: const InputDecoration(
                labelText: "Warnings (optional)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber),
              ),
              maxLines: 3,
              minLines: 2,
              // optional field: no validator (length implicitly unrestricted here)
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _toolsController,
              decoration: const InputDecoration(
                labelText: "Tools Used (e.g., Dumbbells, Mat)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.build),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please list tools (or write None)';
                }
                if (value.trim().length > 200) {
                  return 'Tools should be at most 200 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.save),
                        label: const Text("Save Workout"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
