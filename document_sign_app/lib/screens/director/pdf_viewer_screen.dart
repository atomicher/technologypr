import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/document_model.dart';
import 'sign_dialog.dart';

class PdfViewerScreen extends StatefulWidget {
  final DocumentModel document;

  const PdfViewerScreen({super.key, required this.document});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final token = await ApiClient.getToken();
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/documents/${widget.document.id}/file'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.document.id}.pdf');

        await file.writeAsBytes(response.bodyBytes);

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

  Future<void> _saveFile() async {
    try {
      setState(() => _isLoading = true);

      final token = await ApiClient.getToken();
      final isSigned = widget.document.status == 'signed';

      // Якщо підписаний — завантажуємо підписану версію
      final endpoint = isSigned
          ? '/documents/${widget.document.id}/signed-file'
          : '/documents/${widget.document.id}/file';

      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final dir = Directory('/storage/emulated/0/Download');
        final suffix = isSigned ? '_підписаний' : '';
        final fileName =
            '${widget.document.title.replaceAll(' ', '_')}$suffix.pdf';
        final destFile = File('${dir.path}/$fileName');
        await destFile.writeAsBytes(response.bodyBytes);

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Збережено: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Підписаний файл не знайдено')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  void _showSignDialog() {
    showDialog(
      context: context,
      builder: (_) => SignDialog(
        documentId: widget.document.id,
        documentTitle: widget.document.title,
        pdfPath: widget.document.filePath,
        onSigned: () {
          Navigator.pop(context, true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending =
        widget.document.status == 'pending' ||
        widget.document.status == 'review';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.document.title,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _localPath == null ? null : _saveFile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Завантаження документа...'),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _downloadPdf();
                    },
                    child: const Text('Спробувати знову'),
                  ),
                ],
              ),
            )
          : PDFView(
              filePath: _localPath!,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              onRender: (pages) {
                setState(() {
                  _totalPages = pages ?? 0;
                  _currentPage = 1;
                });
              },
              onPageChanged: (page, total) {
                setState(() => _currentPage = page! + 1);
              },
              onError: (error) {
                setState(() => _error = error.toString());
              },
            ),
      bottomNavigationBar: isPending
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.draw),
                      label: const Text('Підписати КЕП'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _showSignDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Відхилити'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        final controller = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Причина відхилення'),
                            content: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: 'Вкажіть причину...',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Скасувати'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await ApiClient.patch(
                                    '/documents/${widget.document.id}/status',
                                    {
                                      'status': 'rejected',
                                      'rejectionReason': controller.text,
                                    },
                                  );
                                  if (mounted) {
                                    Navigator.pop(context, true);
                                  }
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
                      },
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
