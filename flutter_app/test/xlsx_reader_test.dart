import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xingkong_ledger/xlsx_reader.dart';

void main() {
  test('读取标准 XLSX 表头和数据', () {
    final excel = Excel.createExcel();
    final sheet = excel['账单'];
    sheet.appendRow([
      TextCellValue('日期'),
      TextCellValue('收支类型'),
      TextCellValue('金额'),
      TextCellValue('类别'),
    ]);
    sheet.appendRow([
      TextCellValue('2026-10-26'),
      TextCellValue('支出'),
      DoubleCellValue(12.5),
      TextCellValue('餐饮'),
    ]);
    try { excel.delete('Sheet1'); } catch (_) {}
    final bytes = excel.encode();
    expect(bytes, isNotNull);
    final rows = readXlsxRows(Uint8List.fromList(bytes!));
    expect(rows.length, greaterThanOrEqualTo(2));
    expect(rows[0][0], '日期');
    expect(rows[1][0], '2026-10-26');
    expect(rows[1][1], '支出');
    expect(rows[1][2], '12.5');
  });
}
