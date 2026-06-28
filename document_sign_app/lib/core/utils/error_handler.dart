import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ErrorHandler {
  static String parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      final message = data['message'];
      if (message is List) return message.join('\n');
      return message?.toString() ?? _statusMessage(response.statusCode);
    } catch (e) {
      return _statusMessage(response.statusCode);
    }
  }

  static String _statusMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Невірні дані запиту';
      case 401:
        return 'Невірний логін або пароль';
      case 403:
        return 'Немає доступу';
      case 404:
        return 'Не знайдено';
      case 409:
        return 'Такий запис вже існує';
      case 500:
        return 'Помилка сервера. Спробуйте пізніше';
      default:
        return 'Помилка з\'єднання (код $statusCode)';
    }
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1D4ED8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
