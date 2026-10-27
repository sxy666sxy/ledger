import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils.dart';

Future<String?> showXkDatePicker(BuildContext context, {required String initialDate}) {
  final initial = DateTime.tryParse(initialDate) ?? DateTime.now();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DatePickerSheet(initial: initial),
  );
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({required this.initial});

  final DateTime initial;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selected;
  late DateTime _visible;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(widget.initial.year, widget.initial.month, widget.initial.day);
    _visible = DateTime(_selected.year, _selected.month, 1);
  }

  int get _daysInMonth => DateTime(_visible.year, _visible.month + 1, 0).day;

  int get _leadingBlanks => DateTime(_visible.year, _visible.month, 1).weekday - 1;

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _moveMonth(int delta) {
    setState(() => _visible = DateTime(_visible.year, _visible.month + delta, 1));
  }

  void _choose(DateTime date) {
    setState(() {
      _selected = DateTime(date.year, date.month, date.day);
      _visible = DateTime(date.year, date.month, 1);
    });
  }

  void _quick(int daysAgo) {
    final now = DateTime.now();
    _choose(DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateTime.now();
    final title = '${_selected.year}年${_selected.month}月${_selected.day}日';
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return XkSheet(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('选择日期', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const Spacer(),
                Text('今天 ${today.month}月${today.day}日', style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.55))),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available_outlined, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  const Spacer(),
                  Text(_weekdayName(_selected.weekday), style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 5,
              alignment: WrapAlignment.start,
              children: [
                _quickChip('今天', 0),
                _quickChip('昨天', 1),
                _quickChip('前天', 2),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_visible.year}年${_visible.month}月',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final w in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final day = index - _leadingBlanks + 1;
                if (day < 1 || day > _daysInMonth) return const SizedBox.shrink();
                final date = DateTime(_visible.year, _visible.month, day);
                final selected = _sameDay(date, _selected);
                final isToday = _sameDay(date, today);
                return Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => _choose(date),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? scheme.primary : null,
                        borderRadius: BorderRadius.circular(11),
                        border: !selected && isToday
                            ? Border.all(color: scheme.primary.withValues(alpha: 0.55))
                            : null,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected || isToday ? FontWeight.w800 : FontWeight.w500,
                          color: selected ? scheme.onPrimary : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(dateKey(_selected)),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String label, int daysAgo) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
    final selected = _sameDay(date, _selected);
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _quick(daysAgo),
    );
  }

  String _weekdayName(int weekday) => const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday - 1];
}
