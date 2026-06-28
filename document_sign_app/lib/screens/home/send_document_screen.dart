import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';

class SendDocumentScreen extends StatefulWidget {
  const SendDocumentScreen({super.key});

  @override
  State<SendDocumentScreen> createState() => _SendDocumentScreenState();
}

class _SendDocumentScreenState extends State<SendDocumentScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'other';
  String _priority = 'normal';
  String? _filePath;
  String? _fileName;
  bool _isLoading = false;
  List<dynamic> _allUsers = [];

  // Кроки підписання: [{step: 1, signers: [user1, user2]}, {step: 2, signers: [user3]}]
  List<Map<String, dynamic>> _steps = [
    {'step': 1, 'signers': <dynamic>[]},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await ApiClient.get('/documents/users');
      if (response.statusCode == 200) {
        setState(() => _allUsers = jsonDecode(response.body));
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _pickFile() async {
    try {
      const channel = MethodChannel('file_picker_channel');
      final String? path = await channel.invokeMethod('pickFile');
      if (path != null) {
        setState(() {
          _filePath = path;
          _fileName = path.split('/').last;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _addStep() {
    setState(() {
      _steps.add({'step': _steps.length + 1, 'signers': <dynamic>[]});
    });
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    setState(() {
      _steps.removeAt(index);
      for (int i = 0; i < _steps.length; i++) {
        _steps[i]['step'] = i + 1;
      }
    });
  }

  void _showUserPicker(int stepIndex) {
    final stepSigners = List.from(_steps[stepIndex]['signers'] as List);
    String selectedDept = 'all';

    final departments = <String>{'all'};
    for (final u in _allUsers) {
      if (u['department'] != null && u['department'].toString().isNotEmpty) {
        departments.add(u['department'] as String);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = selectedDept == 'all'
              ? _allUsers
              : _allUsers
                    .where((u) => u['department'] == selectedDept)
                    .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Підписанти — Крок ${stepIndex + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Фільтр по відділах
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: departments.map((dept) {
                      final isSelected = selectedDept == dept;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            dept == 'all' ? 'Всі' : dept,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setSheetState(() => selectedDept = dept),
                          selectedColor: const Color(0xFF1D4ED8),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Немає співробітників у цьому відділі',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView(
                          children: filtered.map((user) {
                            final isSelected = stepSigners.any(
                              (s) => s['id'] == user['id'],
                            );
                            return CheckboxListTile(
                              title: Text(
                                user['fullName'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (user['position'] != null)
                                    Text(
                                      user['position'] as String,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  if (user['department'] != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1D4ED8,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        user['department'] as String,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              value: isSelected,
                              onChanged: (val) {
                                setSheetState(() {
                                  if (val == true) {
                                    stepSigners.add(user);
                                  } else {
                                    stepSigners.removeWhere(
                                      (s) => s['id'] == user['id'],
                                    );
                                  }
                                });
                              },
                              activeColor: const Color(0xFF1D4ED8),
                            );
                          }).toList(),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(
                          () => _steps[stepIndex]['signers'] = stepSigners,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Підтвердити (${stepSigners.length} обрано)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _send() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введіть назву документа')));
      return;
    }
    if (_filePath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Виберіть PDF файл')));
      return;
    }

    final allSigners = _steps.every((s) => (s['signers'] as List).isEmpty);
    if (allSigners) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Додайте хоча б одного підписанта')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Формуємо список recipients
    final recipients = <Map<String, dynamic>>[];
    for (final step in _steps) {
      for (final signer in step['signers'] as List) {
        recipients.add({'signerId': signer['id'], 'step': step['step']});
      }
    }

    try {
      final response =
          await ApiClient.multipartPost('/documents/upload', _filePath!, {
            'title': _titleController.text,
            'description': _descController.text,
            'category': _category,
            'priority': _priority,
            'recipients': jsonEncode(recipients),
          });

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Документ надіслано на підписання'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Помилка підключення')));
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Новий документ'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Інформація про документ',
              child: Column(
                children: [
                  _buildField(
                    _titleController,
                    'Назва документа *',
                    Icons.title,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _descController,
                    'Опис',
                    Icons.notes,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    'Категорія',
                    Icons.category_outlined,
                    _category,
                    [
                      const DropdownMenuItem(
                        value: 'accounting',
                        child: Text('📊 Бухгалтерія'),
                      ),
                      const DropdownMenuItem(
                        value: 'legal',
                        child: Text('⚖️ Юридичні'),
                      ),
                      const DropdownMenuItem(
                        value: 'internal',
                        child: Text('🏢 Внутрішні'),
                      ),
                      const DropdownMenuItem(
                        value: 'financial',
                        child: Text('💰 Фінансові'),
                      ),
                      const DropdownMenuItem(
                        value: 'hr',
                        child: Text('👥 Кадри'),
                      ),
                      const DropdownMenuItem(
                        value: 'contracts',
                        child: Text('📝 Договори'),
                      ),
                      const DropdownMenuItem(
                        value: 'reports',
                        child: Text('📈 Звіти'),
                      ),
                      const DropdownMenuItem(
                        value: 'invoices',
                        child: Text('🧾 Рахунки'),
                      ),
                      const DropdownMenuItem(
                        value: 'orders',
                        child: Text('📋 Накази'),
                      ),
                      const DropdownMenuItem(
                        value: 'other',
                        child: Text('📁 Інші'),
                      ),
                    ],
                    (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    'Пріоритет',
                    Icons.flag_outlined,
                    _priority,
                    [
                      const DropdownMenuItem(
                        value: 'normal',
                        child: Text('⚪ Звичайний'),
                      ),
                      const DropdownMenuItem(
                        value: 'important',
                        child: Text('🟡 Важливо'),
                      ),
                      const DropdownMenuItem(
                        value: 'urgent',
                        child: Text('🔴 Терміново'),
                      ),
                    ],
                    (v) => setState(() => _priority = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'PDF файл',
              child: GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _fileName != null
                          ? Colors.green
                          : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _fileName != null
                        ? Colors.green.withValues(alpha: 0.05)
                        : Colors.grey[50],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _fileName != null
                            ? Icons.check_circle
                            : Icons.attach_file,
                        color: _fileName != null ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _fileName ?? 'Натисніть щоб вибрати PDF',
                          style: TextStyle(
                            color: _fileName != null
                                ? Colors.green
                                : Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Ланцюжок підписів',
              child: Column(
                children: [
                  ..._steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    final signers = step['signers'] as List;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1D4ED8,
                              ).withValues(alpha: 0.05),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1D4ED8),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Крок ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                                const Spacer(),
                                if (_steps.length > 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeStep(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (signers.isEmpty)
                                  const Text(
                                    'Підписантів не вибрано',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: signers
                                        .map<Widget>(
                                          (s) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF1D4ED8,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              s['fullName'] ?? '',
                                              style: const TextStyle(
                                                color: Color(0xFF1D4ED8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.person_add_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Вибрати підписантів'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1D4ED8),
                                    side: const BorderSide(
                                      color: Color(0xFF1D4ED8),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () => _showUserPicker(index),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Додати крок'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1D4ED8),
                      side: const BorderSide(color: Color(0xFF1D4ED8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: _addStep,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text(
                  'Надіслати на підписання',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _send,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController c,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1D4ED8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    IconData icon,
    String value,
    List<DropdownMenuItem<String>> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1D4ED8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
