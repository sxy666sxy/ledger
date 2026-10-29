import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../screens/period_txns_screen.dart';

class YearHeatmapCard extends StatelessWidget {
  const YearHeatmapCard({
    super.key,
    required this.store,
    required this.year,
    required this.type,
  });

  final AppStore store;
  final int year;
  final TxnType type;

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) => DateTime(year, i + 1, 1));
    final maxValues = <int, double>{};
    for (final m in months) {
      final daily = type == TxnType.expense ? store.dailyExpense(m) : store.dailyIncome(m);
      maxValues[m.month] = daily.values.fold<double>(0, (a, b) => a > b ? a : b);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('每月收支热力', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(
                  type == TxnType.expense ? '支出' : '收入',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 24) / 4;
                return Wrap(
                  spacing: 8,
                  runSpacing: 9,
                  children: months.map((m) {
                    final daily = type == TxnType.expense ? store.dailyExpense(m) : store.dailyIncome(m);
                    return SizedBox(
                      width: cellWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.of(context).push(
                          fastPageRoute<void>(
                            YearHeatmapPage(year: year, initialType: type, initialMonth: m.month),
                          ),
                        ),
                        child: _MiniMonthHeat(
                          year: year,
                          month: m.month,
                          daily: daily,
                          maxValue: maxValues[m.month] ?? 0,
                          type: type,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMonthHeat extends StatelessWidget {
  const _MiniMonthHeat({
    required this.year,
    required this.month,
    required this.daily,
    required this.maxValue,
    required this.type,
  });

  final int year;
  final int month;
  final Map<String, double> daily;
  final double maxValue;
  final TxnType type;

  @override
  Widget build(BuildContext context) {
    final dim = DateTime(year, month + 1, 0).day;
    final byDay = <int, double>{};
    for (final e in daily.entries) {
      final d = int.tryParse(e.key.substring(8, 10));
      if (d != null) byDay[d] = e.value;
    }
    final max = maxValue <= 0 ? 1.0 : maxValue;
    final color = type == TxnType.expense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 2.0;
        final square = ((constraints.maxWidth - gap * 6) / 7).clamp(6.0, 13.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$month月', style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
            const SizedBox(height: 3),
            for (var row = 0; row < 6; row++)
              Padding(
                padding: EdgeInsets.only(bottom: row == 5 ? 0.0 : gap),
                child: Row(
                  children: List.generate(7, (col) {
                    final day = row * 7 + col + 1;
                    final value = day <= dim ? (byDay[day] ?? 0) : 0;
                    final alpha = value <= 0
                        ? 0.06
                        : (0.10 + 0.72 * (value / max)).clamp(0.10, 0.82);
                    return Padding(
                      padding: EdgeInsets.only(right: col == 6 ? 0.0 : gap),
                      child: SizedBox(
                        width: square.toDouble(),
                        height: square.toDouble(),
                        child: day > dim
                            ? const SizedBox.shrink()
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: alpha.toDouble()),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}

class YearHeatmapPage extends StatefulWidget {
  const YearHeatmapPage({
    super.key,
    required this.year,
    required this.initialType,
    this.initialMonth = 1,
  });

  final int year;
  final TxnType initialType;
  final int initialMonth;

  @override
  State<YearHeatmapPage> createState() => _YearHeatmapPageState();
}

class _YearHeatmapPageState extends State<YearHeatmapPage> {
  late TxnType _type = widget.initialType;
  final AppStore store = AppStore.instance;
  final GlobalKey _targetKey = GlobalKey();
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset: (((widget.initialMonth - 1) * 300.0).clamp(0.0, double.infinity)).toDouble(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _targetKey.currentContext;
      if (target != null && mounted) {
        Scrollable.ensureVisible(target, alignment: 0.08, duration: const Duration(milliseconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.year}年 每月收支热力'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SegmentedButton<TxnType>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: TxnType.expense, label: Text('支出')),
                ButtonSegment(value: TxnType.income, label: Text('收入')),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() => _type = set.first),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
        children: [
          Text(
            _type == TxnType.expense ? '颜色越深，支出越高' : '颜色越深，收入越高',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          for (var m = 1; m <= 12; m++)
            KeyedSubtree(
              key: m == widget.initialMonth ? _targetKey : null,
              child: _FullMonthHeat(
                year: widget.year,
                month: m,
                type: _type,
                daily: _type == TxnType.expense
                    ? store.dailyExpense(DateTime(widget.year, m, 1))
                    : store.dailyIncome(DateTime(widget.year, m, 1)),
              ),
            ),
        ],
      ),
    );
  }
}

class _FullMonthHeat extends StatelessWidget {
  const _FullMonthHeat({
    required this.year,
    required this.month,
    required this.type,
    required this.daily,
  });

  final int year;
  final int month;
  final TxnType type;
  final Map<String, double> daily;

  @override
  Widget build(BuildContext context) {
    final dim = DateTime(year, month + 1, 0).day;
    final byDay = <int, double>{};
    for (final e in daily.entries) {
      final d = int.tryParse(e.key.substring(8, 10));
      if (d != null) byDay[d] = e.value;
    }
    final max = byDay.values.fold<double>(0, (a, b) => a > b ? a : b);
    final color = type == TxnType.expense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$year年$month月', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: 1,
            children: List.generate(35, (i) {
              final day = i + 1;
              if (day > dim) return const SizedBox.shrink();
              final value = byDay[day] ?? 0;
              final alpha = value <= 0 ? 0.05 : (0.10 + 0.72 * (value / (max <= 0 ? 1 : max))).clamp(0.10, 0.82);
              final date = DateTime(year, month, day);
              return InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () => Navigator.of(context).push(
                  fastPageRoute<void>(
                    PeriodTxnsScreen(
                      title: '$year年$month月$day日账单',
                      start: date,
                      end: date,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: alpha.toDouble()),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600)),
                      if (value > 0)
                        Text(
                          type == TxnType.expense ? '-${_short(value)}' : '+${_short(value)}',
                          style: const TextStyle(fontSize: 7, color: Colors.black54),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _short(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(v >= 100 ? 0 : 1);
  }
}
