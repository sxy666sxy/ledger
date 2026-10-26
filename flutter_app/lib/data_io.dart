import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'models.dart';
import 'store.dart';
import 'utils.dart';

const List<String> excelHeaders = [
  '日期',
  '收支类型',
  '金额',
  '类别',
  '二级分类',
  '账户',
  '账本',
  '退款',
  '优惠',
  '备注',
  '标签',
  '报销账户',
  '报销金额',
  '报销明细',
  '多币种',
  '地址',
  '创建用户',
  '其他',
  '附件1',
  '附件2',
  '附件3',
  '附件4',
  '附件5',
];

Future<Uint8List> buildExcelBytes(AppStore store) async {
  final excel = Excel.createExcel();
  final sheet = excel['账单'];
  sheet.appendRow(excelHeaders.map((h) => TextCellValue(h)).toList());

  final categoryMap = {for (final c in store.categories) c.id: c};
  final accountMap = {for (final a in store.accounts) a.id: a};
  final bookMap = {for (final b in store.books) b.id: b};

  for (final t in store.transactions.where((t) => t.bookId == store.activeBookId)) {
    final cat = categoryMap[t.categoryId];
    final account = accountMap[t.accountId];
    final book = bookMap[t.bookId];
    final reimburseAccount = accountMap[t.reimburseAccountId];
    sheet.appendRow([
      TextCellValue(t.date),
      TextCellValue(t.type == TxnType.expense ? '支出' : '收入'),
      DoubleCellValue(t.amount),
      TextCellValue(cat?.name ?? ''),
      TextCellValue(t.subcategory),
      TextCellValue(account?.name ?? ''),
      TextCellValue(book?.name ?? ''),
      DoubleCellValue(t.refund),
      DoubleCellValue(t.discount),
      TextCellValue(t.note),
      TextCellValue(t.tags.join(',')),
      TextCellValue(reimburseAccount?.name ?? ''),
      DoubleCellValue(t.reimburseAmount),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
  }
  try {
    excel.delete('Sheet1');
  } catch (_) {}
  final bytes = excel.encode();
  return Uint8List.fromList(bytes ?? <int>[]);
}

class ExcelImportResult {
  const ExcelImportResult({required this.imported, required this.skipped});
  final int imported;
  final int skipped;
}

String _cellText(Data? data) {
  final v = data?.value;
  if (v == null) return '';
  if (v is TextCellValue) return (v.value.text ?? '').trim();
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) {
    final d = v.value;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }
  if (v is DateCellValue) return '${v.year}-${two(v.month)}-${two(v.day)}';
  if (v is BoolCellValue) return v.value.toString();
  return v.toString().trim();
}

double _num(String value) {
  final cleaned = value.replaceAll(RegExp(r'[¥,\s]'), '');
  return double.tryParse(cleaned) ?? 0;
}

String? _normalizeDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) return dateKey(iso);
  final m = RegExp(r'(\d{4})[年/\-.](\d{1,2})[月/\-.](\d{1,2})').firstMatch(text);
  if (m != null) {
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y != null && mo != null && d != null) {
      return dateKey(DateTime(y, mo, d));
    }
  }
  return null;
}

ExcelImportResult importExcelBytes(AppStore store, List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return const ExcelImportResult(imported: 0, skipped: 0);
  final sheet = excel.tables.values.first;
  final rows = sheet.rows;
  if (rows.isEmpty) return const ExcelImportResult(imported: 0, skipped: 0);

  final header = <String, int>{};
  final firstRow = rows.first;
  for (var i = 0; i < firstRow.length; i++) {
    final name = _cellText(firstRow[i]).replaceAll('\ufeff', '').trim();
    if (name.isNotEmpty) header[name] = i;
  }
  String cell(List<Data?> row, String name) {
    final i = header[name];
    if (i == null || i >= row.length) return '';
    return _cellText(row[i]);
  }

  final imported = <Txn>[];
  var skipped = 0;
  final categoryMap = {for (final c in store.categories) '${c.type.name}:${c.name}': c};
  final accountMap = {for (final a in store.accounts) a.name: a};
  final bookMap = {for (final b in store.books) b.name: b};
  final seq = DateTime.now().microsecondsSinceEpoch;

  for (var r = 1; r < rows.length; r++) {
    final row = rows[r];
    final date = _normalizeDate(cell(row, '日期'));
    final typeText = cell(row, '收支类型');
    final amount = _num(cell(row, '金额'));
    if (date == null || amount <= 0) {
      skipped++;
      continue;
    }
    final TxnType type;
    if (typeText == '收入' || typeText.toLowerCase() == 'income') {
      type = TxnType.income;
    } else if (typeText == '支出' || typeText.toLowerCase() == 'expense') {
      type = TxnType.expense;
    } else {
      skipped++;
      continue;
    }
    final categoryName = cell(row, '类别').isEmpty ? '未分类' : cell(row, '类别');
    final categoryKey = '${type.name}:$categoryName';
    var category = categoryMap[categoryKey];
    if (category == null) {
      category = Category(
        id: 'c_import_${seq}_$r',
        name: categoryName,
        type: type,
        icon: '🏷️',
        color: 0xFF94A3B8,
        order: store.categories.where((c) => c.type == type).length,
      );
      store.categories.add(category);
      categoryMap[categoryKey] = category;
    }
    final accountName = cell(row, '账户').isEmpty ? '导入账户' : cell(row, '账户');
    var account = accountMap[accountName];
    if (account == null) {
      account = Account(
        id: 'a_import_${seq}_$r',
        name: accountName,
        type: 'other',
        icon: '💳',
        color: 0xFF5B6CFF,
        order: store.accounts.length,
      );
      store.accounts.add(account);
      accountMap[accountName] = account;
    }
    final bookName = cell(row, '账本');
    final book = bookMap[bookName] ?? store.activeBook;
    final reimburseName = cell(row, '报销账户');
    final reimburse = reimburseName.isEmpty ? null : accountMap[reimburseName];
    final tags = cell(row, '标签').split(RegExp(r'[,，;；\s]+')).where((e) => e.isNotEmpty).toList();
    imported.add(Txn(
      id: 't_import_${seq}_$r',
      date: date,
      time: '12:00',
      type: type,
      amount: amount,
      categoryId: category.id,
      subcategory: cell(row, '二级分类'),
      accountId: account.id,
      bookId: book.id,
      note: cell(row, '备注'),
      tags: tags,
      refund: _num(cell(row, '退款')),
      discount: _num(cell(row, '优惠')),
      reimburseAmount: _num(cell(row, '报销金额')),
      reimburseAccountId: reimburse?.id ?? '',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }
  if (imported.isNotEmpty) store.importTransactions(imported);
  return ExcelImportResult(imported: imported.length, skipped: skipped);
}
