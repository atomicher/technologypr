import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../../core/api/api_client.dart';
import '../director/sign_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/date_formatter.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String documentId;
  final String? recipientId;
  final String? myStatus;
  final bool isIncoming;

  const DocumentViewerScreen({
    super.key,
    required this.documentId,
    this.recipientId,
    this.myStatus,
    required this.isIncoming,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;
  Map<String, dynamic>? _docData;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final response = await ApiClient.get('/documents/${widget.documentId}');
      if (response.statusCode == 200) {
        setState(() => _docData = jsonDecode(response.body));
      }

      final token = await ApiClient.getToken();
      final fileResponse = await http.get(
        Uri.parse('${ApiClient.baseUrl}/documents/${widget.documentId}/file'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (fileResponse.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.documentId}_view.pdf');
        await file.writeAsBytes(fileResponse.bodyBytes);
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Не вдалось завантажити файл';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Помилка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String status, {String? reason}) async {
    final body = {
      'status': status,
      if (reason != null) 'rejectionReason': reason,
    };
    final response = await ApiClient.patch(
      '/documents/${widget.documentId}/sign',
      body,
    );
    if (response.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'signed'
                ? '✅ Документ підписано'
                : status == 'rejected'
                ? '❌ Документ відхилено'
                : '🕐 Відкладено',
          ),
          backgroundColor: status == 'signed'
              ? Colors.green
              : status == 'rejected'
              ? Colors.red
              : Colors.orange,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showSignDialog() {
    final filePath = _docData?['filePath'] as String? ?? '';
    showDialog(
      context: context,
      builder: (_) => SignDialog(
        documentId: widget.documentId,
        documentTitle: _docData?['title'] ?? '',
        pdfPath: filePath,
        onSigned: () {
          _updateStatus('signed');
        },
      ),
    );
  }

  void _showRejectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('rejected', reason: controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Відхилити'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.myStatus == 'pending';
    final title = _docData?['title'] as String? ?? 'Документ';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (_totalPages > 0)
              Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _docData == null ? null : _showDocumentDetails,
            tooltip: 'Деталі',
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _localPath == null ? null : _saveFile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : PDFView(
              filePath: _localPath!,
              enableSwipe: true,
              autoSpacing: true,
              pageFling: true,
              onRender: (pages) => setState(() {
                _totalPages = pages ?? 0;
                _currentPage = 1;
              }),
              onPageChanged: (page, _) =>
                  setState(() => _currentPage = page! + 1),
              onError: (e) => setState(() => _error = e.toString()),
            ),
      bottomNavigationBar: widget.isIncoming && isPending
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.draw_rounded),
                      label: const Text('Підписати КЕП'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _showSignDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text('Пізніше'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _updateStatus('review'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text('Відхилити'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _showRejectDialog,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Future<void> _saveFile() async {
    final isSigned = _docData?['status'] == 'signed';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Завантажити документ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Оригінал (без підпису)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _downloadFile(signed: false);
                },
              ),
            ),
            if (isSigned) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('З КЕП підписом'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadFile(signed: true);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile({required bool signed}) async {
    try {
      // Запитуємо дозвіл
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Немає дозволу на запис файлів')),
            );
            return;
          }
        }
      }

      final token = await ApiClient.getToken();
      final endpoint = signed
          ? '/documents/${widget.documentId}/signed-file'
          : '/documents/${widget.documentId}/file';

      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final title = _docData?['title'] as String? ?? 'document';
        final suffix = signed ? '_підписаний' : '';
        final fileName = '${title.replaceAll(' ', '_')}$suffix.pdf';

        // Спробуємо кілька шляхів
        final paths = [
          '/storage/emulated/0/Download/$fileName',
          '/sdcard/Download/$fileName',
        ];

        bool saved = false;
        for (final filePath in paths) {
          try {
            final file = File(filePath);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(response.bodyBytes);
            saved = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Збережено: $fileName'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            break;
          } catch (e) {
            continue;
          }
        }

        if (!saved) {
          // Зберігаємо в кеш додатку
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Збережено в папку додатку: $fileName'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Файл не знайдено')));
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

  void _showDocumentDetails() {
    if (_docData == null) return;
    final createdAt = _docData!['createdAt'] as String? ?? '';
    final createdBy = _docData!['createdBy'] as Map<String, dynamic>?;
    final description = _docData!['description'] as String?;
    final category = _docData!['category'] as String? ?? '';
    final priority = _docData!['priority'] as String? ?? '';
    final recipients = _docData!['recipients'] as List? ?? [];

    String categoryLabel(String cat) {
      const map = {
        'accounting': '📊 Бухгалтерія',
        'legal': '⚖️ Юридичні',
        'internal': '🏢 Внутрішні',
        'financial': '💰 Фінансові',
        'hr': '👥 Кадри',
        'contracts': '📝 Договори',
        'reports': '📈 Звіти',
        'invoices': '🧾 Рахунки',
        'orders': '📋 Накази',
        'other': '📁 Інші',
      };
      return map[cat] ?? cat;
    }

    String priorityLabel(String p) {
      switch (p) {
        case 'urgent':
          return '🔴 Терміново';
        case 'important':
          return '🟡 Важливо';
        default:
          return '⚪ Звичайний';
      }
    }

    String statusLabel(String s) {
      switch (s) {
        case 'pending':
          return 'Очікує підпису';
        case 'signed':
          return '✅ Підписано';
        case 'rejected':
          return '❌ Відхилено';
        case 'waiting':
          return '⏳ Очікує черги';
        case 'review':
          return '🕐 На розгляді';
        default:
          return s;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 8),
                  Text(
                    'Деталі документа',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailItem(
                      Icons.title,
                      'Назва',
                      _docData!['title'] as String? ?? '',
                    ),
                    if (description != null && description.isNotEmpty)
                      _detailItem(Icons.notes, 'Опис', description),
                    _detailItem(
                      Icons.category_outlined,
                      'Категорія',
                      categoryLabel(category),
                    ),
                    _detailItem(
                      Icons.flag_outlined,
                      'Пріоритет',
                      priorityLabel(priority),
                    ),
                    _detailItem(
                      Icons.access_time_rounded,
                      'Дата відправлення',
                      DateFormatter.format(createdAt),
                    ),
                    if (createdBy != null)
                      _detailItem(
                        Icons.person_outline,
                        'Від кого',
                        '${createdBy['fullName'] ?? ''}\n${createdBy['position'] ?? ''} ${createdBy['department'] != null ? '• ${createdBy['department']}' : ''}',
                      ),
                    if (recipients.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Ланцюжок підписів',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(_groupRecipientsByStep(recipients).entries.map((
                        entry,
                      ) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1D4ED8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${entry.key}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Крок ${entry.key}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...entry.value.map((r) {
                              final rStatus = r['status'] as String? ?? '';
                              final signer =
                                  r['signer'] as Map<String, dynamic>?;
                              final signedAt = r['signedAt'] as String?;
                              final statusColor = rStatus == 'signed'
                                  ? Colors.green
                                  : rStatus == 'rejected'
                                  ? Colors.red
                                  : rStatus == 'waiting'
                                  ? Colors.grey
                                  : Colors.orange;

                              return Container(
                                margin: const EdgeInsets.only(
                                  left: 32,
                                  bottom: 6,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      rStatus == 'signed'
                                          ? Icons.check_circle
                                          : rStatus == 'rejected'
                                          ? Icons.cancel
                                          : rStatus == 'waiting'
                                          ? Icons.hourglass_empty
                                          : Icons.pending,
                                      color: statusColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            signer?['fullName'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (signer?['position'] != null)
                                            Text(
                                              signer!['position'],
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          Text(
                                            statusLabel(rStatus),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (signedAt != null)
                                            Text(
                                              DateFormatter.format(signedAt),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      })),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1D4ED8), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<int, List<dynamic>> _groupRecipientsByStep(List<dynamic> recipients) {
    final map = <int, List<dynamic>>{};
    for (final r in recipients) {
      final step = r['step'] as int? ?? 1;
      map.putIfAbsent(step, () => []).add(r);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }
}
