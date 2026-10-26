import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { JSDOM } from 'jsdom';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const core = fs.readFileSync(path.join(root, 'assets/core.js'), 'utf8');
const charts = fs.readFileSync(path.join(root, 'assets/charts.js'), 'utf8');
const xlsx = fs.readFileSync(path.join(root, 'assets/xlsx.js'), 'utf8');
const app = fs.readFileSync(path.join(root, 'assets/app.js'), 'utf8');

function boot() {
  const dom = new JSDOM(html, {
    url: 'http://localhost/',
    runScripts: 'outside-only',
    pretendToBeVisual: true
  });
  const { window } = dom;
  window.scrollTo = () => {};
  window.TextEncoder = TextEncoder;
  window.TextDecoder = TextDecoder;
  window.matchMedia = () => ({
    matches: false, media: '', onchange: null,
    addEventListener() {}, removeEventListener() {},
    addListener() {}, removeListener() {}, dispatchEvent() { return false; }
  });
  if (!window.URL.createObjectURL) window.URL.createObjectURL = () => 'blob:mock';
  if (!window.URL.revokeObjectURL) window.URL.revokeObjectURL = () => {};
  window.eval(core);
  window.eval(charts);
  window.eval(xlsx);
  window.eval(app);
  if (!window.document.getElementById('view').innerHTML) {
    window.document.dispatchEvent(new window.Event('DOMContentLoaded'));
  }
  return { dom, window, document: window.document };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function touch(window, type, x, y) {
  const ev = new window.Event(type, { bubbles: true, cancelable: true });
  Object.defineProperty(ev, 'touches', { value: [{ clientX: x, clientY: y }] });
  Object.defineProperty(ev, 'changedTouches', { value: [{ clientX: x, clientY: y }] });
  return ev;
}

function click(document, selector, scope) {
  const rootEl = scope || document;
  const el = rootEl.querySelector(selector);
  assert.ok(el, '找不到元素: ' + selector);
  el.dispatchEvent(new document.defaultView.MouseEvent('click', { bubbles: true, cancelable: true }));
  return el;
}

function dataOf(window) {
  return JSON.parse(window.localStorage.getItem('xingkong.ledger.v4'));
}

test('首屏渲染：账本、汇总、明细、导航', () => {
  const { window, document } = boot();
  assert.ok(document.querySelector('.book-chip'), '账本胶囊');
  assert.ok(document.querySelector('.hero-amount'), '汇总卡片');
  assert.match(document.querySelector('.hero-label').textContent, /本月支出/);
  assert.equal(document.querySelectorAll('.tabbar > *').length, 6);
  assert.ok(document.querySelectorAll('.tx').length > 5, '示例账单');
  assert.match(document.querySelector('.tx .tx-note').textContent, /\d{2}:\d{2}/, '应显示具体时间');
  const data = dataOf(window);
  assert.ok(data.transactions.length > 10);
  assert.ok(document.querySelector('.hero-budget'), '预算入口');
});

test('导航到统计 / 资产 / 我的', () => {
  const { window, document } = boot();
  click(document, '[data-route="stats"]');
  assert.equal(document.querySelectorAll('.stats-tab').length, 4);
  assert.ok(document.querySelector('[data-stats-pane="month"] .stats-summary'));
  assert.ok(document.querySelector('[data-stats-pane="month"] #statsBars-month'));
  assert.ok(document.querySelector('[data-stats-pane="month"] #assetChart-month'));
  assert.ok(document.querySelector('[data-stats-pane="month"] #sankeyChart-month'));
  assert.match(document.querySelector('.view').textContent, /收支统计/);
  assert.match(document.querySelector('.view').textContent, /报表统计/);
  click(document, '[data-route="assets"]');
  assert.equal(document.querySelector('#appbar').hidden, true);
  assert.match(document.querySelector('.view').textContent, /净资产/);
  assert.ok(document.querySelectorAll('.acct-row').length >= 4);
  click(document, '[data-route="profile"]');
  assert.match(document.querySelector('.view').textContent, /数据与备份/);
  assert.match(document.querySelector('.view').textContent, /周期记账/);
});

test('统计页：四种模式、月份切换与图表切换', async () => {
  const { window, document } = boot();
  click(document, '[data-route="stats"]');
  assert.match(document.querySelector('[data-stats-pane="month"] .stats-summary').textContent, /月支出/);

  click(document, '[data-act="stats-mode"][data-mode="daily"]');
  assert.match(document.querySelector('.view').textContent, /近 7 天/);
  assert.ok(!document.querySelector('#assetChart'), '日常模式不显示资产走势');

  click(document, '[data-act="stats-mode"][data-mode="year"]');
  assert.ok(document.querySelector('.year-rail-bar'));
  assert.ok(document.querySelector('[data-act="stats-year-all"]'));
  assert.match(document.querySelector('.view').textContent, /年支出/);

  click(document, '[data-act="stats-mode"][data-mode="custom"]');
  assert.ok(document.querySelector('[data-preset="7"]'));
  assert.ok(document.querySelector('[data-act="stats-custom-start"]'));

  click(document, '[data-act="stats-mode"][data-mode="month"]');
  click(document, '[data-act="stats-year-picker"]');
  const monthBtn = document.querySelector('[data-picker-month="2026-09"]');
  assert.ok(monthBtn, '年月选择器');
  click(document, '[data-picker-month="2026-09"]');
  await sleep(20);
  assert.match(document.querySelector('[data-stats-pane="month"] .ss-foot').textContent, /2026年9月/);

  click(document, '[data-act="stats-month-step"][data-step="1"]');
  assert.match(document.querySelector('[data-stats-pane="month"] .ss-foot').textContent, /2026年10月/);
  click(document, '[data-act="stats-month-step"][data-step="-1"]');
  assert.match(document.querySelector('[data-stats-pane="month"] .ss-foot').textContent, /2026年9月/);

  click(document, '[data-act="stats-type"][data-type="balance"]');
  assert.match(document.querySelector('.stats-mini-seg .active').textContent, /结余/);
  const monthPane = document.querySelector('[data-stats-pane="month"]');
  assert.ok(monthPane.querySelector('#statsBars-month svg'));
});

test('新增一笔支出并写入本地存储', async () => {
  const { window, document } = boot();
  const before = dataOf(window).transactions.length;
  click(document, '[data-act="open-entry"]');
  assert.ok(document.querySelector('.sheet.entry'), '记账面板');
  click(document, '.key[data-key="1"]');
  click(document, '.key[data-key="2"]');
  click(document, '.key[data-key="."]');
  click(document, '.key[data-key="5"]');
  assert.match(document.querySelector('.entry-amount').textContent, /12\.50/);
  click(document, '.key[data-key="ok"]');
  await sleep(20);
  assert.equal(dataOf(window).transactions.length, before + 1);
  assert.ok(!document.querySelector('.sheet.entry'), '面板已关闭');
  assert.ok(document.querySelector('.toast'), '出现提示');
  assert.ok(document.querySelectorAll('.tx').length >= 6);
});

test('算式记账 12+3.5 得到 15.5', async () => {
  const { window, document } = boot();
  const before = dataOf(window).transactions.length;
  click(document, '[data-act="open-entry"]');
  ['1', '2', '+', '3', '.', '5'].forEach((k) => click(document, '.key[data-key="' + k + '"]'));
  assert.match(document.querySelector('.entry-expr').textContent, /12/);
  click(document, '.key[data-key="ok"]');
  await sleep(20);
  const data = dataOf(window);
  assert.equal(data.transactions.length, before + 1);
  const latest = data.transactions[data.transactions.length - 1];
  assert.equal(latest.amount, 15.5);
  assert.equal(latest.type, 'expense');
});

test('编辑已有账单（改分类/金额）', async () => {
  const { window, document } = boot();
  const first = document.querySelector('.tx');
  const id = first.dataset.id;
  click(document, '.tx');
  assert.ok(document.querySelector('.sheet.entry'));
  click(document, '.key[data-key="del"]');
  click(document, '.key[data-key="del"]');
  click(document, '.key[data-key="del"]');
  click(document, '.key[data-key="del"]');
  click(document, '.key[data-key="del"]');
  click(document, '.key[data-key="del"]');
  click(document, '.key[data-key="8"]');
  click(document, '.key[data-key="ok"]');
  await sleep(20);
  const tx = dataOf(window).transactions.find((t) => t.id === id);
  assert.equal(tx.amount, 8);
});

test('删除账单需要二次确认', async () => {
  const { window, document } = boot();
  const before = dataOf(window).transactions.length;
  click(document, '.tx');
  click(document, '[data-delete]');
  assert.ok(document.querySelector('.modal'), '确认弹窗');
  click(document, '[data-no]');
  assert.equal(dataOf(window).transactions.length, before);
  click(document, '.sheet [data-close]');
  click(document, '.tx');
  click(document, '[data-delete]');
  click(document, '[data-yes]');
  await sleep(120);
  assert.equal(dataOf(window).transactions.length, before - 1);
});

test('更多账单字段：二级分类 / 退款 / 优惠 / 报销 / 多币种 / 地址', async () => {
  const { window, document } = boot();
  const before = dataOf(window).transactions.length;
  click(document, '[data-act="open-entry"]');
  click(document, '.key[data-key="8"]');
  click(document, '.key[data-key="0"]');
  click(document, '[data-more]');
  const sheets = document.querySelectorAll('.sheet');
  const sheet = sheets[sheets.length - 1];
  assert.ok(sheet, '更多信息面板');

  const set = (selector, value) => {
    const el = sheet.querySelector(selector);
    assert.ok(el, '找不到 ' + selector);
    el.value = value;
  };
  set('[data-subcategory]', '午餐');
  set('[data-refund]', '5');
  set('[data-discount]', '3.5');
  set('[data-reimburse-account]', '支付宝');
  set('[data-reimburse-amount]', '40');
  set('[data-reimburse-note]', '项目 A');
  set('[data-currency]', 'USD');
  set('[data-foreign-amount]', '12.5');
  set('[data-location]', '公司楼下');
  set('[data-creator]', '小明');
  set('[data-extra]', '补充说明');
  click(document, '[data-save-more]', sheet);
  await sleep(20);
  click(document, '.key[data-key="ok"]');
  await sleep(30);

  const data = dataOf(window);
  assert.equal(data.transactions.length, before + 1);
  const tx = data.transactions[data.transactions.length - 1];
  assert.equal(tx.amount, 80);
  assert.equal(tx.subcategory, '午餐');
  assert.equal(tx.refund, 5);
  assert.equal(tx.discount, 3.5);
  assert.equal(tx.reimburseAccount, '支付宝');
  assert.equal(tx.reimburseAmount, 40);
  assert.equal(tx.reimburseNote, '项目 A');
  assert.equal(tx.currency, 'USD');
  assert.equal(tx.foreignAmount, 12.5);
  assert.equal(tx.location, '公司楼下');
  assert.equal(tx.creator, '小明');
  assert.equal(tx.extra, '补充说明');
  assert.ok(Array.isArray(tx.attachments));
});

test('设置总预算并显示在首页', async () => {
  const { window, document } = boot();
  click(document, '[data-act="open-budget"]');
  const total = document.querySelector('[data-total]');
  total.value = '5000';
  total.dispatchEvent(new window.Event('input', { bubbles: true }));
  click(document, '[data-save]');
  await sleep(20);
  assert.equal(dataOf(window).books[0].budget.total, 5000);
  assert.match(document.querySelector('.hero-budget').textContent, /5,000/);
  assert.ok(document.querySelector('.budget-fill'));
});

test('新增自定义分类', async () => {
  const { window, document } = boot();
  const before = dataOf(window).categories.length;
  click(document, '[data-route="profile"]');
  click(document, '[data-act="open-categories"]');
  click(document, '[data-add-cat]');
  const name = document.querySelector('[data-name]');
  name.value = '咖啡';
  name.dispatchEvent(new window.Event('input', { bubbles: true }));
  click(document, '[data-save]');
  await sleep(20);
  assert.equal(dataOf(window).categories.length, before + 1);
  assert.ok(dataOf(window).categories.some((c) => c.name === '咖啡'));
});

test('搜索：按分类名过滤', async () => {
  const { window, document } = boot();
  click(document, '[data-act="open-search"]');
  const input = document.querySelector('#searchInput');
  input.value = '餐饮';
  input.dispatchEvent(new window.Event('input', { bubbles: true }));
  await sleep(250);
  const rows = document.querySelectorAll('#searchBody .tx');
  assert.ok(rows.length > 0, '有搜索结果');
  const data = dataOf(window);
  const expected = data.transactions.filter((t) => {
    const cat = data.categories.find((c) => c.id === t.categoryId);
    return cat && cat.name === '餐饮';
  }).length;
  assert.equal(rows.length, expected);
});

test('日历页：节假日、热力设置、每日账单', async () => {
  const { window, document } = boot();
  click(document, '[data-route="calendar"]');
  assert.ok(document.querySelector('.calendar-glass'));
  assert.ok(document.querySelector('.cal-grid'));
  assert.ok(document.querySelectorAll('.cal-grid [data-day]').length >= 28);
  assert.ok(document.querySelector('.calendar-day-panel'));
  assert.ok(document.querySelectorAll('.cal-cell .cc-lunar').length >= 28);
  assert.ok(document.querySelector('.cc-amounts'), '每日框显示收支');

  const label = document.querySelector('.cal-cell .cc-lunar');
  assert.ok(label.textContent.length > 0);

  click(document, '[data-act="calendar-settings"]');
  assert.ok(document.querySelector('.modal, .sheet'));
  assert.ok(document.querySelector('[data-heat]'));
  const heat = document.querySelector('[data-heat]');
  heat.checked = false;
  heat.dispatchEvent(new window.Event('change', { bubbles: true }));
  await sleep(20);
  assert.equal(JSON.parse(window.localStorage.getItem('xingkong.ledger.v4')).settings.calendarHeat, false);

  const before = document.querySelector('.cal-title').textContent;
  click(document, '[data-act="calendar-prev"]');
  assert.notEqual(document.querySelector('.cal-title').textContent, before);
});

test('明细页下拉打开记账面板', async () => {
  const { window, document } = boot();
  window.scrollY = 0;
  const start = new window.Event('touchstart', { bubbles: true, cancelable: true });
  Object.defineProperty(start, 'touches', { value: [{ clientX: 50, clientY: 50 }] });
  document.body.dispatchEvent(start);
  await sleep(230);
  const move = new window.Event('touchmove', { bubbles: true, cancelable: true });
  Object.defineProperty(move, 'touches', { value: [{ clientX: 50, clientY: 280 }] });
  document.body.dispatchEvent(move);
  await sleep(20);
  assert.ok(document.querySelector('.pull-hint.show'), '下拉提示应出现');
  const end = new window.Event('touchend', { bubbles: true, cancelable: true });
  document.body.dispatchEvent(end);
  await sleep(40);
  assert.ok(document.querySelector('.sheet'), '松手应打开记账面板');
});

test('统计月份滑轨：左右各只切换一个月', async () => {
  const { window, document } = boot();
  click(document, '[data-route="stats"]');
  await sleep(130);
  const rail1 = document.querySelector('[data-stats-pane="month"] .month-rail');
  rail1.dispatchEvent(touch(window, 'touchstart', 300, 420));
  rail1.dispatchEvent(touch(window, 'touchmove', 100, 425));
  assert.match(rail1.style.transform, /translateX/);
  rail1.dispatchEvent(touch(window, 'touchend', 100, 425));
  assert.match(document.querySelector('[data-stats-pane="month"] .ss-foot').textContent, /2026年9月/);
  await sleep(120);
  const rail2 = document.querySelector('[data-stats-pane="month"] .month-rail');
  rail2.dispatchEvent(touch(window, 'touchstart', 100, 420));
  rail2.dispatchEvent(touch(window, 'touchmove', 300, 425));
  rail2.dispatchEvent(touch(window, 'touchend', 300, 425));
  assert.match(document.querySelector('[data-stats-pane="month"] .ss-foot').textContent, /2026年10月/);
});

test('日历页向下拖动不会回弹', () => {
  const { window, document } = boot();
  click(document, '[data-route="calendar"]');
  document.body.dispatchEvent(touch(window, 'touchstart', 200, 400));
  const move = touch(window, 'touchmove', 200, 520);
  document.body.dispatchEvent(move);
  assert.equal(move.defaultPrevented, true);
});

test('五个主界面左右滑动切换', async () => {
  const { window, document } = boot();
  document.body.dispatchEvent(touch(window, 'touchstart', 220, 420));
  document.body.dispatchEvent(touch(window, 'touchmove', 90, 425));
  assert.ok(document.querySelector('.page-drag'), '拖动时显示两页各一半');
  document.body.dispatchEvent(touch(window, 'touchend', 90, 425));
  await sleep(320);
  assert.ok(document.querySelector('.calendar-glass'), '向左滑应进入日历');
  document.body.dispatchEvent(touch(window, 'touchstart', 80, 420));
  document.body.dispatchEvent(touch(window, 'touchmove', 220, 425));
  document.body.dispatchEvent(touch(window, 'touchend', 220, 425));
  await sleep(320);
  assert.ok(document.querySelector('.hero'), '向右滑应回到明细');
});

test('日历滑到统计日常，统计自定义滑到资产', async () => {
  const { window, document } = boot();
  click(document, '[data-route="calendar"]');
  document.body.dispatchEvent(touch(window, 'touchstart', 230, 430));
  document.body.dispatchEvent(touch(window, 'touchmove', 80, 432));
  assert.ok(document.querySelector('.page-drag'), '日历到统计跟手过渡');
  assert.ok(document.querySelector('.page-drag .stats-tabs'), '目标页面顶栏同步出现');
  document.body.dispatchEvent(touch(window, 'touchend', 80, 432));
  await sleep(520);
  assert.ok(document.querySelector('.stats-carousel'), '进入统计');
  assert.match(document.querySelector('.stats-tab.active').textContent, /日常/);

  click(document, '[data-act="stats-mode"][data-mode="custom"]');
  await sleep(40);
  assert.match(document.querySelector('.stats-tab.active').textContent, /自定义/);
  await sleep(40);
  const car = document.querySelector('[data-stats-carousel]');
  document.body.dispatchEvent(touch(window, 'touchstart', 300, 430));
  document.body.dispatchEvent(touch(window, 'touchmove', 80, 432));
  assert.ok(document.querySelector('.page-drag'), '统计自定义到资产跟手过渡');
  assert.ok(document.querySelector('.page-drag .appbar'), '原页面顶栏同步滑出');
  document.body.dispatchEvent(touch(window, 'touchend', 80, 432));
  await sleep(320);
  assert.ok(document.querySelector('.assets'), '进入资产');
  assert.equal(document.querySelector('#appbar').hidden, true);
});

test('资产余额编辑与长按删除账户', async () => {
  const { window, document } = boot();
  click(document, '[data-route="assets"]');
  assert.ok(document.querySelector('[data-act="edit-balance"]'));
  click(document, '[data-act="edit-balance"]');
  const input = document.querySelector('[data-balance]');
  assert.ok(input);
  input.value = '1234';
  click(document, '[data-save-balance]');
  await sleep(30);
  assert.match(document.querySelector('.acct-balance').textContent, /1,234\.00/);

  const before = document.querySelectorAll('.acct-row').length;
  const row = document.querySelector('.acct-row');
  row.dispatchEvent(new window.MouseEvent('mousedown', { bubbles: true, cancelable: true, clientX: 10, clientY: 10 }));
  await sleep(900);
  assert.ok(document.querySelector('.modal'), '长按账户应弹出删除确认');
  click(document, '[data-yes]');
  await sleep(40);
  assert.equal(document.querySelectorAll('.acct-row').length, before - 1);
});

test('统计页左右滑动切换统计方式', async () => {
  const { window, document } = boot();
  click(document, '[data-route="stats"]');
  const carousel = document.querySelector('[data-stats-carousel]');
  assert.ok(carousel);
  carousel.dispatchEvent(touch(window, 'touchstart', 300, 430));
  carousel.dispatchEvent(touch(window, 'touchmove', 80, 432));
  carousel.dispatchEvent(touch(window, 'touchend', 80, 432));
  await sleep(320);
  assert.match(document.querySelector('.stats-tab.active').textContent, /年统计/);
  assert.match(document.querySelector('[data-stats-pane="year"] .year-rail-bar') ? 'year' : '', /year/);
});
test('月统计汇总可展开更多数据', async () => {
  const { window, document } = boot();
  click(document, '[data-route="stats"]');
  assert.ok(document.querySelector('[data-stats-pane="month"] [data-act="stats-summary-toggle"]'), '月统计更多数据按钮');
  click(document, '[data-stats-pane="month"] [data-act="stats-summary-toggle"]');
  const extra = document.querySelector('.ss-extra.open');
  assert.ok(extra, '月统计展开');
  assert.match(extra.textContent, /日均支出/);
  assert.match(extra.textContent, /退款/);
});

test('年统计按月份展示，点击柱状图进入该月账单', async () => {
  const { window, document } = boot();
  click(document, '[data-route="stats"]');
  click(document, '[data-act="stats-mode"][data-mode="year"]');
  const yearPane = document.querySelector('[data-stats-pane="year"]');
  const chart = yearPane.querySelector('#statsBars-year');
  assert.match(chart.textContent, /12月/);
  assert.match(yearPane.querySelector('.stats-table .st-head').textContent, /月份/);
  click(document, '[data-stats-pane="year"] #statsBars-year');
  const sheet = document.querySelector('.bill-sheet');
  assert.ok(sheet, '账单列表');
  assert.match(sheet.textContent, /2026年1月账单/);
  assert.ok(sheet.querySelector('.tx-list') || sheet.querySelector('.empty'), '账单内容');
});

test('日历左右滑动切换月份', async () => {
  const { window, document } = boot();
  click(document, '[data-route="calendar"]');
  const title = document.querySelector('.cal-title').textContent;
  const grid = document.querySelector('.calendar-grid-card');
  grid.dispatchEvent(touch(window, 'touchstart', 240, 420));
  grid.dispatchEvent(touch(window, 'touchmove', 90, 425));
  const track = grid.querySelector('[data-calendar-track]');
  assert.ok(track && track.style.transform.indexOf('calc') >= 0, '拖动时应同时露出相邻月份');
  grid.dispatchEvent(touch(window, 'touchend', 90, 425));
  await sleep(320);
  assert.notEqual(document.querySelector('.cal-title').textContent, title, '月份应切换');
  assert.ok(document.querySelector('.calendar-grid-card'), '仍在日历页');
});

test('年统计：所有年份、十年图表、热力图、展开数据与曲线切换', async () => {
  const { window, document } = boot();
  click(document, '[data-route="stats"]');
  click(document, '[data-act="stats-mode"][data-mode="year"]');
  assert.ok(document.querySelector('.year-rail-bar'));
  assert.ok(document.querySelector('[data-act="stats-year-all"]'));
  assert.ok(document.querySelector('.heat-year-grid'), '年度热力图');
  assert.ok(document.querySelectorAll('.year-chip').length >= 8);

  let yp = document.querySelector('[data-stats-pane="year"]');
  yp.querySelector('[data-act="stats-summary-toggle"]').click();
  yp = document.querySelector('[data-stats-pane="year"]');
  assert.ok(yp.querySelector('.ss-extra.open'), '展开更多年度数据');
  assert.match(yp.querySelector('.ss-extra').textContent, /月均支出/);
  assert.match(yp.querySelector('.ss-extra').textContent, /退款/);

  yp.querySelector('[data-act="stats-chart-type"][data-value="line"]').click();
  yp = document.querySelector('[data-stats-pane="year"]');
  assert.ok(yp.querySelector('.stats-chart-type .active').textContent.length > 0);
  assert.ok(yp.querySelector('#statsBars-year svg'));

  yp.querySelector('[data-act="stats-type"][data-type="all"]').click();
  yp = document.querySelector('[data-stats-pane="year"]');
  assert.ok(yp.querySelector('#statsBars-year svg'));

  click(document, '[data-act="open-year-heatmap"]');
  const full = document.querySelector('.heat-full');
  assert.ok(full, '放大热力图');
  assert.ok(document.querySelectorAll('.heat-full-month').length >= 12);
  click(document, '[data-close]');
  await sleep(20);

  click(document, '[data-act="stats-year-all"]');
  assert.match(document.querySelector('[data-stats-pane="year"] .ss-foot').textContent, /全部年份/);
  assert.ok(!document.querySelector('.heat-year-grid'), '所有年份隐藏月度热力图');
});
test('主题中心包含九个新主题并可切换', async () => {
  const { window, document } = boot();
  click(document, '[data-route="profile"]');
  click(document, '[data-act="open-theme"]');
  assert.equal(document.querySelectorAll('[data-theme-opt]').length, 13);
  assert.ok(document.querySelector('[data-theme-opt="grass"]'));
  assert.ok(document.querySelector('[data-theme-opt="ocean"]'));
  assert.ok(document.querySelector('[data-theme-opt="custom"]'));
  assert.ok(document.querySelector('[data-theme-upload]'));
  click(document, '[data-theme-opt="grass"]');
  await sleep(30);
  assert.equal(document.documentElement.dataset.theme, 'grass');
  assert.equal(dataOf(window).settings.theme, 'grass');
  assert.match(document.querySelector('.view').textContent, /星空记账/);
});

test('日历农历开关与记账账户开关', async () => {
  const { window, document } = boot();
  click(document, '[data-route="calendar"]');
  click(document, '[data-act="calendar-settings"]');
  const lunar = document.querySelector('[data-lunar]');
  assert.ok(lunar);
  lunar.checked = false;
  lunar.dispatchEvent(new window.Event('change', { bubbles: true }));
  await sleep(30);
  assert.equal(dataOf(window).settings.calendarLunar, false);
  assert.ok(!Array.from(document.querySelectorAll('.cc-lunar')).some((x) => x.textContent === '十七'));

  click(document, '[data-route="assets"]');
  click(document, '[data-act="open-account-bookkeeping"]');
  const toggle = document.querySelector('[data-bookkeeping-account]');
  assert.ok(toggle);
  toggle.checked = false;
  toggle.dispatchEvent(new window.Event('change', { bubbles: true }));
  await sleep(20);
  assert.equal(dataOf(window).accounts.find((a) => a.id === toggle.dataset.bookkeepingAccount).bookkeeping, false);
  click(document, '[data-close-bookkeeping]');
  await sleep(20);
  assert.match(document.querySelector('.bookkeeping-bar').textContent, /\d+ \/ \d+ 个启用/);
});

test('分类管理长按可转入其他分类', async () => {
  const { window, document } = boot();
  click(document, '[data-route="profile"]');
  click(document, '[data-act="open-categories"]');
  const row = document.querySelector('[data-cat-edit]');
  assert.ok(row);
  row.dispatchEvent(new window.MouseEvent('mousedown', { bubbles: true, cancelable: true, clientX: 10, clientY: 10 }));
  await sleep(900);
  assert.match(document.body.textContent, /转入其他分类/);
  assert.ok(document.querySelector('[data-cat-move]'));
});

test('长按账单进入多选并可取消', async () => {
  const { window, document } = boot();
  const row = document.querySelector('.tx');
  row.dispatchEvent(new window.MouseEvent('mousedown', { bubbles: true, cancelable: true, clientX: 10, clientY: 10 }));
  await sleep(900);
  assert.ok(document.querySelector('.select-bar'), '长按应进入多选');
  assert.match(document.querySelector('.select-bar').textContent, /1/);
  const rows = document.querySelectorAll('.tx');
  rows[1].dispatchEvent(new window.MouseEvent('click', { bubbles: true, cancelable: true }));
  await sleep(20);
  assert.match(document.querySelector('.select-bar').textContent, /2/);
  click(document, '[data-act="select-cancel"]');
  assert.ok(!document.querySelector('.select-bar'));
});

test('账单日历打开并显示当月天数', () => {
  const { window, document } = boot();
  click(document, '[data-act="open-calendar"]');
  assert.ok(document.querySelector('.cal-grid'));
  assert.ok(document.querySelectorAll('.cal-grid [data-day]').length >= 28);
});

test('主题切换为深色并持久化', async () => {
  const { window, document } = boot();
  click(document, '[data-route="profile"]');
  click(document, '[data-act="open-theme"]');
  click(document, '[data-theme-opt="dark"]');
  await sleep(20);
  assert.equal(document.documentElement.getAttribute('data-theme'), 'dark');
  assert.equal(dataOf(window).settings.theme, 'dark');
});

test('隐私锁：设置后立即锁定，输入密码解锁', async () => {
  const { window, document } = boot();
  click(document, '[data-route="profile"]');
  click(document, '[data-act="open-pin"]');
  document.querySelector('[data-pin1]').value = '1234';
  document.querySelector('[data-pin2]').value = '1234';
  click(document, '[data-save-pin]');
  await sleep(20);
  assert.ok(dataOf(window).settings.pinHash, '密码已保存');
  click(document, '[data-act="lock-now"]');
  assert.equal(document.getElementById('lock-screen').hidden, false);
  ['1', '2', '3', '4'].forEach((n) => click(document, '.pin-key[data-pin="' + n + '"]'));
  await sleep(20);
  assert.equal(document.getElementById('lock-screen').hidden, true);
});

test('周期记账：新建每天规则并生成今日账单', async () => {
  const { window, document } = boot();
  const before = dataOf(window).transactions.length;
  click(document, '[data-route="profile"]');
  click(document, '[data-act="open-recurring"]');
  click(document, '[data-new-rule]');
  document.querySelector('[data-amount]').value = '9.9';
  document.querySelector('[data-freq]').value = 'daily';
  document.querySelector('[data-note]').value = '早餐';
  click(document, '[data-save]');
  await sleep(30);
  const data = dataOf(window);
  assert.equal(data.recurring.length, 1);
  assert.equal(data.recurring[0].freq, 'daily');
  assert.ok(data.transactions.length >= before + 1);
});

test('导出 Excel 按钮生成 23 列工作簿', async () => {
  const { window, document } = boot();
  click(document, '[data-route="profile"]');
  click(document, '[data-act="open-data"]');
  let captured = null;
  window.URL.createObjectURL = (blob) => { captured = blob; return 'blob:mock'; };
  click(document, '[data-export-xlsx]');
  await sleep(60);
  assert.ok(captured, '应生成 Excel Blob');
  assert.match(captured.type, /spreadsheetml/);
  const buffer = await new Promise((resolve, reject) => {
    const reader = new window.FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsArrayBuffer(captured);
  });
  const parsed = await window.LedgerXlsx.parseWorkbook(buffer);
  assert.deepEqual(parsed.headers, window.LedgerCore.BILL_HEADERS);
  assert.ok(parsed.rows.length > 0);
});

test('CSV / JSON 导出函数可用（不落盘）', () => {
  const { window } = boot();
  const C = window.LedgerCore;
  const csv = C.toCSV(dataOf(window), 'b_main');
  assert.ok(csv.includes('日期,收支类型,金额,类别,二级分类'));
  const payload = C.exportPayload(dataOf(window));
  assert.equal(C.validateBackup(payload).ok, true);
});

test('转账：账户余额联动', async () => {
  const { window, document } = boot();
  const C = window.LedgerCore;
  const data = dataOf(window);
  const before = C.accountBalances(data);
  click(document, '[data-route="assets"]');
  click(document, '[data-act="open-transfer"]');
  // 默认转出/转入为前两个账户
  click(document, '.key[data-key="1"]');
  click(document, '.key[data-key="0"]');
  click(document, '.key[data-key="0"]');
  click(document, '.key[data-key="ok"]');
  await sleep(20);
  const after = C.accountBalances(dataOf(window));
  assert.equal(C.round2(after[data.accounts[0].id] - before[data.accounts[0].id]), -100);
  assert.equal(C.round2(after[data.accounts[1].id] - before[data.accounts[1].id]), 100);
});
