import 'package:flutter/material.dart';
import 'package:nextone/screens/follow_ups/follow_up_page.dart';
import 'package:nextone/screens/main_screen.dart';
import 'package:nextone/screens/auth/forgot_password_page.dart';
import 'package:nextone/screens/auth/login_page.dart';
import 'package:nextone/screens/auth/register_page.dart';
import 'package:nextone/screens/leads/leads_page.dart';
import 'package:nextone/screens/notifications/notifications_page.dart';
import 'package:nextone/screens/site_visits/site_visits_page.dart';

class AppRoutes {
  static const String login = '/';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String leads = '/leads';
  static const String followUps = '/follow-ups';
  static const String siteVisits = '/site-visits';
  static const String notifications = '/notifications';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());
      case home:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case leads:
        return MaterialPageRoute(builder: (_) => const LeadsPage());
      case followUps:
        return MaterialPageRoute(builder: (_) => const FollowUpPage());
      case siteVisits:
        return MaterialPageRoute(builder: (_) => const SiteVisitsPage());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('No route defined'))),
        );
    }
  }
}
