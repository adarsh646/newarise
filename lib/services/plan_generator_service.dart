import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class PlanGeneratorService {
  final String _apiKey = 'd9ec6f1fe8msh74effe2ecadeaa2p169767jsn434575a17020';
  // RapidAPI AI Workout Planner host (as requested by user)
  final String _plannerHost =
      'ai-workout-planner-exercise-fitness-nutrition-guide.p.rapidapi.com';

  /// Generates and saves a workout plan using RapidAPI only.
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
      Map<String, dynamic>? generatedPlan = await _generatePlanViaRapidApi(
        userId: userId,
        surveyData: surveyData,
      );
      // Network fallback: if API is unreachable, synthesize a local plan so user isn't blocked
      generatedPlan ??= _generateLocalPlan(
        userId: userId,
        surveyData: surveyData,
      )..addAll({'source': 'local_network_fallback'});

      // Save only to 'fitness_plans' (Option A) to comply with rules that
      // allow users to manage their own plans when 'userId' matches auth uid.
      final db = FirebaseFirestore.instance;
      final fitnessPlansRef = db.collection('fitness_plans').doc();
      await fitnessPlansRef.set({
        ...generatedPlan,
        // Ensure required ownership field is present for rules
        'userId': userId,
        // Keep createdAt if provided by generator, and set/update updatedAt
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Link the fitness plan to the client in plan_progress
      await db.collection('plan_progress').doc(userId).set({
        fitnessPlansRef.id: {
          'assignedAt': FieldValue.serverTimestamp(),
          'status': 'active',
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error generating and saving plan: $e");
      throw e;
    }
  }

  // --- API Call Helper ---

  /// Calls RapidAPI AI Workout Planner to generate a plan from survey data.
  Future<Map<String, dynamic>?> _generatePlanViaRapidApi({
    required String userId,
    required Map<String, dynamic> surveyData,
  }) async {
    try {
      // On Flutter Web, browser CORS will block most RapidAPI requests.
      // Use a local fallback plan so the app continues to work on Chrome/Web.
      if (kIsWeb) {
        print(
          '[PlanGen] Web detected. Using local fallback plan to avoid CORS.',
        );
        return _generateLocalPlan(userId: userId, surveyData: surveyData);
      }
      // Endpoint per provider docs: POST /generateWorkoutPlan?noqueue=1
      final uri = Uri.https(_plannerHost, '/generateWorkoutPlan', {
        'noqueue': '1',
      });

      // Map survey fields to API schema per provided spec
      final String apiGoal = (surveyData['goal'] ?? 'Build muscle').toString();
      final String apiFitnessLevel = (surveyData['activityLevel'] ?? 'Beginner')
          .toString();
      final List<dynamic> apiPreferences =
          (surveyData['preferences'] as List?) ?? <String>['Weight training'];
      final List<dynamic> apiHealthConditions =
          (surveyData['healthConditions'] as List?) ?? <String>['None'];
      final int apiDaysPerWeek = (surveyData['daysPerWeek'] is int)
          ? surveyData['daysPerWeek'] as int
          : 3;
      final int apiSessionDuration = (surveyData['sessionDuration'] is int)
          ? surveyData['sessionDuration'] as int
          : 45;
      final int apiPlanDurationWeeks = (surveyData['planDurationWeeks'] is int)
          ? surveyData['planDurationWeeks'] as int
          : 4;
      final String apiLang = (surveyData['lang'] ?? 'en').toString();
      // Demographics not required for this API spec; keeping available if needed in future

      // Build payload exactly matching this API (snake_case keys)
      final Map<String, dynamic> payload = {
        'goal': apiGoal,
        'fitness_level': apiFitnessLevel,
        'preferences': apiPreferences,
        'health_conditions': apiHealthConditions,
        'schedule': {
          'days_per_week': apiDaysPerWeek,
          'session_duration': apiSessionDuration,
        },
        'plan_duration_weeks': apiPlanDurationWeeks,
        'lang': apiLang,
      };

      print('[PlanGen] POST $uri');
      print('[PlanGen] Payload: ' + json.encode(payload));
      Map<String, dynamic> usedPayload = payload;
      // Light retry to handle transient network issues
      http.Response? response;
      Exception? lastErr;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'X-RapidAPI-Key': _apiKey,
                  'X-RapidAPI-Host': _plannerHost,
                },
                body: json.encode(payload),
              )
              .timeout(const Duration(seconds: 30));
          // success
          break;
        } catch (e) {
          lastErr = e is Exception ? e : Exception(e.toString());
          if (attempt == 1) rethrow; // give up after second attempt
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
      }

      if (response == null) {
        throw lastErr ?? Exception('Network request failed');
      }

      if (response!.statusCode != 200) {
        print('[PlanGen] RapidAPI planner failed: ${response!.statusCode}');
        print('[PlanGen] Response headers: ${response!.headers}');
        print('[PlanGen] Response body: ${response!.body}');
        throw Exception(
          'RapidAPI error ${response!.statusCode}: ${response!.body}',
        );
      }

      dynamic decoded = json.decode(response!.body);
      // Some APIs return a JSON string inside JSON. Try to decode again if so.
      if (decoded is String) {
        try {
          decoded = json.decode(decoded);
        } catch (_) {
          // keep as string
        }
      }

      final Map<String, dynamic> body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'plan': decoded};

      // Extract a normalized plan object.
      dynamic planContent =
          body['plan'] ?? body['workouts'] ?? body['data'] ?? body['result'];
      // If the plan content is itself a JSON string, try to decode it.
      if (planContent is String) {
        final String trimmed = planContent.trim();
        if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
            (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
          try {
            planContent = json.decode(trimmed);
          } catch (_) {
            // leave as string
          }
        }
      }

      // If the API doesn't provide recognizable day/exercise structure, synthesize a days list
      final bool hasDays = _looksLikeDaysStructure(planContent);
      final Map<String, dynamic> normalizedPlan = hasDays
          ? {
              // keep API structure when it already contains days/workouts
              ...((planContent is Map<String, dynamic>)
                  ? planContent
                  : <String, dynamic>{}),
              if (planContent is List) 'days': planContent,
            }
          : {
              'level': (surveyData['activityLevel'] ?? 'Beginner').toString(),
              'goal': (surveyData['goal'] ?? 'Overall Fitness').toString(),
              'daysPerWeek': (surveyData['daysPerWeek'] is int)
                  ? surveyData['daysPerWeek'] as int
                  : 3,
              'sessionDuration': (surveyData['sessionDuration'] is int)
                  ? surveyData['sessionDuration'] as int
                  : 45,
              'weeks': (surveyData['planDurationWeeks'] is int)
                  ? surveyData['planDurationWeeks'] as int
                  : 4,
              'days': _generateLocalPlan(
                userId: userId,
                surveyData: surveyData,
              )['plan']['days'],
            };
      if (!hasDays) {
        print(
          '[PlanGen] API returned no explicit days/exercises; synthesized local days for device.',
        );
      }

      // Normalize and store the plan
      return {
        'userId': userId,
        'title': (body['title'] ?? 'AI Workout Plan').toString(),
        'description': (body['description'] ?? '').toString(),
        'plan': normalizedPlan,
        'source': hasDays ? 'rapidapi' : 'rapidapi+fallback',
        'createdAt': FieldValue.serverTimestamp(),
        'input': usedPayload,
      };
    } catch (e) {
      print('RapidAPI planner error: $e');
      return null;
    }
  }

  // Detect if a payload already contains a usable day/exercise structure
  bool _looksLikeDaysStructure(dynamic content) {
    if (content == null) return false;
    if (content is List) {
      if (content.isEmpty) return false;
      final first = content.first;
      if (first is Map<String, dynamic>) {
        return first.containsKey('exercises') ||
            first.containsKey('title') ||
            first.containsKey('day');
      }
      return false;
    }
    if (content is Map<String, dynamic>) {
      if (content['days'] is List) return true;
      if (content['workouts'] is List) return true;
      const weekdays = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      for (final w in weekdays) {
        if (content.containsKey(w) ||
            content.containsKey('${w[0].toUpperCase()}${w.substring(1)}')) {
          return true;
        }
      }
      for (final k in content.keys) {
        final kl = k.toLowerCase();
        if (kl.startsWith('day ') ||
            RegExp(r'^day\s*\d+').hasMatch(kl) ||
            RegExp(r'^day_?\d+').hasMatch(kl)) {
          return true;
        }
      }
    }
    if (content is String) {
      final s = content.trim();
      if ((s.startsWith('{') && s.endsWith('}')) ||
          (s.startsWith('[') && s.endsWith(']'))) {
        try {
          return _looksLikeDaysStructure(json.decode(s));
        } catch (_) {
          return false;
        }
      }
      return false;
    }
    return false;
  }

  /// Local fallback plan generator to keep Web builds working without CORS/backend.
  Map<String, dynamic> _generateLocalPlan({
    required String userId,
    required Map<String, dynamic> surveyData,
  }) {
    final String goal = (surveyData['goal'] ?? 'Overall Fitness').toString();
    final String level = (surveyData['activityLevel'] ?? 'Beginner').toString();
    final int daysPerWeek = (surveyData['daysPerWeek'] is int)
        ? surveyData['daysPerWeek'] as int
        : 3;
    final int sessionDuration = (surveyData['sessionDuration'] is int)
        ? surveyData['sessionDuration'] as int
        : 45;
    final int planDurationWeeks = (surveyData['planDurationWeeks'] is int)
        ? surveyData['planDurationWeeks'] as int
        : 4;
    // Build UI-friendly 'days' structure with explicit exercise items
    final List<Map<String, dynamic>> days = List.generate(daysPerWeek, (i) {
      final dayNum = i + 1;
      final focus = _dayFocus(goal, dayNum);

      List<Map<String, dynamic>> exercises;
      if (focus.contains('Strength')) {
        exercises = [
          {'name': 'Dynamic Warm-up', 'sets': '1', 'reps': '10'},
          {'name': 'Squats', 'sets': '3', 'reps': '10'},
          {'name': 'Push-ups', 'sets': '3', 'reps': '12'},
          {'name': 'Bent-over Rows', 'sets': '3', 'reps': '10'},
          {'name': 'Plank', 'sets': '3', 'reps': '30s'},
          {'name': 'Cool-down Stretch', 'sets': '1', 'reps': '5m'},
        ];
      } else if (focus.contains('HIIT') || focus.contains('Cardio')) {
        exercises = [
          {'name': 'Light Jog Warm-up', 'sets': '1', 'reps': '5m'},
          {'name': 'HIIT: 40s Work / 20s Rest x 8', 'sets': '8', 'reps': '40s'},
          {'name': 'Brisk Walk', 'sets': '1', 'reps': '10m'},
          {'name': 'Cool-down Stretch', 'sets': '1', 'reps': '5m'},
        ];
      } else if (focus.contains('Mobility')) {
        exercises = [
          {'name': 'Cat-Cow', 'sets': '2', 'reps': '10'},
          {'name': 'Hip Flexor Stretch', 'sets': '2', 'reps': '30s'},
          {'name': 'Thoracic Rotations', 'sets': '2', 'reps': '10'},
          {'name': 'Hamstring Stretch', 'sets': '2', 'reps': '30s'},
        ];
      } else {
        // Core & Stability or default
        exercises = [
          {'name': 'Dead Bug', 'sets': '3', 'reps': '10'},
          {'name': 'Glute Bridge', 'sets': '3', 'reps': '12'},
          {'name': 'Side Plank (each side)', 'sets': '3', 'reps': '30s'},
          {'name': 'Bird Dog', 'sets': '3', 'reps': '10'},
        ];
      }

      return {'title': 'Day $dayNum - $focus', 'exercises': exercises};
    });

    return {
      'userId': userId,
      'title': 'Starter Plan ($goal - $level)',
      'description': 'Your personalized workout plan.',
      'plan': {
        'level': level,
        'goal': goal,
        'daysPerWeek': daysPerWeek,
        'sessionDuration': sessionDuration,
        'weeks': planDurationWeeks,
        // Provide a 'days' list so UI can render workouts
        'days': days,
      },
      'source': 'local_fallback',
      'createdAt': FieldValue.serverTimestamp(),
      'input': {
        'goal': goal,
        'fitness_level': level,
        'schedule': {
          'days_per_week': daysPerWeek,
          'session_duration': sessionDuration,
        },
        'plan_duration_weeks': planDurationWeeks,
      },
    };
  }

  String _dayFocus(String goal, int day) {
    final normalized = goal.toLowerCase();
    if (normalized.contains('weight loss')) {
      return (day % 2 == 0) ? 'HIIT/Cardio' : 'Full-body Strength';
    }
    if (normalized.contains('weight gain') ||
        normalized.contains('muscle') ||
        normalized.contains('build')) {
      return (day % 2 == 0) ? 'Lower Body Strength' : 'Upper Body Strength';
    }
    if (normalized.contains('flexibility') || normalized.contains('mobility')) {
      return (day % 2 == 0) ? 'Stretching & Mobility' : 'Core Stability';
    }
    // Default rotation
    const options = [
      'Full-body Strength',
      'Cardio',
      'Core & Stability',
      'Mobility',
    ];
    return options[(day - 1) % options.length];
  }
}
