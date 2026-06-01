import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:nextone/services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log(
    'Background message received: ${message.messageId}, data=${message.data}',
    name: 'PushNotificationService',
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    await _requestPermission();
    await _configureListeners();
    await _printToken();
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    developer.log(
      'Notification permission status: ${settings.authorizationStatus.name}',
      name: 'PushNotificationService',
    );
  }

  static Future<void> _configureListeners() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log(
        'Foreground message: ${message.messageId}, '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}, '
        'data=${message.data}',
        name: 'PushNotificationService',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log(
        'Notification tapped: ${message.messageId}, data=${message.data}',
        name: 'PushNotificationService',
      );
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      developer.log(
        'Opened from terminated state: ${initialMessage.messageId}, data=${initialMessage.data}',
        name: 'PushNotificationService',
      );
    }

    _messaging.onTokenRefresh.listen((token) {
      developer.log('FCM token refreshed: $token', name: 'PushNotificationService');
      unawaited(syncTokenWithBackend(token: token));
    });
  }

  static Future<void> _printToken() async {
    try {
      if (!kIsWeb) {
        final token = await _messaging.getToken();
        developer.log('FCM token: $token', name: 'PushNotificationService');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to fetch FCM token',
        name: 'PushNotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> syncTokenWithBackend({String? token}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final authToken = AuthService.currentAuthToken;
    if (authToken == null || authToken.trim().isEmpty) {
      return;
    }

    final resolvedToken = (token ?? await _messaging.getToken())?.trim();
    if (resolvedToken == null || resolvedToken.isEmpty) {
      return;
    }

    try {
      await AuthService().registerFcmToken(
        fcmToken: resolvedToken,
        platform: 'android',
        token: authToken,
      );
      developer.log(
        'FCM token synced to backend.',
        name: 'PushNotificationService',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to sync FCM token to backend.',
        name: 'PushNotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
