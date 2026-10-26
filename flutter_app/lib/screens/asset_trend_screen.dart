import 'package:flutter/material.dart';

import '../store.dart';
import '../utils.dart';

enum _AssetRange { d30, m12, all }

class AssetTrendScreen extends StatefulWidget {
  const AssetTrendScreen({super.key});

  @override
  State<AssetTrendScreen> createState() => _AssetTrendScreenState();
}

class _AssetTrendScreenState extends State<AssetTrendScreen> {
  final AppStore store = AppStore.instance;
  _AssetRange _range = _AssetRange.m12;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final points = _points();
        final first = points.isEmpty ? 0.0 : points.first;
        final last = points.isEmpty ? 0.0 : points.last;
        final change = last - first;
        final labels = _labels(points.length);
        final dates = _dates();
        return Scaffold(
          appBar: AppBar(title: const Text('资产走势')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              SegmentedButton<_AssetRange>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _AssetRange.d30, label: Text('近30天')),
                  ButtonSegment(value: _AssetRange.m12, label: Text('近12月')),
                  ButtonSegment(value: _AssetRange.all, label: Text('全部')),
                ],
                selected: {_range},
                onSelectionChanged: (set) => setState(() => _range = set.first),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前净资产', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text(formatMoney(store.netAssets), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        '区间变化 ${change >= 0 ? '+' : ''}${formatMoney(change)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: change >= 0 ? const Color(0xFF0E9F6E) : const Color(0xFFE5484D),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _AssetLinePainter(
                            values: points,
                            labels: labels,
                            textColor: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('各账户走势', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      ...store.accounts.map((a) {
                        final series = dates.map((d) => store.accountBalanceAt(a, d)).toList();
                        final balance = store.accountBalance(a);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Text(a.icon, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 7),
                              SizedBox(
                                width: 56,
                                child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                              ),
                              Expanded(
                                child: SizedBox(
                                  height: 28,
                                  child: CustomPaint(
                                    painter: _MiniAccountPainter(
                                      values: series,
                                      color: balance < 0 ? const Color(0xFFE5484D) : Color(a.color),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                formatMoney(balance, symbol: false),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: balance < 0 ? const Color(0xFFE5484D) : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '资产走势按每日结束时的账户余额计算；转账不影响净资产。',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      },
    );
  }

  List<double> _points() => _dates().map(store.netAssetsAt).toList();

  List<DateTime> _dates() {
    if (_range == _AssetRange.d30) {
      final today = DateTime.now();
      return List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));
    }
    if (_range == _AssetRange.m12) {
      final now = DateTime.now();
      return List.generate(12, (i) {
        final month = DateTime(now.year, now.month - 11 + i, 1);
        return DateTime(month.year, month.month, daysInMonth(month));
      });
    }
    final txns = store.activeTransactions;
    DateTime start = DateTime.now();
    if (txns.isNotEmpty) {
      final first = DateTime.tryParse(txns.last.date);
      if (first != null) start = DateTime(first.year, first.month, 1);
    }
    final now = DateTime.now();
    final dates = <DateTime>[];
    var cursor = DateTime(start.year, start.month, 1);
    var guard = 0;
    while (cursor.isBefore(DateTime(now.year, now.month + 1, 1)) && guard++ < 120) {
      dates.add(DateTime(cursor.year, cursor.month, daysInMonth(cursor)));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return dates.isEmpty ? [DateTime.now()] : dates;
  }

  List<String> _labels(int count) {
    if (count == 0) return const [];
    if (_range == _AssetRange.d30) {
      final now = DateTime.now();
      return [dateKey(now.subtract(const Duration(days: 29))).substring(5), dateKey(now).substring(5)];
    }
    if (_range == _AssetRange.m12) {
      final now = DateTime.now();
      return ['${now.year - 1}/${now.month}', '${now.year}/${now.month}'];
    }
    final txns = store.activeTransactions;
    final first = txns.isEmpty ? null : DateTime.tryParse(txns.last.date);
    final start = first == null ? DateTime.now() : DateTime(first.year, first.month, 1);
    return ['${start.year}/${start.month}', '${DateTime.now().year}/${DateTime.now().month}'];
  }
}

class _MiniAccountPainter extends CustomPainter {
  _MiniAccountPainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV == minV) { maxV += 1; minV -= 1; }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = size.height - 3 - ((values[i] - minV) / (maxV - minV)) * (size.height - 7);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _MiniAccountPainter old) => old.values != values || old.color != color;
}

class _AssetLinePainter extends CustomPainter {
  _AssetLinePainter({required this.values, required this.labels, required this.textColor});
  final List<double> values;
  final List<String> labels;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV == minV) { maxV += 1; minV -= 1; }
    final pad = (maxV - minV) * 0.12;
    minV -= pad; maxV += pad;
    final baseY = size.height - 20;
    final grid = Paint()..color = textColor.withValues(alpha: 0.12)..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = baseY - (size.height - 30) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = baseY - ((values[i] - minV) / (maxV - minV)) * (size.height - 32);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF0EA5E9)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
    final dot = Paint()..color = const Color(0xFF0EA5E9);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < values.length; i += (values.length > 20 ? 4 : 1)) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = baseY - ((values[i] - minV) / (maxV - minV)) * (size.height - 32);
      canvas.drawCircle(Offset(x, y), values.length > 20 ? 1.8 : 2.4, dot);
    }
    if (labels.isNotEmpty) {
      textPainter.text = TextSpan(text: labels.first, style: TextStyle(fontSize: 9, color: textColor));
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, baseY + 4));
      textPainter.text = TextSpan(text: labels.last, style: TextStyle(fontSize: 9, color: textColor));
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - textPainter.width, baseY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _AssetLinePainter old) => old.values != values;
}
