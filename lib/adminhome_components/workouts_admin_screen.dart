import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutsAdminScreen extends StatelessWidget {
  const WorkoutsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Workouts'),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workouts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load workouts'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No workouts found'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              return ListTile(
                title: Text(data['name'] ?? 'Unnamed'),
                subtitle: Text(
                  '${data['category'] ?? 'Unknown'} • ${data['trainerName'] ?? ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (_) =>
                              _EditWorkoutDialog(id: id, initialData: data),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('workouts')
                            .doc(id)
                            .delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Workout deleted')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => const _EditWorkoutDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EditWorkoutDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? initialData;
  const _EditWorkoutDialog({this.id, this.initialData});

  @override
  State<_EditWorkoutDialog> createState() => _EditWorkoutDialogState();
}

class _EditWorkoutDialogState extends State<_EditWorkoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _tools;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialData?['name'] ?? '');
    _category = TextEditingController(
      text: widget.initialData?['category'] ?? '',
    );
    _tools = TextEditingController(text: widget.initialData?['tools'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _tools.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'name': _name.text.trim(),
      'category': _category.text.trim(),
      'tools': _tools.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final ref = FirebaseFirestore.instance.collection('workouts');
    if (widget.id == null) {
      await ref.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await ref.doc(widget.id).set(data, SetOptions(merge: true));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.id == null ? 'Add Workout' : 'Edit Workout'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(
                labelText: 'Category (Strength/Cardio/Stretching/Warmup)',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter category' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tools,
              decoration: const InputDecoration(labelText: 'Tools'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

