import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TrainerClientsPage extends StatelessWidget {
  const TrainerClientsPage({super.key});

  Future<void> _updateRequest(String clientId, String status) async {
    final trainerId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection("trainer_requests")
        .doc("$trainerId-$clientId")
        .update({"status": status});
  }

  @override
  Widget build(BuildContext context) {
    final trainerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("trainer_requests")
            .where("trainerId", isEqualTo: trainerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("An error occurred."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No client requests yet."));
          }

          final requests = snapshot.data!.docs;

          // Separate requests into different lists for a cleaner UI
          final pendingRequests = requests
              .where((doc) => doc['status'] == 'pending')
              .toList();
          final acceptedClients = requests
              .where((doc) => doc['status'] == 'accepted')
              .toList();
          final rejectedRequests = requests
              .where((doc) => doc['status'] == 'rejected')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pendingRequests.isNotEmpty) ...[
                const Text(
                  "Pending Requests",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ...pendingRequests.map(
                  (req) => _buildRequestCard(context, req),
                ),
                const SizedBox(height: 24),
              ],
              if (acceptedClients.isNotEmpty) ...[
                const Text(
                  "My Clients",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ...acceptedClients.map(
                  (req) => _buildRequestCard(context, req),
                ),
                const SizedBox(height: 24),
              ],
              if (rejectedRequests.isNotEmpty) ...[
                const Text(
                  "Archived Requests",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                ...rejectedRequests.map(
                  (req) => _buildRequestCard(context, req),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Builds each card using data ONLY from the request document.
  Widget _buildRequestCard(BuildContext context, DocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    final clientId = data["clientId"];
    final status = data["status"] ?? "pending";
    final clientName = data["clientName"] ?? "Client";
    final clientProfileImage = data["clientProfileImage"];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              clientProfileImage != null && clientProfileImage.isNotEmpty
              ? NetworkImage(clientProfileImage)
              : null,
          child: clientProfileImage == null || clientProfileImage.isEmpty
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(
          clientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Status: ${status.toString().capitalize()}',
          style: TextStyle(color: _getStatusColor(status)),
        ),
        trailing: status == "pending"
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28,
                    ),
                    onPressed: () => _updateRequest(clientId, "accepted"),
                    tooltip: 'Accept',
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                    onPressed: () => _updateRequest(clientId, "rejected"),
                    tooltip: 'Reject',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

// Helper extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return "";
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
