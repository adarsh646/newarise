import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'survey_screen.dart';
import 'services/plan_generator_service.dart';
import 'userhome_components/trainer_section.dart';
import 'userhome_components/user_workouts.dart';
import 'userhome_components/myplan.dart';
import 'services/calorie_knn.dart';
import 'widgets/calorie_prediction_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String username = "";

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (mounted) {
        setState(() {
          username = userDoc['username'] ?? "User";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          username = "User";
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
      }
    }
  }

  // ✅ --- MODIFIED PROFILE PAGE ---
  Widget _buildProfilePage() {
    // This main layout is always built. The survey details inside are conditional.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade200,
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? "",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // ✅ The FutureBuilder now only wraps the part that needs the data.
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection("surveys")
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // ✅ If survey exists, show the details card.
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final surveyData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Survey Details",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow("Age", surveyData["age"]),
                                _buildDetailRow("Gender", surveyData["gender"]),
                                _buildDetailRow(
                                  "Height",
                                  "${surveyData["height"]} cm",
                                ),
                                _buildDetailRow(
                                  "Weight",
                                  "${surveyData["weight"]} kg",
                                ),
                                _buildDetailRow("Goal", surveyData["goal"]),
                                _buildDetailRow(
                                  "Activity Level",
                                  surveyData["activityLevel"],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit Survey'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(160, 44),
                                      ),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const SurveyScreen(),
                                          ),
                                        );
                                        if (context.mounted) setState(() {});
                                      },
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.local_fire_department),
                                      label: const Text('View Calories'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(160, 44),
                                      ),
                                      onPressed: () {
                                        final survey = UserSurvey(
                                          age: int.tryParse(surveyData['age']?.toString() ?? '') ?? 25,
                                          gender: (surveyData['gender'] ?? 'male').toString(),
                                          heightCm: double.tryParse(surveyData['height']?.toString() ?? '') ?? 170.0,
                                          weightKg: double.tryParse(surveyData['weight']?.toString() ?? '') ?? 70.0,
                                          activityLevel: (surveyData['activityLevel'] ?? 'moderate').toString(),
                                          goal: (surveyData['goal'] ?? 'maintain').toString(),
                                        );
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                          ),
                                          builder: (_) => DraggableScrollableSheet(
                                            expand: false,
                                            initialChildSize: 0.6,
                                            minChildSize: 0.4,
                                            maxChildSize: 0.9,
                                            builder: (ctx, controller) => SingleChildScrollView(
                                              controller: controller,
                                              child: Padding(
                                                padding: const EdgeInsets.all(12.0),
                                                child: CaloriePredictionCard(survey: survey),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Delete Survey'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        minimumSize: const Size(160, 44),
                                      ),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete survey?'),
                                            content: const Text(
                                                'This will remove all saved survey details. You can fill it again later.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          try {
                                            final uid = FirebaseAuth.instance.currentUser!.uid;
                                            await FirebaseFirestore.instance
                                                .collection('surveys')
                                                .doc(uid)
                                                .delete();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: const Text('Survey deleted.'),
                                                  action: SnackBarAction(
                                                    label: 'Fill Survey',
                                                    onPressed: () async {
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => const SurveyScreen(),
                                                        ),
                                                      );
                                                      if (context.mounted) setState(() {});
                                                    },
                                                  ),
                                                ),
                                              );
                                              setState(() {});
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Failed to delete: $e')),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Regenerate Plan'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(180, 44),
                                      ),
                                      onPressed: () async {
                                        try {
                                          final uid = FirebaseAuth.instance.currentUser!.uid;
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );
                                          await PlanGeneratorService().generateAndSavePlan(userId: uid);
                                          if (context.mounted) {
                                            Navigator.pop(context); // close dialog
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Plan regenerated.')),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to regenerate: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // ✅ Otherwise, show a placeholder card with action to fill survey.
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Please complete your survey to see your details here.",
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.assignment),
                                label: const Text('Fill Survey'),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SurveyScreen(),
                                    ),
                                  );
                                  if (context.mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // ✅ The Logout button is now outside the FutureBuilder and always visible.
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value.toString(),
            style: const TextStyle(color: Color.fromARGB(221, 8, 7, 7)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const MyPlanSection(),
      const UserWorkoutsPage(),
      const TrainerSection(),
      _buildProfilePage(), // This now calls our corrected method
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ARISE",
          style: TextStyle(
            color: Color.fromARGB(255, 3, 3, 3),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        selectedItemColor: const Color.fromARGB(255, 2, 2, 2),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "My Plan"),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: "Workouts",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: "Trainers"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
