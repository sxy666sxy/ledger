import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';

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
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
              children: months.map((m) {
                final daily = type == TxnType.expense ? store.dailyExpense(m) : store.dailyIncome(m);
                return _MiniMonthHeat(
                  year: year,
                  month: m.month,
                  daily: daily,
                  maxValue: maxValues[m.month] ?? 0,
                  type: type,
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => YearHeatmapPage(year: year, initialType: type),
                  ),
                ),
                icon: const Icon(Icons.open_in_full, size: 15),
                label: const Text('点击放大热力图'),
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$month月', style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
        const SizedBox(height: 3),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: List.generate(35, (i) {
            final day = i + 1;
            if (day > dim) return const SizedBox.shrink();
            final value = byDay[day] ?? 0;
            final alpha = value <= 0 ? 0.06 : (0.10 + 0.72 * (value / max)).clamp(0.10, 0.82);
            final color = type == TxnType.expense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E);
            return Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: alpha.toDouble()),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class YearHeatmapPage extends StatefulWidget {
  const YearHeatmapPage({super.key, required this.year, required this.initialType});

  final int year;
  final TxnType initialType;

  @override
  State<YearHeatmapPage> createState() => _YearHeatmapPageState();
}

class _YearHeatmapPageState extends State<YearHeatmapPage> {
  late TxnType _type = widget.initialType;
  final AppStore store = AppStore.instance;

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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
        children: [
          Text(
            _type == TxnType.expense ? '颜色越深，支出越高' : '颜色越深，收入越高',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          for (var m = 1; m <= 12; m++)
            _FullMonthHeat(
              year: widget.year,
              month: m,
              type: _type,
              daily: _type == TxnType.expense
                  ? store.dailyExpense(DateTime(widget.year, m, 1))
                  : store.dailyIncome(DateTime(widget.year, m, 1)),
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
              return Container(
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
