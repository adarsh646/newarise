import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainerSection extends StatelessWidget {
  const TrainerSection({super.key});

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
            final trainerId = trainerDoc.id;

            // Don't show the currently logged-in user if they are a trainer
            if (currentUser != null && trainerId == currentUser.uid) {
              return const SizedBox.shrink();
            }

            // Pass the data to our new StatefulWidget
            return _TrainerListItem(
              trainer: trainer,
              trainerId: trainerId,
              currentUser: currentUser,
            );
          },
        );
      },
    );
  }
}

// ✅ NEW: StatefulWidget for each item in the list
class _TrainerListItem extends StatefulWidget {
  const _TrainerListItem({
    required this.trainer,
    required this.trainerId,
    required this.currentUser,
  });

  final Map<String, dynamic> trainer;
  final String trainerId;
  final User? currentUser;

  @override
  State<_TrainerListItem> createState() => _TrainerListItemState();
}

class _TrainerListItemState extends State<_TrainerListItem> {
  // ✅ NEW: Local state to track processing status for immediate UI feedback
  bool _isProcessing = false;

  Future<void> _toggleRequest(
    String trainerName,
    String trainerProfileImage,
    bool isRequested,
  ) async {
    // Show immediate loading state
    setState(() {
      _isProcessing = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You need to be logged in!")),
      );
      setState(() => _isProcessing = false);
      return;
    }

    final clientDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();

    if (!clientDoc.exists || clientDoc.data() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not find your user profile.")),
      );
      setState(() => _isProcessing = false);
      return;
    }

    final clientData = clientDoc.data()!;
    final clientName = clientData['username'] ?? 'N/A';
    final clientProfileImage = clientData['profileImage'] ?? '';

    final docId = "${widget.trainerId}-${currentUser.uid}";
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
        await docRef.set({
          "trainerId": widget.trainerId,
          "trainerName": trainerName,
          "trainerProfileImage": trainerProfileImage,
          "clientId": currentUser.uid,
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
    } finally {
      // Hide loading state regardless of success or error
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _payFees(int fee) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Redirecting to pay ₹$fee...")));
  }

  @override
  Widget build(BuildContext context) {
    final profileImage =
        widget.trainer["profileImage"] ?? "https://via.placeholder.com/150";
    final name = widget.trainer["name"] ?? "Trainer";
    final specialization = widget.trainer["specialization"] ?? "Fitness Coach";
    final qualification = widget.trainer["qualification"] ?? "N/A";
    final experience = widget.trainer["experience"] ?? "0";
    final fee = int.tryParse(widget.trainer["fee"]?.toString() ?? "0") ?? 0;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("trainer_requests")
          .doc("${widget.trainerId}-${widget.currentUser?.uid}")
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
              // ✅ Disable button while processing
              onPressed: _isProcessing
                  ? null
                  : () {
                      if (status == "accepted") {
                        _payFees(fee);
                      } else {
                        _toggleRequest(name, profileImage, status != null);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: status == "accepted"
                    ? Colors.orange
                    : (status != null ? Colors.grey : Colors.green),
                foregroundColor: Colors.white,
              ),
              child: _isProcessing
                  // ✅ Show a loading indicator for immediate feedback
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      status == "accepted"
                          ? "Pay ₹$fee"
                          : (status != null ? "Requested" : "Follow"),
                    ),
            ),
          ),
        );
      },
    );
  }
}
