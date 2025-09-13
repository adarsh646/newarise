import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // Required for opening links

class AllTrainersScreen extends StatefulWidget {
  const AllTrainersScreen({super.key});

  @override
  State<AllTrainersScreen> createState() => _AllTrainersScreenState();
}

class _AllTrainersScreenState extends State<AllTrainersScreen> {
  // Function to launch the certificate URL in a browser
  Future<void> _viewCertificate(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  Future<void> _deleteTrainer(String docId, String trainerName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to permanently delete $trainerName? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$trainerName has been deleted.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete trainer: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'trainer')
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Something went wrong. Check Firestore indexes.'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No approved trainers found.'));
          }

          final trainers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: trainers.length,
            itemBuilder: (context, index) {
              final trainer = trainers[index];
              final data = trainer.data() as Map<String, dynamic>;

              final name = data['name'] ?? 'No Name';
              final email = data['email'] ?? 'No Email';
              final qualification = data['qualification'] ?? 'N/A';
              final fee = data['fee'] ?? '0';
              final certificateUrl = data['certificateUrl'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      // ✅ TYPO REMOVED FROM THIS LINE
                      backgroundImage: data['profileImage'] != null
                          ? NetworkImage(data['profileImage'])
                          : null,
                      child: data['profileImage'] == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(email),
                        const SizedBox(height: 2),
                        Text('Qualification: $qualification'),
                        const SizedBox(height: 2),
                        Text('Fee: ₹$fee / month'),
                        const SizedBox(height: 8),
                        if (certificateUrl != null)
                          SizedBox(
                            height: 30,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf, size: 16),
                              label: const Text('View Certificate'),
                              onPressed: () => _viewCertificate(certificateUrl),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteTrainer(trainer.id, name),
                    ),
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
