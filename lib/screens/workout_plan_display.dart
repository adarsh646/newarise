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
  final int? initialTab;

  const WorkoutPlanDisplayScreen({Key? key, required this.plan, this.planId, this.initialTab})
    : super(key: key);

  @override
  State<WorkoutPlanDisplayScreen> createState() =>
      _WorkoutPlanDisplayScreenState();
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

  // Timeline view tracking
  int _selectedDayNumber = 1; // 1-based day number globally
  late List<Map<String, dynamic>> _allDays = [];

  // Performance optimization: cache grouped weeks to avoid repeated computation
  late List<List<Map<String, dynamic>>> _cachedWeeks = [];

  // Timer functionality
  Timer? _workoutTimer;
  int _timerSeconds = 0;
  bool _isTimerRunning = false;

  // Live plan data (for realtime updates when planId is provided)
  Map<String, dynamic>? _livePlan;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _planSub;

  // Progress persistence tracking
  bool _isLoadingProgress = true;
  bool _isSavingProgress = false;
  String? _lastSaveError;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _currentWeek = widget.initialTab!.clamp(0, 2);
    }
    _initializeAnimations();
    // Subscribe to live plan updates if a planId is provided
    if (widget.planId != null && widget.planId!.isNotEmpty) {
      _subscribeToPlan();
    }
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _fadeController.forward();
    _slideController.forward();

    // Verify Firestore setup and load progress
    _verifyFirestoreAccess();
    _loadProgress();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _workoutTimer?.cancel();
    _planSub?.cancel();
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

  int get _currentWeekNumber {
    if (_allDays.isEmpty) return 1;
    final n = ((_selectedDayNumber - 1) ~/ 7) + 1;
    return n.clamp(1, _totalWeeks);
  }

  // -------- Progress Persistence --------
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  String? get _planId => widget.planId;

  // Diagnostic method to verify Firestore setup
  Future<void> _verifyFirestoreAccess() async {
    try {
      debugPrint('🔍 Verifying Firestore access...');
      debugPrint('   User ID: $_userId');
      debugPrint('   Plan ID: $_planId');
      debugPrint(
        '   Is Authenticated: ${FirebaseAuth.instance.currentUser != null}',
      );

      if (_userId == null) {
        debugPrint('   ❌ NOT AUTHENTICATED - User is not logged in!');
        return;
      }

      // Try a simple read operation
      final testSnap = await FirebaseFirestore.instance
          .collection('plan_progress')
          .doc(_userId)
          .get();

      if (testSnap.exists) {
        debugPrint('   ✓ Can read from Firestore');
      } else {
        debugPrint(
          '   ℹ Firestore document does not exist yet (will be created on first write)',
        );
      }

      // Verify write by setting a test timestamp
      await FirebaseFirestore.instance
          .collection('plan_progress')
          .doc(_userId)
          .set({
            'lastConnection': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint('   ✓ CAN WRITE to Firestore - Setup is correct!');
    } on FirebaseException catch (e) {
      debugPrint('   ❌ Firebase Error (${e.code}): ${e.message}');
      debugPrint('       Suggestion: Check your Firestore Security Rules');
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
  }

  Future<void> _loadProgress() async {
    if (_userId == null || _planId == null) {
      _initializeDays();
      if (mounted) {
        setState(() => _isLoadingProgress = false);
      }
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('plan_progress')
          .doc(_userId)
          .collection('plans')
          .doc(_planId)
          .get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final map =
            (data['completedExercises'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v == true),
            ) ??
            {};
        if (mounted) {
          setState(() {
            _completedExercises = map;
            _completedWeeks = (data['completedWeeks'] is int)
                ? data['completedWeeks']
                : 0;
            _isLoadingProgress = false;
            _initializeDays();
          });
        }
      } else {
        // Initialize days on first load
        _initializeDays();
        if (mounted) {
          setState(() => _isLoadingProgress = false);
        }
      }
    } catch (e) {
      // Log error for debugging
      debugPrint('Error loading progress: $e');
      _initializeDays();
      if (mounted) {
        setState(() => _isLoadingProgress = false);
      }
    }
  }

  // Subscribe to fitness_plans/{planId} for realtime updates
  void _subscribeToPlan() {
    final pid = widget.planId;
    if (pid == null) return;
    _planSub?.cancel();
    _planSub = FirebaseFirestore.instance
        .collection('fitness_plans')
        .doc(pid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.exists) {
        setState(() {
          _livePlan = snap.data();
          _initializeDays();
        });
      }
    });
  }

  Map<String, dynamic> get _effectivePlan =>
      (_livePlan != null && _livePlan!.isNotEmpty) ? _livePlan! : widget.plan;

  void _initializeDays() {
    final plan = _effectivePlan;
    final content = plan['plan'] ?? plan['workouts'] ?? plan;
    _allDays = _extractDays(content);
    _invalidateWeeksCache(); // Invalidate cached weeks when days change
  }

  void _invalidateWeeksCache() {
    _cachedWeeks = _groupDaysIntoWeeks();
  }

  Future<void> _saveProgress({int retryCount = 0}) async {
    if (_userId == null || _planId == null) {
      debugPrint('Cannot save progress: userId=$_userId, planId=$_planId');
      return;
    }

    if (mounted && retryCount == 0) {
      setState(() => _isSavingProgress = true);
    }

    try {
      // Validate data before saving
      if (_completedExercises.isEmpty && _completedWeeks == 0) {
        debugPrint('No progress to save');
        if (mounted) {
          setState(() => _isSavingProgress = false);
        }
        return;
      }

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

      debugPrint('✓ Progress saved successfully (attempt ${retryCount + 1})');

      // Success - clear any previous error
      if (mounted) {
        setState(() {
          _isSavingProgress = false;
          _lastSaveError = null;
        });
      }
    } on FirebaseException catch (e) {
      final errorMsg = 'Firebase Error (${e.code}): ${e.message}';
      debugPrint('Attempt ${retryCount + 1}: $errorMsg');

      // Retry on certain transient errors
      if ((e.code == 'unavailable' || e.code == 'deadline-exceeded') &&
          retryCount < 3) {
        debugPrint('🔄 Retrying... (attempt ${retryCount + 1}/3)');
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        return _saveProgress(retryCount: retryCount + 1);
      }

      if (mounted) {
        setState(() {
          _isSavingProgress = false;
          _lastSaveError = errorMsg;
        });
      }

      // Show specific error message
      String userMessage = '⚠️ Could not save progress.';
      if (e.code == 'permission-denied') {
        userMessage += ' Permission denied - check Firebase rules.';
      } else if (e.code == 'unauthenticated') {
        userMessage += ' Please log in again.';
      } else if (e.code == 'unavailable') {
        userMessage += ' Firestore is unavailable. Try again later.';
      } else if (e.code == 'deadline-exceeded') {
        userMessage += ' Request timed out. Check your connection.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      final errorMsg = 'Unexpected error: $e';
      debugPrint('Attempt ${retryCount + 1}: $errorMsg');

      // Retry on general connection errors
      if ((e.toString().contains('SocketException') ||
              e.toString().contains('timeout')) &&
          retryCount < 3) {
        debugPrint('🔄 Retrying... (attempt ${retryCount + 1}/3)');
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        return _saveProgress(retryCount: retryCount + 1);
      }

      if (mounted) {
        setState(() {
          _isSavingProgress = false;
          _lastSaveError = errorMsg;
        });
      }

      // Show generic error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  int get _totalWeeks {
    final planMap = widget.plan['plan'] as Map<String, dynamic>?;
    if (planMap != null && planMap['weeks'] is int)
      return planMap['weeks'] as int;
    final input = widget.plan['input'] as Map<String, dynamic>?;
    if (input != null && input['plan_duration_weeks'] is int)
      return input['plan_duration_weeks'] as int;
    return 4;
  }

  void _maybeCompleteWeek() {
    // Determine current week based on selected day (1-based day numbering)
    if (_allDays.isEmpty) return;
    final int currentWeekNumber = ((_selectedDayNumber - 1) ~/ 7) + 1;
    final weeks = _cachedWeeks;
    if (currentWeekNumber < 1 || currentWeekNumber > weeks.length) return;

    // Check if all exercises in the current week are completed
    bool allCompleted = true;
    final weekDays = weeks[currentWeekNumber - 1];
    for (int i = 0; i < weekDays.length; i++) {
      final int globalDayNumber = (currentWeekNumber - 1) * 7 + i + 1;
      final dayIndex = globalDayNumber - 1;
      final exercises = _getExercisesForDay(globalDayNumber);
      for (int j = 0; j < exercises.length; j++) {
        final exerciseId = '$dayIndex-$j';
        if (!(_completedExercises[exerciseId] ?? false)) {
          allCompleted = false;
          break;
        }
      }
      if (!allCompleted) break;
    }

    if (!allCompleted) return;

    // Mark week as completed; reset this week's checkboxes and advance
    setState(() {
      // Increment weeks completed (capped to total weeks)
      _completedWeeks = (_completedWeeks + 1).clamp(0, _totalWeeks);

      // Uncheck all exercises in the completed week
      for (int i = 0; i < weekDays.length; i++) {
        final int globalDayNumber = (currentWeekNumber - 1) * 7 + i + 1;
        final dayIndex = globalDayNumber - 1;
        final exercises = _getExercisesForDay(globalDayNumber);
        for (int j = 0; j < exercises.length; j++) {
          final exerciseId = '$dayIndex-$j';
          _completedExercises[exerciseId] = false;
        }
      }

      // Move to next week's first day; if not defined, wrap to day 1 (repeat workouts)
      final nextWeekStartDay = (currentWeekNumber * 7) + 1; // 1-based
      if (nextWeekStartDay <= _allDays.length) {
        _selectedDayNumber = nextWeekStartDay;
      } else {
        _selectedDayNumber = 1; // repeat from first week's first day
      }
    });

    _saveProgress();
    final nextWeek = (_completedWeeks < _totalWeeks)
        ? ' Starting week ${_completedWeeks + 1}.'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Week $currentWeekNumber of $_totalWeeks completed!$nextWeek'),
      ),
    );
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
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
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
                  Expanded(child: _buildBody()),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.plan['title'] ?? 'AI Workout Plan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Week ${_currentWeekNumber} of $_totalWeeks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildSyncStatusWidget(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTimerWidget(),
        ],
      ),
    );
  }

  Widget _buildSyncStatusWidget() {
    if (_isLoadingProgress) {
      return Tooltip(
        message: 'Loading your progress...',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSavingProgress) {
      return Tooltip(
        message: 'Saving your progress...',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Syncing...',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_lastSaveError != null) {
      return Tooltip(
        message: _lastSaveError!,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_problem, color: Colors.red, size: 14),
              SizedBox(width: 6),
              Text(
                'Sync Error',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Show checkmark when sync is successful
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text('Synced', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTimerWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(_timerSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? const Color(0xFF667eea) : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(input, schedule),
          const SizedBox(height: 12),
          _buildWeeksCompletedBanner(),
          const SizedBox(height: 16),
          _buildDescriptionCard(),
          const SizedBox(height: 16),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildStatsCards(
    Map<String, dynamic> input,
    Map<String, dynamic> schedule,
  ) {
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            widget.plan['description'] ??
                'Your personalized workout plan designed to help you achieve your fitness goals.',
            style: TextStyle(color: Colors.grey[700], height: 1.5),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
    if (_allDays.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show loading indicator while progress is being loaded from Firebase
    if (_isLoadingProgress) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading your progress...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    final weeks = _cachedWeeks;
    final selectedDayIndex = _selectedDayNumber - 1;
    final selectedDayExercises = _getExercisesForDay(_selectedDayNumber);
    final isSelectedDayUnlocked = _isDayUnlocked(_selectedDayNumber);

    return Column(
      children: [
        // Weekly timeline
        Expanded(
          flex: 1,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: weeks.length,
            itemBuilder: (context, weekIndex) {
              return _buildWeeklyTimeline(weekIndex + 1, weeks[weekIndex]);
            },
          ),
        ),
        const Divider(height: 1),
        // Selected day exercises
        Expanded(
          flex: 2,
          child: !isSelectedDayUnlocked
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Day ${_selectedDayNumber} is locked',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete Day ${_selectedDayNumber - 1} to unlock this day',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Day header
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xFF667eea).withOpacity(0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Day ${_selectedDayNumber}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isDayCompleted(_selectedDayNumber))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${selectedDayExercises.length} exercises',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Exercises list
                    Expanded(
                      child: selectedDayExercises.isEmpty
                          ? const Center(
                              child: Text('No exercises for this day'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              itemCount: selectedDayExercises.length,
                              itemBuilder: (context, index) {
                                return _buildExerciseCard(
                                  selectedDayExercises[index],
                                  '$selectedDayIndex-$index',
                                );
                              },
                            ),
                    ),
                  ],
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
        if ((s.startsWith('{') && s.endsWith('}')) ||
            (s.startsWith('[') && s.endsWith(']'))) {
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
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Debug: Raw Plan Data'),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                pretty,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildTimerButton(
              _isTimerRunning ? 'Pause' : 'Start',
              _isTimerRunning ? Icons.pause : Icons.play_arrow,
              _isTimerRunning ? _stopTimer : _startTimer,
              _isTimerRunning ? Colors.orange : Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTimerButton(
              'Reset',
              Icons.refresh,
              _resetTimer,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.08),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildWorkoutDayCard(Map<String, dynamic> day, int dayNumber) {
    final title = day['day'] ?? day['title'] ?? 'Day $dayNumber';
    final exercises = (day['exercises'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(12),
          childrenPadding: const EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 12,
          ),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text(
            '${exercises.length} exercises',
            style: TextStyle(color: Colors.grey[600]),
          ),
          children: [
            ...exercises
                .map(
                  (exercise) => _buildExerciseCard(
                    exercise as Map<String, dynamic>? ?? {},
                    '$dayNumber-${exercises.indexOf(exercise)}',
                  ),
                )
                .toList(),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
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
                        builder: (_) =>
                            WorkoutDetailScreen(exerciseName: name.toString()),
                      ),
                    );
                  },
                  child: Text(
                    name.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
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
    final completedCount = _completedExercises.values
        .where((completed) => completed)
        .length;
    final progressPercentage = totalExercises > 0
        ? (completedCount / totalExercises)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressOverview(
            progressPercentage,
            completedCount,
            totalExercises,
          ),
          const SizedBox(height: 16),
          _buildProgressChart(),
          const SizedBox(height: 16),
          _buildAchievements(),
        ],
      ),
    );
  }

  Widget _buildProgressOverview(double percentage, int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(16),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildAchievementCard(
          'First Workout',
          'Complete your first exercise',
          true,
        ),
        _buildAchievementCard('Consistency', 'Work out 3 days in a row', false),
        _buildAchievementCard('Dedication', 'Complete 50% of your plan', false),
      ],
    );
  }

  Widget _buildAchievementCard(
    String title,
    String description,
    bool unlocked,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? Colors.amber.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? Colors.amber.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
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
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
      final RegExp dayReg = RegExp(
        r'(Day\s*\d+[^\n]*)([\s\S]*?)(?=\n?Day\s*\d+|\Z)',
        multiLine: true,
      );
      final matches = dayReg.allMatches(trimmed).toList();
      if (matches.isEmpty) {
        return const [];
      }
      return matches.map((m) {
        final title = m.group(1) ?? 'Workout';
        final body = m.group(2) ?? '';
        final exs = _parseExercisesFromText(body);
        return {'title': title.trim(), 'exercises': exs};
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
      final weekdays = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      final weekdayDays = <Map<String, dynamic>>[];
      for (final wd in weekdays) {
        final v =
            content[wd] ??
            content[wd.substring(0, 1).toUpperCase() + wd.substring(1)];
        if (v != null) {
          if (v is List) {
            weekdayDays.add({
              'title': wd[0].toUpperCase() + wd.substring(1),
              'exercises': v
                  .map((e) => (e as Map<String, dynamic>? ?? const {}))
                  .toList(),
            });
          } else if (v is String) {
            weekdayDays.add({
              'title': wd[0].toUpperCase() + wd.substring(1),
              'exercises': _parseExercisesFromText(v),
            });
          } else if (v is Map<String, dynamic>) {
            weekdayDays.add({
              'title': wd[0].toUpperCase() + wd.substring(1),
              ...v,
            });
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
              'exercises': v
                  .map((e) => (e as Map<String, dynamic>? ?? const {}))
                  .toList(),
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
    return k.startsWith('day ') ||
        RegExp(r'^day\s*\d+').hasMatch(k) ||
        RegExp(r'^day_?\d+').hasMatch(k) ||
        RegExp(r'^day\d+').hasMatch(k);
  }

  // Extract exercises from freeform text lines: bullets, numbered, or with sets x reps
  List<Map<String, dynamic>> _parseExercisesFromText(String body) {
    final List<Map<String, dynamic>> exs = [];
    final lines = body.split('\n');
    final reg = RegExp(
      r'^(?:[-*]|\d+\.)?\s*(.+?)(?:\s*-\s*)?(?:(\d+)\s*sets?)?(?:\s*x\s*(\d+)\s*reps?)?$',
      caseSensitive: false,
    );
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
    // Use already-extracted _allDays instead of re-extracting
    int total = 0;
    for (final day in _allDays) {
      final exercises = (day['exercises'] as List?) ?? [];
      total += exercises.length;
    }
    return total;
  }

  // -------- New Weekly Timeline Methods --------

  /// Group days into weeks (7 days per week)
  List<List<Map<String, dynamic>>> _groupDaysIntoWeeks() {
    final weeks = <List<Map<String, dynamic>>>[];
    for (int i = 0; i < _allDays.length; i += 7) {
      final endIndex = (i + 7).clamp(0, _allDays.length);
      weeks.add(_allDays.sublist(i, endIndex));
    }
    return weeks;
  }

  /// Check if a specific day is completed (all exercises completed)
  bool _isDayCompleted(int globalDayNumber) {
    if (globalDayNumber < 1 || globalDayNumber > _allDays.length) {
      return false;
    }
    final dayIndex = globalDayNumber - 1;
    final day = _allDays[dayIndex];
    final exercises = (day['exercises'] as List?) ?? [];

    if (exercises.isEmpty) return false;

    // All exercises in this day must be completed
    for (int i = 0; i < exercises.length; i++) {
      final exerciseId = '$dayIndex-$i';
      if (!(_completedExercises[exerciseId] ?? false)) {
        return false;
      }
    }
    return true;
  }

  /// Check if a specific day is unlocked (can be accessed)
  bool _isDayUnlocked(int globalDayNumber) {
    if (globalDayNumber == 1) return true; // First day always unlocked
    return _isDayCompleted(
      globalDayNumber - 1,
    ); // Unlock when previous day completed
  }

  /// Get all exercises for a specific day
  List<Map<String, dynamic>> _getExercisesForDay(int globalDayNumber) {
    if (globalDayNumber < 1 || globalDayNumber > _allDays.length) {
      return [];
    }
    final dayIndex = globalDayNumber - 1;
    final day = _allDays[dayIndex];
    return ((day['exercises'] as List?) ?? [])
        .map((e) => (e as Map<String, dynamic>? ?? {}))
        .toList();
  }

  /// Count completed days in a week
  int _getCompletedDaysInWeek(int weekNumber) {
    final weeks = _cachedWeeks;
    if (weekNumber < 1 || weekNumber > weeks.length) return 0;

    final week = weeks[weekNumber - 1];
    int completedCount = 0;

    for (int i = 0; i < week.length; i++) {
      final globalDayNumber = (weekNumber - 1) * 7 + i + 1;
      if (_isDayCompleted(globalDayNumber)) {
        completedCount++;
      }
    }
    return completedCount;
  }

  /// Count total exercises in a week
  int _getTotalExercisesInWeek(int weekNumber) {
    final weeks = _cachedWeeks;
    if (weekNumber < 1 || weekNumber > weeks.length) return 0;

    final week = weeks[weekNumber - 1];
    int totalCount = 0;

    for (int i = 0; i < week.length; i++) {
      final globalDayNumber = (weekNumber - 1) * 7 + i + 1;
      final exercises = _getExercisesForDay(globalDayNumber);
      totalCount += exercises.length;
    }
    return totalCount;
  }

  /// Count completed exercises in a week
  int _getCompletedExercisesInWeek(int weekNumber) {
    final weeks = _cachedWeeks;
    if (weekNumber < 1 || weekNumber > weeks.length) return 0;

    final week = weeks[weekNumber - 1];
    int completedCount = 0;

    for (int i = 0; i < week.length; i++) {
      final globalDayNumber = (weekNumber - 1) * 7 + i + 1;
      final dayIndex = globalDayNumber - 1;
      final exercises = _getExercisesForDay(globalDayNumber);

      for (int j = 0; j < exercises.length; j++) {
        final exerciseId = '$dayIndex-$j';
        if (_completedExercises[exerciseId] ?? false) {
          completedCount++;
        }
      }
    }
    return completedCount;
  }

  /// Build weekly timeline view with day circles
  Widget _buildWeeklyTimeline(
    int weekNumber,
    List<Map<String, dynamic>> weekDays,
  ) {
    final weeks = _cachedWeeks;
    final globalDayStart = (weekNumber - 1) * 7 + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week header with progress
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week $weekNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_getCompletedDaysInWeek(weekNumber)}/${weekDays.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Days grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // First row (days 1-4)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ...List.generate(
                    (weekDays.length >= 4 ? 4 : weekDays.length),
                    (index) {
                      final globalDayNumber = globalDayStart + index;
                      return _buildDayCircle(globalDayNumber);
                    },
                  ),
                  if (weekDays.length >= 4)
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 16),
              // Second row (days 5-7 + trophy)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ...List.generate(
                    (weekDays.length > 4 ? weekDays.length - 4 : 0),
                    (index) {
                      final globalDayNumber = globalDayStart + 4 + index;
                      return _buildDayCircle(globalDayNumber);
                    },
                  ),
                  // Trophy for week completion
                  if (weekDays.length == 7 &&
                      _getCompletedDaysInWeek(weekNumber) == 7)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.withOpacity(0.2),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 28,
                      ),
                    )
                  else if (weekDays.length == 7)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        color: Colors.grey.withOpacity(0.3),
                        size: 28,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Build individual day circle button
  Widget _buildDayCircle(int globalDayNumber) {
    final isCompleted = _isDayCompleted(globalDayNumber);
    final isUnlocked = _isDayUnlocked(globalDayNumber);
    final isSelected = _selectedDayNumber == globalDayNumber;

    return GestureDetector(
      onTap: isUnlocked
          ? () {
              setState(() => _selectedDayNumber = globalDayNumber);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted
              ? const Color(0xFF4CAF50).withOpacity(0.2)
              : isSelected
              ? const Color(0xFF667eea).withOpacity(0.3)
              : isUnlocked
              ? Colors.white
              : Colors.grey.withOpacity(0.1),
          border: Border.all(
            color: isCompleted
                ? Colors.green
                : isSelected
                ? const Color(0xFF667eea)
                : isUnlocked
                ? const Color(0xFF667eea).withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCompleted)
              const Icon(Icons.check, color: Colors.green, size: 24)
            else if (!isUnlocked)
              const Icon(Icons.lock, color: Colors.grey, size: 16)
            else
              Text(
                globalDayNumber.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
