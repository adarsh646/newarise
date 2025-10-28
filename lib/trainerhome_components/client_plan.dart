import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arise/screens/workout_plan_display.dart';
import 'package:arise/trainerhome_components/client_progress.dart';

class ClientPlanPage extends StatefulWidget {
  final String clientId;
  final String clientName;

  const ClientPlanPage({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  State<ClientPlanPage> createState() => _ClientPlanPageState();
}

class _ClientPlanPageState extends State<ClientPlanPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        title: Text(
          widget.clientName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('fitness_plans')
            .where('userId', isEqualTo: widget.clientId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No AI workout plans generated yet'),
                    ],
                  ),
                ),
              ],
            );
          }

          // Filter relevant sources and sort by createdAt desc
          final List<QueryDocumentSnapshot> aiPlans = snapshot.data!.docs
              .where((doc) {
                final source = doc['source'] as String?;
                return source == 'rapidapi' ||
                    source == 'rapidapi+fallback' ||
                    source == 'local_network_fallback' ||
                    source == 'ai' ||
                    source == null; // fallback if not set
              })
              .toList()
            ..sort((a, b) {
              final dateA = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
              final dateB = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
              return dateB.compareTo(dateA);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: aiPlans.length,
            itemBuilder: (context, index) {
              final planDoc = aiPlans[index];
              final planData = planDoc.data() as Map<String, dynamic>;
              return _buildAIPlanCard(context, planDoc.id, planData);
            },
          );
        },
      ),
    );
  }

  Widget _buildAIPlanCard(
    BuildContext context,
    String planId,
    Map<String, dynamic> planData,
  ) {
    final planTitle = planData['title'] ?? 'AI Workout Plan';
    final planDescription = planData['description'] ?? '';
    final source = planData['source'] ?? 'AI Generated';
    final createdAt = planData['createdAt'] as Timestamp?;
    final planMap = planData['plan'] as Map<String, dynamic>? ?? {};
    final daysCount = ((planMap['days'] as List?) ?? []).length;

    String sourceLabel = '';
    Color sourceBadgeColor = Colors.blue;

    switch (source) {
      case 'rapidapi':
        sourceLabel = 'AI Generated (RapidAPI)';
        sourceBadgeColor = Colors.blue;
        break;
      case 'rapidapi+fallback':
        sourceLabel = 'AI Generated (With Fallback)';
        sourceBadgeColor = Colors.orange;
        break;
      case 'local_network_fallback':
        sourceLabel = 'AI Generated (Local)';
        sourceBadgeColor = Colors.amber;
        break;
      default:
        sourceLabel = 'AI Generated';
        sourceBadgeColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.blue, width: 2),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.auto_awesome, color: Colors.blue),
        title: Text(
          planTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: sourceBadgeColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sourceLabel,
                style: TextStyle(
                  color: sourceBadgeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (createdAt != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  'Created: ${_formatDate(createdAt.toDate())}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (planDescription.isNotEmpty) ...[
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(planDescription),
                  const SizedBox(height: 16),
                ],
                // Actions (wrapped to avoid overflow)
                Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 130,
                      child: ElevatedButton.icon(
                        onPressed: () => _viewPlanDetails(context, planData, planId),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddWorkoutDialog(context, planId, planData),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: ElevatedButton.icon(
                        onPressed: () => _editPlan(context, planId, planData),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: ElevatedButton.icon(
                        onPressed: () => _deletePlan(context, planId, planTitle),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Manage workouts per day
                const Text(
                  'Manage Workouts',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...List.generate(((planMap['days'] as List?) ?? []).length, (dayIdx) {
                  final day = (planMap['days'] as List)[dayIdx] as Map<String, dynamic>? ?? {};
                  final dayTitle = day['title'] ?? 'Day ${dayIdx + 1}';
                  final exercises = (day['exercises'] as List?) ?? [];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      title: Text(dayTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text('${exercises.length} exercises'),
                      children: [
                        if (exercises.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No exercises'),
                          )
                        else
                          ...List.generate(exercises.length, (exIdx) {
                            final ex = exercises[exIdx] as Map<String, dynamic>? ?? {};
                            final name = ex['name'] ?? 'Workout';
                            final sets = ex['sets']?.toString() ?? '-';
                            final reps = ex['reps']?.toString() ?? '-';
                            return ListTile(
                              title: Text(name),
                              subtitle: Text('Sets: $sets • Reps: $reps'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    await _showEditExerciseDialog(context, planId, dayIdx, exIdx, ex);
                                  } else if (val == 'delete') {
                                    await _deleteExerciseFromDay(planId: planId, dayIndex: dayIdx, exerciseIndex: exIdx);
                                    if (mounted) setState(() {});
                                  } else if (val == 'change') {
                                    await _showChangeWorkoutDialog(context, planId, dayIdx, exIdx, ex);
                                    if (mounted) setState(() {});
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'change', child: Text('Change Workout')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    if (value is num) return value.toInt();
    return fallback;
  }

  void _viewPlanDetails(
    BuildContext context,
    Map<String, dynamic> planData,
    String planId,
  ) {
    final plan = planData;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProgressPage(
          clientId: widget.clientId,
          clientName: widget.clientName,
          planId: planId,
          planTitle: plan['title'] ?? 'AI Workout Plan',
        ),
      ),
    );
  }

  Future<void> _showAddWorkoutDialog(
    BuildContext context,
    String planId,
    Map<String, dynamic> planData,
  ) async {
    final planMap = planData['plan'] as Map<String, dynamic>? ?? {};
    final List days = (planMap['days'] as List?) ?? [];
    if (days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No days found in this plan')),
      );
      return;
    }

    int selectedDayIndex = 0;
    String? selectedWorkoutId;
    Map<String, dynamic>? selectedWorkoutData;
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '12');

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Add Workout to Plan'),
          content: StatefulBuilder(
            builder: (ctx, setStateSB) {
              return SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Day'),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: selectedDayIndex,
                      isExpanded: true,
                      items: List.generate(days.length, (i) {
                        final day = days[i] as Map<String, dynamic>? ?? {};
                        final title = (day['title'] as String?) ?? 'Day ${i + 1}';
                        return DropdownMenuItem<int>(
                          value: i,
                          child: Text(title),
                        );
                      }),
                      onChanged: (v) => setStateSB(() => selectedDayIndex = v ?? 0),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Workout'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('workouts')
                            .orderBy('name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('No workouts found'));
                          }
                          final docs = snapshot.data!.docs;
                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (_, i) {
                              final doc = docs[i];
                              final data = doc.data() as Map<String, dynamic>;
                              final isSelected = selectedWorkoutId == doc.id;
                              return ListTile(
                                title: Text(data['name'] ?? 'Unnamed'),
                                subtitle: Text(data['category'] ?? ''),
                                trailing: isSelected
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : null,
                                onTap: () => setStateSB(() {
                                  selectedWorkoutId = doc.id;
                                  selectedWorkoutData = data;
                                }),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: setsController,
                            decoration: const InputDecoration(
                              labelText: 'Sets',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: repsController,
                            decoration: const InputDecoration(
                              labelText: 'Reps',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: selectedWorkoutId == null
                  ? null
                  : () async {
                      try {
                        await _appendWorkoutToDay(
                          planId: planId,
                          dayIndex: selectedDayIndex,
                          exercise: {
                            'name': selectedWorkoutData?['name'] ?? 'Workout',
                            'sets': int.tryParse(setsController.text.trim()) ?? 3,
                            'reps': int.tryParse(repsController.text.trim()) ?? 12,
                            'category': selectedWorkoutData?['category'] ?? '',
                            'source': 'trainer_manual',
                            'workoutRef': selectedWorkoutId,
                          },
                        );
                        if (mounted) Navigator.pop(dialogCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Workout added to plan')),
                          );
                          setState(() {});
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.save),
              label: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _appendWorkoutToDay({
    required String planId,
    required int dayIndex,
    required Map<String, dynamic> exercise,
  }) async {
    final ref = FirebaseFirestore.instance.collection('fitness_plans').doc(planId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Plan not found');
      final data = snap.data() as Map<String, dynamic>;
      final plan = (data['plan'] as Map<String, dynamic>? ?? {});
      final List days = (plan['days'] as List?)?.toList() ?? [];
      if (dayIndex < 0 || dayIndex >= days.length) {
        throw Exception('Invalid day index');
      }
      final day = (days[dayIndex] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
      final List exercises = (day['exercises'] as List?)?.toList() ?? [];
      exercises.add(exercise);
      day['exercises'] = exercises;
      days[dayIndex] = day;
      plan['days'] = days;
      final newData = {'plan': plan, 'updatedAt': FieldValue.serverTimestamp()};
      tx.update(ref, newData);
    });
  }

  Future<void> _showChangeWorkoutDialog(
    BuildContext context,
    String planId,
    int dayIndex,
    int exerciseIndex,
    Map<String, dynamic> currentExercise,
  ) async {
    final selectedWorkoutId = ValueNotifier<String?>(null);
    final selectedWorkoutData = ValueNotifier<Map<String, dynamic>?>(null);
    final keepSetsReps = ValueNotifier<bool>(true);
    final setsController = TextEditingController(text: (currentExercise['sets']?.toString() ?? '3'));
    final repsController = TextEditingController(text: (currentExercise['reps']?.toString() ?? '12'));

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Change Workout'),
        content: StatefulBuilder(
          builder: (ctx, setStateSB) {
            return SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select New Workout'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('workouts')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('No workouts found'));
                        }
                        final docs = snapshot.data!.docs;
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final doc = docs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final isSelected = selectedWorkoutId.value == doc.id;
                            return ListTile(
                              title: Text(data['name'] ?? 'Unnamed'),
                              subtitle: Text(data['category'] ?? ''),
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                              onTap: () => setStateSB(() {
                                selectedWorkoutId.value = doc.id;
                                selectedWorkoutData.value = data;
                              }),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: keepSetsReps,
                        builder: (context, keep, _) => Checkbox(
                          value: keep,
                          onChanged: (v) => keepSetsReps.value = v ?? true,
                        ),
                      ),
                      const Text('Keep current sets & reps'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: keepSetsReps,
                    builder: (context, keep, _) {
                      if (keep) return const SizedBox.shrink();
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: setsController,
                              decoration: const InputDecoration(labelText: 'Sets', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: repsController,
                              decoration: const InputDecoration(labelText: 'Reps', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ValueListenableBuilder<String?>(
            valueListenable: selectedWorkoutId,
            builder: (context, selId, _) => ElevatedButton.icon(
              onPressed: selId == null
                  ? null
                  : () async {
                      try {
                        final keep = keepSetsReps.value;
                        final int newSets =
                            keep ? _asInt(currentExercise['sets'], 3) : (int.tryParse(setsController.text.trim()) ?? 3);
                        final int newReps =
                            keep ? _asInt(currentExercise['reps'], 12) : (int.tryParse(repsController.text.trim()) ?? 12);
                        final data = selectedWorkoutData.value ?? {};
                        await _replaceExerciseInDay(
                          planId: planId,
                          dayIndex: dayIndex,
                          exerciseIndex: exerciseIndex,
                          newExercise: {
                            'name': data['name'] ?? 'Workout',
                            'category': data['category'] ?? '',
                            'workoutRef': selId,
                            'source': 'trainer_manual_change',
                            'sets': newSets,
                            'reps': newReps,
                          },
                        );
                        if (mounted) Navigator.pop(dialogCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Workout changed')),
                          );
                          setState(() {});
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Replace'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _replaceExerciseInDay({
    required String planId,
    required int dayIndex,
    required int exerciseIndex,
    required Map<String, dynamic> newExercise,
  }) async {
    final ref = FirebaseFirestore.instance.collection('fitness_plans').doc(planId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Plan not found');
      final data = snap.data() as Map<String, dynamic>;
      final plan = (data['plan'] as Map<String, dynamic>? ?? {});
      final List days = (plan['days'] as List?)?.toList() ?? [];
      if (dayIndex < 0 || dayIndex >= days.length) throw Exception('Invalid day index');
      final day = (days[dayIndex] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
      final List exercises = (day['exercises'] as List?)?.toList() ?? [];
      if (exerciseIndex < 0 || exerciseIndex >= exercises.length) throw Exception('Invalid exercise index');
      exercises[exerciseIndex] = newExercise;
      day['exercises'] = exercises;
      days[dayIndex] = day;
      plan['days'] = days;
      tx.update(ref, {'plan': plan, 'updatedAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> _deleteExerciseFromDay({
    required String planId,
    required int dayIndex,
    required int exerciseIndex,
  }) async {
    final ref = FirebaseFirestore.instance.collection('fitness_plans').doc(planId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Plan not found');
      final data = snap.data() as Map<String, dynamic>;
      final plan = (data['plan'] as Map<String, dynamic>? ?? {});
      final List days = (plan['days'] as List?)?.toList() ?? [];
      if (dayIndex < 0 || dayIndex >= days.length) throw Exception('Invalid day index');
      final day = (days[dayIndex] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
      final List exercises = (day['exercises'] as List?)?.toList() ?? [];
      if (exerciseIndex < 0 || exerciseIndex >= exercises.length) throw Exception('Invalid exercise index');
      exercises.removeAt(exerciseIndex);
      day['exercises'] = exercises;
      days[dayIndex] = day;
      plan['days'] = days;
      tx.update(ref, {'plan': plan, 'updatedAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> _showEditExerciseDialog(
    BuildContext context,
    String planId,
    int dayIndex,
    int exerciseIndex,
    Map<String, dynamic> exercise,
  ) async {
    final setsController = TextEditingController(text: (exercise['sets']?.toString() ?? '3'));
    final repsController = TextEditingController(text: (exercise['reps']?.toString() ?? '12'));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Exercise'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: setsController,
                decoration: const InputDecoration(labelText: 'Sets', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: repsController,
                decoration: const InputDecoration(labelText: 'Reps', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final parsedSets = int.tryParse(setsController.text.trim());
              final parsedReps = int.tryParse(repsController.text.trim());

              final sets = parsedSets ?? _asInt(exercise['sets'], 3);
              final reps = parsedReps ?? _asInt(exercise['reps'], 12);

              // Validation: sets 1-5, reps 1-19
              if (sets < 1 || sets >= 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Sets must be between 1 and 5')),
                );
                return;
              }
              if (reps < 1 || reps >= 20) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reps must be between 1 and 19')),
                );
                return;
              }

              await _updateExerciseInDay(
                planId: planId,
                dayIndex: dayIndex,
                exerciseIndex: exerciseIndex,
                sets: sets,
                reps: reps,
              );
              if (mounted) setState(() {});
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateExerciseInDay({
    required String planId,
    required int dayIndex,
    required int exerciseIndex,
    required int sets,
    required int reps,
  }) async {
    final ref = FirebaseFirestore.instance.collection('fitness_plans').doc(planId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Plan not found');
      final data = snap.data() as Map<String, dynamic>;
      final plan = (data['plan'] as Map<String, dynamic>? ?? {});
      final List days = (plan['days'] as List?)?.toList() ?? [];
      if (dayIndex < 0 || dayIndex >= days.length) throw Exception('Invalid day index');
      final day = (days[dayIndex] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
      final List exercises = (day['exercises'] as List?)?.toList() ?? [];
      if (exerciseIndex < 0 || exerciseIndex >= exercises.length) throw Exception('Invalid exercise index');
      final ex = (exercises[exerciseIndex] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
      ex['sets'] = sets;
      ex['reps'] = reps;
      exercises[exerciseIndex] = ex;
      day['exercises'] = exercises;
      days[dayIndex] = day;
      plan['days'] = days;
      tx.update(ref, {'plan': plan, 'updatedAt': FieldValue.serverTimestamp()});
    });
  }

  void _editPlan(
    BuildContext context,
    String planId,
    Map<String, dynamic> planData,
  ) {
    final titleController = TextEditingController(text: planData['title'] ?? '');
    final descriptionController =
        TextEditingController(text: planData['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Workout Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Plan Title',
                    border: OutlineInputBorder(),
                    hintText: 'Enter plan title',
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Plan Description',
                    border: OutlineInputBorder(),
                    hintText: 'Enter plan description',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('fitness_plans')
                      .doc(planId)
                      .update({
                        'title': titleController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Plan updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        );
      },
    );
  }

  void _deletePlan(BuildContext context, String planId, String planTitle) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Plan?'),
          content: Text(
            'Are you sure you want to delete the plan "$planTitle"?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('fitness_plans')
                      .doc(planId)
                      .delete();

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Plan deleted successfully'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 238, 255, 65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
