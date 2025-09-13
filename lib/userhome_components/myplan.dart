import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../survey_screen.dart';

class MyPlanSection extends StatefulWidget {
  const MyPlanSection({super.key});

  @override
  State<MyPlanSection> createState() => _MyPlanSectionState();
}

class _MyPlanSectionState extends State<MyPlanSection> {
  String username = "";
  bool isLoading = true;
  bool hasSurvey = false;
  List<Map<String, dynamic>> fitnessPlans = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      String name = userDoc['username'] ?? "User";

      DocumentSnapshot surveyDoc = await FirebaseFirestore.instance
          .collection('surveys')
          .doc(uid)
          .get();

      bool surveyExists = surveyDoc.exists;

      List<Map<String, dynamic>> plans = [];
      if (surveyExists) {
        QuerySnapshot planSnapshot = await FirebaseFirestore.instance
            .collection('plans')
            .where('userId', isEqualTo: uid)
            .get();

        plans = planSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      }

      setState(() {
        username = name;
        hasSurvey = surveyExists;
        fitnessPlans = plans;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        username = "User";
        hasSurvey = false;
        fitnessPlans = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Welcome, $username 👋",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (!hasSurvey) ...[
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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SurveyScreen(),
                    ),
                  );
                  _loadUserData();
                },
                child: const Text(
                  "Get My Plan",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Complete the survey to unlock your fitness plan!"),
            ] else ...[
              const Text(
                "Your Recommended Fitness Plans:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              fitnessPlans.isEmpty
                  ? const Text("Plans will be generated soon ⏳")
                  : Column(
                      children: fitnessPlans.map((plan) {
                        return Card(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              plan['description'] ?? 'Stay fit and healthy!',
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                "/planDetails",
                                arguments: plan,
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
