import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xingkong_ledger/models.dart';
import 'package:xingkong_ledger/utils.dart';

void main() {
  test('交易 JSON 往返', () {
    final txn = Txn(
      id: 't1',
      date: '2026-10-26',
      time: '09:30',
      type: TxnType.expense,
      amount: 12.5,
      categoryId: 'c_food',
      accountId: 'a_cash',
      bookId: 'b_main',
      note: '午饭',
      tags: const ['工作日'],
    );
    final decoded = Txn.fromJson(jsonDecode(jsonEncode(txn.toJson())) as Map<String, dynamic>);
    expect(decoded.id, 't1');
    expect(decoded.type, TxnType.expense);
    expect(decoded.amount, 12.5);
    expect(decoded.tags, ['工作日']);
  });

  test('金额与月份工具', () {
    expect(formatMoney(12.5), '¥12.50');
    expect(formatMoney(-3), '-¥3.00');
    expect(monthKey(DateTime(2026, 9, 1)), '2026-09');
    expect(daysInMonth(DateTime(2026, 2, 1)), 28);
    expect(monthTitle(DateTime(2026, 9, 1)), '2026年9月');
  });
}
