import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoleHelper {
  static Future<String?> getCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;
      return doc.data()?['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> canAddWorkouts() async {
    final role = await getCurrentUserRole();
    return role == 'admin' || role == 'trainer';
  }

  static Future<bool> canDeleteWorkout(String trainerId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final role = await getCurrentUserRole();
    if (role == 'admin') return true;
    if (role == 'trainer') return user.uid == trainerId;

    return false;
  }
}

