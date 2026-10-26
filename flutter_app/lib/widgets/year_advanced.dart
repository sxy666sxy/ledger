import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../screens/asset_trend_screen.dart';
import '../utils.dart';

class YearAdvancedCards extends StatelessWidget {
  const YearAdvancedCards({
    super.key,
    required this.store,
    required this.year,
    required this.type,
    required this.progress,
  });

  final AppStore store;
  final int year;
  final TxnType type;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final months = store.monthlyTotalsForYear(year);
    final counts = store.monthlyCountsForYear(year);
    final total = type == TxnType.expense
        ? months.fold<double>(0, (s, m) => s + m.expense)
        : months.fold<double>(0, (s, m) => s + m.income);
    final cats = store.categoryTotalsForYear(year, type);
    return Column(
      children: [
        _assetCard(context),
        const SizedBox(height: 14),
        _comparisonCard(context, months),
        const SizedBox(height: 14),
        _rankingCard(context, cats, total),
        const SizedBox(height: 14),
        _reportCard(context, months, counts),
      ],
    );
  }

  Widget _assetCard(BuildContext context) {
    final values = store.monthlyNetAssets(year);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('资产走势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AssetTrendScreen()),
                  ),
                  child: const Text('完整走势'),
                ),
              ],
            ),
            Text('每月末净资产', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              width: double.infinity,
              child: CustomPaint(
                painter: _LinePainter(
                  values: values,
                  textColor: Colors.grey.shade600,
                  progress: progress,
                ),
              ),
            ),
            const SizedBox(height: 5),
            _amountStrip(List.generate(12, (i) => '${i + 1}月'), values.map((v) => formatMoney(v, symbol: false)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _comparisonCard(BuildContext context, List<MoneyTotals> months) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('收支对比', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('每月收入与支出', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              width: double.infinity,
              child: CustomPaint(
                painter: _GroupedBarsPainter(
                  expense: months.map((m) => m.expense).toList(),
                  income: months.map((m) => m.income).toList(),
                  textColor: Colors.grey.shade600,
                  progress: progress,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _dot(const Color(0xFFE5484D), '支出'),
                const SizedBox(width: 14),
                _dot(const Color(0xFF0E9F6E), '收入'),
              ],
            ),
            const SizedBox(height: 5),
            _amountStrip(
              List.generate(12, (i) => '${i + 1}月'),
              List.generate(12, (i) => '支 ${formatMoney(months[i].expense, symbol: false)} / 收 ${formatMoney(months[i].income, symbol: false)}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountStrip(List<String> labels, List<String> values) {
    return SizedBox(
      height: 18,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '${labels[i]} ${values[i]}',
                style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _dot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _rankingCard(BuildContext context, List<CategoryTotal> cats, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type == TxnType.expense ? '支出排行' : '收入排行',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (cats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text('暂无数据', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
              )
            else
              ...List.generate(cats.length, (i) {
                final c = cats[i];
                final ratio = total <= 0 ? 0.0 : c.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text('${i + 1}', style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: i < 3 ? const Color(0xFFE0A325) : Colors.grey.shade500,
                        )),
                      ),
                      Text(c.category.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(c.category.name, style: const TextStyle(fontSize: 12.5))),
                                Text(formatMoney(c.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 6),
                                Text('${(ratio * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ratio.clamp(0.0, 1.0).toDouble() *
                                    progress,
                                minHeight: 4,
                                color: Color(c.category.color),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, List<MoneyTotals> months, List<int> counts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$year年完整报表', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(flex: 12, child: _head('月份')),
                Expanded(flex: 20, child: _head('收入', align: TextAlign.center, color: const Color(0xFF0E9F6E))),
                Expanded(flex: 18, child: _head('支出', align: TextAlign.center, color: const Color(0xFFE5484D))),
                Expanded(flex: 20, child: _head('结余', align: TextAlign.right)),
                Expanded(flex: 8, child: _head('笔数', align: TextAlign.right)),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            ...List.generate(12, (i) {
              final m = months[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(flex: 12, child: Text('${i + 1}月', style: const TextStyle(fontSize: 11))),
                    Expanded(flex: 20, child: Text(formatMoney(m.income, symbol: false), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Color(0xFF0E9F6E)))),
                    Expanded(flex: 18, child: Text(formatMoney(m.expense, symbol: false), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Color(0xFFE5484D)))),
                    Expanded(flex: 20, child: Text(formatMoney(m.balance, symbol: false), textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: m.balance < 0 ? const Color(0xFFE5484D) : null))),
                    Expanded(flex: 8, child: Text('${counts[i]}', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _head(String text, {TextAlign align = TextAlign.left, Color? color}) {
    return Text(text, textAlign: align, style: TextStyle(fontSize: 9.5, color: color ?? Colors.grey.shade600));
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.textColor,
    required this.progress,
  });

  final List<double> values;
  final Color textColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV == minV) { maxV += 1; minV -= 1; }
    final pad = (maxV - minV) * 0.12;
    minV -= pad; maxV += pad;
    final baseY = size.height - 18;
    final grid = Paint()..color = textColor.withValues(alpha: 0.12)..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = baseY - (size.height - 28) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final p = progress.clamp(0.0, 1.0).toDouble();
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = baseY -
          ((values[i] - minV) / (maxV - minV)) * (size.height - 30) * p;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
    final dot = Paint()..color = const Color(0xFF3B82F6);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = baseY -
          ((values[i] - minV) / (maxV - minV)) * (size.height - 30) * p;
      canvas.drawCircle(Offset(x, y), 2.4, dot);
      if (i % 3 == 0 || i == values.length - 1) {
        textPainter.text = TextSpan(
          text: _assetAmount(values[i]),
          style: const TextStyle(fontSize: 7.5, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
        );
        textPainter.layout();
        final tx = (x - textPainter.width / 2)
            .clamp(0.0, size.width - textPainter.width)
            .toDouble();
        textPainter.paint(canvas, Offset(tx, (y - 12).clamp(0.0, baseY - 8).toDouble()));
      }
      if (i == 0 || i == values.length - 1) {
        textPainter.text = TextSpan(text: '${i + 1}月', style: TextStyle(fontSize: 8, color: textColor));
        textPainter.layout();
        textPainter.paint(canvas, Offset(i == 0 ? x : x - 18, baseY + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.progress != progress;
}

String _assetAmount(double value) {
  final abs = value.abs();
  if (abs >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
  if (abs >= 1000) return value.toStringAsFixed(0);
  return value.toStringAsFixed(abs % 1 == 0 ? 0 : 2);
}

class _GroupedBarsPainter extends CustomPainter {
  _GroupedBarsPainter({
    required this.expense,
    required this.income,
    required this.textColor,
    required this.progress,
  });

  final List<double> expense;
  final List<double> income;
  final Color textColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height - 18;
    final maxValue = [...expense, ...income].fold<double>(0, (a, b) => a > b ? a : b);
    final grid = Paint()..color = textColor.withValues(alpha: 0.12)..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), grid);
    if (maxValue <= 0 || expense.isEmpty) return;
    final p = progress.clamp(0.0, 1.0).toDouble();
    final slot = size.width / expense.length;
    final barWidth = (slot * 0.32).clamp(1.5, 10.0).toDouble();
    final ePaint = Paint()..color = const Color(0xFFE5484D).withValues(alpha: 0.78);
    final iPaint = Paint()..color = const Color(0xFF0E9F6E).withValues(alpha: 0.78);
    for (var i = 0; i < expense.length; i++) {
      final groupX = slot * i + slot * 0.18;
      final eh = (expense[i] / maxValue) * (size.height - 36) * p;
      final ih = (income[i] / maxValue) * (size.height - 36) * p;
      if (eh > 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(groupX, baseY - eh, barWidth, eh), const Radius.circular(2)), ePaint);
      }
      if (ih > 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(groupX + barWidth + 1, baseY - ih, barWidth, ih), const Radius.circular(2)), iPaint);
      }
    }
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < expense.length; i += 2) {
      final eh = (expense[i] / maxValue) * (size.height - 36) * p;
      if (expense[i] > 0) {
        textPainter.text = TextSpan(
          text: _assetAmount(expense[i]),
          style: const TextStyle(fontSize: 7, color: Color(0xFFE5484D), fontWeight: FontWeight.w600),
        );
        textPainter.layout();
        final tx = (slot * i + slot * 0.22 - textPainter.width / 2)
            .clamp(0.0, size.width - textPainter.width)
            .toDouble();
        textPainter.paint(canvas, Offset(tx, (baseY - eh - 11).clamp(0.0, baseY - 8).toDouble()));
      }
      textPainter.text = TextSpan(text: '${i + 1}', style: TextStyle(fontSize: 8, color: textColor));
      textPainter.layout();
      textPainter.paint(canvas, Offset(slot * i + slot * 0.3, baseY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _GroupedBarsPainter old) =>
      old.expense != expense || old.income != income ||
      old.progress != progress;
}
