import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'manage_predefined_plans_page.dart';

class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({super.key});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _weeksController = TextEditingController(text: '4');

  final ImagePicker _picker = ImagePicker();
  File? _coverFile;
  bool _saving = false;

  final List<String> _tags = ['Cardio', 'Strength', 'Warmup', 'Stretching'];
  final Set<String> _selectedTags = {};
  final List<String> _sections = ['Get fitter', 'Lose fat', 'Gain strength'];
  String _selectedSection = 'Get fitter';

  // Workouts grouped by category
  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _workoutsByCat = {
    'Cardio': [],
    'Strength': [],
    'Warmup': [],
    'Stretching': [],
  };
  final Set<String> _selectedWorkoutIds = {};

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final snap = await FirebaseFirestore.instance.collection('workouts').get();
    final byCat = {
      'Cardio': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      'Strength': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      'Warmup': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      'Stretching': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    };
    for (final doc in snap.docs) {
      final data = doc.data();
      final cat = (data['category'] ?? '').toString();
      if (byCat.containsKey(cat)) {
        byCat[cat]!.add(doc);
      }
    }
    if (mounted) setState(() => _workoutsByCat = byCat);
  }

  Future<void> _pickCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _coverFile = File(picked.path));
  }

  Future<String?> _uploadCover(File? file) async {
    if (file == null) return null;
    try {
      final name = 'plan_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final uid = FirebaseAuth.instance.currentUser?.uid;
      // Ensure path matches Storage rules: plan_covers/{userId}/{filename}
      final path = (uid != null && uid.isNotEmpty)
          ? 'plan_covers/$uid/$name'
          : 'plan_covers/unknown/$name';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload cover: $e')),
      );
      return null;
    }
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkoutIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one workout')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final weeks = int.tryParse(_weeksController.text.trim()) ?? 4;
      final coverUrl = await _uploadCover(_coverFile);

      // Fetch selected workouts to build simple exercises list
      final selectedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      _workoutsByCat.forEach((_, docs) {
        selectedDocs.addAll(docs.where((d) => _selectedWorkoutIds.contains(d.id)));
      });

      final exercises = selectedDocs.map((d) {
        final data = d.data();
        return {
          'name': data['name'] ?? 'Exercise',
          'sourceWorkoutId': d.id,
          'category': data['category'] ?? '',
          'sets': data['sets'] ?? '',
          'reps': data['reps'] ?? '',
        };
      }).toList();

      final planPayload = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'tags': _selectedTags.toList(),
        'imageUrl': coverUrl,
        'section': _selectedSection,
        'createdAt': FieldValue.serverTimestamp(),
        'plan': {
          'weeks': weeks,
          'daysPerWeek': 3,
          'sessionDuration': 45,
          'days': [
            {
              'title': 'Day 1',
              'exercises': exercises,
            },
          ],
        },
        'input': {
          'plan_duration_weeks': weeks,
          'schedule': {
            'days_per_week': 3,
            'session_duration': 45,
          },
        },
        'source': 'admin_predefined',
      };

      await FirebaseFirestore.instance.collection('predefined_plans').add(planPayload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan created successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save plan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _weeksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Fitness Plan'),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Plan Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a title'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _pickCover,
                      icon: const Icon(Icons.image),
                      label: const Text('Cover'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_coverFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_coverFile!, height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedSection,
                items: _sections
                    .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSection = v ?? _selectedSection),
                decoration: const InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weeksController,
                decoration: const InputDecoration(
                  labelText: 'Duration (weeks)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _tags.map((t) {
                  final selected = _selectedTags.contains(t);
                  return FilterChip(
                    label: Text(t),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTags.add(t);
                        } else {
                          _selectedTags.remove(t);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Select Workouts', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._workoutsByCat.entries.map((entry) {
                final cat = entry.key;
                final docs = entry.value;
                if (docs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(cat, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    ...docs.map((d) {
                      final data = d.data();
                      final checked = _selectedWorkoutIds.contains(d.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedWorkoutIds.add(d.id);
                            } else {
                              _selectedWorkoutIds.remove(d.id);
                            }
                          });
                        },
                        title: Text(data['name'] ?? 'Workout'),
                        subtitle: Text((data['muscleGroup'] ?? data['tools'] ?? '').toString()),
                      );
                    }).toList(),
                    const Divider(height: 24),
                  ],
                );
              }).toList(),
              const SizedBox(height: 12),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _savePlan,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Plan'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color.fromARGB(255, 238, 255, 65),
                            foregroundColor: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManagePredefinedPlansPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.list_alt),
                          label: const Text('View Existing Plans'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
