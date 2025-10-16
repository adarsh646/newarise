import 'package:flutter/material.dart';

import 'package:arise/workouts/strength.dart';
import 'package:arise/workouts/cardio.dart';
import 'package:arise/workouts/stretching.dart';
import 'package:arise/workouts/warmup.dart';

class UserWorkoutsPage extends StatelessWidget {
  const UserWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutCategories = [
      {
        "title": "Strength",
        "image": "assets/strenth.png",
        "page": const StrengthWorkoutsPage(),
      },
      {
        "title": "Cardio",
        "image": "assets/cardio.png",
        "page": const CardioWorkoutsPage(),
      },
      {
        "title": "Stretching",
        "image": "assets/stretching.png",
        "page": const StretchingWorkoutsPage(),
      },
      {
        "title": "Warmup",
        "image": "assets/warmup.png",
        "page": const WarmupWorkoutsPage(),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Workouts",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: workoutCategories.length,
        itemBuilder: (context, index) {
          final category = workoutCategories[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => category["page"] as Widget),
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
                        category["title"] as String,
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
                      category["image"] as String,
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
