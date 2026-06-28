import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../api/api_client.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Запитуємо дозвіл
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Отримуємо токен і надсилаємо на сервер
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // Оновлення токена
    _messaging.onTokenRefresh.listen(_saveToken);

    // Обробка повідомлень у фоні
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Обробка повідомлень коли додаток відкритий
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Foreground message: ${message.notification?.title}');
    });
  }

  static Future<void> _saveToken(String token) async {
    try {
      await ApiClient.patch('/users/fcm-token', {'token': token});
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}
