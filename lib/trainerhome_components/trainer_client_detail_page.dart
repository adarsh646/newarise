import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arise/trainerhome_components/client_plan.dart';

class TrainerClientDetailPage extends StatefulWidget {
  final String clientId;
  final String clientName;

  const TrainerClientDetailPage({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  State<TrainerClientDetailPage> createState() =>
      _TrainerClientDetailPageState();
}

class _TrainerClientDetailPageState extends State<TrainerClientDetailPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        children: [
          // Page 1: Survey Details
          _buildSurveyDetailsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        color: const Color.fromARGB(255, 238, 255, 65),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                style: TextButton.styleFrom(
                  backgroundColor: _currentPage == 0
                      ? Colors.blue
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Survey',
                  style: TextStyle(
                    color: _currentPage == 0 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientPlanPage(
                        clientId: widget.clientId,
                        clientName: widget.clientName,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'AI Plans',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ PAGE 1: SURVEY DETAILS ============
  Widget _buildSurveyDetailsPage() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('surveys')
          .doc(widget.clientId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No survey data available'),
              ],
            ),
          );
        }

        final survey = snapshot.data!.data() as Map<String, dynamic>;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionCard(
              title: 'Personal Information',
              children: [
                _buildInfoRow('Age', '${survey['age'] ?? 'N/A'} years'),
                _buildInfoRow('Gender', survey['gender'] ?? 'N/A'),
                _buildInfoRow('Height', '${survey['height'] ?? 'N/A'} cm'),
                _buildInfoRow('Weight', '${survey['weight'] ?? 'N/A'} kg'),
                _buildInfoRow('BMI', survey['bmi'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Fitness Profile',
              children: [
                _buildInfoRow('Fitness Goal', survey['goal'] ?? 'N/A'),
                _buildInfoRow(
                  'Activity Level',
                  survey['activityLevel'] ?? 'N/A',
                ),
                _buildInfoRow(
                  'Days Per Week',
                  '${survey['daysPerWeek'] ?? 'N/A'} days',
                ),
                _buildInfoRow(
                  'Session Duration',
                  '${survey['sessionDuration'] ?? 'N/A'} mins',
                ),
                _buildInfoRow(
                  'Plan Duration',
                  '${survey['planDurationWeeks'] ?? 'N/A'} weeks',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ============ PAGE 2: AI WORKOUT PLANS ============
  Widget _buildAIWorkoutPlansPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Open full trainer plan view'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientPlanPage(
                      clientId: widget.clientId,
                      clientName: widget.clientName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open AI Plans'),
            ),
          ],
        ),
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
        subtitle: Row(
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
            const SizedBox(width: 8),
            if (createdAt != null)
              Text(
                'Created: ${_formatDate(createdAt.toDate())}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                const Text(
                  'Plan Details',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildDetailBox('Total Days', '$daysCount days'),
                const SizedBox(height: 8),
                _buildDetailBox(
                  'Fitness Goal',
                  planData['plan']?['goal'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildDetailBox('Level', planData['plan']?['level'] ?? 'N/A'),
                const SizedBox(height: 16),
                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _viewPlanDetails(context, planData, planId),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _editPlan(context, planId, planData),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _deletePlan(context, planId, planTitle),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
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

  void _viewPlanDetails(
    BuildContext context,
    Map<String, dynamic> planData,
    String planId,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Plan: ${planData['title']}')),
    );
  }

  // ============ EDIT PLAN ============
  void _editPlan(
    BuildContext context,
    String planId,
    Map<String, dynamic> planData,
  ) {
    final titleController = TextEditingController(
      text: planData['title'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: planData['description'] ?? '',
    );

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
                    // Rebuild the page
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

  // ============ DELETE PLAN ============
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
                    // Rebuild the page
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

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Text(value, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
        ],
      ),
    );
  }

  void _showEditPlanDialog(
    BuildContext context,
    String planId,
    Map<String, dynamic> planData,
  ) {
    final titleController = TextEditingController(
      text: planData['title'] ?? '',
    );
    final descController = TextEditingController(
      text: planData['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Plan Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updatePlanDetails(
                planId,
                titleController.text,
                descController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePlanDetails(
    String planId,
    String title,
    String description,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('fitness_plans')
          .doc(planId)
          .update({'title': title, 'description': description});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan updated successfully')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating plan: $e')));
    }
  }

  Future<void> _confirmUnassignPlan(String planId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text(
          'Are you sure you want to delete this plan? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('plan_progress')
                    .doc(widget.clientId)
                    .update({planId: FieldValue.delete()});

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plan deleted successfully')),
                  );
                  setState(() {});
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting plan: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
