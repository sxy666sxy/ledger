import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/date_picker_sheet.dart';

Future<void> showEntrySheet(
  BuildContext context, {
  Txn? existing,
  String? initialDate,
  TxnType? initialType,
  String? initialAccountId,
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
      initialAccountId: initialAccountId,
    ),
  );
}

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    this.existing,
    this.initialDate,
    this.initialType,
    this.initialAccountId,
  });

  final Txn? existing;
  final String? initialDate;
  final TxnType? initialType;
  final String? initialAccountId;

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
  late String _txnId;
  late TextEditingController _noteController;
  final FocusNode _noteFocus = FocusNode();
  double _reimburseAmount = 0;
  String _reimburseAccountId = '';
  String _reimburseDetail = '';
  List<String> _attachments = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.initialType ?? TxnType.expense;
    _date = existing?.date ?? widget.initialDate ?? dateKey(DateTime.now());
    _txnId = existing?.id ?? store.newTxnId();
    _amountText = existing == null ? '' : _amountTextOf(existing.amount);
    _reimburseAmount = existing?.reimburseAmount ?? 0;
    _reimburseAccountId = existing?.reimburseAccountId ?? '';
    _reimburseDetail = existing?.reimburseDetail ?? '';
    _attachments = List<String>.from(existing?.attachments ?? const []);
    _noteController = TextEditingController(text: existing?.note ?? '');
    final cats = store.categoriesFor(_type);
    _categoryId = existing?.categoryId ?? (cats.isNotEmpty ? cats.first.id : '');
    final accts = _availableAccounts;
    final preferred = existing?.accountId ?? widget.initialAccountId;
    _accountId = preferred != null && accts.any((a) => a.id == preferred)
        ? preferred
        : (accts.isNotEmpty ? accts.first.id : '');
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
    _noteFocus.dispose();
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
    final picked = await showXkDatePicker(context, initialDate: _date);
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickAccount({required bool to}) async {
    final list = _availableAccounts
        .where((a) => to ? a.id != _accountId : true)
        .toList(growable: false);
    final allowNone = !to && _type != TxnType.transfer;
    if (list.isEmpty && !allowNone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先新增账户')),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => XkSheet(
        child: SafeArea(
          top: false,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(to ? '选择转入账户' : '选择账户',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (allowNone)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.block, size: 22),
                  title: const Text('不选择账户'),
                  subtitle: const Text('这笔账单不关联账户余额'),
                  trailing: _accountId.isEmpty
                      ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop('__none__'),
                ),
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
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (to) {
        _toAccountId = picked;
      } else {
        _accountId = picked == '__none__' ? '' : picked;
        if (_type == TxnType.transfer && _toAccountId == _accountId) {
          final other = _availableAccounts.where((a) => a.id != _accountId);
          _toAccountId = other.isEmpty ? '' : other.first.id;
        }
      }
    });
  }

  Future<void> _addCategory() async {
    final name = TextEditingController();
    final icon = TextEditingController(text: '🏷️');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => XkDialog(
        title: _type == TxnType.income ? '新增收入分类' : '新增支出分类',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: icon,
              textAlign: TextAlign.center,
              maxLength: 2,
              decoration: const InputDecoration(labelText: '图标', counterText: ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: '分类名称', hintText: '例如：咖啡'),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('添加')),
        ],
      ),
    );
    final label = name.text.trim();
    final iconText = icon.text.trim();
    name.dispose();
    icon.dispose();
    if (result != true || label.isEmpty || !mounted) return;
    final order = store.categories
            .where((c) => c.type == _type)
            .fold<int>(0, (a, c) => c.order > a ? c.order : a) +
        1;
    final category = Category(
      id: '',
      name: label,
      type: _type,
      icon: iconText.isEmpty ? '🏷️' : iconText,
      color: 0xFF5B6CFF,
      order: order,
    );
    store.addCategory(category);
    if (mounted) setState(() => _categoryId = category.id);
  }

  void _pressKey(String key) {
    if (_noteFocus.hasFocus) _noteFocus.unfocus();
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
      if (const ['+', '-', '×', '÷'].contains(key)) {
        final op = key == '×' ? '*' : (key == '÷' ? '/' : key);
        if (_amountText.isEmpty) return;
        if (const ['+', '-', '*', '/'].contains(_amountText[_amountText.length - 1])) {
          _amountText = '${_amountText.substring(0, _amountText.length - 1)}$op';
        } else {
          _amountText += op;
        }
        return;
      }
      if (key == '.') {
        final last = _lastNumber;
        if (last.contains('.')) return;
        _amountText = last.isEmpty ? '${_amountText}0.' : '$_amountText.';
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

  String get _lastNumber {
    final match = RegExp(r'(\d*\.?\d*)$').firstMatch(_amountText);
    return match?.group(1) ?? '';
  }

  void _appendDigit(String digit) {
    final number = _lastNumber;
    final dot = number.indexOf('.');
    if (dot >= 0 && number.length - dot - 1 >= 2) return;
    if (dot < 0 && number.length >= 9) return;
    if (number == '0') {
      if (digit == '0') return;
      _amountText = '${_amountText.substring(0, _amountText.length - 1)}$digit';
      return;
    }
    if (_amountText.length >= 18) return;
    _amountText += digit;
  }

  double? _evaluateAmount(String text) {
    if (text.isEmpty) return null;
    final tokens = RegExp(r'\d+\.?\d*|[+\-*/]')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
    if (tokens.isEmpty) return null;
    final values = <double>[];
    final ops = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (i.isEven) {
        final value = double.tryParse(token);
        if (value == null) return null;
        values.add(value);
      } else {
        if (!const ['+', '-', '*', '/'].contains(token)) return null;
        ops.add(token);
      }
    }
    if (values.length != ops.length + 1) return null;
    for (var i = 0; i < ops.length;) {
      if (ops[i] == '*' || ops[i] == '/') {
        final right = values[i + 1];
        if (ops[i] == '/' && right == 0) return null;
        values[i] = ops[i] == '*' ? values[i] * right : values[i] / right;
        values.removeAt(i + 1);
        ops.removeAt(i);
      } else {
        i++;
      }
    }
    var result = values.first;
    for (var i = 0; i < ops.length; i++) {
      result = ops[i] == '+' ? result + values[i + 1] : result - values[i + 1];
    }
    return result;
  }

  void _save() {
    final amount = _evaluateAmount(_amountText) ?? 0;
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
    if (_type == TxnType.transfer && _accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择转出账户')),
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
      id: _txnId,
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
      reimburseAmount: _reimburseAmount,
      reimburseAccountId: _reimburseAccountId,
      reimburseDetail: _reimburseDetail,
      attachments: _attachments,
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

  Future<void> _editReimbursement() async {
    final amount = TextEditingController(
      text: _reimburseAmount > 0 ? _amountTextOf(_reimburseAmount) : '',
    );
    final detail = TextEditingController(text: _reimburseDetail);
    var accountId = _reimburseAccountId;
    final accounts = _availableAccounts;
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => XkDialog(
          title: '报销信息',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '报销金额', prefixText: '¥ '),
              ),
              const SizedBox(height: 9),
              DropdownButtonFormField<String>(
                value: accountId.isEmpty || accounts.any((a) => a.id == accountId) ? accountId : null,
                decoration: const InputDecoration(labelText: '报销账户'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('不选择报销账户')),
                  ...accounts.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}')),
                  ),
                ],
                onChanged: (v) => setDialogState(() => accountId = v ?? ''),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: detail,
                decoration: const InputDecoration(labelText: '报销明细', hintText: '例如：公司差旅报销'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'amount': double.tryParse(amount.text.trim()) ?? 0.0,
                'account': accountId,
                'detail': detail.text.trim(),
              }),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    detail.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _reimburseAmount = (result['amount'] as double?) ?? 0;
      _reimburseAccountId = (result['account'] as String?) ?? '';
      _reimburseDetail = (result['detail'] as String?) ?? '';
    });
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;

  Future<void> _addAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/attachments/$_txnId');
      await dir.create(recursive: true);
      final added = <String>[];
      for (final picked in result.files) {
        final path = picked.path;
        if (path == null || path.isEmpty) continue;
        final source = File(path);
        if (!await source.exists()) continue;
        final name = '${DateTime.now().microsecondsSinceEpoch}_${_fileName(path)}';
        final target = await source.copy('${dir.path}/$name');
        added.add(target.path);
      }
      if (added.isEmpty) return;
      if (mounted) {
        setState(() => _attachments = [..._attachments, ...added]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${added.length} 个附件')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('附件添加失败：$e')),
      );
    }
  }

  Future<void> _showAttachments() async {
    if (_attachments.isEmpty) {
      await _addAttachments();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => XkSheet(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('附件', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _addAttachments();
                      },
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('添加'),
                    ),
                  ],
                ),
                if (_attachments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('暂无附件')),
                  ),
                ...List.generate(_attachments.length, (i) {
                  final path = _attachments[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file, size: 20),
                    title: Text(_fileName(path), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: '移除',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setSheetState(() => _attachments.removeAt(i));
                        setState(() {});
                      },
                    ),
                  );
                }),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _delete() {
    final existing = widget.existing;
    if (existing == null) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => XkDialog(
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
    if (_accountId.isEmpty) return '不选择账户';
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

    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final typing = keyboard > 0;
    final desiredHeight = media.size.height * 0.94;
    final availableHeight = media.size.height - media.padding.top - keyboard - 6;
    final sheetHeight = keyboard > 0
        ? availableHeight.clamp(360.0, desiredHeight).toDouble()
        : desiredHeight;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboard),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: sheetHeight,
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
                    itemCount: cats.length + 1,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 0.92,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, i) {
                      if (i == cats.length) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _addCategory,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: theme.colorScheme.primary,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '新增',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
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
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 4),
            decoration: BoxDecoration(
              color: panel,
              border: Border(top: BorderSide(color: theme.dividerTheme.color ?? Colors.black12)),
            ),
            child: Column(
              children: [
                Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _noteController,
                    focusNode: _noteFocus,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _noteFocus.unfocus(),
                    onTapOutside: (_) => _noteFocus.unfocus(),
                    style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      hintText: '添加备注',
                      prefixIcon: Icon(Icons.edit_note, size: 16, color: theme.colorScheme.primary),
                      prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      contentPadding: const EdgeInsets.fromLTRB(0, 9, 9, 9),
                      hintStyle: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide(color: theme.dividerTheme.color ?? Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '¥',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: 6,
                  child: Text(
                    amount,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                  ),
                ),
              ],
                ),
                _bottomMetaRow(),
              ],
            ),
          ),
          if (typing)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _noteFocus.unfocus,
                      icon: const Icon(Icons.keyboard_hide, size: 16),
                      label: const Text('完成'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(existing == null ? '保存' : '更新'),
                    ),
                  ),
                ],
              ),
            )
          else
            _Keypad(
              onKey: _pressKey,
              onSave: _save,
              onCancel: () => Navigator.of(context).pop(),
              saveLabel: existing == null ? '保存' : '更新',
            ),
        ],
        ),
      ),
    );
  }

  Widget _bottomMetaRow() {
    if (_type == TxnType.transfer) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _metaChip(
                    icon: Icons.call_made,
                    label: '从 $_accountName',
                    onTap: () => _pickAccount(to: false),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _metaChip(
                    icon: Icons.call_received,
                    label: '到 $_toAccountName',
                    onTap: () => _pickAccount(to: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _metaChip(
                    icon: Icons.calendar_today_outlined,
                    label: _dateLabel,
                    onTap: _pickDate,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: _metaChip(
              icon: Icons.calendar_today_outlined,
              label: _dateLabel,
              onTap: _pickDate,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _metaChip(
              icon: Icons.account_balance_wallet_outlined,
              label: _accountName,
              onTap: () => _pickAccount(to: false),
            ),
          ),
          const SizedBox(width: 5),
          _metaAction(
            icon: Icons.receipt_long_outlined,
            label: _reimburseAmount > 0 ? '已报销' : '报销',
            active: _reimburseAmount > 0,
            onTap: _editReimbursement,
          ),
          const SizedBox(width: 4),
          _metaAction(
            icon: Icons.attach_file,
            label: _attachments.isEmpty ? '附件' : '${_attachments.length}',
            active: _attachments.isNotEmpty,
            onTap: _showAttachments,
          ),
        ],
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaAction({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.13)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: active ? theme.colorScheme.primary : null),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 7.5,
                height: 1.1,
                color: active ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onKey,
    required this.onSave,
    required this.onCancel,
    required this.saveLabel,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final keys = <List<String>>[
      ['1', '2', '3', '⌫'],
      ['4', '5', '6', 'C'],
      ['7', '8', '9', '÷'],
      ['00', '0', '.', '×'],
    ];
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final keyHeight = (MediaQuery.sizeOf(context).height * 0.057).clamp(44.0, 50.0).toDouble();
    return Container(
      padding: EdgeInsets.fromLTRB(10, 4, 10, bottom + 16),
      child: Column(
        children: [
          for (final row in keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Expanded(
                      child: _KeyButton(
                        label: row[i],
                        height: keyHeight,
                        onTap: () => onKey(row[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Row(
            children: [
              Expanded(child: _KeyButton(label: '+', height: keyHeight, onTap: () => onKey('+'))),
              const SizedBox(width: 5),
              Expanded(child: _KeyButton(label: '-', height: keyHeight, onTap: () => onKey('-'))),
              const SizedBox(width: 5),
              Expanded(
                child: SizedBox(
                  height: keyHeight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    onPressed: onCancel,
                    child: const Text('取消'),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: SizedBox(
                  height: keyHeight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
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
  const _KeyButton({required this.label, required this.height, required this.onTap});

  final String label;
  final double height;
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
          height: height,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
