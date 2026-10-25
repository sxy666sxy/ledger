import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const C = require('../assets/core.js');

function fixture() {
  const data = C.createDefaultData();
  data.transactions = [
    { id: 't1', bookId: 'b_main', type: 'expense', amount: 58.5, categoryId: 'c_food', accountId: 'a_alipay', date: '2026-10-01', time: '12:00', note: '午饭', tags: ['日常'] },
    { id: 't2', bookId: 'b_main', type: 'expense', amount: 1800, categoryId: 'c_home', accountId: 'a_bank', date: '2026-10-05', time: '09:00', note: '', tags: [] },
    { id: 't3', bookId: 'b_main', type: 'income', amount: 12000, categoryId: 'c_salary', accountId: 'a_bank', date: '2026-10-10', time: '08:00', note: '工资', tags: [] },
    { id: 't4', bookId: 'b_main', type: 'transfer', amount: 500, categoryId: null, accountId: 'a_bank', toAccountId: 'a_wechat', date: '2026-10-12', time: '10:00', note: '转到微信', tags: [] },
    { id: 't5', bookId: 'b_main', type: 'expense', amount: 12.5, categoryId: 'c_food', accountId: 'a_wechat', date: '2026-10-12', time: '18:30', note: '奶茶', tags: ['日常'] }
  ];
  return data;
}

test('parseAmountExpr 支持加减算式并规避浮点误差', () => {
  assert.equal(C.parseAmountExpr('12+3.5'), 15.5);
  assert.equal(C.parseAmountExpr('0.1+0.2'), 0.3);
  assert.equal(C.parseAmountExpr('10-2.25-1'), 6.75);
  assert.equal(C.parseAmountExpr('-5+2'), -3);
  assert.equal(C.parseAmountExpr('12+'), NaN);
  assert.equal(C.parseAmountExpr(''), NaN);
  assert.equal(C.parseAmountExpr('abc'), NaN);
  assert.equal(C.parseAmountExpr(8.888), 8.89);
});

test('日期工具跨年、闰月与格式化', () => {
  assert.equal(C.addMonthsKey('2026-01', -1), '2025-12');
  assert.equal(C.addMonthsKey('2026-12', 1), '2027-01');
  assert.equal(C.daysInMonth(2024, 2), 29);
  assert.equal(C.daysInMonth(2026, 2), 28);
  assert.equal(C.monthDays('2026-02').length, 28);
  assert.equal(C.monthLabel('2026-10'), '2026年10月');
  assert.equal(C.dateLabel('2026-10-05'), '10月5日');
  assert.equal(C.monthKeyOf('2026-10-25'), '2026-10');
  assert.equal(C.relativeDay(C.todayISO()), '今天');
});

test('金额格式化', () => {
  assert.equal(C.money(1234567.891), '1,234,567.89');
  assert.equal(C.money(-1234.5), '-1,234.50');
  assert.equal(C.money(0), '0.00');
  assert.deepEqual(C.amountParts(3280.5), { sign: '', int: '3,280', dec: '50' });
  assert.equal(C.amountParts(-0.5).sign, '-');
});

test('月度合计与分类占比（转账不计入收支）', () => {
  const data = fixture();
  const t = C.monthTotals(data, 'b_main', '2026-10');
  assert.equal(t.expense, 1871);
  assert.equal(t.income, 12000);
  assert.equal(t.balance, 10129);
  assert.equal(t.transfer, 500);
  assert.equal(t.count, 5);

  const food = C.categoryBreakdown(data, 'b_main', '2026-10', 'expense');
  assert.equal(food.length, 2);
  assert.equal(food[0].id, 'c_home');
  assert.equal(food[0].value, 1800);
  assert.ok(Math.abs(food[0].pct - 1800 / 1871) < 1e-9);
  assert.equal(food[1].count, 2);
});

test('账户余额与转账', () => {
  const data = fixture();
  const bal = C.accountBalances(data);
  const initial = {};
  data.accounts.forEach((a) => { initial[a.id] = a.initial; });
  assert.equal(bal.a_alipay, initial.a_alipay - 58.5);
  assert.equal(bal.a_bank, initial.a_bank - 1800 + 12000 - 500);
  assert.equal(bal.a_wechat, initial.a_wechat + 500 - 12.5);

  data.accounts.find((a) => a.id === 'a_credit').initial = 0;
  data.transactions.push({ id: 't6', bookId: 'b_main', type: 'expense', amount: 300, categoryId: 'c_shopping', accountId: 'a_credit', date: '2026-10-20', time: '12:00', note: '', tags: [] });
  const assets = C.totalAssets(data);
  assert.equal(assets.debts, -300);
  assert.equal(assets.net, assets.assets - 300);
});

