import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';

Future<void> showEntrySheet(
  BuildContext context, {
  Txn? existing,
  String? initialDate,
  TxnType? initialType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => EntrySheet(
      existing: existing,
      initialDate: initialDate,
      initialType: initialType,
    ),
  );
}

class EntrySheet extends StatefulWidget {
  const EntrySheet({super.key, this.existing, this.initialDate, this.initialType});

  final Txn? existing;
  final String? initialDate;
  final TxnType? initialType;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final AppStore store = AppStore.instance;
  late TxnType _type;
  late String _date;
  String _categoryId = '';
  String _accountId = '';
  String _toAccountId = '';
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.initialType ?? TxnType.expense;
    _date = existing?.date ?? widget.initialDate ?? dateKey(DateTime.now());
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    final cats = store.categoriesFor(_type);
    _categoryId = existing?.categoryId ??
        (cats.isNotEmpty ? cats.first.id : '');
    final accts = _availableAccounts;
    _accountId = existing?.accountId ??
        (accts.isNotEmpty ? accts.first.id : '');
    _toAccountId = existing?.toAccountId ??
        (accts.length > 1
            ? accts.firstWhere((a) => a.id != _accountId, orElse: () => accts.first).id
            : '');
  }

  List<Account> get _availableAccounts {
    final list = store.bookkeepingAccounts;
    return list.isEmpty ? store.accounts : list;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setType(TxnType type) {
    setState(() {
      _type = type;
      final cats = store.categoriesFor(type);
      if (cats.isNotEmpty && !cats.any((c) => c.id == _categoryId)) {
        _categoryId = cats.first.id;
      }
      if (type == TxnType.transfer && _toAccountId.isEmpty) {
        final list = _availableAccounts;
        if (list.isNotEmpty) {
          _toAccountId = list.firstWhere((a) => a.id != _accountId, orElse: () => list.first).id;
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = dateKey(picked));
    }
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }
    if (_type != TxnType.transfer && _categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }
    if (_accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择账户')),
      );
      return;
    }
    if (_type == TxnType.transfer && (_toAccountId.isEmpty || _toAccountId == _accountId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择不同的转入账户')),
      );
      return;
    }
    final now = TimeOfDay.now();
    final time = '${two(now.hour)}:${two(now.minute)}';
    final existing = widget.existing;
    final txn = Txn(
      id: existing?.id ?? store.newTxnId(),
      date: _date,
      time: existing?.time ?? time,
      type: _type,
      amount: amount,
      categoryId: _type == TxnType.transfer ? '' : _categoryId,
      accountId: _accountId,
      toAccountId: _type == TxnType.transfer ? _toAccountId : '',
      bookId: store.activeBookId,
      note: _noteController.text.trim(),
      subcategory: existing?.subcategory ?? '',
      tags: existing?.tags ?? const [],
      refund: existing?.refund ?? 0,
      discount: existing?.discount ?? 0,
      reimburseAmount: existing?.reimburseAmount ?? 0,
      reimburseAccountId: existing?.reimburseAccountId ?? '',
      createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    final messenger = ScaffoldMessenger.of(context);
    if (existing == null) {
      store.addTxn(txn);
    } else {
      store.updateTxn(txn);
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(existing == null ? '已保存' : '已更新')),
    );
  }

  void _delete() {
    final existing = widget.existing;
    if (existing == null) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这笔账单？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        store.deleteTxn(existing.id);
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cats = store.categoriesFor(_type);
    final accounts = _availableAccounts;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF10152B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    widget.existing == null ? (_type == TxnType.transfer ? '转账' : '记一笔') : '编辑账单',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (widget.existing != null)
                    IconButton(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SegmentedButton<TxnType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: TxnType.expense, label: Text('支出')),
                  ButtonSegment(value: TxnType.income, label: Text('收入')),
                  ButtonSegment(value: TxnType.transfer, label: Text('转账')),
                ],
                selected: {_type},
                onSelectionChanged: (set) => _setType(set.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                autofocus: widget.existing == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  prefixText: '¥ ',
                  hintText: '0.00',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 18),
              if (_type != TxnType.transfer) ...[
                const Text('分类', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cats.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    final selected = c.id == _categoryId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _categoryId = c.id),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? Color(c.color).withValues(alpha: 0.15)
                              : (dark ? const Color(0xFF141B34) : const Color(0xFFF7F8FF)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? Color(c.color) : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(c.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 3),
                            Text(c.name, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              Text(_type == TxnType.transfer ? '从账户' : '账户',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: accounts.map((a) {
                  final selected = a.id == _accountId;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => _accountId = a.id),
                    avatar: Text(a.icon),
                    label: Text(a.name),
                  );
                }).toList(),
              ),
              if (_type == TxnType.transfer) ...[
                const SizedBox(height: 14),
                const Text('到账户', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: accounts.where((a) => a.id != _accountId).map((a) {
                    final selected = a.id == _toAccountId;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) => setState(() => _toAccountId = a.id),
                      avatar: Text(a.icon),
                      label: Text(a.name),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text(fullDateTitle(_date)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '备注（可选）',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.existing == null ? '保存' : '更新'),
                ),
              ),
              if (cats.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('暂无分类，请先到我的页面管理分类。', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
