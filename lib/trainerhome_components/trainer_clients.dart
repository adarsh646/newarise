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
      appBar: AppBar(
        title: const Text("My Clients"),
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No client requests yet."));
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final clientId = request["clientId"];
              final status = request["status"];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(clientId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(title: Text("Loading client..."));
                  }

                  final user = userSnapshot.data!;
                  final username = user["username"] ?? "User";
                  final email = user["email"] ?? "";

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(username),
                      subtitle: Text(email),
                      trailing: status == "pending"
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    await _updateRequest(clientId, "accepted");
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text("Accept"),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _updateRequest(clientId, "rejected");
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text("Reject"),
                                ),
                              ],
                            )
                          : Text(
                              status == "accepted"
                                  ? "Accepted ✅"
                                  : "Rejected ❌",
                              style: TextStyle(
                                color: status == "accepted"
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientDetailPage(
                              username: username,
                              email: email,
                              userData: user.data() as Map<String, dynamic>,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ClientDetailPage extends StatelessWidget {
  final String username;
  final String email;
  final Map<String, dynamic> userData;

  const ClientDetailPage({
    super.key,
    required this.username,
    required this.email,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: $email"),
            const SizedBox(height: 10),
            Text("Age: ${userData["age"] ?? "N/A"}"),
            Text("Goal: ${userData["goal"] ?? "N/A"}"),
            Text("Activity Level: ${userData["activityLevel"] ?? "N/A"}"),
          ],
        ),
      ),
    );
  }
}
