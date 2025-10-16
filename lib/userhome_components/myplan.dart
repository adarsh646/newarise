import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../survey_screen.dart';
import '../screens/workout_plan_display.dart';
import '../screens/predefined_plan_workouts_screen.dart';

class MyPlanSection extends StatefulWidget {
  const MyPlanSection({super.key});

  @override
  State<MyPlanSection> createState() => _MyPlanSectionState();
}

class _MyPlanSectionState extends State<MyPlanSection> with AutomaticKeepAliveClientMixin {
  late Future<String> _usernameFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _usernameFuture = _fetchUsername();
  }

  Widget _buildPredefinedSection({
    required String section,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('predefined_plans')
              .where('section', isEqualTo: section)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            final docs = snapshot.data!.docs;
            return GridView.builder(
              key: PageStorageKey('predefined_${section}'),
              itemCount: docs.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              cacheExtent: 800,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final String title = (data['title'] ?? 'Fitness Plan').toString();
                final String? imageUrl = (data['imageUrl']?.toString().trim().isNotEmpty == true)
                    ? data['imageUrl'].toString()
                    : null;
                final List tags = (data['tags'] as List?) ?? const [];
                final int weeks = ((data['plan'] ?? {})['weeks'] is int)
                    ? (data['plan']['weeks'] as int)
                    : ((data['input'] ?? {})['plan_duration_weeks'] is int)
                        ? (data['input']['plan_duration_weeks'] as int)
                        : 4;

                return KeyedSubtree(
                  key: ValueKey(doc.id),
                  child: _PredefinedPlanCard(
                  title: title,
                  imageUrl: imageUrl,
                  weeks: weeks,
                  tags: tags.map((e) => e.toString()).toList(),
                  onTap: () {
                    final planMap = {
                      'title': data['title'],
                      'description': data['description'],
                      'plan': data['plan'],
                      'input': data['input'],
                      'imageUrl': data['imageUrl'],
                      'source': data['source'] ?? 'admin_predefined',
                    };
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PredefinedPlanWorkoutsScreen(
                          plan: planMap,
                          planId: doc.id,
                        ),
                      ),
                    );
                  },
                ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<String> _fetchUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "User";
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      // ✅ FIX 2: Changed 'name' to 'username' to match your Firestore data structure.
      return userDoc.data()?['username'] ?? "User";
    } catch (e) {
      return "User";
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keep-alive mixin
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Please log in."));

    // ✅ FIX 1: Wrapped the content in a Center widget.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Helps with vertical centering
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder<String>(
              future: _usernameFuture,
              builder: (context, snapshot) {
                final username = snapshot.data ?? 'User';
                return Text(
                  "Welcome, $username 👋",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // --- User's AI-generated plan (latest) ---
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('plans')
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, planSnap) {
                if (planSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (planSnap.hasError) {
                  return const SizedBox.shrink();
                }
                final docs = planSnap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  // No plan yet; show CTA to get plan via survey
                  return _buildNoPlanUI(uid);
                }
                final doc = docs.first;
                final data = doc.data();
                final Map<String, dynamic> planMap = {
                  ...data,
                  '__planId': doc.id,
                };
                return _buildPlanCard(planMap);
              },
            ),
            const SizedBox(height: 24),
            // --- Admin predefined plans ---
            _buildPredefinedSection(
              section: 'Get fitter',
              title: 'Get fitter',
              subtitle:
                  'Training plans designed to improve or maintain your physical condition.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return Column(
      children: [
        const Text(
          "Your Recommended Fitness Plan:",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(
              Icons.fitness_center,
              color: Colors.blue,
              size: 32,
            ),
            title: Text(
              plan['title'] ?? 'Fitness Plan',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              (plan['description'] ?? 'Stay fit and healthy!')
                      .toString()
                      .trim()
                      .isEmpty
                  ? 'Your personalized plan is ready.'
                  : plan['description'],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutPlanDisplayScreen(
                    plan: plan,
                    planId: (plan['__planId'] as String?),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoPlanUI(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('surveys').doc(uid).get(),
      builder: (context, surveySnapshot) {
        if (surveySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (surveySnapshot.hasData && surveySnapshot.data!.exists) {
          return const Text("Your plan is being generated, please wait... ⏳");
        }

        return Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 238, 255, 65),
                foregroundColor: const Color.fromARGB(221, 22, 20, 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SurveyScreen()),
                );
              },
              child: const Text(
                "Get My Plan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Complete the survey to unlock your fitness plan!"),
          ],
        );
      },
    );
  }
}


class _PredefinedPlanCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final int weeks;
  final List<String> tags;
  final VoidCallback onTap;

  const _PredefinedPlanCard({
    required this.title,
    required this.imageUrl,
    required this.weeks,
    required this.tags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background image
            AspectRatio(
              aspectRatio: 1.35,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      useOldImageOnUrlChange: true,
                      memCacheWidth: 800,
                      memCacheHeight: 600,
                      placeholder: (_, __) => Container(color: Colors.grey[200]),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image, size: 40, color: Colors.grey),
                      ),
                    ),
            ),
            // Top-left weeks pill
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$weeks weeks',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
            // Bottom gradient overlay with title and two tags
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(0, 0, 0, 0),
                      Color.fromARGB(160, 0, 0, 0),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    ...tags.take(2).map((t) => _tagRow(t)).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagRow(String label) {
    IconData icon;
    Color color;
    switch (label.toLowerCase()) {
      case 'cardio':
        icon = Icons.fitness_center; color = const Color(0xFF7CFC00); // light green
        break;
      case 'strength':
        icon = Icons.fitness_center; color = const Color(0xFF7CB9FF); // light blue
        break;
      case 'warmup':
        icon = Icons.local_fire_department; color = const Color(0xFFFFB74D);
        break;
      case 'stretching':
        icon = Icons.self_improvement; color = const Color(0xFFCE93D8);
        break;
      default:
        icon = Icons.label_outline; color = Colors.white70;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.95)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

