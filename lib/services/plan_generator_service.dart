import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class PlanGeneratorService {
  final String _apiKey =
      'd9ec6f1fe8msh74effe2ecadeaa2p169767jsn434575a17020'; // ⚠️ PASTE YOUR API KEY
  // ✅ 1. Updated to the host that worked in Postman
  final String _apiHost = 'exercisedb-api1.p.rapidapi.com';

  /// Generates and saves a workout plan based on the user's survey goal.
  Future<void> generateAndSavePlan({required String userId}) async {
    try {
      final surveyDoc = await FirebaseFirestore.instance
          .collection('surveys')
          .doc(userId)
          .get();
      if (!surveyDoc.exists) {
        throw Exception("Survey document not found for user $userId");
      }

      final surveyData = surveyDoc.data()!;
      final String goal = surveyData['goal'] ?? 'Overall Fitness';

      Map<String, dynamic>? generatedPlan;

      if (goal == "Weight Gain" || goal == "Build Muscle") {
        generatedPlan = await _createPushPullLegsPlan(userId);
      } else if (goal == "Weight Loss" || goal == "Tone & Sculpt Body") {
        generatedPlan = await _createFullBodyFatLossPlan(userId);
      } else {
        generatedPlan = await _createGeneralFitnessPlan(userId);
      }

      if (generatedPlan != null) {
        await FirebaseFirestore.instance.collection('plans').add(generatedPlan);
      }
    } catch (e) {
      print("Error generating and saving plan: $e");
      throw e;
    }
  }

  // --- Plan Creation Logic ---

  Future<Map<String, dynamic>> _createPushPullLegsPlan(String userId) async {
    // Push Day: Chest, Shoulders, Triceps
    final chestExercises = await _fetchExercisesByKeyword('chest', limit: 2);
    final shoulderExercises = await _fetchExercisesByKeyword(
      'shoulder',
      limit: 2,
    );
    final tricepsExercises = await _fetchExercisesByKeyword(
      'triceps',
      limit: 1,
    );

    // Pull Day: Back, Biceps
    final backExercises = await _fetchExercisesByKeyword('back', limit: 3);
    final bicepsExercises = await _fetchExercisesByKeyword('biceps', limit: 2);

    // Leg Day: Quads, Hamstrings, Calves
    final legExercises = await _fetchExercisesByKeyword('leg', limit: 3);

    return {
      'userId': userId,
      'title': 'Push/Pull/Legs Strength Plan',
      'description':
          'A 3-day split designed to build muscle and increase strength.',
      'workouts': [
        {
          'day': 'Day 1: Push',
          'exercises': [
            ...chestExercises,
            ...shoulderExercises,
            ...tricepsExercises,
          ],
        },
        {
          'day': 'Day 2: Pull',
          'exercises': [...backExercises, ...bicepsExercises],
        },
        {'day': 'Day 3: Legs', 'exercises': legExercises},
      ],
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<Map<String, dynamic>> _createFullBodyFatLossPlan(String userId) async {
    final fullBodyExercises = await _fetchExercisesByKeyword(
      'full body',
      limit: 5,
    );
    return {
      'userId': userId,
      'title': 'Full Body Fat Loss Plan',
      'description': 'A 3-day routine focusing on calorie expenditure.',
      'workouts': [
        {'day': 'Day 1: Full Body', 'exercises': fullBodyExercises},
        {'day': 'Day 2: Full Body', 'exercises': fullBodyExercises},
        {'day': 'Day 3: Full Body', 'exercises': fullBodyExercises},
      ],
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<Map<String, dynamic>> _createGeneralFitnessPlan(String userId) async {
    return _createFullBodyFatLossPlan(userId);
  }

  // --- API Call Helper ---

  /// Fetches exercises by passing the muscle group as a keyword.
  Future<List<Map<String, dynamic>>> _fetchExercisesByKeyword(
    String keyword, {
    int limit = 10,
  }) async {
    // ✅ 2. Correct URL structure with query parameters
    final url = Uri.https(_apiHost, '/api/v1/exercises', {
      'keywords': keyword,
      'limit': '100', // Fetch more than needed to allow for randomization
    });

    final response = await http.get(
      url,
      headers: {'X-RapidAPI-Key': _apiKey, 'X-RapidAPI-Host': _apiHost},
    );

    if (response.statusCode == 200) {
      // The API returns a map with a 'results' key, which is a list
      final Map<String, dynamic> decodedData = json.decode(response.body);
      final List<dynamic> results = decodedData['results'] ?? [];

      if (results.isEmpty) return [];

      final random = Random();
      results.shuffle(random);
      final selectedData = results.take(limit);

      return selectedData
          .map(
            (exercise) => {
              'name': (exercise['name'] as String? ?? 'Unknown Exercise')
                  .capitalize(),
              'equipment': (exercise['equipment'] as String? ?? 'N/A')
                  .capitalize(),
              'gifUrl': exercise['gif_url'] ?? '', // API uses 'gif_url'
              'target': (exercise['primary_muscle'] as String? ?? 'N/A')
                  .capitalize(), // API uses 'primary_muscle'
              'sets': 3,
              'reps': 10,
            },
          )
          .toList();
    } else {
      print('API call failed with status: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception(
        'Failed to load exercises. Check Debug Console for details.',
      );
    }
  }
}

// Helper extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return "";
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
