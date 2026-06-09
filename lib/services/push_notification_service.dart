import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nextone/services/auth_service.dart';
import 'package:nextone/utils/app_error_handler.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppErrorHandler.logDebug(
    'Background message received: ${message.messageId}, data=${message.data}',
    name: 'PushNotificationService',
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'nextone_foreground_notifications',
    'Foreground Notifications',
    description: 'Shows incoming FCM alerts when app is in foreground.',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _requestPermission();
    await _configureForegroundPresentation();
    await _configureListeners();
    await _printToken();
  }

  static Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initializationSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
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

    AppErrorHandler.logDebug(
      'Notification permission status: ${settings.authorizationStatus.name}',
      name: 'PushNotificationService',
    );
  }

  static Future<void> _configureListeners() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      AppErrorHandler.logDebug(
        'Foreground message: ${message.messageId}, '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}, '
        'data=${message.data}',
        name: 'PushNotificationService',
      );

      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppErrorHandler.logDebug(
        'Notification tapped: ${message.messageId}, data=${message.data}',
        name: 'PushNotificationService',
      );
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      AppErrorHandler.logDebug(
        'Opened from terminated state: ${initialMessage.messageId}, data=${initialMessage.data}',
        name: 'PushNotificationService',
      );
    }

    _messaging.onTokenRefresh.listen((token) {
      AppErrorHandler.logDebug('FCM token refreshed: $token',
          name: 'PushNotificationService');
      unawaited(syncTokenWithBackend(token: token));
    });
  }

  static Future<void> _configureForegroundPresentation() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      title ?? 'New notification',
      body ?? '',
      notificationDetails,
    );
  }

  static Future<void> _printToken() async {
    try {
      if (!kIsWeb) {
        final token = await _messaging.getToken();
        AppErrorHandler.logDebug('FCM token: $token',
            name: 'PushNotificationService');
      }
    } catch (e, stackTrace) {
      AppErrorHandler.logDebug(
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
      AppErrorHandler.logDebug(
        'FCM token synced to backend.',
        name: 'PushNotificationService',
      );
    } catch (e, stackTrace) {
      AppErrorHandler.logDebug(
        'Failed to sync FCM token to backend.',
        name: 'PushNotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
