import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

Future<void> showAccountEditor(
  BuildContext context,
  AppStore store,
  Account? account,
) async {
  final editing = account != null;
  final current = editing ? store.accountBalance(account) : 0.0;
  final name = TextEditingController(text: account?.name ?? '');
  final balance = TextEditingController(text: current.toStringAsFixed(2));
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => XkDialog(
      title: editing ? '编辑账户' : '新增账户',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '账户名称', hintText: '例如：现金'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 170,
            child: TextField(
              controller: balance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: editing ? '当前余额' : '初始余额',
                prefixText: '¥ ',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            editing ? '修改当前余额会自动校正初始余额，不改变已有账单。' : '初始余额将作为账户余额起点。',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
          if (editing) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5484D)),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => XkDialog(
                      title: '删除账户',
                      content: Text('删除「${account!.name}」会同时删除该账户的账单，确定吗？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('取消')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
                          onPressed: () => Navigator.of(c).pop(true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && ctx.mounted) {
                    store.deleteAccount(account!.id);
                    Navigator.of(ctx).pop(false);
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('删除账户', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(editing ? '保存' : '新增'),
        ),
      ],
    ),
  );
  if (result != true || !context.mounted) return;
  final newName = name.text.trim().isEmpty ? (account?.name ?? '新账户') : name.text.trim();
  final target = double.tryParse(balance.text.trim());
  if (target == null) return;
  if (editing) {
    final targetAccount = account;
    if (targetAccount == null) return;
    final delta = target - current;
    targetAccount
      ..name = newName
      ..initial += delta;
    store.updateAccount(targetAccount);
  } else {
    store.addAccount(Account(
      id: '',
      name: newName,
      type: 'other',
      icon: '💳',
      initial: target,
      order: store.accounts.length,
    ));
  }
}
