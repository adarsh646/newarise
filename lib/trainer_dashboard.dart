import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'trainerhome_components/trainer_clients.dart';
import 'trainerhome_components/trainer_workouts.dart';
import 'trainerhome_components/trainer_profile.dart';

// Converted to a StatefulWidget to manage the navigation state
class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  int _selectedIndex = 0;

  // List of the main pages for the trainer
  static const List<Widget> _pages = <Widget>[
    TrainerClientsPage(),
    TrainerWorkoutsPage(),
    TrainerProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ AppBar styled to match the AdminDashboard
      appBar: AppBar(
        title: const Text(
          "ARISE",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
      // The body now shows the selected page from the navigation bar
      body: _pages.elementAt(_selectedIndex),

      // ✅ BottomNavigationBar added with the same professional theme
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'My Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade700,
        onTap: _onItemTapped,
      ),
    );
  }
}
