import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/api/api_client.dart';

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
  List<dynamic> _keys = [];
  String? _selectedKeyId;
  bool _keysLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() => _keysLoading = true);
    try {
      final response = await ApiClient.get('/signatures/keys');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _keys = data;
          final defaultKey = data.firstWhere(
            (k) => k['isDefault'] == true,
            orElse: () => data.isNotEmpty ? data[0] : null,
          );
          if (defaultKey != null) _selectedKeyId = defaultKey['id'];
        });
      }
    } catch (e) {
      // ignore
    }
    setState(() => _keysLoading = false);
  }

  Future<void> _uploadKey() async {
    try {
      const channel = MethodChannel('file_picker_channel');
      final String? path = await channel.invokeMethod('pickFile');
      if (path == null) return;

      // Питаємо пароль
      final passwordController = TextEditingController();
      bool obscure = true;
      String? error;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    color: Color(0xFF1D4ED8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Пароль до ключа'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path.split('/').last,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Введіть пароль для перевірки та підтвердження ключа',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (ctx2, setFieldState) => TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Пароль від .p12 ключа',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF1D4ED8),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setFieldState(() => obscure = !obscure);
                          setDialogState(() {});
                        },
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Скасувати'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('Додати ключ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  if (passwordController.text.isEmpty) {
                    setDialogState(() => error = 'Введіть пароль');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) return;

      // Показуємо індикатор завантаження
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Перевірка ключа...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final response = await ApiClient.multipartPost(
        '/signatures/upload-key',
        path,
        {'password': passwordController.text},
        fieldName: 'key',
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ключ перевірено та додано'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadKeys();
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Помилка додавання ключа'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  Future<void> _sign() async {
    if (_selectedKeyId == null) {
      setState(() => _error = 'Виберіть ключ для підписання');
      return;
    }
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
          'keyId': _selectedKeyId,
          'password': _passwordController.text,
          'pdfPath': widget.pdfPath,
        }),
      );

      if (response.statusCode == 201) {
        await ApiClient.patch('/documents/${widget.documentId}/sign', {
          'status': 'signed',
        });
        if (mounted) {
          Navigator.pop(context);
          widget.onSigned();
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.draw_rounded,
              color: Color(0xFF1D4ED8),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text('КЕП Підписання'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.documentTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // Вибір ключа
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ключ підпису',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Додати', style: TextStyle(fontSize: 12)),
                  onPressed: _uploadKey,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _keysLoading
                ? const Center(child: CircularProgressIndicator())
                : _keys.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '⚠️ Немає завантажених ключів',
                          style: TextStyle(color: Colors.orange),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Завантажити .p12'),
                          onPressed: _uploadKey,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _keys.map((key) {
                      final isSelected = _selectedKeyId == key['id'];
                      final isDefault = key['isDefault'] == true;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedKeyId = key['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1D4ED8).withValues(alpha: 0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1D4ED8)
                                  : Colors.grey[200]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? const Color(0xFF1D4ED8)
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      key['keyName'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF1D4ED8)
                                            : Colors.black,
                                      ),
                                    ),
                                    if (isDefault)
                                      const Text(
                                        'За замовчуванням',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 16),

            // Пароль
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Пароль від ключа',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
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
              : const Icon(Icons.draw_rounded),
          label: const Text('Підписати'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: (_isLoading || _keys.isEmpty) ? null : _sign,
        ),
      ],
    );
  }
}
