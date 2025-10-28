import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Step 1: Import the package

class ManageTrainersScreen extends StatelessWidget {
  const ManageTrainersScreen({super.key});

  Future<void> _updateStatus(BuildContext context, String docId, String status) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(docId).update({
        "status": status,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trainer ${status == 'approved' ? 'approved' : 'rejected'}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteTrainer(BuildContext context, String docId, String? name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trainer Request?'),
        content: Text('This will permanently remove ${name ?? 'this trainer'}\'s request.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection("users").doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trainer request deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  // ✅ Step 2: Rework the function to launch the URL
  Future<void> _viewCertificate(
    BuildContext context,
    String certificateUrl,
  ) async {
    final Uri uri = Uri.parse(certificateUrl);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open the certificate at $certificateUrl'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The main dashboard provides the AppBar, so this one can be removed
      // to avoid a double AppBar. If this screen is ever pushed independently,
      // you can add it back.
      // appBar: AppBar(
      //   title: const Text("Manage Trainer Requests"),
      //   backgroundColor: Colors.black,
      // ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .where("role", isEqualTo: "trainer")
            .where("status", isEqualTo: "pending")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading trainers"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No new trainer requests found"));
          }

          final trainers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: trainers.length,
            itemBuilder: (context, index) {
              final trainer = trainers[index];
              final data = trainer.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: data["profileImage"] != null
                        ? NetworkImage(data["profileImage"])
                        : null,
                    child: data["profileImage"] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(data["name"] ?? "Unknown"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Email: ${data["email"] ?? ""}"),
                      Text("Qualification: ${data["qualification"] ?? ""}"),
                      Text("Experience: ${data["experience"] ?? ""}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _updateStatus(context, trainer.id, "approved"),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _updateStatus(context, trainer.id, "rejected"),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          if (data["certificateUrl"] != null) {
                            _viewCertificate(context, data["certificateUrl"]);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        onPressed: () => _deleteTrainer(context, trainer.id, data["name"]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
