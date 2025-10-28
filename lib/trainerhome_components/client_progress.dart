import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

class ClientProgressPage extends StatelessWidget {
  final String clientId;
  final String clientName;
  final String planId;
  final String planTitle;

  const ClientProgressPage({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.planId,
    required this.planTitle,
  });

  @override
  Widget build(BuildContext context) {
    final progressDoc = FirebaseFirestore.instance
        .collection('plan_progress')
        .doc(clientId)
        .collection('plans')
        .doc(planId);

    final planDoc = FirebaseFirestore.instance
        .collection('fitness_plans')
        .doc(planId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        title: Text(
          '$clientName • Progress',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
            onPressed: () async {
              try {
                final pdfBytes = await _buildProgressPdf(
                  planDoc: planDoc,
                  progressDoc: progressDoc,
                  clientName: clientName,
                  planTitle: planTitle,
                );
                await Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: '${clientName.replaceAll(' ', '_')}_progress.pdf',
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to generate PDF: $e')),
                );
              }
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: progressDoc.snapshots(),
        builder: (context, progressSnap) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: planDoc.snapshots(),
            builder: (context, planSnap) {
              final planData = planSnap.data?.data() ?? {};
              final planMap = (planData['plan'] as Map<String, dynamic>?) ?? {};
              final days = (planMap['days'] as List?) ?? [];
              int totalExercises = 0;
              for (final day in days) {
                final ex = (day as Map?)?.cast<String, dynamic>()['exercises'] as List? ?? [];
                totalExercises += ex.length;
              }

              // Guard: Ensure this plan actually belongs to the specified client
              final planOwnerId = planData['userId'];
              if (planOwnerId != null && planOwnerId.toString() != clientId) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'This plan does not belong to this client.',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                );
              }

              // Progress data for this specific client+plan
              final progressExists = progressSnap.data?.exists == true;
              final progressData = progressSnap.data?.data() ?? {};
              final completedExercisesMap = (progressData['completedExercises'] as Map?)
                      ?.map((k, v) => MapEntry(k.toString(), v == true)) ??
                  {};
              final completedCount = completedExercisesMap.values.where((v) => v).length;
              final completedWeeks = (progressData['completedWeeks'] is int)
                  ? progressData['completedWeeks'] as int
                  : 0;
              final updatedAt = progressData['updatedAt'];

              if (!progressExists) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(planTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('No progress has been recorded yet.'),
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(planTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          title: 'Exercises Done',
                          value: '$completedCount/${totalExercises > 0 ? totalExercises : '-'}',
                          color: Colors.green,
                          icon: Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          title: 'Weeks Completed',
                          value: '$completedWeeks',
                          color: Colors.blue,
                          icon: Icons.calendar_today,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _progressList(days, completedExercisesMap),
                  const SizedBox(height: 12),
                  if (updatedAt != null)
                    Center(
                      child: Text(
                        'Updated: ${_formatTimestamp(updatedAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressList(List days, Map<String, bool> completed) {
    if (days.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No days in this plan.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ListView.separated(
        separatorBuilder: (_, __) => const Divider(height: 1),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = (days[i] as Map?)?.cast<String, dynamic>() ?? {};
          final title = day['title']?.toString() ?? 'Day ${i + 1}';
          final exercises = (day['exercises'] as List?) ?? [];
          final total = exercises.length;
          int done = 0;
          for (int j = 0; j < exercises.length; j++) {
            final id = '$i-$j';
            if (completed[id] == true) done++;
          }
          return ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Completed: $done/$total'),
            trailing: SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : (done / total),
                backgroundColor: Colors.grey[200],
                color: Colors.green,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final d = ts.toDate();
        return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
      return ts.toString();
    } catch (_) {
      return '';
    }
  }
}

// Build a PDF of the client's progress for a specific plan and return bytes
Future<Uint8List> _buildProgressPdf({
  required DocumentReference<Map<String, dynamic>> planDoc,
  required DocumentReference<Map<String, dynamic>> progressDoc,
  required String clientName,
  required String planTitle,
}) async {
  final planSnap = await planDoc.get();
  final progressSnap = await progressDoc.get();

  final planData = planSnap.data() ?? {};
  final planMap = (planData['plan'] as Map<String, dynamic>?) ?? {};
  final days = (planMap['days'] as List?) ?? [];

  final progressData = progressSnap.data() ?? {};
  final completedExercisesMap = (progressData['completedExercises'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v == true)) ??
      {};

  int totalExercises = 0;
  final rows = <List<String>>[];
  for (int i = 0; i < days.length; i++) {
    final day = (days[i] as Map?)?.cast<String, dynamic>() ?? {};
    final title = day['title']?.toString() ?? 'Day ${i + 1}';
    final exercises = (day['exercises'] as List?) ?? [];
    final total = exercises.length;
    totalExercises += total;
    int done = 0;
    for (int j = 0; j < exercises.length; j++) {
      final id = '$i-$j';
      if (completedExercisesMap[id] == true) done++;
    }
    rows.add([title, '$done/$total']);
  }

  final completedCount = completedExercisesMap.values.where((v) => v).length;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Progress Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        pw.Text('Client: $clientName'),
        pw.Text('Plan: $planTitle'),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all()), child: pw.Column(children: [
            pw.Text('Exercises Done', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('$completedCount/${totalExercises > 0 ? totalExercises : 0}')
          ]))),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          pw.Text('No days in this plan.')
        else
          pw.Table.fromTextArray(
            headers: const ['Day', 'Completed'],
            data: rows,
          ),
      ],
    ),
  );

  return pdf.save();
}
