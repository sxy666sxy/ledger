import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'models.dart';
import 'store.dart';
import 'utils.dart';
import 'xlsx_reader.dart';

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
    final toAccount = accountMap[t.toAccountId];
    final typeLabel = t.type == TxnType.expense
        ? '支出'
        : t.type == TxnType.income
            ? '收入'
            : '转账';
    final accountLabel = t.type == TxnType.transfer
        ? '${account?.name ?? '?'} → ${toAccount?.name ?? '?'}'
        : (account?.name ?? '');
    final attachments = List<String>.from(t.attachments);
    while (attachments.length < 5) {
      attachments.add('');
    }
    final multiCurrency = t.currency.isEmpty
        ? ''
        : '${t.currency} ${t.foreignAmount.toStringAsFixed(2)}';
    sheet.appendRow([
      TextCellValue(t.date),
      TextCellValue(typeLabel),
      DoubleCellValue(t.amount),
      TextCellValue(cat?.name ?? ''),
      TextCellValue(t.subcategory),
      TextCellValue(accountLabel),
      TextCellValue(book?.name ?? ''),
      DoubleCellValue(t.refund),
      DoubleCellValue(t.discount),
      TextCellValue(t.note),
      TextCellValue(t.tags.join(',')),
      TextCellValue(reimburseAccount?.name ?? ''),
      DoubleCellValue(t.reimburseAmount),
      TextCellValue(t.reimburseDetail),
      TextCellValue(multiCurrency),
      TextCellValue(t.address),
      TextCellValue(t.createdBy),
      TextCellValue(t.other),
      TextCellValue(attachments[0]),
      TextCellValue(attachments[1]),
      TextCellValue(attachments[2]),
      TextCellValue(attachments[3]),
      TextCellValue(attachments[4]),
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

double _num(String value) {
  final cleaned = value.replaceAll(RegExp(r'[¥,\s]'), '');
  return double.tryParse(cleaned) ?? 0;
}

String _timeFromCell(String value) {
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (m == null) return '12:00';
  final h = int.tryParse(m.group(1)!) ?? 12;
  final min = int.tryParse(m.group(2)!) ?? 0;
  return '${two(h)}:${two(min)}';
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
  final rows = readXlsxRows(Uint8List.fromList(bytes));
  if (rows.isEmpty) return const ExcelImportResult(imported: 0, skipped: 0);

  final header = <String, int>{};
  final firstRow = rows.first;
  for (var i = 0; i < firstRow.length; i++) {
    final name = firstRow[i].replaceAll('\ufeff', '').trim();
    if (name.isNotEmpty) header[name] = i;
  }
  String cell(List<String> row, String name) {
    final i = header[name];
    if (i == null || i >= row.length) return '';
    return row[i].trim();
  }

  final imported = <Txn>[];
  var skipped = 0;
  final categoryMap = {for (final c in store.categories) '${c.type.name}:${c.name}': c};
  final accountMap = {for (final a in store.accounts) a.name: a};
  final bookMap = {for (final b in store.books) b.name: b};
  final seq = DateTime.now().microsecondsSinceEpoch;

  for (var r = 1; r < rows.length; r++) {
    final row = rows[r];
    final dateCell = cell(row, '日期');
    final date = _normalizeDate(dateCell);
    final time = _timeFromCell(dateCell);
    final typeText = cell(row, '收支类型');
    final rawAmount = _num(cell(row, '金额'));
    if (date == null || rawAmount == 0) {
      skipped++;
      continue;
    }
    final TxnType type;
    if (typeText == '收入' || typeText.toLowerCase() == 'income') {
      type = TxnType.income;
    } else if (typeText == '支出' || typeText.toLowerCase() == 'expense') {
      type = TxnType.expense;
    } else if (typeText == '转账' || typeText.toLowerCase() == 'transfer') {
      type = TxnType.transfer;
    } else {
      skipped++;
      continue;
    }
    // Old WebView exports expenses as negative numbers; Flutter exports positive.
    final amount = rawAmount.abs();
    Category? category;
    if (type != TxnType.transfer) {
      final categoryName = cell(row, '类别').isEmpty ? '未分类' : cell(row, '类别');
      final categoryKey = '${type.name}:$categoryName';
      category = categoryMap[categoryKey];
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
    }
    final accountCell = cell(row, '账户');
    final arrowIndex = accountCell.indexOf('→');
    final fromName = (arrowIndex >= 0 ? accountCell.substring(0, arrowIndex) : accountCell).trim();
    final toName = arrowIndex >= 0 ? accountCell.substring(arrowIndex + 1).trim() : '';
    Account? ensureAccount(String name, int suffix) {
      if (name.isEmpty) return null;
      var a = accountMap[name];
      if (a == null) {
        a = Account(
          id: 'a_import_${seq}_${r}_$suffix',
          name: name,
          type: 'other',
          icon: '💳',
          color: 0xFF5B6CFF,
          order: store.accounts.length,
        );
        store.accounts.add(a);
        accountMap[name] = a;
      }
      return a;
    }
    final account = ensureAccount(fromName.isEmpty ? '导入账户' : fromName, 1);
    if (account == null) {
      skipped++;
      continue;
    }
    final toAccount = type == TxnType.transfer ? ensureAccount(toName, 2) : null;
    if (type == TxnType.transfer && toAccount == null) {
      skipped++;
      continue;
    }
    final bookName = cell(row, '账本');
    final book = bookMap[bookName] ?? store.activeBook;
    final reimburseName = cell(row, '报销账户');
    final reimburse = reimburseName.isEmpty ? null : accountMap[reimburseName];
    final tags = cell(row, '标签').split(RegExp(r'[,，;；\s]+')).where((e) => e.isNotEmpty).toList();
    final multi = cell(row, '多币种');
    final multiParts = multi.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final currency = multiParts.isEmpty ? '' : multiParts.first;
    final foreignAmount = multiParts.length > 1 ? _num(multiParts[1]) : 0.0;
    final attachments = <String>[];
    for (var i = 1; i <= 5; i++) {
      final a = cell(row, '附件$i');
      if (a.isNotEmpty) attachments.add(a);
    }
    imported.add(Txn(
      id: 't_import_${seq}_$r',
      date: date,
      time: time,
      type: type,
      amount: amount,
      categoryId: category?.id ?? '',
      subcategory: cell(row, '二级分类'),
      accountId: account.id,
      toAccountId: toAccount?.id ?? '',
      bookId: book.id,
      note: cell(row, '备注'),
      tags: tags,
      refund: _num(cell(row, '退款')),
      discount: _num(cell(row, '优惠')),
      reimburseAmount: _num(cell(row, '报销金额')),
      reimburseAccountId: reimburse?.id ?? '',
      reimburseDetail: cell(row, '报销明细'),
      currency: currency,
      foreignAmount: foreignAmount,
      address: cell(row, '地址'),
      createdBy: cell(row, '创建用户'),
      other: cell(row, '其他'),
      attachments: attachments,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }
  final inserted = imported.isEmpty ? 0 : store.importTransactions(imported);
  return ExcelImportResult(
    imported: inserted,
    skipped: skipped + (imported.length - inserted),
  );
}
