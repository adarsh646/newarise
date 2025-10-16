import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/role_helper.dart';

class WorkoutDetailsPage extends StatelessWidget {
  final String workoutId;
  const WorkoutDetailsPage({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Details'),
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('workouts')
            .doc(workoutId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load workout'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data()!;
          final String? gifUrl = data['gifUrl'];
          final String? videoUrl = data['videoUrl'];
          final String name = data['name'] ?? 'Workout';
          final String tools = data['tools'] ?? 'N/A';
          final String instructions = data['instructions'] ?? '';
          final String warnings = data['warnings'] ?? '';
          final String trainerId = data['trainerId'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tools: $tools'),
                const SizedBox(height: 16),
                if (gifUrl != null && gifUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      gifUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          height: 220,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      (progress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        height: 220,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 48),
                        ),
                      ),
                    ),
                  ),
                if ((gifUrl == null || gifUrl.isEmpty) &&
                    (videoUrl == null || videoUrl.isEmpty))
                  const Text('No media attached'),
                const SizedBox(height: 16),
                const Text(
                  'Instructions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(instructions.isNotEmpty ? instructions : '—'),
                const SizedBox(height: 16),
                const Text(
                  'Warnings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(warnings.isNotEmpty ? warnings : '—'),
                const SizedBox(height: 16),
                // Show Start button only to regular users
                FutureBuilder<String?>(
                  future: RoleHelper.getCurrentUserRole(),
                  builder: (context, roleSnap) {
                    final role = roleSnap.data;
                    if (role == 'user') {
                      return Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () async {
                            final tts = FlutterTts();
                            await tts.setLanguage('en-US');
                            await tts.setSpeechRate(0.45);
                            await tts.setVolume(1.0);
                            await tts.setPitch(1.0);

                            await showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) {
                                // Start speaking warnings when dialog builds
                                () async {
                                  final toSpeak = (warnings.isNotEmpty)
                                      ? warnings
                                      : 'No specific warnings. Please proceed carefully and stop if you feel any pain.';
                                  await tts.stop();
                                  await tts.speak(toSpeak);
                                }();
                                return AlertDialog(
                                  title: const Text('Workout Instructions'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (gifUrl != null && gifUrl.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              gifUrl,
                                              height: 180,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stack) => Container(
                                                height: 180,
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: Icon(Icons.image_not_supported, size: 48),
                                                ),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Instructions',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(instructions.isNotEmpty ? instructions : '—'),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Warnings (spoken out loud)',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(warnings.isNotEmpty ? warnings : 'No specific warnings.'),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton.icon(
                                      onPressed: () async {
                                        await tts.stop();
                                      },
                                      icon: const Icon(Icons.volume_off),
                                      label: const Text('Mute warnings'),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        await tts.stop();
                                        if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                                      },
                                      child: const Text('Start Now'),
                                    ),
                                  ],
                                );
                              },
                            );

                            await tts.stop();
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 24),
                FutureBuilder<bool>(
                  future: RoleHelper.canDeleteWorkout(trainerId),
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Delete button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete workout?'),
                                  content: const Text('This action cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('workouts')
                                    .doc(workoutId)
                                    .delete();
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete workout'),
                          ),
                          const SizedBox(height: 12),
                          // Unified Edit button
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: () async {
                              final nameController = TextEditingController(text: name);
                              final toolsController = TextEditingController(text: tools);
                              final targetController = TextEditingController(text: data['target'] ?? '');
                              final equipmentController = TextEditingController(text: data['equipment'] ?? '');
                              final tipsController = TextEditingController(text: data['tips'] ?? '');
                              final instrController = TextEditingController(text: instructions);
                              final warnController = TextEditingController(text: warnings);

                              // Local state for picked files and current URLs
                              PlatformFile? pickedGif;
                              PlatformFile? pickedVideo;
                              String? gifUrlLocal = gifUrl;
                              String? videoUrlLocal = videoUrl;

                              final formKey = GlobalKey<FormState>();

                              await showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Edit workout'),
                                  content: Form(
                                    key: formKey,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextFormField(
                                            controller: nameController,
                                            decoration: const InputDecoration(
                                              labelText: 'Name',
                                              border: OutlineInputBorder(),
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: toolsController,
                                            decoration: const InputDecoration(
                                              labelText: 'Tools',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          // Choose GIF file instead of typing URL
                                          StatefulBuilder(
                                            builder: (context, setState) => Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () async {
                                                    final res = await FilePicker.platform.pickFiles(
                                                      type: FileType.custom,
                                                      allowedExtensions: ['gif'],
                                                      withData: true,
                                                    );
                                                    if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
                                                      pickedGif = res.files.first;
                                                      setState(() {});
                                                    }
                                                  },
                                                  icon: const Icon(Icons.image),
                                                  label: const Text('Choose GIF image'),
                                                ),
                                                Text(
                                                  pickedGif != null
                                                      ? 'Selected: ${pickedGif!.name}'
                                                      : (gifUrlLocal != null && gifUrlLocal!.isNotEmpty
                                                          ? 'Current GIF is set'
                                                          : 'No GIF selected'),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          // Choose Video file instead of typing URL
                                          StatefulBuilder(
                                            builder: (context, setState) => Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () async {
                                                    final res = await FilePicker.platform.pickFiles(
                                                      type: FileType.custom,
                                                      allowedExtensions: ['mp4', 'mov', 'avi', 'webm'],
                                                      withData: true,
                                                    );
                                                    if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
                                                      pickedVideo = res.files.first;
                                                      setState(() {});
                                                    }
                                                  },
                                                  icon: const Icon(Icons.video_file),
                                                  label: const Text('Choose Video'),
                                                ),
                                                Text(
                                                  pickedVideo != null
                                                      ? 'Selected: ${pickedVideo!.name}'
                                                      : (videoUrlLocal != null && videoUrlLocal!.isNotEmpty
                                                          ? 'Current video is set'
                                                          : 'No video selected'),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: targetController,
                                            decoration: const InputDecoration(
                                              labelText: 'Target muscle/area',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: equipmentController,
                                            decoration: const InputDecoration(
                                              labelText: 'Equipment',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: tipsController,
                                            maxLines: 3,
                                            decoration: const InputDecoration(
                                              labelText: 'Tips',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: instrController,
                                            maxLines: 5,
                                            decoration: const InputDecoration(
                                              labelText: 'Instructions',
                                              alignLabelWithHint: true,
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: warnController,
                                            maxLines: 4,
                                            decoration: const InputDecoration(
                                              labelText: 'Warnings',
                                              alignLabelWithHint: true,
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.save),
                                      onPressed: () async {
                                        if (!formKey.currentState!.validate()) return;
                                        // Upload picked GIF if any
                                        String? newGifUrl = gifUrlLocal;
                                        String? newVideoUrl = videoUrlLocal;
                                        if (pickedGif != null && pickedGif!.bytes != null) {
                                          final ext = pickedGif!.extension ?? 'gif';
                                          final ref = FirebaseStorage.instance
                                              .ref('workouts/$workoutId/gif_${DateTime.now().millisecondsSinceEpoch}.$ext');
                                          await ref.putData(pickedGif!.bytes!);
                                          newGifUrl = await ref.getDownloadURL();
                                        }
                                        // Upload picked Video if any
                                        if (pickedVideo != null && pickedVideo!.bytes != null) {
                                          final ext = pickedVideo!.extension ?? 'mp4';
                                          final ref = FirebaseStorage.instance
                                              .ref('workouts/$workoutId/video_${DateTime.now().millisecondsSinceEpoch}.$ext');
                                          await ref.putData(pickedVideo!.bytes!);
                                          newVideoUrl = await ref.getDownloadURL();
                                        }

                                        await FirebaseFirestore.instance
                                            .collection('workouts')
                                            .doc(workoutId)
                                            .update({
                                          'name': nameController.text.trim(),
                                          'tools': toolsController.text.trim(),
                                          'gifUrl': (newGifUrl ?? '').trim(),
                                          'videoUrl': (newVideoUrl ?? '').trim(),
                                          'target': targetController.text.trim(),
                                          'equipment': equipmentController.text.trim(),
                                          'tips': tipsController.text.trim(),
                                          'instructions': instrController.text.trim(),
                                          'warnings': warnController.text.trim(),
                                        });
                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Workout updated')),
                                          );
                                        }
                                      },
                                      label: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit workout'),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}