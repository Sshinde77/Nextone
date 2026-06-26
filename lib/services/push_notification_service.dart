import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nextone/services/auth_service.dart';
import 'package:nextone/services/notification_navigation_service.dart';
import 'package:nextone/utils/app_error_handler.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppErrorHandler.logDebug(
    'Background message received: '
    'id=${message.messageId}, '
    'title=${message.notification?.title}, '
    'body=${message.notification?.body}, '
    'data=${message.data}',
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
    AppErrorHandler.logDebug(
      'Initializing push notification service.',
      name: 'PushNotificationService',
    );
    await _initializeLocalNotifications();
    await _requestPermission();
    await _configureForegroundPresentation();
    await _configureListeners();
    await _printToken();
  }

  static Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

    AppErrorHandler.logDebug(
      'Initializing local notifications.',
      name: 'PushNotificationService',
    );
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        AppErrorHandler.logDebug(
          'Local notification tapped: '
          'id=${response.id}, '
          'actionId=${response.actionId}, '
          'payload=${response.payload}',
          name: 'PushNotificationService',
        );
        unawaited(_handleLocalNotificationPayload(response.payload));
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    AppErrorHandler.logDebug(
      'Notification launch details: '
      'didLaunch=${launchDetails?.didNotificationLaunchApp}, '
      'payload=$launchPayload',
      name: 'PushNotificationService',
    );
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.trim().isNotEmpty) {
      await _handleLocalNotificationPayload(launchPayload);
    }
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
        'Foreground message received: ${message.messageId}, '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}, '
        'data=${message.data}',
        name: 'PushNotificationService',
      );

      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppErrorHandler.logDebug(
        'Notification tapped while app in background: '
        'id=${message.messageId}, '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}, '
        'data=${message.data}',
        name: 'PushNotificationService',
      );
      unawaited(NotificationNavigationService.handleRemoteMessage(message));
    });

    final initialMessage = await _messaging.getInitialMessage();
    AppErrorHandler.logDebug(
      'Initial FCM message: '
      'id=${initialMessage?.messageId}, '
      'title=${initialMessage?.notification?.title}, '
      'body=${initialMessage?.notification?.body}, '
      'data=${initialMessage?.data}',
      name: 'PushNotificationService',
    );
    if (initialMessage != null) {
      AppErrorHandler.logDebug(
        'Opened from terminated state via FCM.',
        name: 'PushNotificationService',
      );
      unawaited(
          NotificationNavigationService.handleRemoteMessage(initialMessage));
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
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        message.data['description']?.toString();
    final resolvedTitle =
        (title == null || title.trim().isEmpty) ? 'New notification' : title;
    final resolvedBody =
        (body == null || body.trim().isEmpty) ? 'Tap to view details' : body;

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    AppErrorHandler.logDebug(
      'Showing local foreground notification: '
      'id=${message.messageId}, '
      'title=$resolvedTitle, '
      'body=$resolvedBody, '
      'data=${message.data}',
      name: 'PushNotificationService',
    );

    await _localNotifications.show(
      message.hashCode,
      resolvedTitle,
      resolvedBody,
      notificationDetails,
      payload: jsonEncode(<String, dynamic>{
        ...message.data,
        if (message.messageId != null) 'message_id': message.messageId,
        'title': resolvedTitle,
        'body': resolvedBody,
      }),
    );
  }

  static Future<void> _handleLocalNotificationPayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) {
      AppErrorHandler.logDebug(
        'Local notification payload was empty.',
        name: 'PushNotificationService',
      );
      return;
    }

    AppErrorHandler.logDebug(
      'Decoding local notification payload: $payload',
      name: 'PushNotificationService',
    );
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        AppErrorHandler.logDebug(
          'Local notification payload decoded successfully: $decoded',
          name: 'PushNotificationService',
        );
        await NotificationNavigationService.handlePayload(
          decoded.map(
            (key, dynamic value) => MapEntry(key.toString(), value),
          ),
          sourceLabel: 'local_notification',
        );
      } else {
        AppErrorHandler.logDebug(
          'Local notification payload decoded to non-map type: ${decoded.runtimeType}',
          name: 'PushNotificationService',
        );
      }
    } catch (error, stackTrace) {
      AppErrorHandler.logDebug(
        'Failed to decode local notification payload.',
        name: 'PushNotificationService',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
