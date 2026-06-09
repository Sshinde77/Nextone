import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nextone/routes/app_routes.dart';
import 'package:nextone/services/auth_service.dart';
import 'package:nextone/services/push_notification_service.dart';
import 'package:nextone/theme/app_theme.dart';
import 'package:nextone/utils/app_error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await PushNotificationService.initialize();
  } catch (e, stackTrace) {
    AppErrorHandler.logDebug(
      'Firebase setup is incomplete. Add firebase config files and rerun.',
      name: 'main',
      error: e,
      stackTrace: stackTrace,
    );
  }
  final isLoggedIn = await AuthService.hasPersistedSession();
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NextOne',
      theme: AppTheme.light(),
      initialRoute: isLoggedIn ? AppRoutes.home : AppRoutes.login,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
