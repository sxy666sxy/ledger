import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import '../theme.dart';
import 'asset_trend_screen.dart';
import 'entry_sheet.dart';

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final accounts = store.accounts;
        final net = store.netAssets;
        final totalAssets = accounts
            .where((a) => a.include && store.accountBalance(a) >= 0)
            .fold<double>(0, (s, a) => s + store.accountBalance(a));
        final debts = accounts
            .where((a) => a.include && store.accountBalance(a) < 0)
            .fold<double>(0, (s, a) => s + store.accountBalance(a).abs());
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: themeHeroDecoration(context, radius: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('净资产', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      formatMoney(net),
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _heroCell('总资产', formatMoney(totalAssets))),
                        Expanded(child: _heroCell('总负债', formatMoney(debts))),
                        Expanded(child: _heroCell('账户', '${accounts.length} 个')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('资金账户', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    tooltip: '转账',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showEntrySheet(context, initialType: TxnType.transfer),
                    icon: const Icon(Icons.swap_horiz, size: 20),
                  ),
                  IconButton(
                    tooltip: '新增账户',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _editAccount(context, store, null),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                  IconButton(
                    tooltip: '完整资产走势',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AssetTrendScreen()),
                    ),
                    icon: const Icon(Icons.show_chart, size: 20),
                  ),
                ],
              ),
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('还没有账户', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ),
                )
              else
                ...accounts.map((a) {
                  final balance = store.accountBalance(a);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        leading: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color(a.color).withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(a.icon, style: const TextStyle(fontSize: 17)),
                        ),
                        title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: Text(a.bookkeeping ? '记账账户' : '未启用记账', style: const TextStyle(fontSize: 9.5)),
                        trailing: Text(
                          formatMoney(balance),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: balance < 0 ? const Color(0xFFE5484D) : null,
                          ),
                        ),
                        onTap: () => _editAccount(context, store, a),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              Text(
                '账户余额 = 初始余额 + 收入 - 支出。所有数据只保存在本机。',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _editAccount(BuildContext context, AppStore store, Account? account) async {
    final name = TextEditingController(text: account?.name ?? '');
    final initial = TextEditingController(text: account?.initial.toStringAsFixed(2) ?? '0.00');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(account == null ? '新增账户' : '编辑账户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '账户名称', hintText: '例如：现金'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: initial,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '初始余额', prefixText: '¥ '),
            ),
            if (account != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('删除账户？'),
                        content: const Text('该账户下的账单也会被删除。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      store.deleteAccount(account.id);
                      if (ctx.mounted) Navigator.pop(ctx, false);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('删除账户', style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == true) {
      final parsed = double.tryParse(initial.text.trim()) ?? 0;
      final label = name.text.trim();
      if (label.isEmpty) return;
      if (account == null) {
        store.addAccount(Account(
          id: '',
          name: label,
          initial: parsed,
          type: 'other',
          icon: '💳',
          color: 0xFF5B6CFF,
          order: store.accounts.length,
        ));
      } else {
        account.name = label;
        account.initial = parsed;
        store.updateAccount(account);
      }
    }
  }
}
