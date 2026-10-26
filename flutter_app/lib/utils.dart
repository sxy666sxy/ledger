import 'package:intl/intl.dart';

const String appVersion = '0.7.0';

final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');

String formatMoney(num value, {bool symbol = true}) {
  final abs = value.abs();
  final text = _money.format(abs);
  final sign = value < 0 ? '-' : '';
  return '$sign${symbol ? '¥' : ''}$text';
}

String formatCompactMoney(num value) {
  final v = value.abs();
  if (v >= 10000) return '¥${(v / 10000).toStringAsFixed(1)}万';
  if (v >= 1000) return '¥${(v / 1000).toStringAsFixed(1)}k';
  return '¥${v.toStringAsFixed(0)}';
}

String two(int v) => v.toString().padLeft(2, '0');

String dateKey(DateTime date) => '${date.year}-${two(date.month)}-${two(date.day)}';

String monthKey(DateTime date) => '${date.year}-${two(date.month)}';

String monthTitle(DateTime date) => '${date.year}年${date.month}月';

String dateTitle(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.month}月${d.day}日';
}

String fullDateTitle(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.year}年${d.month}月${d.day}日';
}

String weekdayCN(DateTime date) {
  const names = ['一', '二', '三', '四', '五', '六', '日'];
  return '周${names[date.weekday - 1]}';
}

int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

DateTime monthStart(DateTime month) => DateTime(month.year, month.month, 1);

DateTime addMonths(DateTime month, int delta) => DateTime(month.year, month.month + delta, 1);

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
