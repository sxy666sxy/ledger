import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

const _accountIconOptions = <String, String>{
  '💵': '现金',
  '💬': '微信',
  '💙': '支付宝',
  '💳': '银行卡',
  '🏦': '银行',
  '🪙': '零钱',
  '📱': '电子钱包',
  '🛒': '消费',
};

Future<void> showAccountEditor(
  BuildContext context,
  AppStore store,
  Account? account,
) async {
  final editing = account != null;
  final current = editing ? store.accountBalance(account) : 0.0;
  final name = TextEditingController(text: account?.name ?? '');
  final balance = TextEditingController(text: current.toStringAsFixed(2));
  var selectedIcon = account?.icon ?? '💵';
  final options = <String, String>{..._accountIconOptions};
  if (!options.containsKey(selectedIcon)) {
    options[selectedIcon] = '其他';
  }
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setDialogState) => XkDialog(
        title: editing ? '编辑账户' : '新增账户',
        content: SizedBox(
          width: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 170,
                child: TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '账户名称',
                    hintText: '例如：现金',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: balance,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: editing ? '当前余额' : '初始余额',
                    prefixText: '¥ ',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '账户图标',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in options.entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          setDialogState(() => selectedIcon = entry.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 55,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedIcon == entry.key
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.14)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedIcon == entry.key
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                editing
                    ? '修改当前余额会自动校正初始余额，不改变已有账单。'
                    : '初始余额将作为账户余额起点。',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
              if (editing) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE5484D),
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (c) => XkDialog(
                          title: '删除账户',
                          content: Text('删除「${account!.name}」会同时删除该账户的账单，确定吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(c).pop(false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE5484D),
                              ),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(editing ? '保存' : '新增'),
          ),
        ],
      ),
    ),
  );
  if (result != true || !context.mounted) return;
  final newName = name.text.trim().isEmpty
      ? (account?.name ?? '新账户')
      : name.text.trim();
  final target = double.tryParse(balance.text.trim());
  if (target == null) return;
  if (editing) {
    final targetAccount = account;
    if (targetAccount == null) return;
    final delta = target - current;
    targetAccount
      ..name = newName
      ..icon = selectedIcon
      ..initial += delta;
    store.updateAccount(targetAccount);
  } else {
    final type = switch (selectedIcon) {
      '💬' => 'wechat',
      '💙' => 'alipay',
      '💳' => 'bank',
      '💵' => 'cash',
      _ => 'other',
    };
    store.addAccount(Account(
      id: '',
      name: newName,
      type: type,
      icon: selectedIcon,
      initial: target,
      order: store.accounts.length,
    ));
  }
}
