import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import '../widgets/classic_month_card.dart';
import '../widgets/orbit_month_card.dart';
import '../widgets/swipe_delete_tile.dart';
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

        final topInset = MediaQuery.of(context).padding.top + kToolbarHeight - 6;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(top: topInset),
              sliver: SliverToBoxAdapter(
                child: store.cardStyle == 'classic'
                    ? ClassicMonthCard(
                        month: _month,
                        totals: totals,
                        bookName: book.name,
                        bookIcon: book.icon,
                        count: txns.length,
                        onChanged: (m) => setState(() => _month = monthStart(m)),
                      )
                    : OrbitMonthCard(
                        month: _month,
                        totals: totals,
                        bookName: book.name,
                        bookIcon: book.icon,
                        count: txns.length,
                        onChanged: (m) => setState(() => _month = monthStart(m)),
                      ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
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
                  if (dates.isEmpty) _emptyState(context),
                ]),
              ),
            ),
            if (dates.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _daySection(context, dates[i], grouped[dates[i]]!, store),
                    childCount: dates.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 132)),
          ],
        );
      },
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
    final to = store.accountById(t.toAccountId);
    final isExpense = t.type == TxnType.expense;
    final isTransfer = t.type == TxnType.transfer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SwipeDeleteTile(
        onDelete: () {
          store.deleteTxn(t.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除')),
          );
        },
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showEntrySheet(context, existing: t),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(cat?.color ?? 0xFF94A3B8).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(isTransfer ? '🔁' : (cat?.icon ?? '🏷️'), style: const TextStyle(fontSize: 17)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTransfer
                              ? '转账'
                              : '${cat?.name ?? '未分类'}${t.subcategory.isNotEmpty ? ' · ${t.subcategory}' : ''}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isTransfer
                              ? [t.time, '${acc?.name ?? '?'} → ${to?.name ?? '?'}', t.note]
                                  .where((e) => e.isNotEmpty)
                                  .join(' · ')
                              : [t.time, acc?.name ?? '', t.note].where((e) => e.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTransfer
                        ? formatMoney(t.amount)
                        : '${isExpense ? '-' : '+'}${formatMoney(t.amount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isTransfer
                          ? const Color(0xFF5B6CFF)
                          : (isExpense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E)),
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
