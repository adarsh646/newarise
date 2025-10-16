import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

Future<void> openWorkoutDialog({
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
    if (instructions.trim().isNotEmpty) parts.add('Instructions: $instructions');
    if (warning.trim().isNotEmpty) parts.add('Warning: $warning');
    if (parts.isEmpty) return;
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.5);
    await tts.speak(parts.join('. '));
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _formatTime(seconds),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                              const Icon(Icons.warning_amber_outlined, color: Color(0xFFFFA000)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  warning,
                                  style: const TextStyle(color: Color(0xFF6D4C41)),
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
                                timer = Timer.periodic(const Duration(seconds: 1), (_) {
                                  setState(() => seconds += 1);
                                });
                                speakAll();
                              } else {
                                timer?.cancel();
                                timer = null;
                              }
                            },
                            icon: Icon((timer == null) ? Icons.play_arrow : Icons.pause),
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
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
