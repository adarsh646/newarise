import 'package:flutter/material.dart';

class WorkoutSection extends StatelessWidget {
  const WorkoutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final workouts = [
      {
        "title": "Strength",
        "image": "assets/strenth.png",
        "exercises": [
          {
            "name": "Push Ups",
            "desc": "Great for chest, shoulders, and triceps.",
            "image": "assets/exercises/pushups.jpg",
          },
          {
            "name": "Squats",
            "desc": "Builds strength in legs and glutes.",
            "image": "assets/exercises/squats.jpg",
          },
        ],
      },
      {
        "title": "HIIT, Cardio",
        "image": "assets/cardio.png",
        "exercises": [
          {
            "name": "Jumping Jacks",
            "desc": "Full-body warmup exercise.",
            "image": "assets/exercises/jumpingjacks.jpg",
          },
          {
            "name": "Burpees",
            "desc": "Intense cardio + strength movement.",
            "image": "assets/exercises/burpees.jpg",
          },
        ],
      },
      {
        "title": "Stretching",
        "image": "assets/stretching.png",
        "exercises": [
          {
            "name": "Downward Dog",
            "desc": "Stretches hamstrings, calves, and shoulders.",
            "image": "assets/exercises/downwarddog.jpg",
          },
          {
            "name": "Cobra Pose",
            "desc": "Strengthens spine and stretches chest.",
            "image": "assets/exercises/cobra.jpg",
          },
        ],
      },
      {
        "title": "Warmup, Recovery",
        "image": "assets/warmup.png",
        "exercises": [
          {
            "name": "Arm Circles",
            "desc": "Loosens shoulders and warms up arms.",
            "image": "assets/exercises/armcircles.jpg",
          },
          {
            "name": "Hamstring Stretch",
            "desc": "Improves flexibility and recovery.",
            "image": "assets/exercises/hamstring.jpg",
          },
        ],
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Workouts",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: workouts.length,
        itemBuilder: (context, index) {
          final workout = workouts[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutDetailPage(
                    title: workout["title"] as String,
                    exercises: workout["exercises"] as List,
                  ),
                ),
              );
            },
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        workout["title"] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Image.asset(
                      workout["image"] as String,
                      width: 140,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class WorkoutDetailPage extends StatelessWidget {
  final String title;
  final List exercises;

  const WorkoutDetailPage({
    super.key,
    required this.title,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: exercises.length,
        itemBuilder: (context, index) {
          final exercise = exercises[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  exercise["image"],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                exercise["name"],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(exercise["desc"]),
            ),
          );
        },
      ),
    );
  }
}
