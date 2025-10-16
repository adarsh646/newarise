import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TrainerClientsPage extends StatelessWidget {
  const TrainerClientsPage({super.key});

  Future<void> _updateRequest(String clientId, String status) async {
    final trainerId = FirebaseAuth.instance.currentUser!.uid;
    // The document ID is a combination of both UIDs
    final docId = await _getRequestDocId(trainerId, clientId);
    if (docId != null) {
      await FirebaseFirestore.instance
          .collection("trainer_requests")
          .doc(docId)
          .update({"status": status});
    }
  }

  // Helper function to find the correct request document ID
  Future<String?> _getRequestDocId(String trainerId, String clientId) async {
    // It's safer to query for the document than to guess the ID format
    final query = await FirebaseFirestore.instance
        .collection("trainer_requests")
        .where("trainerId", isEqualTo: trainerId)
        .where("clientId", isEqualTo: clientId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final trainerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Clients & Requests"),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
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

  /// ✅ UPDATED WIDGET: Builds each card by fetching fresh client data.
  Widget _buildRequestCard(BuildContext context, DocumentSnapshot request) {
    final requestData = request.data() as Map<String, dynamic>;
    final clientId = requestData["clientId"];
    final status = requestData["status"] ?? "pending";

    // Use a FutureBuilder to fetch data from the 'users' collection
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(clientId)
          .get(),
      builder: (context, userSnapshot) {
        // Show a placeholder while loading the user's data
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: ListTile(title: Text("Loading client...")));
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Card(child: ListTile(title: Text("Client data not found.")));
        }

        // Once data is loaded, extract the username and profile image
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final clientName =
            userData['username'] ?? 'Unnamed Client'; // Use 'username'
        final clientProfileImage = userData['profileImage'];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.red,
                          size: 28,
                        ),
                        onPressed: () => _updateRequest(clientId, "rejected"),
                        tooltip: 'Reject',
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
