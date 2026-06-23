import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/models/document_model.dart';

class SecretaryPdfViewer extends StatefulWidget {
  final DocumentModel document;

  const SecretaryPdfViewer({super.key, required this.document});

  @override
  State<SecretaryPdfViewer> createState() => _SecretaryPdfViewerState();
}

class _SecretaryPdfViewerState extends State<SecretaryPdfViewer> {
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
      final isSigned = widget.document.status == 'signed';
      final endpoint = isSigned
          ? '/documents/${widget.document.id}/signed-file'
          : '/documents/${widget.document.id}/file';

      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.document.id}_sec.pdf');
        await file.writeAsBytes(response.bodyBytes);
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
      } else {
        // Якщо підписаний не знайдено — завантажуємо оригінал
        final response2 = await http.get(
          Uri.parse(
            '${ApiClient.baseUrl}/documents/${widget.document.id}/file',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response2.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/${widget.document.id}_sec.pdf');
          await file.writeAsBytes(response2.bodyBytes);
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
      final token = await ApiClient.getToken();
      final isSigned = widget.document.status == 'signed';
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
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Збережено: $fileName'),
              backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    final isSigned = widget.document.status == 'signed';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              isSigned ? '✅ Підписаний документ' : widget.document.statusLabel,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Text(
                '$_currentPage/$_totalPages',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _localPath == null ? null : _saveFile,
            tooltip: 'Завантажити',
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
      bottomNavigationBar: isSigned
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
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: const Text('Завантажити підписаний PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveFile,
              ),
            )
          : null,
    );
  }
}
