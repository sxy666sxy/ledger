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
  late String _amountText;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.initialType ?? TxnType.expense;
    _date = existing?.date ?? widget.initialDate ?? dateKey(DateTime.now());
    _amountText = existing == null ? '' : _amountTextOf(existing.amount);
    _noteController = TextEditingController(text: existing?.note ?? '');
    final cats = store.categoriesFor(_type);
    _categoryId = existing?.categoryId ?? (cats.isNotEmpty ? cats.first.id : '');
    final accts = _availableAccounts;
    _accountId = existing?.accountId ?? (accts.isNotEmpty ? accts.first.id : '');
    _toAccountId = existing?.toAccountId ??
        (accts.length > 1
            ? accts.firstWhere((a) => a.id != _accountId, orElse: () => accts.first).id
            : '');
  }

  String _amountTextOf(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  List<Account> get _availableAccounts {
    final list = store.bookkeepingAccounts;
    return list.isEmpty ? store.accounts : list;
  }

  @override
  void dispose() {
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
    if (picked != null && mounted) {
      setState(() => _date = dateKey(picked));
    }
  }

  Future<void> _pickAccount({required bool to}) async {
    final list = _availableAccounts
        .where((a) => to ? a.id != _accountId : true)
        .toList(growable: false);
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先新增账户')),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(to ? '选择转入账户' : '选择账户',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...list.map((a) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Text(a.icon, style: const TextStyle(fontSize: 22)),
                    title: Text(a.name),
                    trailing: (to ? _toAccountId : _accountId) == a.id
                        ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(a.id),
                  )),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (to) {
        _toAccountId = picked;
      } else {
        _accountId = picked;
        if (_type == TxnType.transfer && _toAccountId == _accountId) {
          final other = _availableAccounts.where((a) => a.id != _accountId);
          _toAccountId = other.isEmpty ? '' : other.first.id;
        }
      }
    });
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _noteController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: '写点什么…'),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('确定')),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _noteController.text = result.trim());
    }
    controller.dispose();
  }

  void _pressKey(String key) {
    setState(() {
      if (key == 'C') {
        _amountText = '';
        return;
      }
      if (key == '⌫') {
        if (_amountText.isNotEmpty) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
        }
        return;
      }
      if (key == '.') {
        if (_amountText.contains('.')) return;
        _amountText = _amountText.isEmpty ? '0.' : '$_amountText.';
        return;
      }
      if (key == '00') {
        _appendDigit('0');
        _appendDigit('0');
        return;
      }
      _appendDigit(key);
    });
  }

  void _appendDigit(String digit) {
    final dot = _amountText.indexOf('.');
    if (dot >= 0 && _amountText.length - dot - 1 >= 2) return;
    if (dot < 0 && _amountText.length >= 9) return;
    if (_amountText == '0') {
      if (digit == '0') return;
      _amountText = digit;
      return;
    }
    _amountText += digit;
  }

  void _save() {
    final amount = double.tryParse(_amountText) ?? 0;
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

  String get _dateLabel {
    final now = DateTime.now();
    if (_date == dateKey(now)) return '今天';
    final d = DateTime.tryParse(_date);
    if (d == null) return _date;
    return '${d.month}月${d.day}日';
  }

  String get _accountName {
    for (final a in _availableAccounts) {
      if (a.id == _accountId) return a.name;
    }
    return '账户';
  }

  String get _toAccountName {
    for (final a in _availableAccounts) {
      if (a.id == _toAccountId) return a.name;
    }
    return '转入账户';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panel = theme.colorScheme.surface;
    final cats = store.categoriesFor(_type);
    final amount = _amountText.isEmpty ? '0.00' : _amountText;
    final existing = widget.existing;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 8, 0),
            child: Row(
              children: [
                Text(
                  existing == null ? '记一笔' : '编辑账单',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (existing != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '删除',
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<TxnType>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: TxnType.expense, label: Text('支出')),
                  ButtonSegment(value: TxnType.income, label: Text('收入')),
                  ButtonSegment(value: TxnType.transfer, label: Text('转账')),
                ],
                selected: {_type},
                onSelectionChanged: (set) => _setType(set.first),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              children: [
                if (_type != TxnType.transfer) ...[
                  Row(
                    children: [
                      const Text('分类', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        cats.where((c) => c.id == _categoryId).map((c) => c.name).join(),
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.48)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cats.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 0.92,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, i) {
                      final c = cats[i];
                      final selected = c.id == _categoryId;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _categoryId = c.id),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? Color(c.color).withValues(alpha: 0.20)
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                border: selected ? Border.all(color: Color(c.color), width: 1.4) : null,
                              ),
                              child: Text(c.icon, style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? Color(c.color) : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _selectorRow([
                    _SelectorItem(icon: Icons.calendar_today_outlined, label: _dateLabel, onTap: _pickDate),
                    _SelectorItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: _accountName,
                      onTap: () => _pickAccount(to: false),
                    ),
                    _SelectorItem(
                      icon: Icons.edit_note,
                      label: _noteController.text.trim().isEmpty ? '备注' : _noteController.text.trim(),
                      onTap: _editNote,
                    ),
                  ]),
                ] else ...[
                  _accountPickerTile('从账户', _accountName, () => _pickAccount(to: false)),
                  const SizedBox(height: 8),
                  _accountPickerTile('到账户', _toAccountName, () => _pickAccount(to: true)),
                  const SizedBox(height: 8),
                  _selectorRow([
                    _SelectorItem(icon: Icons.calendar_today_outlined, label: _dateLabel, onTap: _pickDate),
                    _SelectorItem(
                      icon: Icons.edit_note,
                      label: _noteController.text.trim().isEmpty ? '备注' : _noteController.text.trim(),
                      onTap: _editNote,
                    ),
                  ]),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            decoration: BoxDecoration(
              color: panel,
              border: Border(top: BorderSide(color: theme.dividerTheme.color ?? Colors.black12)),
            ),
            child: Row(
              children: [
                Text(
                  '¥',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    amount,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                  ),
                ),
              ],
            ),
          ),
          _Keypad(
            onKey: _pressKey,
            onSave: _save,
            saveLabel: existing == null ? '保存' : '更新',
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _accountPickerTile(String label, String value, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _selectorRow(List<_SelectorItem> items) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: items[i].onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(items[i].icon, size: 15),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectorItem {
  const _SelectorItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, required this.onSave, required this.saveLabel});

  final ValueChanged<String> onKey;
  final VoidCallback onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final keys = <List<String>>[
      ['1', '2', '3', '⌫'],
      ['4', '5', '6', 'C'],
      ['7', '8', '9', '.'],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        children: [
          for (final row in keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _KeyButton(
                        label: row[i],
                        onTap: () => onKey(row[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _KeyButton(label: '00', onTap: () => onKey('00')),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _KeyButton(label: '0', onTap: () => onKey('0')),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 43,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    onPressed: onSave,
                    child: Text(saveLabel),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          height: 43,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
