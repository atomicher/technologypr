import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/models/document_model.dart';
import '../../core/providers/auth_provider.dart';
import 'secretary_pdf_viewer.dart';

class SecretaryScreen extends StatefulWidget {
  const SecretaryScreen({super.key});

  @override
  State<SecretaryScreen> createState() => _SecretaryScreenState();
}

class _SecretaryScreenState extends State<SecretaryScreen>
    with SingleTickerProviderStateMixin {
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  late TabController _tabController;
  List<Map<String, dynamic>> _directors = [];
  List<String> _selectedDirectorIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDocuments();
    _loadDirectors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get('/documents');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _documents = data.map((e) => DocumentModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Помилка завантаження')));
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadDirectors() async {
    try {
      print('Починаю завантаження директорів...');
      final response = await ApiClient.get('/documents/directors');

      print('Статус код: ${response.statusCode}');
      print('Тіло відповіді: ${response.body}'); // Дивимось, що реально прийшло

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _directors = List<Map<String, dynamic>>.from(data);
        });
        print('Директорів завантажено: ${_directors.length}');
      } else {
        print('Помилка сервера: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Помилка у Flutter: $e');
      print('Стек: $stackTrace');
    }
  }

  List<DocumentModel> _getByStatus(String status) {
    if (status == 'all') return _documents;
    return _documents.where((d) => d.status == status).toList();
  }

  Future<void> _downloadSignedDocument(DocumentModel doc) async {
    try {
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
                  Text('Завантаження...'),
                ],
              ),
            ),
          ),
        ),
      );

      final token = await ApiClient.getToken();
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/documents/${doc.id}/signed-file'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final dir = Directory('/storage/emulated/0/Download');
        final fileName = '${doc.title.replaceAll(' ', '_')}_підписаний.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Збережено: $fileName'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Підписаний файл не знайдено'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  void _showUploadDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'other';
    String selectedPriority = 'normal';
    String? selectedFilePath;
    String? selectedFileName;
    List<String> localSelectedDirectors = List.from(_selectedDirectorIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Новий документ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  titleController,
                  'Назва документа *',
                  Icons.title,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  descController,
                  'Опис (необов\'язково)',
                  Icons.notes,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Категорія',
                  icon: Icons.category_outlined,
                  value: selectedCategory,
                  items: const [
                    DropdownMenuItem(
                      value: 'accounting',
                      child: Text('📊 Бухгалтерія'),
                    ),
                    DropdownMenuItem(
                      value: 'legal',
                      child: Text('⚖️ Юридичні'),
                    ),
                    DropdownMenuItem(
                      value: 'internal',
                      child: Text('🏢 Внутрішні'),
                    ),
                    DropdownMenuItem(
                      value: 'financial',
                      child: Text('💰 Фінансові'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('📁 Інші')),
                  ],
                  onChanged: (v) => setModalState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Пріоритет',
                  icon: Icons.flag_outlined,
                  value: selectedPriority,
                  items: const [
                    DropdownMenuItem(
                      value: 'normal',
                      child: Text('⚪ Звичайний'),
                    ),
                    DropdownMenuItem(
                      value: 'important',
                      child: Text('🟡 Важливо'),
                    ),
                    DropdownMenuItem(
                      value: 'urgent',
                      child: Text('🔴 Терміново'),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => selectedPriority = v!),
                ),
                const SizedBox(height: 12),
                // Вибір директорів
                const Text(
                  'Надіслати директорам *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (_directors.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Немає доступних директорів',
                      style: TextStyle(color: Colors.orange),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: _directors.map((director) {
                        final isSelected = localSelectedDirectors.contains(
                          director['id'],
                        );
                        return CheckboxListTile(
                          title: Text(
                            director['fullName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            director['email'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: isSelected,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                localSelectedDirectors.add(director['id']);
                              } else {
                                localSelectedDirectors.remove(director['id']);
                              }
                            });
                          },
                          activeColor: const Color(0xFF1976D2),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                // Вибір файлу
                GestureDetector(
                  onTap: () async {
                    try {
                      const channel = MethodChannel('file_picker_channel');
                      final String? path = await channel.invokeMethod(
                        'pickFile',
                      );
                      if (path != null) {
                        setModalState(() {
                          selectedFilePath = path;
                          selectedFileName = path.split('/').last;
                        });
                      }
                    } catch (e) {
                      // ignore
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedFileName != null
                            ? Colors.green
                            : Colors.grey[400]!,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: selectedFileName != null
                          ? Colors.green.withValues(alpha: 0.05)
                          : Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedFileName != null
                              ? Icons.check_circle
                              : Icons.attach_file,
                          color: selectedFileName != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedFileName ?? 'Вибрати PDF файл',
                            style: TextStyle(
                              color: selectedFileName != null
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      'Надіслати на підпис',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (titleController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Введіть назву документа'),
                          ),
                        );
                        return;
                      }
                      if (localSelectedDirectors.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Виберіть хоча б одного директора'),
                          ),
                        );
                        return;
                      }
                      if (selectedFilePath == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Виберіть PDF файл')),
                        );
                        return;
                      }
                      setState(
                        () => _selectedDirectorIds = localSelectedDirectors,
                      );
                      Navigator.pop(context);
                      await _uploadDocument(
                        title: titleController.text,
                        description: descController.text,
                        category: selectedCategory,
                        priority: selectedPriority,
                        filePath: selectedFilePath!,
                        directorIds: localSelectedDirectors,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Future<void> _uploadDocument({
    required String title,
    required String description,
    required String category,
    required String priority,
    required String filePath,
    required List<String> directorIds,
  }) async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final response =
          await ApiClient.multipartPost('/documents/upload', filePath, {
            'title': title,
            'description': description,
            'category': category,
            'priority': priority,
            'directorIds': jsonEncode(directorIds),
          });

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 201) {
        setState(() => _selectedDirectorIds = []);
        await _loadDocuments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Документ надіслано директорам на підпис'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Помилка підключення')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pendingCount = _getByStatus('pending').length;
    final signedCount = _getByStatus('signed').length;
    final rejectedCount = _getByStatus('rejected').length;
    final reviewCount = _getByStatus('review').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 210,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDocuments,
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await auth.logout();
                  if (mounted) Navigator.pushReplacementNamed(context, '/');
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF1976D2),
                      Color(0xFF42A5F5),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Вітаємо, ${auth.user?.fullName.split(' ').first ?? 'Секретар'}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _statBadge(
                                'На підписі',
                                pendingCount,
                                Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              _statBadge(
                                'Підписано',
                                signedCount,
                                Colors.green,
                              ),
                              const SizedBox(width: 8),
                              _statBadge(
                                'Відхилено',
                                rejectedCount,
                                Colors.red,
                              ),
                              const SizedBox(width: 8),
                              _statBadge(
                                'Відкладено',
                                reviewCount,
                                Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                const Tab(text: 'Всі'),
                Tab(text: pendingCount > 0 ? '⏳ ($pendingCount)' : '⏳'),
                Tab(text: signedCount > 0 ? '✅ ($signedCount)' : '✅'),
                Tab(text: rejectedCount > 0 ? '❌ ($rejectedCount)' : '❌'),
              ],
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildDocumentList(_getByStatus('all')),
                  _buildDocumentList(_getByStatus('pending')),
                  _buildDocumentList(_getByStatus('signed')),
                  _buildDocumentList(_getByStatus('rejected')),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text(
          'Завантажити',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 4,
      ),
    );
  }

  Widget _buildDocumentList(List<DocumentModel> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 40,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Немає документів',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: docs.length,
        itemBuilder: (context, index) => _buildDocumentCard(docs[index]),
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel doc) {
    final statusColor = _statusColor(doc.status);
    final isSigned = doc.status == 'signed';
    final isRejected = doc.status == 'rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isSigned || isRejected
            ? Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SecretaryPdfViewer(document: doc),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSigned
                            ? Icons.verified_rounded
                            : Icons.picture_as_pdf_rounded,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            doc.categoryLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        doc.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isSigned) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Директор підписав документ КЕП',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _downloadSignedDocument(doc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.download,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Скачати',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isRejected) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Директор відхилив документ',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'signed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'review':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
