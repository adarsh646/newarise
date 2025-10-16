import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ManagePredefinedPlansPage extends StatelessWidget {
  const ManagePredefinedPlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Predefined Plans'),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('predefined_plans')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No plans found.'));
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = (data['title'] ?? 'Plan').toString();
              final section = (data['section'] ?? '').toString();
              final imageUrl = (data['imageUrl'] ?? '').toString();
              final weeks = ((data['plan'] ?? {})['weeks'] is int)
                  ? (data['plan']['weeks'] as int)
                  : ((data['input'] ?? {})['plan_duration_weeks'] is int)
                      ? (data['input']['plan_duration_weeks'] as int)
                      : 4;

              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover)
                        : Container(width: 56, height: 56, color: Colors.grey[200], child: const Icon(Icons.image)),
                  ),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$section • $weeks weeks'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditPredefinedPlanPage(planId: doc.id, initial: data),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete plan?'),
                                  content: const Text('This will permanently delete the plan.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                  ],
                                ),
                              ) ??
                              false;
                          if (!ok) return;
                          try {
                            // Attempt to delete Storage cover if exists
                            if (imageUrl.isNotEmpty) {
                              try {
                                await FirebaseStorage.instance.refFromURL(imageUrl).delete();
                              } catch (_) {}
                            }
                            await FirebaseFirestore.instance.collection('predefined_plans').doc(doc.id).delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Plan deleted')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPredefinedPlanPage(planId: doc.id, initial: data),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EditPredefinedPlanPage extends StatefulWidget {
  final String planId;
  final Map<String, dynamic> initial;
  const EditPredefinedPlanPage({super.key, required this.planId, required this.initial});

  @override
  State<EditPredefinedPlanPage> createState() => _EditPredefinedPlanPageState();
}

class _EditPredefinedPlanPageState extends State<EditPredefinedPlanPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _desc;
  late TextEditingController _weeks;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial['title']?.toString() ?? '');
    _desc = TextEditingController(text: widget.initial['description']?.toString() ?? '');
    final w = ((widget.initial['plan'] ?? {})['weeks'] is int)
        ? (widget.initial['plan']['weeks'] as int)
        : ((widget.initial['input'] ?? {})['plan_duration_weeks'] is int)
            ? (widget.initial['input']['plan_duration_weeks'] as int)
            : 4;
    _weeks = TextEditingController(text: w.toString());
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _weeks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final weeks = int.tryParse(_weeks.text.trim()) ?? 4;
      await FirebaseFirestore.instance.collection('predefined_plans').doc(widget.planId).update({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'plan.weeks': weeks,
        'input.plan_duration_weeks': weeks,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan updated')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Plan'),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weeks,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weeks', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color.fromARGB(255, 238, 255, 65),
                    foregroundColor: Colors.black,
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
