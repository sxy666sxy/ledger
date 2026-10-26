import 'package:flutter/material.dart';

import '../store.dart';
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
          const SizedBox(height: 12),
          Text(
            '预算只保存在本机，不会上传。分类预算将在后续阶段迁移。',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
