import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/features/home/home_page.dart';
import 'package:students_reminder/src/features/notes/my_notes_page.dart';
import 'package:students_reminder/src/features/profile/profile_page.dart';
import 'package:students_reminder/src/features/public_notes/public_notes_page.dart';
import 'package:students_reminder/src/services/auth_service.dart';

class MainLayoutPage extends StatefulWidget {
  const MainLayoutPage({super.key});

  @override
  State<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends State<MainLayoutPage> {
  int _index = 0;

    final _pages = const [HomePage(), MyNotesPage(), PublicFeeds(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanged(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return LoginPage();
        return Scaffold(
          body: _pages[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(
                icon: Icon(Icons.event_note),
                label: 'Notes',
              ),
              NavigationDestination(
                icon: Icon(Icons.public),
                label: 'public feeds'),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
            onDestinationSelected: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}
