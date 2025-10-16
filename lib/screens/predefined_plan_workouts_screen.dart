import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'workout_tts_dialog.dart';

class PredefinedPlanWorkoutsScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final String? planId;

  const PredefinedPlanWorkoutsScreen({super.key, required this.plan, this.planId});

  @override
  State<PredefinedPlanWorkoutsScreen> createState() => _PredefinedPlanWorkoutsScreenState();
}

class _PredefinedPlanWorkoutsScreenState extends State<PredefinedPlanWorkoutsScreen> {
  @override
  void dispose() {
    // Ensure any ongoing TTS is stopped when leaving this screen
    FlutterTts().stop();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final planMap = widget.plan['plan'] as Map<String, dynamic>? ?? {};
    final days = (planMap['days'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    return WillPopScope(
      onWillPop: () async {
        // Stop any ongoing TTS when user presses back
        await FlutterTts().stop();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.plan['title']?.toString() ?? 'Plan Workouts'),
          backgroundColor: const Color.fromARGB(255, 238, 255, 65),
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: days.isEmpty
            ? const Center(child: Text('No workouts found in this plan.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final exercises = (day['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
                  final dayTitle = (day['title'] ?? 'Day ${index + 1}').toString();
                  return _DayCard(
                    title: dayTitle,
                    exercises: exercises,
                  );
                },
              ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> exercises;

  const _DayCard({required this.title, required this.exercises});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: exercises
              .asMap()
              .entries
              .map((e) => _ExerciseTile(exercise: e.value))
              .toList(),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatefulWidget {
  final Map<String, dynamic> exercise;
  const _ExerciseTile({required this.exercise});

  @override
  State<_ExerciseTile> createState() => _ExerciseTileState();
}

class _ExerciseTileState extends State<_ExerciseTile> {
  bool _loading = false;

  Future<void> _openWithDetails(BuildContext context) async {
    setState(() => _loading = true);
    try {
      // Try to resolve full workout details by sourceWorkoutId
      final sourceId = widget.exercise['sourceWorkoutId']?.toString();
      String gifUrl = '';
      String instructions = '';
      String warning = '';

      if (sourceId != null && sourceId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('workouts').doc(sourceId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          gifUrl = (data['gifUrl'] ?? data['gif'] ?? '').toString();
          instructions = (data['instructions'] ?? '').toString();
          warning = (data['warnings'] ?? data['warning'] ?? '').toString();
        }
      }

      // Fallback: basic info from the exercise item
      instructions = instructions.isNotEmpty
          ? instructions
          : 'Perform ${widget.exercise['name'] ?? 'exercise'}. Sets: ${widget.exercise['sets'] ?? '-'}, Reps: ${widget.exercise['reps'] ?? '-'}.';

      await openWorkoutDialog(
        context: context,
        gifUrl: gifUrl,
        instructions: instructions,
        warning: warning,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.exercise['name'] ?? 'Exercise').toString();
    final sets = (widget.exercise['sets'] ?? '').toString();
    final reps = (widget.exercise['reps'] ?? '').toString();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF667eea).withOpacity(0.12),
        child: const Icon(Icons.fitness_center, color: Color(0xFF667eea)),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          if (sets.isNotEmpty || reps.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Sets $sets  Reps $reps', style: const TextStyle(color: Colors.orange)),
            ),
        ],
      ),
      trailing: _loading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: const Icon(Icons.play_circle_fill, color: Colors.green),
              onPressed: () => _openWithDetails(context),
            ),
      onTap: () => _openWithDetails(context),
    );
  }
}
