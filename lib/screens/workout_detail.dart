import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final String exerciseName;

  const WorkoutDetailScreen({super.key, required this.exerciseName});

  Future<Map<String, dynamic>?> _fetchTrainerWorkout() async {
    try {
      final col = FirebaseFirestore.instance.collection('workouts');

      // 1) Try exact name match
      final exact = await col
          .where('name', isEqualTo: exerciseName)
          .limit(1)
          .get();
      if (exact.docs.isNotEmpty) return exact.docs.first.data();

      // 2) Try case-insensitive by scanning a small subset
      final snap = await col.limit(25).get();
      Map<String, dynamic>? best;
      for (final d in snap.docs) {
        final data = d.data();
        final n = (data['name'] ?? '').toString();
        if (n.toLowerCase() == exerciseName.toLowerCase()) {
          best = data;
          break;
        }
        final aliases =
            (data['aliases'] as List?)
                ?.map((e) => e.toString().toLowerCase())
                .toList() ??
            const [];
        if (aliases.contains(exerciseName.toLowerCase())) {
          best = data;
          break;
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exerciseName),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchTrainerWorkout(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null) {
            return _fallbackContent();
          }

          final instructions = (data['instructions'] ?? '').toString();
          final gifUrl = (data['gifUrl'] ?? data['gif'] ?? '').toString();
          final warnings = (data['warnings'] ?? '').toString();
          final tools = (data['tools'] ?? '').toString();
          final category = (data['category'] ?? '').toString();
          final muscleGroup = (data['muscleGroup'] ?? '').toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gifUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      gifUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _imagePlaceholder(),
                    ),
                  )
                else
                  _imagePlaceholder(),
                const SizedBox(height: 16),
                _chipRow(
                  category: category,
                  muscleGroup: muscleGroup,
                  tools: tools,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Instructions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  instructions.isNotEmpty
                      ? instructions
                      : 'No detailed instructions available for this exercise yet.',
                  style: TextStyle(color: Colors.grey[800], height: 1.5),
                ),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_outlined,
                          color: Color(0xFFFFA000),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Warnings',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6D4C41),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                warnings,
                                style: const TextStyle(
                                  color: Color(0xFF6D4C41),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openWorkoutDialog(
                      context: context,
                      gifUrl: gifUrl,
                      instructions: instructions,
                      warning: warnings,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fallbackContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _imagePlaceholder(),
          const SizedBox(height: 16),
          const Text(
            'Instructions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Detailed trainer instructions are not available for this exercise yet. Try checking back later.',
            style: TextStyle(color: Colors.grey[800], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text('No GIF available', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _chipRow({
    required String category,
    required String muscleGroup,
    required String tools,
  }) {
    final chips = <Widget>[];
    if (category.isNotEmpty) {
      chips.add(_chip('Category: $category', const Color(0xFF2196F3)));
    }
    if (muscleGroup.isNotEmpty) {
      chips.add(_chip('Muscle: $muscleGroup', const Color(0xFF4CAF50)));
    }
    if (tools.isNotEmpty) {
      chips.add(_chip('Tools: $tools', const Color(0xFF9C27B0)));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Popup dialog with GIF, TTS and a simple timer
Future<void> _openWorkoutDialog({
  required BuildContext context,
  required String gifUrl,
  required String instructions,
  required String warning,
}) async {
  final tts = FlutterTts();
  int seconds = 0;
  Timer? timer;

  Future<void> speakAll() async {
    final parts = <String>[];
    if (instructions.trim().isNotEmpty)
      parts.add('Instructions: $instructions');
    if (warning.trim().isNotEmpty) parts.add('Warning: $warning');
    if (parts.isEmpty) return;
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.5);
    await tts.speak(parts.join('. '));
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: gifUrl.isNotEmpty
                      ? Image.network(
                          gifUrl,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : _DialogImagePlaceholder(),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Workout Running',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatTime(seconds),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (warning.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFE0B2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_outlined,
                                color: Color(0xFFFFA000),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  warning,
                                  style: const TextStyle(
                                    color: Color(0xFF6D4C41),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        instructions.isNotEmpty
                            ? instructions
                            : 'Follow along with proper form and breathing. Stay hydrated.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              if (timer == null) {
                                timer = Timer.periodic(
                                  const Duration(seconds: 1),
                                  (_) {
                                    setState(() => seconds += 1);
                                  },
                                );
                                speakAll();
                              } else {
                                timer?.cancel();
                                timer = null;
                              }
                            },
                            icon: Icon(
                              (timer == null) ? Icons.play_arrow : Icons.pause,
                            ),
                            label: Text((timer == null) ? 'Start' : 'Pause'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              timer?.cancel();
                              timer = null;
                              setState(() => seconds = 0);
                              tts.stop();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              timer?.cancel();
                              tts.stop();
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String _formatTime(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _DialogImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text('No GIF available', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
