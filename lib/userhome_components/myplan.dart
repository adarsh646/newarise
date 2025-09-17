import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../survey_screen.dart';

class MyPlanSection extends StatefulWidget {
  const MyPlanSection({super.key});

  @override
  State<MyPlanSection> createState() => _MyPlanSectionState();
}

class _MyPlanSectionState extends State<MyPlanSection> {
  late Future<String> _usernameFuture;

  @override
  void initState() {
    super.initState();
    _usernameFuture = _fetchUsername();
  }

  Future<String> _fetchUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "User";
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      // ✅ FIX 2: Changed 'name' to 'username' to match your Firestore data structure.
      return userDoc.data()?['username'] ?? "User";
    } catch (e) {
      return "User";
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Please log in."));

    // ✅ FIX 1: Wrapped the content in a Center widget.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Helps with vertical centering
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder<String>(
              future: _usernameFuture,
              builder: (context, snapshot) {
                final username = snapshot.data ?? 'User';
                return Text(
                  "Welcome, $username 👋",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('plans')
                  .where('userId', isEqualTo: uid)
                  .limit(1)
                  .snapshots(),
              builder: (context, planSnapshot) {
                if (planSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (planSnapshot.hasError) {
                  return const Center(child: Text("Something went wrong."));
                }

                if (planSnapshot.hasData &&
                    planSnapshot.data!.docs.isNotEmpty) {
                  final plan =
                      planSnapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                  return _buildPlanCard(plan);
                }

                return _buildNoPlanUI(uid);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return Column(
      children: [
        const Text(
          "Your Recommended Fitness Plan:",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(
              Icons.fitness_center,
              color: Colors.blue,
              size: 32,
            ),
            title: Text(
              plan['title'] ?? 'Fitness Plan',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(plan['description'] ?? 'Stay fit and healthy!'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () {
              Navigator.pushNamed(context, "/planDetails", arguments: plan);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoPlanUI(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('surveys').doc(uid).get(),
      builder: (context, surveySnapshot) {
        if (surveySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (surveySnapshot.hasData && surveySnapshot.data!.exists) {
          return const Text("Your plan is being generated, please wait... ⏳");
        }

        return Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 238, 255, 65),
                foregroundColor: const Color.fromARGB(221, 22, 20, 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SurveyScreen()),
                );
              },
              child: const Text(
                "Get My Plan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Complete the survey to unlock your fitness plan!"),
          ],
        );
      },
    );
  }
}
