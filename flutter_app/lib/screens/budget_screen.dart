import 'package:flutter/material.dart';
import '../models.dart';

import '../store.dart';
import '../theme.dart';
import '../utils.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final AppStore store = AppStore.instance;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final budget = store.activeBook.budget;
    _controller = TextEditingController(text: budget > 0 ? budget.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim()) ?? 0;
    final book = store.activeBook;
    book.budget = value < 0 ? 0 : value;
    final messenger = ScaffoldMessenger.of(context);
    store.updateBook(book);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(book.budget > 0 ? '预算已保存' : '已关闭月预算')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: store, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final book = store.activeBook;
    return Scaffold(
      appBar: AppBar(title: const Text('预算设置')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('设置每月总预算；填 0 可关闭预算提醒。', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(prefixText: '¥ ', hintText: '0.00'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(onPressed: _save, child: const Text('保存预算')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('分类预算', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('每月独立预算，填 0 取消', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  ...store.categoriesFor(TxnType.expense).map((c) {
                    final b = book.categoryBudgets[c.id] ?? 0;
                    final spent = store.categoryTotals(DateTime.now(), TxnType.expense)
                        .where((x) => x.category.id == c.id)
                        .fold<double>(0, (s, x) => s + x.value);
                    final ratio = b <= 0 ? 0.0 : (spent / b).clamp(0.0, 1.0).toDouble();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(c.icon, style: const TextStyle(fontSize: 20)),
                      title: Text(c.name),
                      subtitle: b > 0
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('本月 ${formatMoney(spent, symbol: false)} / ${formatMoney(b, symbol: false)}',
                                    style: TextStyle(fontSize: 10, color: spent > b ? Colors.red : Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 4,
                                  color: spent > b ? Colors.red : Color(c.color),
                                  backgroundColor: const Color(0xFFEEF0FF),
                                ),
                              ],
                            )
                          : const Text('未设置', style: TextStyle(fontSize: 10)),
                      trailing: Text(b > 0 ? formatMoney(b, symbol: false) : '—',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onTap: () => _editCategoryBudget(context, c),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '预算只保存在本机，不会上传。',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _editCategoryBudget(BuildContext context, Category category) async {
    final book = store.activeBook;
    final controller = TextEditingController(
      text: (book.categoryBudgets[category.id] ?? 0) > 0
          ? book.categoryBudgets[category.id]!.toStringAsFixed(2)
          : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => XkDialog(
        title: Text('${category.icon} ${category.name} 预算'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '每月预算', prefixText: '¥ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      final value = double.tryParse(controller.text.trim()) ?? 0;
      if (value <= 0) {
        book.categoryBudgets.remove(category.id);
      } else {
        book.categoryBudgets[category.id] = value;
      }
      store.updateBook(book);
    }
    controller.dispose();
  }
}
