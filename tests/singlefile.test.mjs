import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { JSDOM } from 'jsdom';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const file = path.join(root, 'dist', '星空记账.html');

test('单文件构建：内联脚本可直接运行并记账', async () => {
  assert.ok(fs.existsSync(file), '请先运行 node build.mjs');
  const html = fs.readFileSync(file, 'utf8');
  assert.ok(!html.includes('src="assets/'), '不应残留外部脚本');
  assert.ok(!html.includes('href="assets/'), '不应残留外部样式/图标');

  const dom = new JSDOM(html, {
    url: 'http://localhost/',
    runScripts: 'dangerously',
    pretendToBeVisual: true,
    beforeParse(window) {
      window.scrollTo = () => {};
      window.matchMedia = () => ({
        matches: false,
        addEventListener() {}, removeEventListener() {},
        addListener() {}, removeListener() {}, dispatchEvent() { return false; }
      });
    }
  });
  const { window } = dom;
  const document = window.document;
  await new Promise((r) => setTimeout(r, 30));
  assert.ok(document.querySelector('.hero-amount'), '首页应渲染');
  assert.ok(document.querySelectorAll('.tx').length > 0, '示例账单应存在');

  const before = JSON.parse(window.localStorage.getItem('xingkong.ledger.v4')).transactions.length;
  document.querySelector('[data-act="open-entry"]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
  assert.ok(document.querySelector('.sheet.entry'), '记账面板应打开');
  ['5', '0'].forEach((k) => {
    document.querySelector('.key[data-key="' + k + '"]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
  });
  document.querySelector('.key[data-key="ok"]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
  await new Promise((r) => setTimeout(r, 30));
  const after = JSON.parse(window.localStorage.getItem('xingkong.ledger.v4')).transactions.length;
  assert.equal(after, before + 1);
  dom.window.close();
});
