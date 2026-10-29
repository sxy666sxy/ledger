import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/account_editor.dart';
import '../widgets/date_picker_sheet.dart';
import 'entry_sheet.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final account = store.accountById(accountId);
        if (account == null) {
          return const Scaffold(body: Center(child: Text('账户不存在')));
        }
        final txns = _txnsOf(store, account.id);
        final balance = store.accountBalance(account);
        final transfers = txns.where((t) => t.type == TxnType.transfer).toList();
        return Scaffold(
          appBar: AppBar(title: Text(account.name)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              ThemeHeroCard(
                radius: 24,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(account.color).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                      ),
                      child: Text(account.icon, style: const TextStyle(fontSize: 25)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('当前余额', style: TextStyle(color: themeHeroMuted(context), fontSize: 10.5)),
                          const SizedBox(height: 2),
                          Text(
                            formatMoney(balance),
                            style: TextStyle(color: themeHeroFg(context), fontSize: 30, fontWeight: FontWeight.w800),
                          ),
                          Text('${txns.length} 笔流水 · 记账账户', style: TextStyle(color: themeHeroMuted(context), fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _action(context, Icons.add, '记账', () => showEntrySheet(context, initialAccountId: account.id)),
                  _action(context, Icons.swap_horiz, '转账', () => showEntrySheet(context, initialType: TxnType.transfer, initialAccountId: account.id)),
                  _action(context, Icons.insights_outlined, '统计', () => Navigator.of(context).push(fastPageRoute<void>(AccountStatsScreen(accountId: account.id)))),
                  _action(context, Icons.file_download_outlined, '导出', () => _export(context, store, account, txns)),
                  _action(context, Icons.edit_outlined, '编辑', () => showAccountEditor(context, store, account)),
                  _action(context, Icons.receipt_long_outlined, '转账记录', () => Navigator.of(context).push(fastPageRoute<void>(AccountTransfersScreen(accountId: account.id)))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('账户流水', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${txns.length} 笔', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 6),
              if (txns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('暂无流水', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                )
              else
                ..._grouped(txns).entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 10, 2, 5),
                        child: Text(entry.key, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                      ),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < entry.value.length; i++) ...[
                              if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                              _TxnRow(txn: entry.value[i], account: account, store: store),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              if (transfers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('含 ${transfers.length} 笔转账，可在“转账记录”中单独查看', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _action(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 19),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 9.5)),
          ],
        ),
      ),
    );
  }

  static List<Txn> _txnsOf(AppStore store, String id) {
    final list = store.transactions
        .where((t) => t.accountId == id || t.toAccountId == id)
        .toList();
    list.sort((a, b) {
      final d = b.date.compareTo(a.date);
      return d != 0 ? d : b.time.compareTo(a.time);
    });
    return list;
  }

  static Map<String, List<Txn>> _grouped(List<Txn> txns) {
    final map = <String, List<Txn>>{};
    for (final t in txns) {
      map.putIfAbsent(t.date, () => []).add(t);
    }
    return map;
  }

  Future<void> _export(BuildContext context, AppStore store, Account account, List<Txn> txns) async {
    if (txns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无流水可导出')));
      return;
    }
    final rows = <List<String>>[
      ['日期', '时间', '类型', '金额', '分类', '账户', '对方账户', '备注'],
    ];
    for (final t in txns) {
      final category = store.categoryById(t.categoryId)?.name ?? '';
      final from = store.accountById(t.accountId)?.name ?? '';
      final to = store.accountById(t.toAccountId)?.name ?? '';
      rows.add([
        t.date,
        t.time,
        t.type == TxnType.expense ? '支出' : (t.type == TxnType.income ? '收入' : '转账'),
        t.amount.toStringAsFixed(2),
        category,
        t.type == TxnType.transfer ? from : from,
        t.type == TxnType.transfer ? to : '',
        t.note,
      ]);
    }
    String esc(String value) => '"${value.replaceAll('"', '""')}"';
    final csv = rows.map((row) => row.map(esc).join(',')).join('\r\n');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/星空记账_${account.name}_流水.csv');
    await file.writeAsString('\uFEFF$csv');
    if (!context.mounted) return;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: '星空记账 · ${account.name}流水',
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn, required this.account, required this.store});

  final Txn txn;
  final Account account;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final category = store.categoryById(txn.categoryId);
    final isTransfer = txn.type == TxnType.transfer;
    final isOut = txn.accountId == account.id;
    final other = isTransfer
        ? (isOut ? store.accountById(txn.toAccountId)?.name : store.accountById(txn.accountId)?.name)
        : null;
    final title = isTransfer ? '转账${isOut ? '转出' : '转入'}' : (category?.name ?? '未分类');
    final subtitle = [
      txn.time,
      if (isTransfer && other != null) '对方：$other',
      if (!isTransfer && txn.note.isNotEmpty) txn.note,
    ].join(' · ');
    final amountColor = txn.type == TxnType.expense
        ? themeHeroExpense(context)
        : txn.type == TxnType.income
            ? themeHeroIncome(context)
            : Theme.of(context).colorScheme.primary;
    final sign = txn.type == TxnType.expense || (isTransfer && isOut) ? '-' : '+';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(14, 2, 12, 2),
      leading: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(category?.color ?? 0xFF5B6CFF).withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(isTransfer ? '⇄' : (category?.icon ?? '🏷️'), style: const TextStyle(fontSize: 15)),
      ),
      title: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5)),
      trailing: Text(
        '$sign${formatMoney(txn.amount, symbol: false)}',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: amountColor),
      ),
      onTap: () => showEntrySheet(context, existing: txn),
    );
  }
}

