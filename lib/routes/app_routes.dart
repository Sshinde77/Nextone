import 'package:flutter/material.dart';
import 'package:nextone/screens/attendance/leave_management_page.dart';
import 'package:nextone/screens/eoi/eoi_page.dart';
import 'package:nextone/screens/follow_ups/follow_up_page.dart';
import 'package:nextone/screens/main_screen.dart';
import 'package:nextone/screens/closures/closures_page.dart';
import 'package:nextone/screens/auth/forgot_password_page.dart';
import 'package:nextone/screens/auth/login_page.dart';
import 'package:nextone/screens/auth/register_page.dart';
import 'package:nextone/screens/leads/leads_page.dart';
import 'package:nextone/screens/leads/site_visit_done_page.dart';
import 'package:nextone/screens/notifications/notifications_page.dart';
import 'package:nextone/screens/site_visits/site_visit_form_page.dart';
import 'package:nextone/screens/site_visits/site_visits_page.dart';
import 'package:nextone/screens/startup/startup_page.dart';

class AppRoutes {
  static const String startup = '/startup';
  static const String login = '/';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String leads = '/leads';
  static const String siteVisitDone = '/site-visit-done';
  static const String followUps = '/follow-ups';
  static const String siteVisits = '/site-visits';
  static const String siteVisitForm = '/site-visits/form';
  static const String leaveManagement = '/attendance/leaves';
  static const String notifications = '/notifications';
  static const String closures = '/closures';
  static const String eoi = '/eoi';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case startup:
        return MaterialPageRoute(builder: (_) => const StartupPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());
      case home:
        final dynamic args = settings.arguments;
        final int initialIndex = args is int ? args : 0;
        return MaterialPageRoute(
          builder: (_) => MainScreen(initialIndex: initialIndex),
        );
      case leads:
        return MaterialPageRoute(builder: (_) => const LeadsPage());
      case siteVisitDone:
        return MaterialPageRoute(builder: (_) => const SiteVisitDonePage());
      case followUps:
        return MaterialPageRoute(builder: (_) => const FollowUpPage());
      case siteVisits:
        return MaterialPageRoute(builder: (_) => const SiteVisitsPage());
      case siteVisitForm:
        return MaterialPageRoute(builder: (_) => const SiteVisitFormPage());
      case leaveManagement:
        return MaterialPageRoute(builder: (_) => const LeaveManagementPage());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());
      case closures:
        return MaterialPageRoute(builder: (_) => const ClosuresPage());
      case eoi:
        return MaterialPageRoute(builder: (_) => const EoiPage());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('No route defined'))),
        );
    }
  }
}
