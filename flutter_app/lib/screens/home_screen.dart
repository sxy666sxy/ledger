import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import 'entry_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenCalendar});

  final VoidCallback? onOpenCalendar;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _month = monthStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final totals = store.totalsForMonth(_month);
        final txns = store.txnsForMonth(_month);
        final grouped = <String, List<Txn>>{};
        for (final t in txns) {
          grouped.putIfAbsent(t.date, () => []).add(t);
        }
        final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
        final book = store.activeBook;
        final budget = book.budget;
        final budgetRatio = budget <= 0 ? 0.0 : (totals.expense / budget).clamp(0.0, 1.0).toDouble();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _monthHeader(context),
            const SizedBox(height: 10),
            _summaryCard(context, totals, book),
            if (budget > 0) ...[
              const SizedBox(height: 12),
              _budgetCard(context, totals.expense, budget, budgetRatio),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text('${txns.length} 笔', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onOpenCalendar,
                  icon: const Icon(Icons.calendar_month_outlined, size: 17),
                  label: const Text('日历'),
                ),
              ],
            ),
            if (dates.isEmpty)
              _emptyState(context)
            else
              ...dates.map((date) => _daySection(context, date, grouped[date]!, store)),
          ],
        );
      },
    );
  }

  Widget _monthHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(() => _month = addMonths(_month, -1)),
          icon: const Icon(Icons.chevron_left),
          tooltip: '上个月',
        ),
        Expanded(
          child: Center(
            child: Text(
              monthTitle(_month),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _month = addMonths(_month, 1)),
          icon: const Icon(Icons.chevron_right),
          tooltip: '下个月',
        ),
        if (!sameMonth(_month, DateTime.now()))
          TextButton(
            onPressed: () => setState(() => _month = monthStart(DateTime.now())),
            child: const Text('本月'),
          ),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, MoneyTotals totals, Book book) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2355), Color(0xFF0A0F2A), Color(0xFF211747)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2355).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${book.icon} ${book.name}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(monthTitle(_month), style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('本月支出', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            formatMoney(totals.expense),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _sumCell('收入', formatMoney(totals.income))),
              Expanded(child: _sumCell('结余', formatMoney(totals.balance))),
              Expanded(child: _sumCell('笔数', '${AppStore.instance.txnsForMonth(_month).length}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sumCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _budgetCard(BuildContext context, double expense, double budget, double ratio) {
    final over = expense > budget;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('本月预算', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${formatMoney(expense, symbol: false)} / ${formatMoney(budget, symbol: false)}',
                  style: TextStyle(fontSize: 11, color: over ? Colors.red : Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              borderRadius: BorderRadius.circular(6),
              color: over ? Colors.red : const Color(0xFF5B6CFF),
              backgroundColor: const Color(0xFFEEF0FF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daySection(BuildContext context, String date, List<Txn> txns, AppStore store) {
    final dt = DateTime.tryParse(date);
    final dayExpense = txns.where((t) => t.type == TxnType.expense).fold<double>(0, (s, t) => s + t.amount);
    final dayIncome = txns.where((t) => t.type == TxnType.income).fold<double>(0, (s, t) => s + t.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
          child: Row(
            children: [
              Text('${dt?.day ?? ''}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text(
                '${dt == null ? '' : '${dt.month}月 · ${weekdayCN(dt)}'}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const Spacer(),
              if (dayExpense > 0) Text('支出 ${formatMoney(dayExpense)}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
              if (dayExpense > 0 && dayIncome > 0) const SizedBox(width: 8),
              if (dayIncome > 0) Text('收入 ${formatMoney(dayIncome)}', style: const TextStyle(fontSize: 11, color: Color(0xFF0E9F6E))),
            ],
          ),
        ),
        ...txns.map((t) => _txnTile(context, t, store)),
      ],
    );
  }

  Widget _txnTile(BuildContext context, Txn t, AppStore store) {
    final cat = store.categoryById(t.categoryId);
    final acc = store.accountById(t.accountId);
    final isExpense = t.type == TxnType.expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: ValueKey(t.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) {
          store.deleteTxn(t.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除')),
          );
        },
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showEntrySheet(context, existing: t),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(cat?.color ?? 0xFF94A3B8).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(cat?.icon ?? '🏷️', style: const TextStyle(fontSize: 19)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cat?.name ?? '未分类'}${t.subcategory.isNotEmpty ? ' · ${t.subcategory}' : ''}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [t.time, acc?.name ?? '', t.note].where((e) => e.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isExpense ? '-' : '+'}${formatMoney(t.amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isExpense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Text('✦', style: TextStyle(fontSize: 42, color: Color(0xFF5B6CFF))),
          const SizedBox(height: 12),
          const Text('这个月还没有账单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('点右下角的 + 记下第一笔', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
