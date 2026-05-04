import 'package:nextone/screens/attendance/attendance_page.dart';
import 'package:flutter/material.dart';
import 'package:nextone/screens/follow_ups/follow_up_page.dart';
import 'package:nextone/screens/home/home_page.dart';
import 'package:nextone/screens/leads/leads_page.dart';
import 'package:nextone/screens/projects/projects_page.dart';
import 'package:nextone/screens/site_visits/site_visits_page.dart';
import 'package:nextone/screens/team/team_page.dart';
import 'package:nextone/screens/users/users_page.dart';
import 'package:nextone/widgets/crm_bottom_nav.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  final List<Widget> _screens = [
    const HomePage(showBottomNav: false),
    const LeadsPage(),
    const FollowUpPage(),
    const SiteVisitsPage(),
    const ProjectsPage(),
    const TeamPage(),
    const AttendancePage(),
    const UsersPage(),
  ];

  @override
  void initState() {
    super.initState();
    final index = widget.initialIndex;
    _currentIndex = index < 0
        ? 0
        : (index >= _screens.length ? _screens.length - 1 : index);
  }

  void _setIndex(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _screens[_currentIndex],
      bottomNavigationBar: CRMAppBottomNav(
        currentIndex: _currentIndex,
        onDashboard: () => _setIndex(0),
        onLeads: () => _setIndex(1),
        onFollowUps: () => _setIndex(2),
        onSiteVisits: () => _setIndex(3),
        onProjects: () => _setIndex(4),
        onTeam: () => _setIndex(5),
        onReports: () => _setIndex(6),
        onSettings: () => _setIndex(7),
        onMore: () {},
        onLess: () {},
      ),
    );
  }
}
