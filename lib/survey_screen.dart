import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _formKey = GlobalKey<FormState>();

  final heightController = TextEditingController();
  final weightController = TextEditingController();

  String gender = "Male";
  String activityLevel = "Beginner"; // ✅ must match dropdown items
  String fitnessGoal = "Overall Fitness"; // ✅ must match dropdown items

  DateTime? dob;
  int? age;

  int _currentStep = 0;

  final List<String> _questions = [
    "What is your Date of Birth?",
    "What is your gender?",
    "What is your height (cm)?",
    "What is your weight (kg)?",
    "What is your fitness goal?",
    "How much are you engaged in physical activities?",
  ];

  // --- Pick DOB and calculate age ---
  Future<void> _pickDob() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dob = picked;
        final today = DateTime.now();
        age = today.year - dob!.year;
        if (today.month < dob!.month ||
            (today.month == dob!.month && today.day < dob!.day)) {
          age = age! - 1;
        }
      });
    }
  }

  // --- Calculate BMI ---
  double? _calculateBmi() {
    final h = double.tryParse(heightController.text);
    final w = double.tryParse(weightController.text);
    if (h != null && w != null && h > 0) {
      final heightInMeters = h / 100; // convert cm → meters
      return w / (heightInMeters * heightInMeters);
    }
    return null;
  }

  Future<void> _submitSurvey() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      final bmi = _calculateBmi();

      await FirebaseFirestore.instance.collection("surveys").doc(uid).set({
        "dob": dob != null ? dob!.toIso8601String() : null,
        "age": age,
        "gender": gender,
        "height": heightController.text,
        "weight": weightController.text,
        "bmi": bmi?.toStringAsFixed(2), // ✅ store BMI
        "goal": fitnessGoal,
        "activityLevel": activityLevel,
        "timestamp": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Survey Submitted Successfully ✅")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildQuestion() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _pickDob,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                dob == null
                    ? "Pick your Date of Birth"
                    : DateFormat("dd-MM-yyyy").format(dob!),
              ),
            ),
            if (age != null)
              Text(
                "Age: $age years",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        );
      case 1:
        return DropdownButtonFormField(
          value: gender,
          decoration: const InputDecoration(labelText: "Gender"),
          items: [
            "Male",
            "Female",
            "Other",
          ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (val) => setState(() => gender = val!),
        );
      case 2:
        return TextFormField(
          controller: heightController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ), // ✅ decimals
          decoration: const InputDecoration(labelText: "Height (cm)"),
          validator: (value) {
            if (value == null || value.isEmpty) return "Enter your height";
            final h = double.tryParse(value);
            if (h == null || h < 50 || h > 300) {
              return "Enter a valid height (50–300 cm)";
            }
            return null;
          },
        );
      case 3:
        return TextFormField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ), // ✅ decimals
          decoration: const InputDecoration(labelText: "Weight (kg)"),
          validator: (value) {
            if (value == null || value.isEmpty) return "Enter your weight";
            final w = double.tryParse(value);
            if (w == null || w < 20 || w > 500) {
              return "Enter a valid weight (20–500 kg)";
            }
            return null;
          },
        );
      case 4:
        return DropdownButtonFormField(
          value: fitnessGoal, // ✅ matches items
          decoration: const InputDecoration(labelText: "Fitness Goal"),
          items: [
            "Overall Fitness",
            "Weight Gain",
            "Weight Loss",
            "Flexibility & Mobility",
            "Tone & Sculpt Body",
            "Improve Athletic Performance",
            "Maintain Current Fitness",
          ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (val) => setState(() => fitnessGoal = val!),
        );
      case 5:
        return DropdownButtonFormField(
          value: activityLevel, // ✅ matches items
          decoration: const InputDecoration(labelText: "Activity Level"),
          items: [
            "Beginner",
            "Intermediate",
            "Advanced",
          ].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (val) => setState(() => activityLevel = val!),
        );
      default:
        return const SizedBox();
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && dob == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select your DOB")));
      return;
    }
    if (_formKey.currentState!.validate()) {
      if (_currentStep < _questions.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        _submitSurvey();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Survey",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _questions[_currentStep],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildQuestion(),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _prevStep,
                      child: const Text(
                        "Back",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 238, 255, 65),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentStep == _questions.length - 1 ? "Submit" : "Next",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
