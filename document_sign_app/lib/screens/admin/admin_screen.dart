import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import 'create_user_screen.dart';
import 'edit_user_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedDepartment = 'all';
  List<String> _departments = ['all'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get('/users');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final deps = <String>{'all'};
        for (final u in data) {
          if (u['department'] != null &&
              u['department'].toString().isNotEmpty) {
            deps.add(u['department'] as String);
          }
        }
        setState(() {
          _users = data;
          _departments = deps.toList();
          _applyFilter();
        });
      }
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    _filtered = _users.where((u) {
      final matchDept =
          _selectedDepartment == 'all' ||
          u['department'] == _selectedDepartment;
      final matchSearch =
          _searchQuery.isEmpty ||
          (u['fullName'] as String? ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (u['email'] as String? ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchDept && matchSearch;
    }).toList();
  }

  Future<void> _deleteUser(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Видалити користувача?'),
        content: Text('Ви впевнені що хочете деактивувати "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await ApiClient.delete('/users/$id');
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Користувача деактивовано'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'employee':
        return const Color(0xFF1D4ED8);
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Адмін';
      case 'employee':
        return 'Співробітник';
      default:
        return role ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final byDept = <String, List<dynamic>>{};
    for (final u in _filtered) {
      final dept = u['department'] as String? ?? 'Без відділу';
      byDept.putIfAbsent(dept, () => []).add(u);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Адмін панель'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Статистика
          Container(
            color: const Color(0xFF1D4ED8),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _statCard('Всього', _users.length.toString()),
                const SizedBox(width: 8),
                _statCard('Відділів', (_departments.length - 1).toString()),
                const SizedBox(width: 8),
                _statCard(
                  'Адмінів',
                  _users.where((u) => u['role'] == 'admin').length.toString(),
                ),
              ],
            ),
          ),
          // Пошук і фільтр
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Пошук за іменем або email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _applyFilter();
                  }),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _departments.map((dept) {
                      final isSelected = _selectedDepartment == dept;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(dept == 'all' ? 'Всі відділи' : dept),
                          selected: isSelected,
                          onSelected: (_) => setState(() {
                            _selectedDepartment = dept;
                            _applyFilter();
                          }),
                          selectedColor: const Color(0xFF1D4ED8),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Список
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Немає користувачів',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    children: byDept.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1D4ED8),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${entry.value.length})',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...entry.value.map((user) => _buildUserCard(user)),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateUserScreen()),
          );
          _load();
        },
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Додати користувача',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final role = user['role'] as String? ?? '';
    final roleColor = _roleColor(role);

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              (user['fullName'] as String? ?? 'U')[0].toUpperCase(),
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          user['fullName'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['email'] as String? ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (user['position'] != null)
              Text(
                user['position'] as String,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _roleLabel(role),
                style: TextStyle(
                  color: roleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Редагувати'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Видалити', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'edit') {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditUserScreen(user: user)),
              );
              _load();
            } else if (value == 'delete') {
              await _deleteUser(
                user['id'] as String,
                user['fullName'] as String? ?? '',
              );
            }
          },
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
