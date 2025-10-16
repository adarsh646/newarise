import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyConfigScreen extends StatefulWidget {
  const SurveyConfigScreen({super.key});

  @override
  State<SurveyConfigScreen> createState() => _SurveyConfigScreenState();
}

class _SurveyConfigScreenState extends State<SurveyConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newGoalController = TextEditingController();
  final TextEditingController _newActivityController = TextEditingController();

  CollectionReference<Map<String, dynamic>> get _configRef =>
      FirebaseFirestore.instance.collection('survey_config');

  Future<void> _addItem(String docId, String field, String value) async {
    final doc = _configRef.doc(docId);
    await doc.set({
      field: FieldValue.arrayUnion([value.trim()]),
    }, SetOptions(merge: true));
  }

  Future<void> _removeItem(String docId, String field, String value) async {
    final doc = _configRef.doc(docId);
    await doc.set({
      field: FieldValue.arrayRemove([value]),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _newGoalController.dispose();
    _newActivityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Configuration'),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _configRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load config'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = {for (var d in snapshot.data!.docs) d.id: d.data()};
          final List goals = (docs['goals']?['values'] as List?) ?? const [];
          final List activity =
              (docs['activity_levels']?['values'] as List?) ?? const [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fitness Goals',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in goals)
                      Chip(
                        label: Text(g.toString()),
                        onDeleted: () =>
                            _removeItem('goals', 'values', g.toString()),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newGoalController,
                          decoration: const InputDecoration(
                            labelText: 'Add new goal',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter a goal'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            await _addItem(
                              'goals',
                              'values',
                              _newGoalController.text,
                            );
                            _newGoalController.clear();
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Activity Levels',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in activity)
                      Chip(
                        label: Text(a.toString()),
                        onDeleted: () => _removeItem(
                          'activity_levels',
                          'values',
                          a.toString(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _newActivityController,
                        decoration: const InputDecoration(
                          labelText: 'Add new activity level',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final text = _newActivityController.text.trim();
                        if (text.isNotEmpty) {
                          await _addItem('activity_levels', 'values', text);
                          _newActivityController.clear();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

