import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientSurveyDetailPage extends StatelessWidget {
  final String clientId;
  final String clientName;

  const ClientSurveyDetailPage({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        title: Text(
          clientName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('surveys')
            .doc(clientId)
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
      ),
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
}
