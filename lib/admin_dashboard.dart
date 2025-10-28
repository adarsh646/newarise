import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'adminhome_components/managetrainer.dart';
import 'adminhome_components/all_trainers_screen.dart'; 
import 'adminhome_components/workouts_admin_screen.dart';
import 'adminhome_components/create_plan_page.dart';

// Main Dashboard Widget
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    ManageTrainersScreen(),
    AllTrainersScreen(), 
    ViewAllUsersScreen(),
    WorkoutsAdminScreen(),
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
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton.extended(
              backgroundColor: const Color.fromARGB(255, 238, 255, 65),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('Create Plan'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePlanPage()),
                );
              },
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Requests', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports), 
            label: 'All Trainers',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'All Users'),
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

class ViewAllUsersScreen extends StatelessWidget {
  const ViewAllUsersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('View All Users Screen', style: TextStyle(fontSize: 24)),
    );
  }
}