test('预算状态与分类预算', () => {
  const data = fixture();
  data.books[0].budget = { total: 5000, categories: { c_food: 100, c_home: 2000 } };
  const b = C.budgetStatus(data, 'b_main', '2026-10');
  assert.equal(b.total, 5000);
  assert.equal(b.spent, 1871);
  assert.equal(b.remain, 3129);
  assert.ok(Math.abs(b.percent - 0.3742) < 1e-4);
  const food = b.categories.find((c) => c.id === 'c_food');
  assert.equal(food.spent, 71);
  assert.equal(food.remain, 29);
  assert.equal(food.percent, 0.71);
  assert.equal(b.categories.length, 2);
});

test('近六个月趋势', () => {
  const data = fixture();
  data.transactions.push({ id: 't7', bookId: 'b_main', type: 'expense', amount: 100, categoryId: 'c_food', accountId: 'a_cash', date: '2026-09-03', time: '12:00', note: '', tags: [] });
  const trend = C.trendMonths(data, 'b_main', '2026-10', 6);
  assert.equal(trend.length, 6);
  assert.equal(trend[5].key, '2026-10');
  assert.equal(trend[5].expense, 1871);
  assert.equal(trend[4].expense, 100);
  assert.equal(trend[0].key, '2026-05');
});

test('筛选与搜索', () => {
  const data = fixture();
  assert.equal(C.filterTransactions(data, { q: '奶茶' }).length, 1);
  assert.equal(C.filterTransactions(data, { q: '餐饮' }).length, 2);
  assert.equal(C.filterTransactions(data, { q: '1800' }).length, 1);
  assert.equal(C.filterTransactions(data, { type: 'income' }).length, 1);
  assert.equal(C.filterTransactions(data, { accountId: 'a_wechat' }).length, 2);
  assert.equal(C.filterTransactions(data, { month: '2026-09' }).length, 0);
  assert.equal(C.filterTransactions(data, { tag: '日常' }).length, 2);
});

