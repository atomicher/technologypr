class DocumentModel {
  final String id;
  final String title;
  final String? description;
  final String originalName;
  final String category;
  final String status;
  final String priority;
  final String createdAt;
  final String filePath;
  final Map<String, dynamic>? createdBy;

  DocumentModel({
    required this.id,
    required this.title,
    this.description,
    required this.originalName,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.createdBy,
    required this.filePath,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      originalName: json['originalName'],
      category: json['category'],
      status: json['status'],
      priority: json['priority'],
      createdAt: json['createdAt'],
      createdBy: json['createdBy'],
      filePath: json['filePath'],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'На підписанні';
      case 'signed':
        return 'Підписано';
      case 'rejected':
        return 'Відхилено';
      case 'review':
        return 'На розгляді';
      case 'draft':
        return 'Чернетка';
      default:
        return status;
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'accounting':
        return 'Бухгалтерія';
      case 'legal':
        return 'Юридичні';
      case 'internal':
        return 'Внутрішні';
      case 'financial':
        return 'Фінансові';
      default:
        return 'Інші';
    }
  }
}
