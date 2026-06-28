import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class EditUserScreen extends StatefulWidget {
  final dynamic user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _positionController;
  late TextEditingController _departmentController;
  late String _role;
  bool _isLoading = false;
  List<String> _existingDepartments = [];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.user['fullName'] as String? ?? '',
    );
    _positionController = TextEditingController(
      text: widget.user['position'] as String? ?? '',
    );
    _departmentController = TextEditingController(
      text: widget.user['department'] as String? ?? '',
    );
    _role = widget.user['role'] as String? ?? 'employee';
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final response = await ApiClient.get('/users/departments');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() => _existingDepartments = data.cast<String>());
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.patch('/users/${widget.user['id']}', {
        'fullName': _fullNameController.text.trim(),
        'position': _positionController.text.trim(),
        'department': _departmentController.text.trim(),
        'role': _role,
      });

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Збережено'),
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
        title: const Text('Редагування'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
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
                  const Text(
                    'Дані користувача',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _fullNameController,
                    "Повне ім'я",
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _field(_positionController, 'Посада', Icons.work_outline),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _departmentController,
                    decoration: InputDecoration(
                      labelText: 'Відділ',
                      prefixIcon: const Icon(
                        Icons.business_outlined,
                        color: Color(0xFF1D4ED8),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  if (_existingDepartments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _existingDepartments
                          .map(
                            (dept) => ActionChip(
                              label: Text(
                                dept,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () =>
                                  _departmentController.text = dept,
                              backgroundColor: const Color(
                                0xFF1D4ED8,
                              ).withValues(alpha: 0.1),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Роль',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _roleButton(
                          'employee',
                          'Співробітник',
                          Icons.person_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _roleButton(
                          'admin',
                          'Адміністратор',
                          Icons.admin_panel_settings_rounded,
                        ),
                      ),
                    ],
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
                    : const Icon(Icons.save_rounded),
                label: const Text(
                  'Зберегти зміни',
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
                onPressed: _isLoading ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
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
    );
  }

  Widget _roleButton(String value, String label, IconData icon) {
    final isSelected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
