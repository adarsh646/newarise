import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainerSection extends StatelessWidget {
  const TrainerSection({super.key});

  Future<void> _toggleRequest(
    BuildContext context,
    String trainerId,
    String trainerName,
    String trainerProfileImage,
    bool isRequested,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You need to be logged in!")),
      );
      return;
    }

    final clientId = currentUser.uid;
    final clientDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(clientId)
        .get();

    if (!clientDoc.exists || clientDoc.data() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not find your user profile.")),
      );
      return;
    }

    final clientData = clientDoc.data()!;
    // ✅ CORRECTLY using 'username' for the client's name
    final clientName = clientData['username'] ?? 'N/A';
    final clientProfileImage = clientData['profileImage'] ?? '';

    final docId = "$trainerId-$clientId";
    final docRef = FirebaseFirestore.instance
        .collection("trainer_requests")
        .doc(docId);

    try {
      if (isRequested) {
        await docRef.delete();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Request cancelled ❌")));
      } else {
        // ✅ Saving the complete, correct data structure
        await docRef.set({
          "trainerId": trainerId,
          "trainerName": trainerName,
          "trainerProfileImage": trainerProfileImage,
          "clientId": clientId,
          "clientName": clientName,
          "clientProfileImage": clientProfileImage,
          "status": "pending",
          "timestamp": FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Follow request sent ✅")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _payFees(BuildContext context, String trainerId, int fee) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Redirecting to pay ₹$fee...")));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "trainer")
          .where("status", isEqualTo: "approved")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No trainers available right now."));
        }

        final trainers = snapshot.data!.docs;
        final currentUser = FirebaseAuth.instance.currentUser;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trainers.length,
          itemBuilder: (context, index) {
            final trainerDoc = trainers[index];
            final trainer = trainerDoc.data() as Map<String, dynamic>;
            final trainerId = trainerDoc.id; // Correctly get the trainer's UID

            if (currentUser != null && trainerId == currentUser.uid) {
              return const SizedBox.shrink();
            }

            final profileImage =
                trainer["profileImage"] ?? "https://via.placeholder.com/150";
            final name = trainer["name"] ?? "Trainer";
            final specialization = trainer["specialization"] ?? "Fitness Coach";
            final qualification = trainer["qualification"] ?? "N/A";
            final experience = trainer["experience"] ?? "0";
            final fee = int.tryParse(trainer["fee"]?.toString() ?? "0") ?? 0;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("trainer_requests")
                  .doc("$trainerId-${currentUser?.uid}")
                  .snapshots(),
              builder: (context, requestSnapshot) {
                String? status;
                if (requestSnapshot.hasData && requestSnapshot.data!.exists) {
                  status = requestSnapshot.data!.get("status") ?? "pending";
                }

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(profileImage),
                      backgroundColor: Colors.grey.shade200,
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
                        Text("Specialization: $specialization"),
                        Text("Qualification: $qualification"),
                        Text("Experience: $experience years"),
                        Text("Fee: ₹$fee / month"),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      onPressed: () {
                        if (status == "accepted") {
                          _payFees(context, trainerId, fee);
                        } else {
                          _toggleRequest(
                            context,
                            trainerId,
                            name,
                            profileImage,
                            status != null,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status == "accepted"
                            ? Colors.orange
                            : (status != null ? Colors.grey : Colors.green),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        status == "accepted"
                            ? "Pay ₹$fee"
                            : (status != null ? "Requested" : "Follow"),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
