//lib/notifications_helper.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html; // Web only
import 'dart:async';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static final Map<String, Timer> _webTimers = {};

  static Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;

        if (payload == 'attendance:open') {
          _navigatorKey?.currentState?.pushNamed('/attendance-status');
        }
      },
    );
  }

  static Future<void> schedule(
  String idKey, {
  required int minutesFromNow,
  required String title,
  required String body,
  required String soundFileName,
  String? payload,
}) async {
  final id = idKey.hashCode;

  // ✅ IF WEB — use browser notification
  if (kIsWeb) {
    // Request permission if not granted
    if (html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }

    // Schedule using Future.delayed
    Future.delayed(Duration(minutes: minutesFromNow), () {
      if (html.Notification.permission == 'granted') {
        html.Notification(title, body: body);
      }
    });

    return;
  }

  // ✅ MOBILE (Android/iOS)
  final scheduled =
      tz.TZDateTime.now(tz.local).add(Duration(minutes: minutesFromNow));

  final androidDetails = AndroidNotificationDetails(
    'break_channel',
    'Break Alerts',
    channelDescription: 'Break notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(
        soundFileName.replaceAll('.mp3', '')),
  );

  final iosDetails = DarwinNotificationDetails(
    sound: soundFileName,
  );

  await _plugin.zonedSchedule(
    id,
    title,
    body,
    scheduled,
    NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    payload: payload,
  );
}

  static Future<void> cancel(String idKey) async {
  if (kIsWeb) {
    _webTimers[idKey]?.cancel();
    _webTimers.remove(idKey);
    return;
  }

  await _plugin.cancel(idKey.hashCode);
}
  static Future<void> cancelBreakNotifications(String empId) async {
    await cancel('break58_$empId');
    await cancel('break60_$empId');
  }
}