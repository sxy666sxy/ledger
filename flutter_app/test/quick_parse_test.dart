import 'package:flutter_test/flutter_test.dart';
import 'package:xingkong_ledger/models.dart';
import 'package:xingkong_ledger/quick_parse.dart';
import 'package:xingkong_ledger/utils.dart';

void main() {
  final categories = [
    Category(id: 'c_food', name: '食品餐饮', type: TxnType.expense),
    Category(id: 'c_traffic', name: '出行交通', type: TxnType.expense),
    Category(id: 'c_other', name: '其他', type: TxnType.expense),
    Category(id: 'c_salary', name: '工资', type: TxnType.income),
    Category(id: 'c_other_income', name: '其他收入', type: TxnType.income),
  ];
  final accounts = [
    Account(id: 'a_cash', name: '现金'),
    Account(id: 'a_alipay', name: '支付宝'),
    Account(id: 'a_wechat', name: '微信'),
    Account(id: 'a_bank', name: '银行卡'),
  ];

  QuickParseResult parse(String text, {DateTime? now}) => parseQuickEntry(
        text,
        categories: categories,
        accounts: accounts,
        now: now,
      );

  test('parses Chinese amount and food category', () {
    final r = parse('早餐十二块 支付宝');
    expect(r.amount, 12);
    expect(r.type, TxnType.expense);
    expect(r.categoryId, 'c_food');
    expect(r.accountId, 'a_alipay');
    expect(r.note, contains('早餐'));
  });

  test('parses income salary and bank account', () {
    final r = parse('工资到账 8000元 银行卡');
    expect(r.amount, 8000);
    expect(r.type, TxnType.income);
    expect(r.categoryId, 'c_salary');
    expect(r.accountId, 'a_bank');
  });

  test('parses transfer between two accounts', () {
    final r = parse('支付宝转到微信15元');
    expect(r.amount, 15);
    expect(r.type, TxnType.transfer);
    expect(r.accountId, 'a_alipay');
    expect(r.toAccountId, 'a_wechat');
  });

  test('uses yesterday when the sentence says so', () {
    final now = DateTime(2026, 10, 27);
    final r = parse('昨天打车20元', now: now);
    expect(r.date, dateKey(DateTime(2026, 10, 26)));
    expect(r.categoryId, 'c_traffic');
  });

  test('returns zero amount when there is no number', () {
    final r = parse('奶茶');
    expect(r.amount, 0);
    expect(r.valid, isFalse);
    expect(r.categoryId, 'c_food');
  });
}
