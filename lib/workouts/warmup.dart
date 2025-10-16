import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_workout_page.dart'; // Adjust this import path if needed
import 'workout_details_page.dart';
import '../utils/role_helper.dart';

class WarmupWorkoutsPage extends StatelessWidget {
  const WarmupWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const String categoryName = "Warmup";

    return Scaffold(
      appBar: AppBar(
        title: const Text(categoryName),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workouts')
            .where('category', isEqualTo: categoryName)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Failed to load workouts. If you recently added filters or ordering, a composite index may be required in Firestore.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No Warmup workouts found.\nTap '+' to add one!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          final workouts = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workoutData =
                  workouts[index].data() as Map<String, dynamic>;
              final String? gifUrl = workoutData['gifUrl'];

              // --- WIDGET UPDATED HERE ---
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WorkoutDetailsPage(workoutId: workouts[index].id),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (gifUrl != null && gifUrl.isNotEmpty)
                        Image.network(
                          gifUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 50,
                                ),
                              ),
                            );
                          },
                        ),

                      ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text(
                          workoutData['name'] ?? 'No Name',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Tools: ${workoutData['tools'] ?? 'N/A'}",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: RoleHelper.canAddWorkouts(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const AddWorkoutPage(category: categoryName),
                  ),
                );
              },
              tooltip: 'Add Warmup Workout',
              child: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
