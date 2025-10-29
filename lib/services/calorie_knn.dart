import 'dart:math';

class UserSurvey {
  final int age;
  final String gender;
  final double heightCm;
  final double weightKg;
  final String activityLevel;
  final String goal;

  const UserSurvey({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
  });
}

class CaloriePredictionResult {
  final int calories;
  final Map<String, int> macros;

  const CaloriePredictionResult({required this.calories, required this.macros});
}

class CalorieKNN {
  static int predictCalories(UserSurvey s, {List<Map<String, dynamic>>? dataset, int k = 7}) {
    if (dataset == null || dataset.isEmpty) {
      return _formulaTdee(s);
    }

    final points = <_Point>[];
    for (final row in dataset) {
      final int? cals = _asInt(row['calories']);
      final int? age = _asInt(row['age']);
      final double? height = _asDouble(row['height_cm']);
      final double? weight = _asDouble(row['weight_kg']);
      final String? gender = row['gender']?.toString();
      final String? activity = row['activity']?.toString();
      final String? goal = row['goal']?.toString();
      if ([cals, age, height, weight, gender, activity, goal].contains(null)) continue;
      final d = _distance(
        sAge: s.age,
        sGender: s.gender,
        sHeight: s.heightCm,
        sWeight: s.weightKg,
        sActivity: s.activityLevel,
        sGoal: s.goal,
        age: age!,
        gender: gender!,
        height: height!,
        weight: weight!,
        activity: activity!,
        goal: goal!,
      );
      points.add(_Point(distance: d, calories: cals!));
    }

    if (points.isEmpty) return _formulaTdee(s);
    points.sort((a, b) => a.distance.compareTo(b.distance));
    final n = min(k, points.length);
    double weighted = 0;
    double weightSum = 0;
    for (int i = 0; i < n; i++) {
      final p = points[i];
      final w = 1.0 / (p.distance + 1e-6);
      weighted += w * p.calories;
      weightSum += w;
    }
    final pred = (weighted / max(weightSum, 1e-6)).round();
    return pred;
  }

  static CaloriePredictionResult predict(UserSurvey s, {List<Map<String, dynamic>>? dataset, int k = 7}) {
    final calories = predictCalories(s, dataset: dataset, k: k);
    final macros = _macroSplit(calories, s.goal);
    return CaloriePredictionResult(calories: calories, macros: macros);
  }

  static int _formulaTdee(UserSurvey s) {
    final bool male = s.gender.toLowerCase().startsWith('m');
    final bmr = male
        ? 10 * s.weightKg + 6.25 * s.heightCm - 5 * s.age + 5
        : 10 * s.weightKg + 6.25 * s.heightCm - 5 * s.age - 161;
    final factor = _activityFactor(s.activityLevel);
    double tdee = bmr * factor;
    final g = s.goal.toLowerCase();
    if (g.contains('loss') || g.contains('cut')) {
      tdee -= 400;
    } else if (g.contains('gain') || g.contains('bulk')) {
      tdee += 400;
    }
    return tdee.round();
  }

  static double _distance({
    required int sAge,
    required String sGender,
    required double sHeight,
    required double sWeight,
    required String sActivity,
    required String sGoal,
    required int age,
    required String gender,
    required double height,
    required double weight,
    required String activity,
    required String goal,
  }) {
    final sBmi = sWeight / pow(sHeight / 100.0, 2);
    final bmi = weight / pow(height / 100.0, 2);
    final ageD = ((sAge - age).abs()) / 50.0;
    final bmiD = ((sBmi - bmi).abs()) / 15.0;
    final genderD = sGender.toLowerCase() == gender.toLowerCase() ? 0.0 : 1.0;
    final actD = (_activityIndex(sActivity) - _activityIndex(activity)).abs() / 4.0;
    final goalD = (_goalIndex(sGoal) - _goalIndex(goal)).abs() / 2.0;
    return sqrt(ageD * ageD + bmiD * bmiD + genderD * genderD + actD * actD + goalD * goalD);
  }

  static int _activityIndex(String v) {
    final t = v.toLowerCase();
    if (t.contains('sed')) return 0;
    if (t.contains('light')) return 1;
    if (t.contains('moder')) return 2;
    if (t.contains('very') || t.contains('high')) return 3;
    return 2;
  }

  static int _goalIndex(String v) {
    final t = v.toLowerCase();
    if (t.contains('loss') || t.contains('cut')) return 0;
    if (t.contains('maint')) return 1;
    if (t.contains('gain') || t.contains('bulk')) return 2;
    return 1;
  }

  static double _activityFactor(String v) {
    switch (_activityIndex(v)) {
      case 0:
        return 1.2;
      case 1:
        return 1.375;
      case 2:
        return 1.55;
      case 3:
        return 1.725;
      default:
        return 1.55;
    }
  }

  static Map<String, int> _macroSplit(int calories, String goal) {
    final t = goal.toLowerCase();
    double p = 0.3, c = 0.45, f = 0.25;
    if (t.contains('loss') || t.contains('cut')) {
      p = 0.35; c = 0.4; f = 0.25;
    } else if (t.contains('gain') || t.contains('bulk')) {
      p = 0.25; c = 0.5; f = 0.25;
    }
    final proteinCal = (calories * p).round();
    final carbsCal = (calories * c).round();
    final fatCal = (calories * f).round();
    return {
      'protein_g': (proteinCal / 4).round(),
      'carbs_g': (carbsCal / 4).round(),
      'fat_g': (fatCal / 9).round(),
    };
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class _Point {
  final double distance;
  final int calories;
  _Point({required this.distance, required this.calories});
}
