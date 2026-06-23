import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/models/document_model.dart';
import '../../core/providers/auth_provider.dart';
import 'pdf_viewer_screen.dart';
import 'sign_dialog.dart';

class DirectorScreen extends StatefulWidget {
  const DirectorScreen({super.key});

  @override
  State<DirectorScreen> createState() => _DirectorScreenState();
}

class _DirectorScreenState extends State<DirectorScreen>
    with SingleTickerProviderStateMixin {
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  String _categoryFilter = 'all';
  String _priorityFilter = 'all';
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDocuments();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Помилка завантаження документів')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  List<DocumentModel> _getByStatus(String status) {
    var docs = status == 'all'
        ? _documents
        : _documents.where((d) => d.status == status).toList();

    if (_categoryFilter != 'all') {
      docs = docs.where((d) => d.category == _categoryFilter).toList();
    }
    if (_priorityFilter != 'all') {
      docs = docs.where((d) => d.priority == _priorityFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      docs = docs
          .where(
            (d) =>
                d.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                d.originalName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }
    return docs;
  }

  Future<void> _updateStatus(
    String docId,
    String status, {
    String? reason,
  }) async {
    final body = {
      'status': status,
      if (reason != null) 'rejectionReason': reason,
    };
    final response = await ApiClient.patch('/documents/$docId/status', body);
    if (response.statusCode == 200) {
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusMessage(status)),
            backgroundColor: status == 'signed'
                ? Colors.green
                : status == 'rejected'
                ? Colors.red
                : Colors.orange,
          ),
        );
      }
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'signed':
        return '✅ Документ підписано КЕП';
      case 'rejected':
        return '❌ Документ відхилено';
      case 'review':
        return '🕐 Відкладено на потім';
      default:
        return 'Статус оновлено';
    }
  }

  void _showActionSheet(DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              doc.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              doc.categoryLabel,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 20),
            _actionButton(
              icon: Icons.draw_rounded,
              label: 'Підписати КЕП',
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => SignDialog(
                    documentId: doc.id,
                    documentTitle: doc.title,
                    pdfPath: doc.filePath,
                    onSigned: _loadDocuments,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _actionButton(
              icon: Icons.schedule_rounded,
              label: 'Підписати пізніше',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.pop(context);
                _updateStatus(doc.id, 'review');
              },
            ),
            const SizedBox(height: 8),
            _actionButton(
              icon: Icons.cancel_rounded,
              label: 'Відхилити',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.pop(context);
                _showRejectDialog(doc);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
      ),
    );
  }

  void _showRejectDialog(DocumentModel doc) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Причина відхилення'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Вкажіть причину...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(doc.id, 'rejected', reason: controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Відхилити'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'signed':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'review':
        return const Color(0xFF3B82F6);
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'important':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pendingCount = _documents.where((d) => d.status == 'pending').length;
    final signedCount = _documents.where((d) => d.status == 'signed').length;
    final rejectedCount = _documents
        .where((d) => d.status == 'rejected')
        .length;
    final reviewCount = _documents.where((d) => d.status == 'review').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 260,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadDocuments,
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
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
                      Color(0xFF1E3A8A),
                      Color(0xFF1D4ED8),
                      Color(0xFF3B82F6),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Директор',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  auth.user?.fullName.split(' ').first ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _statCard(
                                'На підписі',
                                pendingCount,
                                const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 8),
                              _statCard(
                                'Підписано',
                                signedCount,
                                const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              _statCard(
                                'Відхилено',
                                rejectedCount,
                                const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 8),
                              _statCard(
                                'Відкладено',
                                reviewCount,
                                const Color(0xFF3B82F6),
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(110),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Пошук документів...',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white60,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  TabBar(
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
                ],
              ),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: docs.length,
        itemBuilder: (context, index) => _buildDocumentCard(docs[index]),
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel doc) {
    final statusColor = _statusColor(doc.status);
    final isPending = doc.status == 'pending' || doc.status == 'review';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: isPending
            ? Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5)
            : Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PdfViewerScreen(document: doc)),
            );
            if (result == true) _loadDocuments();
          },
          onLongPress: () => _showActionSheet(doc),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    doc.status == 'signed'
                        ? Icons.verified_rounded
                        : Icons.picture_as_pdf_rounded,
                    color: statusColor,
                    size: 24,
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
                      const SizedBox(height: 2),
                      Text(
                        doc.categoryLabel,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
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
                          if (doc.priority != 'normal') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _priorityColor(
                                  doc.priority,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                doc.priority == 'urgent'
                                    ? '🔴 Терміново'
                                    : '🟡 Важливо',
                                style: TextStyle(
                                  color: _priorityColor(doc.priority),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isPending)
                  GestureDetector(
                    onTap: () => _showActionSheet(doc),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: Color(0xFF1D4ED8),
                        size: 20,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
}
