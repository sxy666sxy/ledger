import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _month = monthStart(DateTime.now());
  TxnType _type = TxnType.expense;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final totals = store.totalsForMonth(_month);
        final cats = store.categoryTotals(_month, _type);
        final daily = _type == TxnType.expense
            ? store.dailyExpense(_month)
            : store.dailyIncome(_month);
        final values = List<double>.generate(
          daysInMonth(_month),
          (i) => daily[dateKey(DateTime(_month.year, _month.month, i + 1))] ?? 0,
        );
        final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _month = addMonths(_month, -1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(monthTitle(_month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _month = addMonths(_month, 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A2355), Color(0xFF0A0F2A), Color(0xFF211747)],
                ),
              ),
              child: Row(
                children: [
                  _summary('支出', formatMoney(totals.expense), Colors.white),
                  _summary('收入', formatMoney(totals.income), const Color(0xFF8FE3C8)),
                  _summary('结余', formatMoney(totals.balance), Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('每日趋势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        SegmentedButton<TxnType>(
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
                          ),
                          segments: const [
                            ButtonSegment(value: TxnType.expense, label: Text('支出')),
                            ButtonSegment(value: TxnType.income, label: Text('收入')),
                          ],
                          selected: {_type},
                          onSelectionChanged: (set) => setState(() => _type = set.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _DailyBarsPainter(
                          values: values,
                          color: _type == TxnType.expense
                              ? const Color(0xFFE5484D)
                              : const Color(0xFF0E9F6E),
                          maxValue: maxValue,
                          textColor: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('1 日', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                        const Spacer(),
                        Text('${values.length} 日', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _type == TxnType.expense ? '支出分类' : '收入分类',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    if (cats.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('这个月还没有数据', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                      )
                    else
                      ...cats.map((c) {
                        final ratio = totals.expense <= 0 || _type == TxnType.income
                            ? 0.0
                            : c.value / (totals.expense == 0 ? 1 : totals.expense);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(c.category.icon, style: const TextStyle(fontSize: 17)),
                                  const SizedBox(width: 7),
                                  Expanded(child: Text(c.category.name)),
                                  Text(formatMoney(c.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(ratio * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio.clamp(0.0, 1.0).toDouble(),
                                  minHeight: 5,
                                  color: Color(c.category.color),
                                  backgroundColor: const Color(0xFFEEF0FF),
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
          ],
        );
      },
    );
  }

  Widget _summary(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DailyBarsPainter extends CustomPainter {
  _DailyBarsPainter({
    required this.values,
    required this.color,
    required this.maxValue,
    required this.textColor,
  });

  final List<double> values;
  final Color color;
  final double maxValue;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.75);
    final line = Paint()
      ..color = textColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    final baseY = size.height - 18;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), line);
    if (values.isEmpty || maxValue <= 0) return;
    final slot = size.width / values.length;
    final barWidth = (slot * 0.55).clamp(2.0, 14.0).toDouble();
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value <= 0) continue;
      final h = (value / maxValue) * (size.height - 28);
      final x = slot * i + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - h, barWidth, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (var i = 0; i < values.length; i += 5) {
      textPainter.text = TextSpan(
        text: '${i + 1}',
        style: TextStyle(fontSize: 8, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(slot * i, baseY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _DailyBarsPainter old) =>
      old.values != values || old.color != color || old.maxValue != maxValue;
}
