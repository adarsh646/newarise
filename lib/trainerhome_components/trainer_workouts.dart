import 'package:flutter/material.dart';

class TrainerWorkoutsPage extends StatelessWidget {
  const TrainerWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Later connect this to Firestore "workouts_assigned" collection
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assigned Workouts"),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.fitness_center),
              title: Text("Push Ups - 3 sets x 15 reps"),
              subtitle: Text("Assigned to Client A"),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.directions_run),
              title: Text("Jogging - 20 mins"),
              subtitle: Text("Assigned to Client B"),
            ),
          ),
        ],
      ),
    );
  }
}
