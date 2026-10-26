import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('周期记账')),
          body: store.recurringRules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔁', style: TextStyle(fontSize: 42)),
                      const SizedBox(height: 10),
                      Text('还没有周期规则', style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text('比如每天早餐、每月房租', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  itemCount: store.recurringRules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final rule = store.recurringRules[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B6CFF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(rule.type == TxnType.expense ? '🔁' : '📈', style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(rule.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${_frequencyLabel(rule.frequency)} · ${rule.type == TxnType.expense ? '-' : '+'}${formatMoney(rule.amount)}'
                          '\n${rule.enabled ? '下次：${_nextLabel(rule)}' : '已暂停'}',
                        ),
                        isThreeLine: true,
                        trailing: Switch(
                          value: rule.enabled,
                          onChanged: (v) {
                            rule.enabled = v;
                            store.updateRecurring(rule);
                            store.applyRecurringRules();
                            store.touch();
                            store.save();
                          },
                        ),
                        onTap: () => _edit(context, store, rule),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, store, null),
            icon: const Icon(Icons.add),
            label: const Text('新增周期'),
          ),
        );
      },
    );
  }

  String _frequencyLabel(String f) {
    if (f == 'daily') return '每天';
    if (f == 'weekly') return '每周';
    return '每月';
  }

  String _nextLabel(RecurringRule rule) {
    if (rule.lastGenerated.isEmpty) return rule.startDate;
    final d = DateTime.tryParse(rule.lastGenerated);
    if (d == null) return rule.startDate;
    if (rule.frequency == 'daily') return dateKey(d.add(const Duration(days: 1)));
    if (rule.frequency == 'weekly') return dateKey(d.add(const Duration(days: 7)));
    final y = d.month == 12 ? d.year + 1 : d.year;
    final m = d.month == 12 ? 1 : d.month + 1;
    final maxDay = DateTime(y, m + 1, 0).day;
    return dateKey(DateTime(y, m, d.day > maxDay ? maxDay : d.day));
  }

  Future<void> _edit(BuildContext context, AppStore store, RecurringRule? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final amount = TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
    var type = existing?.type ?? TxnType.expense;
    var categoryId = existing?.categoryId ?? (store.categoriesFor(type).isNotEmpty ? store.categoriesFor(type).first.id : '');
    var accountId = existing?.accountId ?? (store.bookkeepingAccounts.isNotEmpty
        ? store.bookkeepingAccounts.first.id
        : (store.accounts.isNotEmpty ? store.accounts.first.id : ''));
    var frequency = existing?.frequency ?? 'monthly';
    var startDate = existing?.startDate ?? dateKey(DateTime.now());
    final note = TextEditingController(text: existing?.note ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cats = store.categoriesFor(type);
          final accts = store.bookkeepingAccounts.isNotEmpty ? store.bookkeepingAccounts : store.accounts;
          return AlertDialog(
            title: Text(existing == null ? '新增周期记账' : '编辑周期记账'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: existing == null,
                    decoration: const InputDecoration(labelText: '名称', hintText: '例如：房租'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '金额', prefixText: '¥ '),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TxnType>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: TxnType.expense, label: Text('支出')),
                      ButtonSegment(value: TxnType.income, label: Text('收入')),
                    ],
                    selected: {type},
                    onSelectionChanged: (set) => setDialogState(() {
                      type = set.first;
                      final list = store.categoriesFor(type);
                      if (list.isNotEmpty) categoryId = list.first.id;
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: cats.any((c) => c.id == categoryId) ? categoryId : null,
                    decoration: const InputDecoration(labelText: '分类'),
                    items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}'))).toList(),
                    onChanged: (v) => setDialogState(() => categoryId = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: accts.any((a) => a.id == accountId) ? accountId : null,
                    decoration: const InputDecoration(labelText: '账户'),
                    items: accts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}'))).toList(),
                    onChanged: (v) => setDialogState(() => accountId = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: frequency,
                    decoration: const InputDecoration(labelText: '周期'),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('每天')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周')),
                      DropdownMenuItem(value: 'monthly', child: Text('每月')),
                    ],
                    onChanged: (v) => setDialogState(() => frequency = v ?? 'monthly'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(startDate) ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setDialogState(() => startDate = dateKey(d));
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('开始：$startDate'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: '备注（可选）'),
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () {
                    store.deleteRecurring(existing.id);
                    Navigator.pop(ctx, false);
                  },
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
            ],
          );
        },
      ),
    );
    if (result != true) return;
    final v = double.tryParse(amount.text.trim()) ?? 0;
    if (v <= 0 || name.text.trim().isEmpty || categoryId.isEmpty || accountId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写名称、金额、分类和账户')));
      }
      return;
    }
    final rule = RecurringRule(
      id: existing?.id ?? '',
      name: name.text.trim(),
      type: type,
      amount: v,
      categoryId: categoryId,
      accountId: accountId,
      bookId: store.activeBookId,
      frequency: frequency,
      startDate: startDate,
      note: note.text.trim(),
      lastGenerated: existing?.lastGenerated ?? '',
      enabled: existing?.enabled ?? true,
    );
    if (existing == null) {
      store.addRecurring(rule);
    } else {
      store.updateRecurring(rule);
    }
  }
}
