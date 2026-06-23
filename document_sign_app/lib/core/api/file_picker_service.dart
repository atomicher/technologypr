import 'package:flutter/services.dart';

class FilePickerService {
  static const _channel = MethodChannel('file_picker_channel');

  static Future<String?> pickFile() async {
    try {
      final String? path = await _channel.invokeMethod('pickFile');
      return path;
    } catch (e) {
      return null;
    }
  }
}
