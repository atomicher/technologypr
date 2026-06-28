class DateFormatter {
  // Цей метод гарантовано повертає київський час (+3 години від UTC)
  static DateTime _parseToKyiv(String dateStr) {
    try {
      String cleaned = dateStr.trim().replaceAll(' ', 'T');

      // Якщо сервер не додав маркер UTC (Z), додаємо його примусово
      if (!cleaned.endsWith('Z') && !cleaned.contains('+')) {
        cleaned += 'Z';
      }

      // Парсимо і примусово переводимо в чистий UTC baseline
      DateTime utc = DateTime.parse(cleaned).toUtc();

      // Додаємо 3 години для України (літній час)
      return utc.add(const Duration(hours: 6));
    } catch (e) {
      return DateTime.now();
    }
  }

  static String format(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = _parseToKyiv(dateStr);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day.$month.$year $hour:$minute';
    } catch (e) {
      return dateStr;
    }
  }

  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = _parseToKyiv(dateStr);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      return '$day.$month.$year';
    } catch (e) {
      return dateStr ?? '';
    }
  }

  static String timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      String cleaned = dateStr.trim().replaceAll(' ', 'T');
      if (!cleaned.endsWith('Z') && !cleaned.contains('+')) {
        cleaned += 'Z';
      }
      final dtUtc = DateTime.parse(cleaned).toUtc();
      final nowUtc = DateTime.now().toUtc();
      final diff = nowUtc.difference(dtUtc);

      if (diff.isNegative || diff.inMinutes < 1) return 'Щойно';
      if (diff.inMinutes < 60) return '${diff.inMinutes} хв тому';
      if (diff.inHours < 24) return '${diff.inHours} год тому';
      if (diff.inDays < 7) return '${diff.inDays} дн тому';
      return format(dateStr);
    } catch (e) {
      return dateStr ?? '';
    }
  }
}
