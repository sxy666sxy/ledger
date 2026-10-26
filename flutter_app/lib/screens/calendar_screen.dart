import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import 'entry_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = monthStart(DateTime.now());
  String _selected = dateKey(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final expenses = store.dailyExpense(_month);
        final incomes = store.dailyIncome(_month);
        final selectedTxns = store.txnsForDate(_selected);
        final first = DateTime(_month.year, _month.month, 1);
        final offset = first.weekday % 7;
        final dim = daysInMonth(_month);

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _month = addMonths(_month, -1)),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(monthTitle(_month), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('点日期查看当天账单', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _month = addMonths(_month, 1)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: '今天',
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _month = monthStart(now);
                          _selected = dateKey(now);
                        });
                      },
                      icon: const Icon(Icons.today_outlined),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  children: [
                    const Row(
                      children: [
                        _WeekLabel('日'),
                        _WeekLabel('一'),
                        _WeekLabel('二'),
                        _WeekLabel('三'),
                        _WeekLabel('四'),
                        _WeekLabel('五'),
                        _WeekLabel('六'),
                      ],
                    ),
                    const SizedBox(height: 5),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 42,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (context, i) {
                        final day = i - offset + 1;
                        if (day < 1 || day > dim) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime(_month.year, _month.month, day);
                        final iso = dateKey(date);
                        final selected = iso == _selected;
                        final today = sameDay(date, DateTime.now());
                        final expense = expenses[iso] ?? 0;
                        final income = incomes[iso] ?? 0;
                        final heat = expense > 0
                            ? expense / (expenses.values.fold<double>(1, (a, b) => a > b ? a : b))
                            : 0.0;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selected = iso),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF5B6CFF)
                                  : Color.lerp(
                                      Theme.of(context).colorScheme.surface,
                                      const Color(0xFFFFE5E5),
                                      heat.clamp(0.0, 0.55).toDouble(),
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: today && !selected
                                  ? Border.all(color: const Color(0xFF5B6CFF), width: 1.2)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? Colors.white : null,
                                  ),
                                ),
                                if (expense > 0)
                                  Text(
                                    '-${expense.toStringAsFixed(expense >= 100 ? 0 : 1)}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: selected ? Colors.white70 : const Color(0xFFE5484D),
                                    ),
                                  ),
                                if (income > 0)
                                  Text(
                                    '+${income.toStringAsFixed(income >= 100 ? 0 : 1)}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: selected ? Colors.white70 : const Color(0xFF0E9F6E),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(fullDateTitle(_selected), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Text('${selectedTxns.length} 笔', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: () => showEntrySheet(context, initialDate: _selected),
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text('记一笔'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedTxns.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text('这天还没有账单', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ),
                      )
                    else
                      ...selectedTxns.map((t) {
                        final cat = store.categoryById(t.categoryId);
                        final isExpense = t.type == TxnType.expense;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: Text(cat?.icon ?? '🏷️', style: const TextStyle(fontSize: 20)),
                            title: Text(cat?.name ?? '未分类'),
                            subtitle: Text([t.time, t.note].where((e) => e.isNotEmpty).join(' · ')),
                            trailing: Text(
                              '${isExpense ? '-' : '+'}${formatMoney(t.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isExpense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E),
                              ),
                            ),
                            onTap: () => showEntrySheet(context, existing: t),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(text, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
      ),
    );
  }
}