test('周期记账：1 月 31 日按月顺延到 2 月末', () => {
  const rule = { id: 'r1', enabled: true, freq: 'monthly', startDate: '2026-01-31', lastRun: null };
  const dates = C.dueDates(rule, '2026-04-30');
  assert.deepEqual(dates, ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30']);
});

test('周期记账：每周、每年、lastRun 去重', () => {
  const weekly = { id: 'r2', enabled: true, freq: 'weekly', startDate: '2026-10-05', lastRun: '2026-10-12' };
  assert.deepEqual(C.dueDates(weekly, '2026-10-26'), ['2026-10-19', '2026-10-26']);
  const yearly = { id: 'r3', enabled: true, freq: 'yearly', startDate: '2024-02-29', lastRun: null };
  assert.deepEqual(C.dueDates(yearly, '2026-03-01'), ['2024-02-29', '2025-02-28', '2026-02-28']);
  assert.deepEqual(C.dueDates({ ...weekly, enabled: false }, '2026-10-26'), []);
});

test('自动入账幂等', () => {
  const data = fixture();
  data.recurring = [{
    id: 'r1', bookId: 'b_main', type: 'expense', amount: 30, categoryId: 'c_food',
    accountId: 'a_alipay', note: '早餐', freq: 'daily', startDate: '2026-10-20', lastRun: null, enabled: true
  }];
  const n1 = C.applyRecurring(data, '2026-10-22');
  assert.equal(n1, 3);
  assert.equal(data.recurring[0].lastRun, '2026-10-22');
  const n2 = C.applyRecurring(data, '2026-10-22');
  assert.equal(n2, 0);
  assert.equal(data.transactions.filter((t) => t.recurringId === 'r1').length, 3);
  const n3 = C.applyRecurring(data, '2026-10-23');
  assert.equal(n3, 1);
});

test('CSV 导出含 BOM 与转义', () => {
  const data = fixture();
  data.transactions[0].note = '午饭, "加辣"';
  const csv = C.toCSV(data, 'b_main');
  assert.ok(csv.startsWith('\ufeff'));
  assert.ok(csv.includes('"午饭, ""加辣"""'));
  assert.ok(csv.includes('餐饮'));
  assert.equal(csv.split('\r\n').length, 6);
});

test('备份校验与迁移', () => {
  const data = fixture();
  const payload = C.exportPayload(data);
  const res = C.validateBackup(JSON.parse(JSON.stringify(payload)));
  assert.equal(res.ok, true);
  assert.equal(res.data.transactions.length, 5);
  assert.equal(res.data.settings.theme, 'auto');

  assert.equal(C.validateBackup(null).ok, false);
  assert.equal(C.validateBackup({ foo: 1 }).ok, false);

  const legacy = {
    books: [{ id: 'b1', name: '旧账本' }],
    activeBookId: 'b1',
    categories: [{ id: 'c1', name: '吃', icon: '🍚', type: 'expense' }],
    accounts: [{ id: 'a1', name: '钱包', type: 'cash' }],
    transactions: [{ date: '2026-01-02', type: 'expense', amount: '9.9', categoryId: 'c1', accountId: 'a1' }]
  };
  const migrated = C.migrateData(legacy);
  assert.equal(migrated.books[0].budget.total, 0);
  assert.equal(migrated.transactions[0].time, '12:00');
  assert.equal(migrated.transactions[0].amount, 9.9);
  assert.equal(migrated.accounts[0].initial, 0);
});

test('整体统计与连续记账天数', () => {
  const data = fixture();
  const s = C.overallStats(data);
  assert.equal(s.count, 5);
  assert.equal(s.days, 4);
  assert.equal(s.books, 1);
  assert.equal(s.streak, 0);
});

test('演示数据可用且分类/账户引用有效', () => {
  const data = C.createDefaultData({ demo: true });
  assert.ok(data.transactions.length > 20);
  const cats = new Set(data.categories.map((c) => c.id));
  const accs = new Set(data.accounts.map((a) => a.id));
  for (const t of data.transactions) {
    assert.ok(accs.has(t.accountId));
    if (t.type !== 'transfer') assert.ok(cats.has(t.categoryId), 'bad cat ' + t.categoryId);
    assert.ok(t.amount > 0);
    assert.match(t.date, /^\d{4}-\d{2}-\d{2}$/);
  }
  const migrated = C.migrateData(JSON.parse(JSON.stringify(data)));
  assert.equal(migrated.transactions.length, data.transactions.length);
});

test('统计页数据：区间合计、每日报表、资产走势、年度月份', () => {
  const data = C.createDefaultData();
  data.transactions = [
    { id: 's1', bookId: 'b_main', type: 'income', amount: 100, categoryId: 'c_salary', accountId: 'a_alipay', date: '2026-10-01', time: '09:00', note: '', tags: [] },
    { id: 's2', bookId: 'b_main', type: 'expense', amount: 30, categoryId: 'c_food', accountId: 'a_alipay', date: '2026-10-02', time: '12:00', note: '', tags: [] },
    { id: 's3', bookId: 'b_main', type: 'transfer', amount: 50, categoryId: null, accountId: 'a_alipay', toAccountId: 'a_bank', date: '2026-10-03', time: '10:00', note: '', tags: [] }
  ];
  const totals = C.rangeTotals(data, 'b_main', '2026-10-01', '2026-10-31');
  assert.equal(totals.income, 100);
  assert.equal(totals.expense, 30);
  assert.equal(totals.balance, 70);
  assert.equal(totals.count, 3);

  const days = C.dailyRows(data, 'b_main', '2026-10-01', '2026-10-31');
  assert.equal(days.length, 3);
  assert.equal(days[2].date, '2026-10-01');
  assert.equal(days[2].balance, 100);

  const initial = data.accounts.reduce((sum, a) => sum + Math.round(a.initial * 100), 0) / 100;
  const series = C.assetSeries(data, '2026-10');
  assert.equal(series.length, 31);
  assert.equal(series[0].value, initial + 100);
  assert.equal(series[1].value, initial + 70);
  assert.equal(series[2].value, initial + 70); // 转账不改变净资产

  assert.equal(C.monthDailySeries(data, 'b_main', '2026-10', 'expense').length, 31);
  assert.equal(C.monthDailySeries(data, 'b_main', '2026-10', 'expense')[1], 30);

  const months = C.yearMonths(data, 'b_main', 2026);
  assert.equal(months.length, 12);
  assert.equal(months[9].expense, 30);
  assert.equal(C.categoryBreakdownRange(data, 'b_main', '2026-10-01', '2026-10-31', 'expense')[0].name, '餐饮');
});

test('日历农历与节假日标签', () => {
  assert.equal(C.calendarLabel('2026-02-17').text, '春节');
  assert.equal(C.calendarLabel('2026-09-25').text, '中秋节');
  assert.equal(C.calendarLabel('2026-10-10').text, '九月');
  assert.equal(C.calendarLabel('2026-10-23').text, '霜降');
  assert.equal(C.calendarLabel('2026-10-31').text, '万圣节');
  assert.ok(C.calendarLabel('2026-10-26').lunar.length > 0);
});

test('导入标签智能归类到内置标签', () => {
  assert.equal(C.canonicalTag('食品餐饮', ['餐饮']), '餐饮');
  assert.equal(C.canonicalTag('餐饮美食', ['餐饮']), '餐饮');
  assert.equal(C.canonicalTag('工资收入', ['工资']), '工资');
  assert.equal(C.canonicalTag('午餐', ['餐饮']), '午餐');

  const data = C.createDefaultData();
  const headers = C.BILL_HEADERS;
  const row = new Array(headers.length).fill('');
  const set = (key, value) => { row[headers.indexOf(key)] = value; };
  set('日期', '2026-10-05');
  set('收支类型', '支出');
  set('金额', '12.50');
  set('类别', '餐饮');
  set('账户', '支付宝');
  set('标签', '食品餐饮');
  const result = C.importBillRows(data, [headers, row]);
  assert.equal(result.imported, 1);
  const tx = data.transactions.find((t) => t.date === '2026-10-05' && t.amount === 12.5);
  assert.ok(tx);
  assert.deepEqual(tx.tags, ['餐饮']);
  assert.ok(data.tags.includes('餐饮'));
});
