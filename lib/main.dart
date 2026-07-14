import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nextone/routes/app_routes.dart';
import 'package:nextone/services/notification_navigation_service.dart';
import 'package:nextone/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationNavigationService.flushPendingNavigation());
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NextOne',
      theme: AppTheme.light(),
      navigatorKey: NotificationNavigationService.navigatorKey,
      initialRoute: AppRoutes.startup,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
