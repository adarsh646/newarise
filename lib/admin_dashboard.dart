import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'adminhome_components/managetrainer.dart';
import 'adminhome_components/all_trainers_screen.dart'; // ✅ Import the new screen

// Main Dashboard Widget
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // ✅ Added the new AllTrainersScreen to the list of pages
  static const List<Widget> _pages = <Widget>[
    ManageTrainersScreen(),
    AllTrainersScreen(), // New page for viewing/deleting all trainers
    ViewAllUsersScreen(),
    UploadQualificationsScreen(),
    ViewWorkoutsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ARISE",
          style: TextStyle(
            color: Color.fromARGB(255, 3, 3, 3),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(child: _pages.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        // ✅ Added a new BottomNavigationBarItem
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Requests', // Renamed for clarity
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports), // New icon
            label: 'All Trainers',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'All Users'),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Qualifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        selectedItemColor: const Color.fromARGB(255, 2, 2, 2),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- Placeholder Screens ---
// You can replace these with your actual screen widgets later.

class ViewAllUsersScreen extends StatelessWidget {
  const ViewAllUsersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('View All Users Screen', style: TextStyle(fontSize: 24)),
    );
  }
}

class UploadQualificationsScreen extends StatelessWidget {
  const UploadQualificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Upload Qualifications Screen',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}

class ViewWorkoutsScreen extends StatelessWidget {
  const ViewWorkoutsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('View Workouts Screen', style: TextStyle(fontSize: 24)),
    );
  }
}
