import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/api/api_client.dart';
import '../../core/api/file_picker_service.dart';

class SignDialog extends StatefulWidget {
  final String documentId;
  final String documentTitle;
  final String pdfPath;
  final VoidCallback onSigned;

  const SignDialog({
    super.key,
    required this.documentId,
    required this.documentTitle,
    required this.pdfPath,
    required this.onSigned,
  });

  @override
  State<SignDialog> createState() => _SignDialogState();
}

class _SignDialogState extends State<SignDialog> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final response = await ApiClient.get('/signatures/check-key');
    setState(() => _hasKey = response.statusCode == 200);
  }

  Future<void> _uploadKey() async {
    final path = await FilePickerService.pickFile();
    if (path != null) {
      await _sendKey(path);
    }
  }

  Future<void> _sendKey(String filePath) async {
    setState(() => _isLoading = true);
    print('Uploading key from: $filePath');
    try {
      final response = await ApiClient.multipartPost(
        '/signatures/upload-key',
        filePath,
        {},
        fieldName: 'key',
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 201) {
        setState(() => _hasKey = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ключ завантажено'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Помилка: ${response.statusCode} ${response.body}'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _sign() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Введіть пароль від ключа');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await ApiClient.getToken();
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/signatures/${widget.documentId}/sign'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'password': _passwordController.text,
          'pdfPath': widget.pdfPath,
        }),
      );

      if (response.statusCode == 201) {
        // Також оновлюємо статус документа
        await ApiClient.patch('/documents/${widget.documentId}/status', {
          'status': 'signed',
        });

        if (mounted) {
          Navigator.pop(context);
          widget.onSigned();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Документ підписано КЕП'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() => _error = data['message'] ?? 'Помилка підписання');
      }
    } catch (e) {
      setState(() => _error = 'Помилка підключення');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('КЕП Підписання'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.documentTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (!_hasKey) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  '⚠️ Ключ .p12 не завантажено. Спочатку завантажте ваш ключ.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Завантажити .p12 ключ'),
                  onPressed: _isLoading ? null : _uploadKey,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_hasKey) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text(
                  '✅ Ключ завантажено. Введіть пароль для підписання.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Пароль від .p12 ключа',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Скасувати'),
        ),
        ElevatedButton.icon(
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.draw),
          label: const Text('Підписати КЕП'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
          ),
          onPressed: (_isLoading || !_hasKey) ? null : _sign,
        ),
      ],
    );
  }
}
