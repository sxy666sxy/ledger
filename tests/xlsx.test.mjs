import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { JSDOM } from 'jsdom';

const require = createRequire(import.meta.url);
const C = require('../assets/core.js');
const X = require('../assets/xlsx.js');

const dom = new JSDOM('<!doctype html><html><body></body></html>');
global.DOMParser = dom.window.DOMParser;

test('账单表头与星空导出列完全一致', () => {
  assert.deepEqual(C.BILL_HEADERS, [
    '日期', '收支类型', '金额', '类别', '二级分类', '账户', '账本',
    '退款', '优惠', '备注', '标签', '报销账户', '报销金额', '报销明细',
    '多币种', '地址', '创建用户', '其他',
    '附件1', '附件2', '附件3', '附件4', '附件5'
  ]);
  const data = C.createDefaultData({ demo: true });
  const table = C.billRows(data);
  assert.equal(table.headers.length, 23);
  assert.equal(table.rows.length, data.transactions.length);
  table.rows.forEach((row) => assert.equal(row.length, 23));
  const food = table.rows.find((r) => r[3] === '餐饮');
  assert.ok(food, '演示数据里应有餐饮');
  assert.equal(food[1], '支出');
  assert.equal(food[6], '日常账本');
  assert.equal(food[16], '我');
});

test('xlsx 构建与解析往返', async () => {
  const data = C.createDefaultData({ demo: true });
  const table = C.billRows(data);
  table.rows[0][7] = 5.5; // 退款
  table.rows[0][19] = 'receipt.jpg';
  const bytes = X.buildWorkbook(table.headers, table.rows);
  assert.equal(String.fromCharCode(bytes[0], bytes[1]), 'PK');

  const text = new TextDecoder('utf-8').decode(bytes);
  assert.ok(text.includes('日期'), 'ZIP 中应有表头');
  assert.ok(text.includes('收支类型'));
  assert.ok(text.includes('附件5'));

  const parsed = await X.parseWorkbook(bytes.buffer);
  assert.deepEqual(parsed.headers, C.BILL_HEADERS);
  assert.equal(parsed.rows.length, table.rows.length);
  assert.equal(parsed.rows[0][2], table.rows[0][2]);
  assert.equal(parsed.rows[0][4], table.rows[0][4]); // 二级分类
  assert.equal(parsed.rows[0][7], 5.5);
  assert.ok(parsed.rows[0][8] == null);
});

test('Excel 导入合并（含去重）', async () => {
  const demo = C.createDefaultData({ demo: true });
  const table = C.billRows(demo);
  const bytes = X.buildWorkbook(table.headers, table.rows);
  const parsed = await X.parseWorkbook(bytes.buffer);
  const rows = [parsed.headers].concat(parsed.rows);

  const target = C.createDefaultData();
  const result = C.importBillRows(target, rows);
  assert.equal(result.error, '');
  assert.equal(result.imported, demo.transactions.length);
  assert.equal(result.skipped, 0);
  assert.equal(target.transactions.length, demo.transactions.length);

  const again = C.importBillRows(target, rows);
  assert.equal(again.imported, 0);
  assert.equal(again.skipped, demo.transactions.length);
});

test('CSV 导出使用新列并可回导', () => {
  const demo = C.createDefaultData({ demo: true });
  const csv = C.toCSV(demo);
  const header = csv.replace(/^\ufeff/, '').split('\r\n')[0];
  assert.equal(header, C.BILL_HEADERS.join(','));
  const rows = C.parseCSV(csv);
  assert.equal(rows.length, demo.transactions.length + 1);

  const target = C.createDefaultData();
  const result = C.importBillRows(target, rows);
  assert.equal(result.imported, demo.transactions.length);
  assert.equal(target.transactions.length, demo.transactions.length);
});

test('旧版 CSV 表头兼容（日期/时间/类型/分类/转入账户）', () => {
  const target = C.createDefaultData();
  const rows = [
    ['日期', '时间', '类型', '分类', '金额', '账户', '转入账户', '备注', '标签'],
    ['2026-10-25', '12:30', '支出', '餐饮', '35.50', '支付宝', '', '午饭', '日常 朋友'],
    ['2026-10-25', '13:00', '转账', '', '100', '银行卡', '微信', '转到微信', '']
  ];
  const result = C.importBillRows(target, rows);
  assert.equal(result.imported, 2);
  const exp = target.transactions.find((t) => t.type === 'expense');
  assert.equal(exp.date, '2026-10-25');
  assert.equal(exp.time, '12:30');
  assert.deepEqual(exp.tags, ['日常', '朋友']);
  const tr = target.transactions.find((t) => t.type === 'transfer');
  assert.ok(tr.accountId);
  assert.ok(tr.toAccountId);
  assert.notEqual(tr.accountId, tr.toAccountId);
});

test('解析 Excel 生成的 xlsx（deflate 压缩）并导入全部扩展字段', async () => {
  const fs = await import('node:fs');
  const path = await import('node:path');
  const { fileURLToPath } = await import('node:url');
  const here = path.dirname(fileURLToPath(import.meta.url));
  const buf = fs.readFileSync(path.join(here, 'fixtures', 'import.xlsx'));
  const parsed = await X.parseWorkbook(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
  assert.equal(parsed.rows.length, 2);
  assert.equal(parsed.rows[0][1], '支出');

  const target = C.createDefaultData();
  const result = C.importBillRows(target, [parsed.headers].concat(parsed.rows));
  assert.equal(result.imported, 2);
  const exp = target.transactions.find((t) => t.type === 'expense');
  assert.equal(exp.date, '2026-10-01');
  assert.equal(exp.amount, 35.5);
  assert.equal(exp.subcategory, '午餐');
  assert.equal(exp.refund, 2);
  assert.equal(exp.discount, 1);
  assert.equal(exp.reimburseAccount, '公司');
  assert.equal(exp.reimburseAmount, 20);
  assert.equal(exp.currency, 'USD');
  assert.equal(exp.foreignAmount, 9.9);
  assert.equal(exp.location, '公司');
  assert.equal(exp.creator, '小明');
  assert.equal(exp.extra, '其他说明');
  assert.deepEqual(exp.tags, ['日常', '朋友']);
  assert.equal(exp.attachments[0].name, 'a.jpg');
});
