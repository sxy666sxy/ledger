import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import '../theme.dart';
import '../widgets/hero_card_settings.dart';
import 'account_detail_screen.dart';
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
        final heroFg = themeHeroFg(context);
        final heroMuted = themeHeroMuted(context);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              GestureDetector(
                onTap: () => showHeroCardSettings(context),
                child: ThemeHeroCard(
                radius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('净资产', style: TextStyle(color: heroMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      formatMoney(net),
                      style: TextStyle(color: heroFg, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _heroCell(context, '总资产', formatMoney(totalAssets))),
                        Expanded(child: _heroCell(context, '总负债', formatMoney(debts))),
                        Expanded(child: _heroCell(context, '账户', '${accounts.length} 个')),
                      ],
                    ),
                  ],
                ),
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
                      fastPageRoute<void>(const AssetTrendScreen()),
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
                        onTap: () => Navigator.of(context).push(
                          fastPageRoute<void>(AccountDetailScreen(accountId: a.id)),
                        ),
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

  Widget _heroCell(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: themeHeroMuted(context), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: themeHeroFg(context), fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _editAccount(BuildContext context, AppStore store, Account? account) async {
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
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => XkDialog(
                        title: '删除账户？',
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
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: const Text('删除账户', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
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
    final label = name.text.trim();
    final target = double.tryParse(balance.text.trim());
    name.dispose();
    balance.dispose();
    if (result != true || label.isEmpty) return;
    if (account == null) {
      store.addAccount(Account(
        id: '',
        name: label,
        initial: target ?? 0,
        type: 'other',
        icon: '💳',
        color: 0xFF5B6CFF,
        order: store.accounts.length,
      ));
    } else {
      account.name = label;
      if (target != null) {
        account.initial += target - current;
      }
      store.updateAccount(account);
    }
  }
}
