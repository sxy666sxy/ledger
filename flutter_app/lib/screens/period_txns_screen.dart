import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import 'entry_sheet.dart';

/// 统计图表点击后展示对应日期范围的账单列表。
class PeriodTxnsScreen extends StatelessWidget {
  const PeriodTxnsScreen({
    super.key,
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final txns = store.txnsBetween(start, end);
        final totals = store.totalsBetween(start, end);
        final byDay = <String, List<Txn>>{};
        for (final t in txns) {
          byDay.putIfAbsent(t.date, () => []).add(t);
        }
        final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  child: Row(
                    children: [
                      _metric('支出', totals.expense, const Color(0xFFD92D20)),
                      _metric('收入', totals.income, const Color(0xFF0E9F6E)),
                      _metric('结余', totals.balance, totals.balance < 0 ? const Color(0xFFD92D20) : const Color(0xFF0E9F6E)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (txns.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('这个时间段还没有账单')),
                )
              else
                for (final day in days) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 10, 2, 7),
                    child: Row(
                      children: [
                        Text(day.substring(5), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Text('${byDay[day]!.length} 笔', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        const Spacer(),
                        Text(
                          '支出 ${formatMoney(byDay[day]!.where((t) => t.type == TxnType.expense).fold<double>(0, (a, t) => a + t.amount))}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFD92D20)),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < byDay[day]!.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 52),
                          _row(context, store, byDay[day]![i]),
                        ],
                      ],
                    ),
                  ),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _metric(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(value),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppStore store, Txn txn) {
    final category = store.categoryById(txn.categoryId);
    final account = store.accountById(txn.accountId);
    final isExpense = txn.type == TxnType.expense;
    final color = isExpense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Color(category?.color ?? 0xFF94A3B8).withValues(alpha: 0.14),
        child: Text(category?.icon ?? '🧾', style: const TextStyle(fontSize: 15)),
      ),
      title: Text(
        category?.name ?? '未分类',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${txn.time} · ${account?.name ?? '账户'}${txn.note.isEmpty ? '' : ' · ${txn.note}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Text(
        '${isExpense ? '-' : '+'}${formatMoney(txn.amount)}',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
      ),
      onTap: () => showEntrySheet(context, existing: txn),
    );
  }
}
