import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_workout_page.dart';
import 'workout_details_page.dart';
import '../utils/role_helper.dart';

class StrengthWorkoutsPage extends StatelessWidget {
  const StrengthWorkoutsPage({super.key});

  static const List<Map<String, String>> groups = [
    {'key': 'Chest', 'image': 'assets/chest.png'},
    {'key': 'Back', 'image': 'assets/back.jpeg'},
    {'key': 'Biceps', 'image': 'assets/biceps.jpeg'},
    {'key': 'Triceps', 'image': 'assets/triceps.jpg'},
    {'key': 'Forearm', 'image': 'assets/forearm.jpg'},
    {'key': 'Shoulder', 'image': 'assets/shoulder.jpg'},
    {'key': 'Abs', 'image': 'assets/abs.png'},
    {'key': 'Leg', 'image': 'assets/leg.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strength - Muscle Groups'),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // Taller to accommodate image tile + label outside the card
          childAspectRatio: 0.75,
        ),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final g = groups[index];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image tile takes flexible space to avoid overflow
                Expanded(
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StrengthGroupWorkoutsPage(muscleGroup: g['key']!),
                          ),
                        );
                      },
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Ink.image(
                          image: AssetImage(g['image']!),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Label outside the tile
                Center(
                  child: Text(
                    g['key']!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
        },
      ),
    );
  }
}

class StrengthGroupWorkoutsPage extends StatelessWidget {
  final String muscleGroup;
  const StrengthGroupWorkoutsPage({super.key, required this.muscleGroup});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Strength • $muscleGroup'),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workouts')
            .where('category', isEqualTo: 'Strength')
            .where('muscleGroup', isEqualTo: muscleGroup)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load workouts'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No workouts yet in this muscle group.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String? gifUrl = data['gifUrl'];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutDetailsPage(workoutId: docs[index].id),
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
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.image_not_supported)),
                          ),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text(
                          data['name'] ?? 'No Name',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Tools: ${data['tools'] ?? 'N/A'}'),
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
                    builder: (context) => AddWorkoutPage(
                      category: 'Strength',
                      muscleGroup: muscleGroup,
                    ),
                  ),
                );
              },
              tooltip: 'Add $muscleGroup Workout',
              child: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
