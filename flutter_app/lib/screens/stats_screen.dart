import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import '../widgets/year_advanced.dart';
import 'report_export_screen.dart';
import '../widgets/year_heatmap.dart';

enum _StatsView { week, month, year, custom }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _month = monthStart(DateTime.now());
  DateTime _weekStart = _monday(DateTime.now());
  DateTime _customStart = DateTime.now().subtract(const Duration(days: 29));
  DateTime _customEnd = DateTime.now();
  int _year = DateTime.now().year;
  bool _yearAll = false;
  TxnType _type = TxnType.expense;
  _StatsView _view = _StatsView.month;

  static DateTime _monday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

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
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11.5)),
                ),
                segments: const [
                  ButtonSegment(value: _StatsView.week, label: Text('周')),
                  ButtonSegment(value: _StatsView.month, label: Text('月')),
                  ButtonSegment(value: _StatsView.year, label: Text('年')),
                  ButtonSegment(value: _StatsView.custom, label: Text('自定义')),
                ],
                selected: {_view},
                onSelectionChanged: (set) => setState(() => _view = set.first),
              ),
            ),
            Expanded(
              child: switch (_view) {
                _StatsView.week => _buildWeek(context, store),
                _StatsView.month => _buildMonth(context, store),
                _StatsView.year => _buildYear(context, store),
                _StatsView.custom => _buildCustom(context, store),
              },
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
        const SizedBox(height: 14),
        Builder(builder: (context) {
          final days = daysInMonth(_month);
          final labels = List.generate(days, (i) => '${i + 1}');
          final dailyTotals = List.generate(days, (i) {
            final t = store.totalsForRangeDay(DateTime(_month.year, _month.month, i + 1));
            return t;
          });
          final counts = List.generate(days, (i) => store.txnsForDate(dateKey(DateTime(_month.year, _month.month, i + 1))).length);
          return _reportCard('本月统计报表', labels, dailyTotals, counts);
        }),
        const SizedBox(height: 14),
        _bottomSummary(totals, store.txnsForMonth(_month).length, daysInMonth(_month)),
      ],
    );
  }

  Widget _buildWeek(BuildContext context, AppStore store) {
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final txns = store.txnsBetween(start, end);
    final totals = store.totalsBetween(start, end);
    final cats = store.categoryTotalsBetween(start, end, _type);
    final labels = const ['一', '二', '三', '四', '五', '六', '日'];
    final daily = List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      final t = store.totalsForRangeDay(d);
      return _type == TxnType.expense ? t.expense : t.income;
    });
    final reportTotals = List.generate(7, (i) => store.totalsForRangeDay(start.add(Duration(days: i))));
    final counts = List.generate(7, (i) => store.txnsForDate(dateKey(start.add(Duration(days: i)))).length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        _rangeHeader(
          '本周',
          '${dateKey(start).substring(5)} — ${dateKey(end).substring(5)}',
          () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
          () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7))),
        ),
        _summaryCard('周', totals),
        const SizedBox(height: 14),
        _chartCard(context, title: '每日趋势', values: daily, labels: labels, color: _type == TxnType.expense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E), labelEvery: 1, unit: '日'),
        const SizedBox(height: 14),
        _categoryCard(cats, _type == TxnType.expense ? totals.expense : totals.income, _type),
        const SizedBox(height: 14),
        _reportCard('本周统计报表', labels, reportTotals, counts),
        const SizedBox(height: 14),
        _bottomSummary(totals, txns.length, 7),
      ],
    );
  }

  Widget _buildCustom(BuildContext context, AppStore store) {
    final start = DateTime(_customStart.year, _customStart.month, _customStart.day);
    final end = DateTime(_customEnd.year, _customEnd.month, _customEnd.day);
    final from = start.isAfter(end) ? end : start;
    final to = start.isAfter(end) ? start : end;
    final txns = store.txnsBetween(from, to);
    final totals = store.totalsBetween(from, to);
    final cats = store.categoryTotalsBetween(from, to, _type);
    final days = to.difference(from).inDays + 1;
    final useMonthly = days > 92;
    final labels = <String>[];
    final values = <double>[];
    final reportTotals = <MoneyTotals>[];
    final counts = <int>[];
    if (useMonthly) {
      var cursor = DateTime(from.year, from.month, 1);
      while (!cursor.isAfter(DateTime(to.year, to.month, 1))) {
        final monthEnd = DateTime(cursor.year, cursor.month, daysInMonth(cursor));
        final realStart = cursor.isBefore(from) ? from : cursor;
        final realEnd = monthEnd.isAfter(to) ? to : monthEnd;
        final t = store.totalsBetween(realStart, realEnd);
        labels.add('${cursor.year}/${cursor.month}');
        values.add(_type == TxnType.expense ? t.expense : t.income);
        reportTotals.add(t);
        counts.add(store.txnsBetween(realStart, realEnd).length);
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    } else {
      for (var i = 0; i < days; i++) {
        final d = from.add(Duration(days: i));
        final t = store.totalsForRangeDay(d);
        labels.add('${d.month}/${d.day}');
        values.add(_type == TxnType.expense ? t.expense : t.income);
        reportTotals.add(t);
        counts.add(store.txnsForDate(dateKey(d)).length);
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickCustomDate(true),
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(dateKey(from), style: const TextStyle(fontSize: 11)),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('至', style: TextStyle(fontSize: 11))),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickCustomDate(false),
                icon: const Icon(Icons.event_outlined, size: 15),
                label: Text(dateKey(to), style: const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _summaryCard('区间', totals),
        const SizedBox(height: 14),
        _chartCard(context, title: '区间趋势', values: values, labels: labels, color: _type == TxnType.expense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E), labelEvery: values.length > 15 ? (values.length / 5).ceil() : 1, unit: useMonthly ? '月' : '日'),
        const SizedBox(height: 14),
        _categoryCard(cats, _type == TxnType.expense ? totals.expense : totals.income, _type),
        const SizedBox(height: 14),
        _reportCard('区间统计报表', labels, reportTotals, counts),
        const SizedBox(height: 14),
        _bottomSummary(totals, txns.length, days),
      ],
    );
  }

  Future<void> _pickCustomDate(bool isStart) async {
    final current = isStart ? _customStart : _customEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart ? '选择开始日期' : '选择结束日期',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStart = picked;
        if (_customStart.isAfter(_customEnd)) _customEnd = picked;
      } else {
        _customEnd = picked;
        if (_customEnd.isBefore(_customStart)) _customStart = picked;
      }
    });
  }

  Widget _rangeHeader(String title, String subtitle, VoidCallback previous, VoidCallback next) {
    return Row(
      children: [
        IconButton(onPressed: previous, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ),
        IconButton(onPressed: next, icon: const Icon(Icons.chevron_right)),
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
          const SizedBox(height: 14),
          _bottomSummary(totals, store.txnsForYear(_year).length, 365),
        ] else ...[
          const SizedBox(height: 14),
          _categoryCard(cats, _type == TxnType.expense ? totals.expense : totals.income, _type),
          const SizedBox(height: 14),
          _reportCard(
            '年度统计报表',
            years.map((y) => '$y').toList(),
            yearTotals,
            years.map((y) => store.txnsForYear(y).length).toList(),
          ),
          const SizedBox(height: 14),
          _bottomSummary(totals, store.activeTransactions.length, 365),
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
    String? unit,
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
              '单位：${unit ?? (_view == _StatsView.year ? (_yearAll ? '年' : '月') : '日')} · 点击柱/点查看明细',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(
    String title,
    List<String> labels,
    List<MoneyTotals> totals,
    List<int> counts,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(flex: 16, child: _headText('区间')),
                Expanded(flex: 18, child: _headText('收入', align: TextAlign.right)),
                Expanded(flex: 18, child: _headText('支出', align: TextAlign.right)),
                Expanded(flex: 18, child: _headText('结余', align: TextAlign.right)),
                Expanded(flex: 9, child: _headText('笔数', align: TextAlign.right)),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            ...List.generate(labels.length, (i) {
              final t = totals[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(flex: 16, child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))),
                    Expanded(flex: 18, child: Text(formatMoney(t.income, symbol: false), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9.5))),
                    Expanded(flex: 18, child: Text(formatMoney(t.expense, symbol: false), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9.5))),
                    Expanded(flex: 18, child: Text(formatMoney(t.balance, symbol: false), textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, color: t.balance < 0 ? const Color(0xFFE5484D) : null))),
                    Expanded(flex: 9, child: Text('${counts[i]}', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _bottomSummary(MoneyTotals totals, int count, int days) {
    final avg = days <= 0 ? 0.0 : totals.expense / days;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('总结', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('$count 笔 · $days 天', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _summaryCell('支出', formatMoney(totals.expense), const Color(0xFFE5484D))),
                Expanded(child: _summaryCell('收入', formatMoney(totals.income), const Color(0xFF0E9F6E))),
                Expanded(child: _summaryCell('结余', formatMoney(totals.balance), const Color(0xFF5B6CFF))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '日均支出 ${formatMoney(avg)} · ${totals.expense > totals.income ? '支出高于收入' : '收支平衡或结余'}',
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCell(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    );
  }

  Widget _headText(String text, {TextAlign align = TextAlign.left}) {
    return Text(text, textAlign: align, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600));
  }

  Widget _categoryCard(List<CategoryTotal> cats, double total, TxnType type) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type == TxnType.expense ? '支出排行' : '收入排行',
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
              ...List.generate(cats.length, (i) {
                final c = cats[i];
                final ratio = total <= 0 ? 0.0 : c.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 18,
                            child: Text('${i + 1}', style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: i < 3 ? const Color(0xFFC08A2E) : Colors.grey.shade500,
                            )),
                          ),
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
