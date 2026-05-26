import 'package:nextone/screens/attendance/attendance_page.dart';
import 'package:flutter/material.dart';
import 'package:nextone/screens/closures/closures_page.dart';
import 'package:nextone/screens/follow_ups/follow_up_page.dart';
import 'package:nextone/screens/home/home_page.dart';
import 'package:nextone/screens/leads/leads_page.dart';
import 'package:nextone/screens/phone_requests/phone_requests_page.dart';
import 'package:nextone/screens/projects/projects_page.dart';
import 'package:nextone/screens/salary/salary_management_page.dart';
import 'package:nextone/screens/site_visits/site_visits_page.dart';
import 'package:nextone/screens/site_visits/site_revisits_page.dart';
import 'package:nextone/screens/team/team_page.dart';
import 'package:nextone/screens/users/users_page.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/crm_bottom_nav.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final AuthProvider _authProvider = AuthProvider();
  String _currentRole = '';
  bool _isLoadingAccess = true;

  final List<Widget> _screens = [
    const HomePage(showBottomNav: false),
    const LeadsPage(),
    const FollowUpPage(),
    const SiteVisitsPage(),
    const SiteRevisitsPage(),
    const ProjectsPage(),
    const TeamPage(),
    const AttendancePage(),
    const UsersPage(),
    const PhoneRequestsPage(),
    const SalaryManagementPage(),
    const ClosuresPage(),
  ];

  @override
  void initState() {
    super.initState();
    final index = widget.initialIndex;
    _currentIndex = index < 0
        ? 0
        : (index >= _screens.length ? _screens.length - 1 : index);
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final role = await RoleAccess.currentRole(_authProvider);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
        _isLoadingAccess = false;
        if (!RoleAccess.canAccessMainTab(role, _currentIndex)) {
          _currentIndex = 0;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingAccess = false;
        if (!RoleAccess.canAccessMainTab(_currentRole, _currentIndex)) {
          _currentIndex = 0;
        }
      });
    }
  }

  void _setIndex(int index) {
    if (!RoleAccess.canAccessMainTab(_currentRole, index)) return;
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoadingAccess
          ? const Center(child: CircularProgressIndicator())
          : _screens[_currentIndex],
      bottomNavigationBar: CRMAppBottomNav(
        currentIndex: _currentIndex,
        showProjects: RoleAccess.canViewProjects(_currentRole),
        showTeam: RoleAccess.canViewTeam(_currentRole),
        showUsers: RoleAccess.canViewUsers(_currentRole),
        showPhoneRequests: RoleAccess.canViewPhoneRequests(_currentRole),
        showSalary: RoleAccess.canViewSalaryManagement(_currentRole),
        onDashboard: () => _setIndex(0),
        onLeads: () => _setIndex(1),
        onFollowUps: () => _setIndex(2),
        onSiteVisits: () => _setIndex(3),
        onRevisits: () => _setIndex(4),
        onProjects: () => _setIndex(5),
        onTeam: () => _setIndex(6),
        onReports: () => _setIndex(7),
        onSettings: () => _setIndex(8),
        onPhoneRequests: () => _setIndex(9),
        onSalary: () => _setIndex(10),
        onMore: () {},
        onLess: () {},
        onClosures: () => _setIndex(11),
      ),
    );
  }
}
