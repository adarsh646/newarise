import 'package:flutter/material.dart';
import '../services/calorie_knn.dart';

class CaloriePredictionCard extends StatelessWidget {
  final UserSurvey survey;
  final List<Map<String, dynamic>>? dataset;

  const CaloriePredictionCard({super.key, required this.survey, this.dataset});

  @override
  Widget build(BuildContext context) {
    final result = CalorieKNN.predict(survey, dataset: dataset);
    final calories = result.calories;
    final protein = result.macros['protein_g'] ?? 0;
    final carbs = result.macros['carbs_g'] ?? 0;
    final fat = result.macros['fat_g'] ?? 0;

    final totalMacroCal = protein * 4 + carbs * 4 + fat * 9;
    double pPct = totalMacroCal == 0 ? 0 : (protein * 4) / totalMacroCal;
    double cPct = totalMacroCal == 0 ? 0 : (carbs * 4) / totalMacroCal;
    double fPct = totalMacroCal == 0 ? 0 : (fat * 9) / totalMacroCal;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Calorie Target',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$calories kcal',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _macroRow('Protein', protein, Colors.purple, pPct),
            const SizedBox(height: 8),
            _macroRow('Carbs', carbs, Colors.green, cPct),
            const SizedBox(height: 8),
            _macroRow('Fat', fat, Colors.orange, fPct),
            const SizedBox(height: 16),
            const Text('Suggestions', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _bullets([
              'Aim for $protein g protein spread across meals.',
              'Prioritize whole grains, fruits, and vegetables for ~$carbs g carbs.',
              'Include healthy fats (nuts, olive oil, fish) for ~$fat g fat.',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _macroRow(String label, int grams, Color color, double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$grams g'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct.clamp(0, 1),
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _bullets(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(e)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
