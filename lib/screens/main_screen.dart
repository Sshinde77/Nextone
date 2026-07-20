import 'dart:async';

import 'package:nextone/screens/attendance/attendance_page.dart';
import 'package:nextone/screens/attendance/leave_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextone/screens/closures/closures_page.dart';
import 'package:nextone/screens/eoi/eoi_page.dart';
import 'package:nextone/screens/follow_ups/follow_up_page.dart';
import 'package:nextone/screens/home/home_page.dart';
import 'package:nextone/screens/leads/leads_page.dart';
import 'package:nextone/screens/leads/site_visit_done_page.dart';
import 'package:nextone/screens/projects/projects_page.dart';
import 'package:nextone/screens/salary/salary_management_page.dart';
import 'package:nextone/screens/site_visits/site_visits_page.dart';
import 'package:nextone/screens/site_visits/site_revisits_page.dart';
import 'package:nextone/screens/team/team_page.dart';
import 'package:nextone/screens/targets/targets_page.dart';
import 'package:nextone/screens/users/users_page.dart';
import 'package:nextone/screens/website_enquiries/website_enquiries_page.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/services/notification_navigation_service.dart';
import 'package:nextone/utils/role_access.dart';
import 'package:nextone/widgets/app_preloader.dart';
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
  bool _isRefreshingAccess = false;
  DateTime? _lastBackPressAt;

  @override
  void initState() {
    super.initState();
    final index = widget.initialIndex;
    _currentIndex = index < 0 ? 0 : (index >= 16 ? 15 : index);
    _loadAccess();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationNavigationService.flushPendingNavigation());
    });
  }

  Future<void> _loadAccess() async {
    try {
      final permissions = await RoleAccess.currentPermissionSet(
        _authProvider,
        forceRefresh: true,
      );
      final role = permissions.role;
      final hasCurrentTabAccess =
          RoleAccess.canAccessMainTab(role, _currentIndex);
      if (!mounted) return;
      setState(() {
        _currentRole = role;
        _isLoadingAccess = false;
        if (!hasCurrentTabAccess) {
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

  Future<void> _setIndex(int index) async {
    if (_isRefreshingAccess) return;

    setState(() {
      _isRefreshingAccess = true;
    });

    try {
      final permissions = await RoleAccess.currentPermissionSet(
        _authProvider,
        forceRefresh: true,
      );
      final role = permissions.role;
      final hasAccess = RoleAccess.canAccessMainTab(role, index);
      if (!mounted) return;

      setState(() {
        _currentRole = role;
        if (hasAccess) {
          _currentIndex = index;
        } else if (!RoleAccess.canAccessMainTab(role, _currentIndex)) {
          _currentIndex = 0;
        }
        _isRefreshingAccess = false;
      });
      if (!hasAccess) {
        _showPermissionDenied(RoleAccess.mainTabLabel(index));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRefreshingAccess = false;
      });
    }
  }

  void _showPermissionDenied(String moduleLabel) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "You don't have permission to access $moduleLabel.",
          ),
        ),
      );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const HomePage(showBottomNav: false);
      case 1:
        return const LeadsPage();
      case 2:
        return const FollowUpPage();
      case 3:
        return const SiteVisitsPage();
      case 4:
        return const SiteRevisitsPage();
      case 5:
        return const ProjectsPage();
      case 6:
        return const TeamPage();
      case 7:
        return const AttendancePage();
      case 8:
        return const UsersPage();
      case 9:
        return const SalaryManagementPage();
      case 10:
        return const ClosuresPage();
      case 11:
        return const TargetsPage();
      case 12:
        return const EoiPage();
      case 13:
        return const SiteVisitDonePage();
      case 14:
        return const LeaveManagementPage();
      case 15:
        return const WebsiteEnquiriesPage();
      default:
        return const HomePage(showBottomNav: false);
    }
  }

  Future<void> _handleSystemBack() async {
    if (_currentIndex != 0) {
      _setIndex(0);
      return;
    }

    final now = DateTime.now();
    final pressedRecently = _lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) <= const Duration(seconds: 2);

    if (pressedRecently) {
      await SystemNavigator.pop();
      return;
    }

    _lastBackPressAt = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Press back again to exit')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleSystemBack();
      },
      child: Scaffold(
        body: _isLoadingAccess
            ? const AppPreloader.screen(message: 'Loading access...')
            : Stack(
                children: [
                  _buildCurrentScreen(),
                  if (_isRefreshingAccess)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x66000000),
                        child: AppPreloader.compact(
                          message: 'Refreshing access...',
                        ),
                      ),
                    ),
                ],
              ),
        bottomNavigationBar: CRMAppBottomNav(
          currentIndex: _currentIndex,
          showLeads: RoleAccess.canViewModule('leads'),
          showFollowUps: RoleAccess.canViewModule('follow_ups'),
          showEoi: RoleAccess.canViewModule('leads'),
          showSiteVisits: RoleAccess.canViewModule('site_visits'),
          showSiteVisitDone: RoleAccess.canViewModule('leads'),
          showRevisits: RoleAccess.canViewModule('revisits'),
          showProjects: RoleAccess.canViewProjects(_currentRole),
          showTeam: RoleAccess.canViewTeam(_currentRole),
          showAttendance: RoleAccess.canViewModule('attendance'),
          showTargets: RoleAccess.canViewModule('targets'),
          showLeaves: RoleAccess.canViewModule('attendance'),
          showWebsiteEnquiries: RoleAccess.isAdminOrSuperAdmin(_currentRole),
          showUsers: RoleAccess.canViewUsers(_currentRole),
          showSalary: RoleAccess.canViewSalaryManagement(_currentRole),
          showNotifications: RoleAccess.canViewModule('notifications'),
          onDashboard: () => _setIndex(0),
          onLeads: () => _setIndex(1),
          onFollowUps: () => _setIndex(2),
          onEoi: () => _setIndex(12),
          onSiteVisits: () => _setIndex(3),
          onSiteVisitDone: () => _setIndex(13),
          onRevisits: () => _setIndex(4),
          onProjects: () => _setIndex(5),
          onTeam: () => _setIndex(6),
          onReports: () => _setIndex(7),
          onSettings: () => _setIndex(8),
          onTargets: () => _setIndex(11),
          onLeaves: () => _setIndex(14),
          onWebsiteEnquiries: () => _setIndex(15),
          onNotifications: () => Navigator.pushNamed(context, '/notifications'),
          onSalary: () => _setIndex(9),
          onMore: () {},
          onLess: () {},
          onClosures:
              RoleAccess.canViewModule('closures') ? () => _setIndex(10) : null,
        ),
      ),
    );
  }
}
