import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import '../widgets/year_advanced.dart';
import 'report_export_screen.dart';
import '../widgets/year_heatmap.dart';

enum _StatsView { month, year }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _month = monthStart(DateTime.now());
  int _year = DateTime.now().year;
  bool _yearAll = false;
  TxnType _type = TxnType.expense;
  _StatsView _view = _StatsView.month;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final topInset = MediaQuery.of(context).padding.top + kToolbarHeight - 6;
        return Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: SegmentedButton<_StatsView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _StatsView.month, label: Text('月统计')),
                  ButtonSegment(value: _StatsView.year, label: Text('年统计')),
                ],
                selected: {_view},
                onSelectionChanged: (set) => setState(() => _view = set.first),
              ),
            ),
            Expanded(
              child: _view == _StatsView.month
                  ? _buildMonth(context, store)
                  : _buildYear(context, store),
            ),
          ],
        ),
        );
      },
    );
  }

  Widget _buildMonth(BuildContext context, AppStore store) {
    final totals = store.totalsForMonth(_month);
    final cats = store.categoryTotals(_month, _type);
    final daily = _type == TxnType.expense ? store.dailyExpense(_month) : store.dailyIncome(_month);
    final values = List<double>.generate(
      daysInMonth(_month),
      (i) => daily[dateKey(DateTime(_month.year, _month.month, i + 1))] ?? 0,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        _monthHeader(),
        const SizedBox(height: 4),
        _summaryCard('月', totals),
        const SizedBox(height: 14),
        _chartCard(
          context,
          title: '每日趋势',
          values: values,
          labels: List.generate(values.length, (i) => '${i + 1}'),
          color: _type == TxnType.expense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E),
          labelEvery: 5,
        ),
        const SizedBox(height: 14),
        _categoryCard(cats, _type == TxnType.expense ? totals.expense : totals.income, _type),
      ],
    );
  }

  Widget _buildYear(BuildContext context, AppStore store) {
    final totals = _yearAll ? store.allYearsTotals : store.totalsForYear(_year);
    final cats = _yearAll ? store.categoryTotalsAllYears(_type) : store.categoryTotalsForYear(_year, _type);
    final years = List<int>.generate(10, (i) => DateTime.now().year - 9 + i);
    final yearTotals = years.map((y) => store.totalsForYear(y)).toList();
    final months = store.monthlyTotalsForYear(_year);
    final List<double> values;
    final List<String> labels;
    Color color;
    if (_yearAll) {
      values = yearTotals
          .map((t) => _type == TxnType.expense ? t.expense : t.income)
          .toList();
      labels = years.map((y) => '$y').toList();
    } else {
      values = months
          .map((t) => _type == TxnType.expense ? t.expense : t.income)
          .toList();
      labels = List.generate(12, (i) => '${i + 1}月');
    }
    color = _type == TxnType.expense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        Row(
          children: [
            if (!_yearAll)
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(Icons.chevron_left),
              ),
            Expanded(
              child: Center(
                child: Text(
                  _yearAll ? '所有年份' : '$_year年',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (!_yearAll)
              IconButton(
                onPressed: () => setState(() => _year++),
                icon: const Icon(Icons.chevron_right),
              ),
            if (!_yearAll)
              IconButton(
                tooltip: '导出报表',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReportExportScreen(year: _year)),
                ),
                icon: const Icon(Icons.ios_share, size: 20),
              ),
            FilterChip(
              label: const Text('所有'),
              selected: _yearAll,
              onSelected: (v) => setState(() => _yearAll = v),
            ),
          ],
        ),
        _summaryCard(_yearAll ? '全部' : '年', totals),
        const SizedBox(height: 14),
        _chartCard(
          context,
          title: _yearAll ? '近十年收支' : '$_year年月度收支',
          values: values,
          labels: labels,
          color: color,
          labelEvery: 1,
        ),
        if (!_yearAll) ...[
          const SizedBox(height: 14),
          YearHeatmapCard(store: store, year: _year, type: _type),
          const SizedBox(height: 14),
          YearAdvancedCards(store: store, year: _year, type: _type),
        ] else ...[
          const SizedBox(height: 14),
          _categoryCard(cats, _type == TxnType.expense ? totals.expense : totals.income, _type),
        ],
      ],
    );
  }

  Widget _monthHeader() {
    return Row(
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
    );
  }

  Widget _summaryCard(String prefix, MoneyTotals totals) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF1A2355), Color(0xFF0A0F2A), Color(0xFF211747)]),
      ),
      child: Row(
        children: [
          _summary('$prefix支出', formatMoney(totals.expense), Colors.white),
          _summary('$prefix收入', formatMoney(totals.income), const Color(0xFF8FE3C8)),
          _summary('$prefix结余', formatMoney(totals.balance), Colors.white),
        ],
      ),
    );
  }

  Widget _summary(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required List<double> values,
    required List<String> labels,
    required Color color,
    required int labelEvery,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                SegmentedButton<TxnType>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 10.5)),
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
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _BarsPainter(
                  values: values,
                  labels: labels,
                  color: color,
                  textColor: Colors.grey.shade600,
                  labelEvery: labelEvery,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '单位：${_view == _StatsView.year ? (_yearAll ? '年' : '月') : '日'} · 点击柱/点查看明细',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(List<CategoryTotal> cats, double total, TxnType type) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type == TxnType.expense ? '支出分类' : '收入分类',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (cats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('这个区间还没有数据', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
              )
            else
              ...cats.map((c) {
                final ratio = total <= 0 ? 0.0 : c.value / total;
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
                          Text('${(ratio * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.textColor,
    required this.labelEvery,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color textColor;
  final int labelEvery;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.75);
    final line = Paint()
      ..color = textColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    final baseY = size.height - 20;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), line);
    if (values.isEmpty) return;
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    if (maxValue <= 0) return;
    final slot = size.width / values.length;
    final barWidth = (slot * 0.55).clamp(2.0, 16.0).toDouble();
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final h = (v / maxValue) * (size.height - 30);
      final x = slot * i + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - h, barWidth, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < values.length; i += labelEvery) {
      textPainter.text = TextSpan(
        text: labels.length > i ? labels[i] : '',
        style: TextStyle(fontSize: 8, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(slot * i, baseY + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.values != values || old.labels != labels || old.color != color;
}
