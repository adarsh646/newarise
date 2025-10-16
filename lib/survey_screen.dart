import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/plan_generator_service.dart';

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
  String activityLevel = "Beginner";
  String fitnessGoal = "Overall Fitness";
  int daysPerWeek = 5; // new
  int sessionDuration = 45; // minutes - new
  int planDurationWeeks = 8; // new

  DateTime? dob;
  int? age;

  int _currentStep = 0;
  bool _isSubmitting = false;

  final List<String> _questions = [
    "What is your Date of Birth?",
    "What is your gender?",
    "What is your height (cm)?",
    "What is your weight (kg)?",
    "What is your fitness goal?",
    "How much are you engaged in physical activities?",
    "How many days per week can you work out?",
    "How long is each session (minutes)?",
    "How many weeks should the plan cover?",
  ];

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

  double? _calculateBmi() {
    final h = double.tryParse(heightController.text);
    final w = double.tryParse(weightController.text);
    if (h != null && w != null && h > 0) {
      final heightInMeters = h / 100;
      return w / (heightInMeters * heightInMeters);
    }
    return null;
  }

  Future<void> _submitSurvey() async {
    setState(() => _isSubmitting = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      final bmi = _calculateBmi();

      await FirebaseFirestore.instance.collection("surveys").doc(uid).set({
        "dob": dob != null ? dob!.toIso8601String() : null,
        "age": age,
        "gender": gender,
        "height": heightController.text,
        "weight": weightController.text,
        "bmi": bmi?.toStringAsFixed(2),
        "goal": fitnessGoal,
        "activityLevel": activityLevel,
        "daysPerWeek": daysPerWeek,
        "sessionDuration": sessionDuration,
        "planDurationWeeks": planDurationWeeks,
        "timestamp": FieldValue.serverTimestamp(),
      });

      await PlanGeneratorService().generateAndSavePlan(userId: uid);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Success! Your personalized plan is being generated. ✅",
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildQuestion() {
    // This switch statement remains the same
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "Height (cm)"),
          validator: (value) {
            if (value == null || value.isEmpty) return "Enter your height";
            final h = double.tryParse(value);
            if (h == null || h < 50 || h > 300)
              return "Enter a valid height (50–300 cm)";
            return null;
          },
        );
      case 3:
        return TextFormField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "Weight (kg)"),
          validator: (value) {
            if (value == null || value.isEmpty) return "Enter your weight";
            final w = double.tryParse(value);
            if (w == null || w < 20 || w > 500)
              return "Enter a valid weight (20–500 kg)";
            return null;
          },
        );
      case 4:
        return DropdownButtonFormField(
          value: fitnessGoal,
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
          value: activityLevel,
          decoration: const InputDecoration(labelText: "Activity Level"),
          items: [
            "Beginner",
            "Intermediate",
            "Advanced",
          ].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (val) => setState(() => activityLevel = val!),
        );
      case 6:
        return DropdownButtonFormField<int>(
          value: daysPerWeek,
          decoration: const InputDecoration(labelText: "Days per week"),
          items: List.generate(7, (i) => i + 1)
              .map((d) => DropdownMenuItem(value: d, child: Text("$d days")))
              .toList(),
          onChanged: (val) => setState(() => daysPerWeek = val ?? 5),
        );
      case 7:
        return DropdownButtonFormField<int>(
          value: sessionDuration,
          decoration: const InputDecoration(labelText: "Session duration (minutes)"),
          items: const [20, 30, 45, 60, 75, 90]
              .map((d) => DropdownMenuItem(value: d, child: Text("$d minutes")))
              .toList(),
          onChanged: (val) => setState(() => sessionDuration = val ?? 45),
        );
      case 8:
        return DropdownButtonFormField<int>(
          value: planDurationWeeks,
          decoration: const InputDecoration(labelText: "Plan duration (weeks)"),
          items: const [4, 6, 8, 10, 12, 16]
              .map((w) => DropdownMenuItem(value: w, child: Text("$w weeks")))
              .toList(),
          onChanged: (val) => setState(() => planDurationWeeks = val ?? 8),
        );
      default:
        return const SizedBox();
    }
  }

  // ✅ THIS FUNCTION IS UPDATED
  void _nextStep() {
    // --- Step-specific validation for DOB/Age ---
    if (_currentStep == 0) {
      if (dob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select your Date of Birth.")),
        );
        return; // Stop processing
      }
      if (age! < 10 || age! > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Age must be between 10 and 100.")),
        );
        return; // Stop processing
      }
    }

    // --- General validation for TextFormFields etc. ---
    if (_formKey.currentState!.validate()) {
      if (_currentStep < _questions.length - 1) {
        setState(() => _currentStep++);
      } else {
        _submitSurvey();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
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
                    onPressed: _isSubmitting ? null : _nextStep,
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
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _currentStep == _questions.length - 1
                                ? "Submit"
                                : "Next",
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
