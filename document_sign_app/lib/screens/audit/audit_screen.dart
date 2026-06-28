import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/date_formatter.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get('/audit/my');
      if (response.statusCode == 200) {
        setState(() => _logs = jsonDecode(response.body));
      }
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filtered {
    if (_filter == 'all') return _logs;
    return _logs.where((l) => l['action'] == _filter).toList();
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'upload':
        return Icons.upload_file_rounded;
      case 'sign':
        return Icons.draw_rounded;
      case 'reject':
        return Icons.cancel_rounded;
      case 'review':
        return Icons.schedule_rounded;
      case 'view':
        return Icons.visibility_rounded;
      case 'login':
        return Icons.login_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'upload':
        return const Color(0xFF1D4ED8);
      case 'sign':
        return Colors.green;
      case 'reject':
        return Colors.red;
      case 'review':
        return Colors.orange;
      case 'view':
        return Colors.grey;
      case 'login':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'upload':
        return 'Завантажено документ';
      case 'sign':
        return 'Підписано документ';
      case 'reject':
        return 'Відхилено документ';
      case 'review':
        return 'Відкладено документ';
      case 'view':
        return 'Переглянуто документ';
      case 'login':
        return 'Вхід до системи';
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Журнал дій'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Фільтри (Виправлено кольори та фон)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: const Color(
              0xFFF8FAFC,
            ), // Колір фону такий самий як у екрану
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('all', 'Всі'),
                  _chip('upload', '📤 Завантаження'),
                  _chip('sign', '✅ Підписи'),
                  _chip('reject', '❌ Відхилення'),
                  _chip('view', '👁 Перегляди'),
                ],
              ),
            ),
          ),
          // Список
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Немає записів',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final log = _filtered[index];
                        final action = log['action'] as String? ?? '';
                        final color = _actionColor(action);
                        final metadata =
                            log['metadata'] as Map<String, dynamic>?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _actionIcon(action),
                                color: color,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              _actionLabel(action),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (metadata?['title'] != null)
                                  Text(
                                    metadata!['title'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormatter.format(
                                    log['createdAt'] as String?,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                log['entityType'] as String? ?? '',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Виправлений віджет кнопок фільтру
  Widget _chip(String value, String label) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 13)),
        selected: isSelected,
        onSelected: (_) => setState(() => _filter = value),

        // Колір фону
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF1D4ED8).withValues(alpha: 0.1),

        // Рамка
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey[300]!,
            width: 1,
          ),
        ),

        // Колір тексту: чорний, якщо не обрано, синій, якщо обрано
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF1D4ED8) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        checkmarkColor: const Color(0xFF1D4ED8),
      ),
    );
  }
}
