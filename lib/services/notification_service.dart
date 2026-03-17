import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Callback for navigating to a detail screen when notification is tapped.
  void Function(String entityId, String entityName)? onNotificationTap;

  Future<void> init() async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications for foreground display
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'service_updates',
          'Service Updates',
          description: 'Notifications when bookmarked services are updated',
          importance: Importance.defaultImportance,
        ));

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle notification tap from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'service_updates',
          'Service Updates',
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: '${message.data['entity_id']}|${message.data['entity_name']}',
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.contains('|')) return;
    final parts = payload.split('|');
    if (parts.length >= 2) {
      onNotificationTap?.call(parts[0], parts[1]);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final entityId = message.data['entity_id'] as String?;
    final entityName = message.data['entity_name'] as String? ?? '';
    if (entityId != null) {
      onNotificationTap?.call(entityId, entityName);
    }
  }

  /// Subscribe to push notifications for a bookmarked entity.
  Future<void> subscribeToEntity(String entityId) async {
    try {
      await _messaging.subscribeToTopic('entity_$entityId');
      if (kDebugMode) debugPrint('FCM: subscribed to entity_$entityId');
    } catch (e) {
      if (kDebugMode) debugPrint('FCM: subscribe failed: $e');
    }
  }

  /// Unsubscribe from push notifications for an unbookmarked entity.
  Future<void> unsubscribeFromEntity(String entityId) async {
    try {
      await _messaging.unsubscribeFromTopic('entity_$entityId');
      if (kDebugMode) debugPrint('FCM: unsubscribed from entity_$entityId');
    } catch (e) {
      if (kDebugMode) debugPrint('FCM: unsubscribe failed: $e');
    }
  }
}
