import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../screens/chat_screen.dart';
import '../services/chat_service.dart';

class TrainerSection extends StatelessWidget {
  const TrainerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text("Please log in to view trainers."));
    }

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

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("user_payments")
              .where("userId", isEqualTo: currentUser.uid)
              .snapshots(),
          builder: (context, paymentSnapshot) {
            // Get list of paid trainer IDs
            Set<String> paidTrainerIds = {};
            if (paymentSnapshot.hasData) {
              for (var doc in paymentSnapshot.data!.docs) {
                final trainerId = doc.get("trainerId") as String?;
                if (trainerId != null) {
                  paidTrainerIds.add(trainerId);
                }
              }
            }

            // Separate trainers into paid and unpaid
            List<DocumentSnapshot> paidTrainers = [];
            List<DocumentSnapshot> unpaidTrainers = [];

            for (var trainer in trainers) {
              if (currentUser.uid == trainer.id)
                continue; // Skip current user if trainer

              if (paidTrainerIds.contains(trainer.id)) {
                paidTrainers.add(trainer);
              } else {
                unpaidTrainers.add(trainer);
              }
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ PAID TRAINERS SECTION
                  if (paidTrainers.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            "Your Trainers",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${paidTrainers.length} Active",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paidTrainers.length,
                      itemBuilder: (context, index) {
                        final trainerDoc = paidTrainers[index];
                        final trainer =
                            trainerDoc.data() as Map<String, dynamic>;
                        final trainerId = trainerDoc.id;

                        return _TrainerListItem(
                          trainer: trainer,
                          trainerId: trainerId,
                          currentUser: currentUser,
                          isPaid: true,
                        );
                      },
                    ),
                    const Divider(height: 24, thickness: 1),
                  ],

                  // ✅ AVAILABLE TRAINERS SECTION
                  if (unpaidTrainers.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            "Available Trainers",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${unpaidTrainers.length} Available",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: unpaidTrainers.length,
                      itemBuilder: (context, index) {
                        final trainerDoc = unpaidTrainers[index];
                        final trainer =
                            trainerDoc.data() as Map<String, dynamic>;
                        final trainerId = trainerDoc.id;

                        return _TrainerListItem(
                          trainer: trainer,
                          trainerId: trainerId,
                          currentUser: currentUser,
                          isPaid: false,
                        );
                      },
                    ),
                  ],

                  if (paidTrainers.isEmpty && unpaidTrainers.isEmpty)
                    const Center(
                      child: Text("No trainers available right now."),
                    )
                  else
                    const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ✅ StatefulWidget for each item in the list
class _TrainerListItem extends StatefulWidget {
  const _TrainerListItem({
    required this.trainer,
    required this.trainerId,
    required this.currentUser,
    required this.isPaid,
  });

  final Map<String, dynamic> trainer;
  final String trainerId;
  final User? currentUser;
  final bool isPaid;

  @override
  State<_TrainerListItem> createState() => _TrainerListItemState();
}

class _TrainerListItemState extends State<_TrainerListItem> {
  bool _isProcessing = false;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _removeTrainer(String trainerName) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Trainer'),
        content: Text(
          'Are you sure you want to remove $trainerName from your trainers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Find and delete the payment record
      final snapshot = await FirebaseFirestore.instance
          .collection('user_payments')
          .where('userId', isEqualTo: currentUser.uid)
          .where('trainerId', isEqualTo: widget.trainerId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$trainerName removed ✓'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing trainer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _toggleRequest(
    String trainerName,
    String trainerProfileImage,
    bool isRequested,
  ) async {
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Request cancelled ❌")));
        }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Follow request sent ✅")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _payFees(int fee, String trainerName) {
    setState(() {
      _isProcessing = true;
    });

    final options = {
      'key': 'rzp_test_RVfRg0s4WjSnkL', // Test mode key
      'amount': fee * 100, // Amount in paise
      'name': 'Arise Fitness',
      'description': 'Payment for trainer: $trainerName',
      'prefill': {
        'contact': widget.currentUser?.phoneNumber ?? '',
        'email': widget.currentUser?.email ?? '',
      },
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    Fluttertoast.showToast(msg: "Payment Successful!");

    // Save payment to Firestore
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection("user_payments").add({
          'userId': currentUser.uid,
          'trainerId': widget.trainerId,
          'trainerName': widget.trainer['name'],
          'amount': int.tryParse(widget.trainer['fee']?.toString() ?? '0') ?? 0,
          'paymentId': response.paymentId,
          'orderId': response.orderId,
          'signature': response.signature,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        debugPrint('Payment saved successfully');

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Payment successful! Trainer added to your account.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error saving payment: $e");
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Fluttertoast.showToast(msg: "Payment Failed: ${response.message}");
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(msg: "External Wallet: ${response.walletName}");
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
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

    if (!widget.isPaid) {
      // Show follow request flow for unpaid trainers
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
                  Text(
                    "Fee: ₹$fee / month",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            if (status == "accepted") {
                              _payFees(fee, name);
                            } else {
                              _toggleRequest(
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: _isProcessing
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
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Show paid trainer card with status indicator
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.green, width: 2),
        ),
        elevation: 5,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(profileImage),
                backgroundColor: Colors.grey.shade200,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ],
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
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "✓ Verified Trainer",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.blue),
                onPressed: () async {
                  try {
                    final chatService = ChatService();
                    final conversationId = await chatService
                        .getOrCreateConversation(
                          otherUserId: widget.trainerId,
                          otherUserName: name,
                          currentUserName:
                              widget.currentUser?.displayName ??
                              widget.currentUser?.email ??
                              'User',
                        );

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: conversationId,
                            otherUserId: widget.trainerId,
                            otherUserName: name,
                            currentUserName:
                                widget.currentUser?.displayName ??
                                widget.currentUser?.email ??
                                'User',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Remove trainer',
                onPressed: _isProcessing ? null : () => _removeTrainer(name),
              ),
              const Icon(Icons.verified, color: Colors.green, size: 24),
            ],
          ),
        ),
      );
    }
  }
}
