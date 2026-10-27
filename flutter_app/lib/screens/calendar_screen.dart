import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'entry_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _LunarDay {
  const _LunarDay(this.text, {this.highlight = false, this.work = false});
  final String text;
  final bool highlight;
  final bool work;
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = monthStart(DateTime.now());
  String _selected = dateKey(DateTime.now());

  _LunarDay _lunarOf(DateTime date) {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();
    final holiday = HolidayUtil.getHolidayByYmd(date.year, date.month, date.day);
    if (holiday != null) {
      if (holiday.isWork()) return const _LunarDay('班', work: true);
      return _LunarDay(holiday.getName().replaceAll('节', ''), highlight: true);
    }
    final festivals = [...solar.getFestivals(), ...lunar.getFestivals()];
    if (festivals.isNotEmpty) return _LunarDay(festivals.first, highlight: true);
    final jieQi = lunar.getJieQi();
    if (jieQi.isNotEmpty) return _LunarDay(jieQi);
    if (lunar.getDay() == 1) return _LunarDay('${lunar.getMonthInChinese()}月');
    return _LunarDay(lunar.getDayInChinese());
  }

  void _shiftMonth(int delta) {
    final next = addMonths(_month, delta);
    final day = DateTime.tryParse(_selected)?.day ?? 1;
    final maxDay = daysInMonth(next);
    setState(() {
      _month = next;
      _selected = dateKey(DateTime(next.year, next.month, day > maxDay ? maxDay : day));
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selected) ?? _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择年月',
    );
    if (picked != null) {
      setState(() {
        _month = monthStart(picked);
        _selected = dateKey(picked);
      });
    }
  }

  void _showSettings() {
    final store = AppStore.instance;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimatedBuilder(
        animation: store,
        builder: (context, _) => XkSheet(
          child: SafeArea(
            top: false,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('日历设置', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('农历、节假日显示只影响日历格子'),
              ),
              SwitchListTile(
                value: store.showLunar,
                onChanged: store.setShowLunar,
                title: const Text('显示农历与节假日'),
                subtitle: const Text('节气、农历日期和法定节假日'),
              ),
              const SizedBox(height: 8),
            ],
          ),
          ),
        ),
      ),
    );
  }

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
        final maxExpense = expenses.values.fold<double>(1, (a, b) => a > b ? a : b);

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 2),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _pickMonth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(monthTitle(_month), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.expand_more, size: 17),
                                ],
                              ),
                              Text('左右滑动日历 · 点击年月选择', style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '今天',
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _month = monthStart(now);
                          _selected = dateKey(now);
                        });
                      },
                      icon: const Icon(Icons.today_outlined, size: 21),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '日历设置',
                      onPressed: _showSettings,
                      icon: const Icon(Icons.settings_outlined, size: 21),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 100),
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
                    const SizedBox(height: 3),
                    GestureDetector(
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v < -120) {
                          _shiftMonth(1);
                        } else if (v > 120) {
                          _shiftMonth(-1);
                        }
                      },
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: offset + dim,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 3,
                          crossAxisSpacing: 3,
                          childAspectRatio: 0.82,
                        ),
                        itemBuilder: (context, i) {
                          final day = i - offset + 1;
                          if (day < 1 || day > dim) return const SizedBox.shrink();
                          final date = DateTime(_month.year, _month.month, day);
                          final iso = dateKey(date);
                          final selected = iso == _selected;
                          final today = sameDay(date, DateTime.now());
                          final expense = expenses[iso] ?? 0;
                          final income = incomes[iso] ?? 0;
                          final lunar = _lunarOf(date);
                          final heat = expense > 0 ? expense / maxExpense : 0.0;
                          final amountLabel = expense > 0 && income > 0
                              ? '-${_short(expense)} +${_short(income)}'
                              : expense > 0
                                  ? '-${_short(expense)}'
                                  : income > 0
                                      ? '+${_short(income)}'
                                      : '';
                          return InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: () => setState(() => _selected = iso),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 1),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF5B6CFF)
                                    : Color.lerp(
                                        Theme.of(context).colorScheme.surface,
                                        const Color(0xFFFFE5E5),
                                        heat.clamp(0.0, 0.55).toDouble(),
                                      ),
                                borderRadius: BorderRadius.circular(11),
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
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: selected ? Colors.white : null,
                                    ),
                                  ),
                                  if (store.showLunar)
                                    Text(
                                      lunar.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 7.2,
                                        height: 1.1,
                                        color: selected
                                            ? Colors.white70
                                            : lunar.work
                                                ? Colors.grey
                                                : lunar.highlight
                                                    ? const Color(0xFFE5484D)
                                                    : Colors.grey.shade600,
                                      ),
                                    ),
                                  if (amountLabel.isNotEmpty)
                                    Text(
                                      amountLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 8.0,
                                        height: 1.1,
                                        color: selected
                                            ? Colors.white70
                                            : expense > 0
                                                ? const Color(0xFFE5484D)
                                                : const Color(0xFF0E9F6E),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 2),
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
                    const SizedBox(height: 6),
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
                        final to = store.accountById(t.toAccountId);
                        final acc = store.accountById(t.accountId);
                        final isExpense = t.type == TxnType.expense;
                        final isTransfer = t.type == TxnType.transfer;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 5),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            leading: Text(isTransfer ? '🔁' : (cat?.icon ?? '🏷️'), style: const TextStyle(fontSize: 18)),
                            title: Text(isTransfer ? '转账' : (cat?.name ?? '未分类'), style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              isTransfer ? '${acc?.name ?? '?'} → ${to?.name ?? '?'}' : [t.time, t.note].where((e) => e.isNotEmpty).join(' · '),
                              style: const TextStyle(fontSize: 9.5),
                            ),
                            trailing: Text(
                              isTransfer ? formatMoney(t.amount) : '${isExpense ? '-' : '+'}${formatMoney(t.amount)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isTransfer
                                    ? const Color(0xFF5B6CFF)
                                    : (isExpense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E)),
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

  String _short(double value) => value.toStringAsFixed(value >= 100 ? 0 : 1);
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