class AccountTransfersScreen extends StatelessWidget {
  const AccountTransfersScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final account = store.accountById(accountId);
        if (account == null) return const Scaffold(body: Center(child: Text('账户不存在')));
        final transfers = AccountDetailScreen._txnsOf(store, accountId)
            .where((t) => t.type == TxnType.transfer)
            .toList();
        return Scaffold(
          appBar: AppBar(title: Text('${account.name} · 转账记录')),
          body: transfers.isEmpty
              ? Center(child: Text('暂无转账记录', style: TextStyle(color: Colors.grey.shade600)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
                  itemCount: transfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, i) {
                    final t = transfers[i];
                    final isOut = t.accountId == account.id;
                    final other = store.accountById(isOut ? t.toAccountId : t.accountId)?.name ?? '未知账户';
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        title: Text('${isOut ? '转出到' : '转入自'} $other', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        subtitle: Text('${t.date} ${t.time}${t.note.isEmpty ? '' : ' · ${t.note}'}', style: const TextStyle(fontSize: 9.5)),
                        trailing: Text(
                          '${isOut ? '-' : '+'}${formatMoney(t.amount, symbol: false)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isOut ? themeHeroExpense(context) : themeHeroIncome(context),
                          ),
                        ),
                        onTap: () => showEntrySheet(context, existing: t),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class AccountStatsScreen extends StatefulWidget {
  const AccountStatsScreen({super.key, required this.accountId});

  final String accountId;

  @override
  State<AccountStatsScreen> createState() => _AccountStatsScreenState();
}

class _AccountStatsScreenState extends State<AccountStatsScreen> {
  final AppStore store = AppStore.instance;
  DateTime _month = monthStart(DateTime.now());
  bool _custom = false;
  late DateTime _start = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _end = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final account = store.accountById(widget.accountId);
    if (account == null) return const Scaffold(body: Center(child: Text('账户不存在')));
    final start = _custom ? _start : _month;
    final end = _custom ? _end : DateTime(_month.year, _month.month + 1, 0);
    final txns = AccountDetailScreen._txnsOf(store, account.id)
        .where((t) => t.type != TxnType.transfer && t.date.compareTo(dateKey(start)) >= 0 && t.date.compareTo(dateKey(end)) <= 0)
        .toList();
    var expense = 0.0;
    var income = 0.0;
    final cats = <String, double>{};
    for (final t in txns) {
      if (t.type == TxnType.expense) {
        expense += t.amount;
        cats[t.categoryId] = (cats[t.categoryId] ?? 0) + t.amount;
      } else {
        income += t.amount;
      }
    }
    final ranked = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: Text('${account.name} · 统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('月统计')),
              ButtonSegment(value: true, label: Text('自定义')),
            ],
            selected: {_custom},
            onSelectionChanged: (s) => setState(() => _custom = s.first),
          ),
          const SizedBox(height: 10),
          if (!_custom)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                Text(monthTitle(_month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text(dateKey(_start)))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('至')),
                Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text(dateKey(_end)))),
              ],
            ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _stat('支出', expense, themeHeroExpense(context)),
                  _stat('收入', income, themeHeroIncome(context)),
                  _stat('结余', income - expense, income - expense < 0 ? themeHeroExpense(context) : themeHeroIncome(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('支出分类', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (ranked.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('该区间暂无支出', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < ranked.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                    ListTile(
                      dense: true,
                      leading: Text(store.categoryById(ranked[i].key)?.icon ?? '🏷️'),
                      title: Text(store.categoryById(ranked[i].key)?.name ?? '未分类', style: const TextStyle(fontSize: 12.5)),
                      trailing: Text(
                        formatMoney(ranked[i].value),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: themeHeroExpense(context)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatMoney(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  Future<void> _pick(bool start) async {
    final picked = await showXkDatePicker(context, initialDate: dateKey(start ? _start : _end));
    if (picked == null) return;
    final value = DateTime.tryParse(picked);
    if (value == null) return;
    setState(() {
      if (start) {
        _start = value;
        if (_start.isAfter(_end)) _end = _start;
      } else {
        _end = value;
        if (_end.isBefore(_start)) _start = _end;
      }
    });
  }
}
