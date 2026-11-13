import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for resurfaced threads.
///
/// A singleton because the plugin's tap callback outlives any widget. Web is
/// skipped: browser surfaces are not part of this phase.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String channelId = 'ghost_thread_resurface';
  static const String channelName = 'ghost_thread_resurface';
  static const String channelDescription =
      'Unfinished thoughts resurfaced at the right moment.';
  static const int snippetLength = 80;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  ValueChanged<String>? _onThreadTap;
  bool _ready = false;

  /// Initializes the plugin and wires the tap callback.
  ///
  /// Returns quickly: permission prompts are requested in the background so
  /// startup is never blocked.
  Future<void> init({ValueChanged<String>? onThreadTap}) async {
    _onThreadTap = onThreadTap;
    if (kIsWeb) {
      return;
    }

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final threadId = response.payload;
          if (threadId != null && threadId.isNotEmpty) {
            _onThreadTap?.call(threadId);
          }
        },
      );
      _ready = true;
      unawaited(_requestPermissions());
    } on Object catch (error) {
      debugPrint('Notifications unavailable: $error');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } on Object catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
  }

  /// The thread id if the app was launched from a resurfacing notification.
  Future<String?> launchPayload() async {
    if (!_ready) {
      return null;
    }

    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) {
        return null;
      }
      return details.notificationResponse?.payload;
    } on Object catch (error) {
      debugPrint('Could not read notification launch details: $error');
      return null;
    }
  }

  /// Shows the "Remember this unfinished thought?" notification for [threadId].
  Future<void> showResurface({
    required String threadId,
    required String snippet,
  }) async {
    if (!_ready) {
      return;
    }

    try {
      await _plugin.show(
        id: threadId.hashCode & 0x7fffffff,
        title: 'Remember this unfinished thought?',
        body: truncateSnippet(snippet),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: threadId,
      );
    } on Object catch (error) {
      debugPrint('Could not show resurface notification: $error');
    }
  }

  /// Collapses whitespace and shortens to about [snippetLength] characters.
  static String truncateSnippet(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= snippetLength) {
      return collapsed;
    }
    return '${collapsed.substring(0, snippetLength - 1)}…';
  }
}
