import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_detail.dart';

class WorkoutPlanDisplayScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final String? planId;

  const WorkoutPlanDisplayScreen({
    Key? key,
    required this.plan,
    this.planId,
  }) : super(key: key);

  @override
  State<WorkoutPlanDisplayScreen> createState() => _WorkoutPlanDisplayScreenState();
}

class _WorkoutPlanDisplayScreenState extends State<WorkoutPlanDisplayScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _currentWeek = 1;
  Map<String, bool> _completedExercises = {};
  Map<String, int> _exerciseProgress = {};
  int _completedWeeks = 0;
  
  // Timer functionality
  Timer? _workoutTimer;
  int _timerSeconds = 0;
  bool _isTimerRunning = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    _fadeController.forward();
    _slideController.forward();

    // Load any saved progress
    _loadProgress();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _workoutTimer?.cancel();
    super.dispose();
  }
  
  void _startTimer() {
    if (_isTimerRunning) return;
    
    setState(() {
      _isTimerRunning = true;
    });
    
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timerSeconds++;
      });
    });
  }
  
  void _stopTimer() {
    _workoutTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }
  
  void _resetTimer() {
    _workoutTimer?.cancel();
    setState(() {
      _timerSeconds = 0;
      _isTimerRunning = false;
    });
  }

  // -------- Progress Persistence --------
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  String? get _planId => widget.planId;

  Future<void> _loadProgress() async {
    if (_userId == null || _planId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('plan_progress')
          .doc(_userId)
          .collection('plans')
          .doc(_planId)
          .get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final map = (data['completedExercises'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v == true),
            ) ?? {};
        setState(() {
          _completedExercises = map;
          _completedWeeks = (data['completedWeeks'] is int) ? data['completedWeeks'] : 0;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveProgress() async {
    if (_userId == null || _planId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('plan_progress')
          .doc(_userId)
          .collection('plans')
          .doc(_planId)
          .set({
        'completedExercises': _completedExercises,
        'completedWeeks': _completedWeeks,
        'updatedAt': FieldValue.serverTimestamp(),
        'planTitle': widget.plan['title'] ?? '',
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore
    }
  }

  int get _totalWeeks {
    final planMap = widget.plan['plan'] as Map<String, dynamic>?;
    if (planMap != null && planMap['weeks'] is int) return planMap['weeks'] as int;
    final input = widget.plan['input'] as Map<String, dynamic>?;
    if (input != null && input['plan_duration_weeks'] is int) return input['plan_duration_weeks'] as int;
    return 4;
  }

  void _maybeCompleteWeek() {
    // Count total exercises visible
    final content = widget.plan['plan'] ?? widget.plan['workouts'] ?? widget.plan;
    final days = _extractDays(content);
    int total = 0;
    for (final d in days) {
      total += ((d['exercises'] as List?) ?? const []).length;
    }
    if (total == 0) return;

    final completedCount = _completedExercises.values.where((v) => v).length;
    if (completedCount >= total) {
      if (_completedWeeks < _totalWeeks) {
        setState(() {
          _completedWeeks += 1;
          _completedExercises.clear(); // reset for next week cycle
        });
        _saveProgress();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Week $_completedWeeks of $_totalWeeks completed!')),
        );
      }
    }
  }
  
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: _buildBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan['title'] ?? 'AI Workout Plan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your Personalized Fitness Journey',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildTimerWidget(),
        ],
      ),
    );
  }
  
  Widget _buildTimerWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isTimerRunning ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(_timerSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBody() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildTabButton('Overview', 0),
          _buildTabButton('Workouts', 1),
          _buildTabButton('Progress', 2),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(String title, int index) {
    bool isSelected = _currentWeek == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentWeek = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF667eea) : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildContent() {
    switch (_currentWeek) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildWorkoutsTab();
      case 2:
        return _buildProgressTab();
      default:
        return _buildWorkoutsTab();
    }
  }
  
  Widget _buildOverviewTab() {
    final input = widget.plan['input'] as Map<String, dynamic>? ?? {};
    final schedule = input['schedule'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(input, schedule),
          const SizedBox(height: 12),
          _buildWeeksCompletedBanner(),
          const SizedBox(height: 24),
          _buildDescriptionCard(),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }
  
  Widget _buildStatsCards(Map<String, dynamic> input, Map<String, dynamic> schedule) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Duration',
            '${input['plan_duration_weeks'] ?? 4} weeks',
            Icons.calendar_today,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Frequency',
            '${schedule['days_per_week'] ?? 3} days/week',
            Icons.fitness_center,
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Session',
            '${schedule['session_duration'] ?? 45} min',
            Icons.timer,
            const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.1),
            const Color(0xFF764ba2).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About Your Plan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.plan['description'] ?? 'Your personalized workout plan designed to help you achieve your fitness goals.',
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Start Workout',
                Icons.play_arrow,
                const Color(0xFF4CAF50),
                () {
                  setState(() => _currentWeek = 1);
                  _startTimer();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'View Progress',
                Icons.trending_up,
                const Color(0xFF2196F3),
                () => setState(() => _currentWeek = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWorkoutsTab() {
    final content = widget.plan['plan'] ?? widget.plan['workouts'] ?? widget.plan;
    final days = _extractDays(content);
    final bool anyExercises = days.any((d) => ((d['exercises'] as List?) ?? const []).isNotEmpty);
    
    return Column(
      children: [
        _buildTimerControls(),
        if (!anyExercises)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _noExercisesHint(content),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: days.length,
            itemBuilder: (context, index) {
              return _buildWorkoutDayCard(days[index], index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _noExercisesHint(dynamic content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No exercises were detected in this plan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The AI may have returned a narrative plan without explicit exercise lists. We will show the raw plan below. You can try adjusting your survey (days/week, duration) and regenerating.',
          ),
        ],
      ),
    );
  }

  Widget _debugRawPlan(dynamic content) {
    String pretty;
    try {
      if (content is String) {
        final s = content.trim();
        if ((s.startsWith('{') && s.endsWith('}')) || (s.startsWith('[') && s.endsWith(']'))) {
          pretty = const JsonEncoder.withIndent('  ').convert(json.decode(s));
        } else {
          pretty = content;
        }
      } else {
        pretty = const JsonEncoder.withIndent('  ').convert(content);
      }
    } catch (_) {
      pretty = content.toString();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: Colors.grey[50],
        collapsedBackgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Debug: Raw Plan Data'),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                pretty,
                style: TextStyle(fontFamily: 'monospace', color: Colors.grey[800]),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimerControls() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTimerButton(
            _isTimerRunning ? 'Pause' : 'Start',
            _isTimerRunning ? Icons.pause : Icons.play_arrow,
            _isTimerRunning ? _stopTimer : _startTimer,
            _isTimerRunning ? Colors.orange : Colors.green,
          ),
          _buildTimerButton(
            'Reset',
            Icons.refresh,
            _resetTimer,
            Colors.red,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimerButton(String label, IconData icon, VoidCallback onTap, Color color) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, minHeight: 44),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withOpacity(0.08),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }
  
  Widget _buildWorkoutDayCard(Map<String, dynamic> day, int dayNumber) {
    final title = day['day'] ?? day['title'] ?? 'Day $dayNumber';
    final exercises = (day['exercises'] as List?) ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(20),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                dayNumber.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          title: Text(
            title.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          subtitle: Text(
            '${exercises.length} exercises',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          children: [
            ...exercises.map((exercise) => _buildExerciseCard(
              exercise as Map<String, dynamic>? ?? {},
              '$dayNumber-${exercises.indexOf(exercise)}',
            )).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExerciseCard(Map<String, dynamic> exercise, String exerciseId) {
    final name = exercise['name'] ?? exercise['exercise'] ?? 'Exercise';
    final target = exercise['target'] ?? exercise['muscle'] ?? '';
    final equipment = exercise['equipment'] ?? '';
    final sets = exercise['sets'] ?? '';
    final reps = exercise['reps'] ?? '';
    final isCompleted = _completedExercises[exerciseId] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutDetailScreen(exerciseName: name.toString()),
                      ),
                    );
                  },
                  child: Text(
                    name.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _completedExercises[exerciseId] = !isCompleted;
                  });
                  _saveProgress();
                  _maybeCompleteWeek();
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : Colors.transparent,
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.grey,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (target.toString().isNotEmpty)
                _buildInfoChip('Target: $target', Colors.blue),
              if (equipment.toString().isNotEmpty)
                _buildInfoChip('Equipment: $equipment', Colors.purple),
              if (sets.toString().isNotEmpty || reps.toString().isNotEmpty)
                _buildInfoChip('$sets x $reps', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildProgressTab() {
    final totalExercises = _getTotalExercises();
    final completedCount = _completedExercises.values.where((completed) => completed).length;
    final progressPercentage = totalExercises > 0 ? (completedCount / totalExercises) : 0.0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressOverview(progressPercentage, completedCount, totalExercises),
          const SizedBox(height: 24),
          _buildProgressChart(),
          const SizedBox(height: 24),
          _buildAchievements(),
        ],
      ),
    );
  }
  
  Widget _buildProgressOverview(double percentage, int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Overall Progress',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$completed of $total exercises completed',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Weeks: $_completedWeeks / $_totalWeeks',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeksCompletedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Weeks completed: $_completedWeeks / $_totalWeeks',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final random = Random();
              final height = 20.0 + random.nextDouble() * 60;
              return Column(
                children: [
                  Container(
                    width: 20,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFF667eea),
                          Color(0xFF764ba2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achievements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildAchievementCard('First Workout', 'Complete your first exercise', true),
        _buildAchievementCard('Consistency', 'Work out 3 days in a row', false),
        _buildAchievementCard('Dedication', 'Complete 50% of your plan', false),
      ],
    );
  }
  
  Widget _buildAchievementCard(String title, String description, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? Colors.amber.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? Colors.amber.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: unlocked ? Colors.amber : Colors.grey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              unlocked ? Icons.emoji_events : Icons.lock,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: unlocked ? Colors.amber[800] : Colors.grey[600],
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  List<Map<String, dynamic>> _extractDays(dynamic content) {
    // 1) If it's a string, try to decode JSON; otherwise parse plaintext.
    if (content is String) {
      final String trimmed = content.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final dynamic decoded = json.decode(trimmed);
          return _extractDays(decoded);
        } catch (_) {
          // Fall through to plaintext parsing
        }
      }

      // Plaintext heuristic parsing: split by Day sections
      final RegExp dayReg = RegExp(r'(Day\s*\d+[^\n]*)([\s\S]*?)(?=\n?Day\s*\d+|\Z)', multiLine: true);
      final matches = dayReg.allMatches(trimmed).toList();
      if (matches.isEmpty) {
        return const [];
      }
      return matches.map((m) {
        final title = m.group(1) ?? 'Workout';
        final body = m.group(2) ?? '';
        final exs = _parseExercisesFromText(body);
        return {
          'title': title.trim(),
          'exercises': exs,
        };
      }).toList();
    }

    // 2) If it's a list of days
    if (content is List) {
      return content
          .map((e) => (e as Map<String, dynamic>? ?? const {}))
          .toList();
    }

    // 3) If it's a map with conventional fields
    if (content is Map<String, dynamic>) {
      if (content['days'] is List) {
        return (content['days'] as List)
            .map((e) => (e as Map<String, dynamic>? ?? const {}))
            .toList();
      }
      if (content['workouts'] is List) {
        return (content['workouts'] as List)
            .map((e) => (e as Map<String, dynamic>? ?? const {}))
            .toList();
      }

      // Weekday keys (monday, tuesday, ...)
      final weekdays = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
      final weekdayDays = <Map<String, dynamic>>[];
      for (final wd in weekdays) {
        final v = content[wd] ?? content[wd.substring(0,1).toUpperCase()+wd.substring(1)];
        if (v != null) {
          if (v is List) {
            weekdayDays.add({'title': wd[0].toUpperCase()+wd.substring(1), 'exercises': v.map((e)=> (e as Map<String, dynamic>? ?? const {})).toList()});
          } else if (v is String) {
            weekdayDays.add({'title': wd[0].toUpperCase()+wd.substring(1), 'exercises': _parseExercisesFromText(v)});
          } else if (v is Map<String, dynamic>) {
            weekdayDays.add({'title': wd[0].toUpperCase()+wd.substring(1), ...v});
          }
        }
      }
      if (weekdayDays.isNotEmpty) return weekdayDays;

      // 4) Heuristic: collect keys that look like day sections (e.g., 'Day 1', 'day1', 'day_1').
      final dayEntries = <Map<String, dynamic>>[];
      final keys = content.keys.toList();
      keys.sort();
      for (final k in keys) {
        if (_looksLikeDayKey(k)) {
          final v = content[k];
          if (v is Map<String, dynamic>) {
            dayEntries.add({'title': k.toString(), ...v});
          } else if (v is List) {
            dayEntries.add({
              'title': k.toString(),
              'exercises': v.map((e) => (e as Map<String, dynamic>? ?? const {})).toList(),
            });
          } else if (v is String) {
            // treat as plaintext with bullet items
            final exs = _parseExercisesFromText(v);
            dayEntries.add({'title': k.toString(), 'exercises': exs});
          } else {
            dayEntries.add({'title': k.toString(), 'exercises': const []});
          }
        }
      }
      if (dayEntries.isNotEmpty) return dayEntries;
    }

    return const [];
  }

  bool _looksLikeDayKey(String key) {
    final k = key.toLowerCase();
    return k.startsWith('day ') || RegExp(r'^day\s*\d+').hasMatch(k) ||
        RegExp(r'^day_?\d+').hasMatch(k) || RegExp(r'^day\d+').hasMatch(k);
  }

  // Extract exercises from freeform text lines: bullets, numbered, or with sets x reps
  List<Map<String, dynamic>> _parseExercisesFromText(String body) {
    final List<Map<String, dynamic>> exs = [];
    final lines = body.split('\n');
    final reg = RegExp(r'^(?:[-*]|\d+\.)?\s*(.+?)(?:\s*-\s*)?(?:(\d+)\s*sets?)?(?:\s*x\s*(\d+)\s*reps?)?$', caseSensitive: false);
    for (final raw in lines) {
      final l = raw.trim();
      if (l.isEmpty) continue;
      // Skip pure headers like Warm-up:
      if (l.endsWith(':') && !l.contains('x') && !l.contains('set')) continue;
      final m = reg.firstMatch(l);
      if (m != null) {
        final name = (m.group(1) ?? '').trim();
        if (name.isEmpty) continue;
        final sets = (m.group(2) ?? '').trim();
        final reps = (m.group(3) ?? '').trim();
        exs.add({
          'name': name,
          if (sets.isNotEmpty) 'sets': sets,
          if (reps.isNotEmpty) 'reps': reps,
        });
      } else if (l.startsWith('-') || l.startsWith('*')) {
        final name = l.replaceFirst(RegExp(r'^[-*]\\s*'), '');
        if (name.isNotEmpty) exs.add({'name': name});
      } else if (l.isNotEmpty) {
        exs.add({'name': l});
      }
    }
    return exs;
  }
  
  int _getTotalExercises() {
    final content = widget.plan['plan'] ?? widget.plan['workouts'] ?? widget.plan;
    final days = _extractDays(content);
    int total = 0;
    for (final day in days) {
      final exercises = (day['exercises'] as List?) ?? [];
      total += exercises.length;
    }
    return total;
  }
}
