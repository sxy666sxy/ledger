import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const exists = (p) => fs.existsSync(path.join(root, p));

function pngSize(file) {
  const b = fs.readFileSync(path.join(root, file));
  assert.equal(b.slice(1, 4).toString(), 'PNG', file + ' 不是 PNG');
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

test('manifest：安装所需字段、图标、截图与快捷方式', () => {
  const manifest = JSON.parse(read('manifest.webmanifest'));
  assert.equal(manifest.name, '星空记账 · 极简本地记账');
  assert.equal(manifest.short_name, '星空记账');
  assert.equal(manifest.start_url, './');
  assert.equal(manifest.scope, './');
  assert.equal(manifest.display, 'standalone');
  assert.equal(manifest.theme_color, '#0e9f6e');
  assert.equal(manifest.background_color, '#f2f5f3');
  assert.equal(manifest.lang, 'zh-CN');
  assert.ok(Array.isArray(manifest.icons) && manifest.icons.length >= 3);

  const sizes = manifest.icons.map((i) => i.sizes);
  assert.ok(sizes.includes('192x192'));
  assert.ok(sizes.includes('512x512'));
  assert.ok(manifest.icons.some((i) => i.purpose === 'maskable'));
  manifest.icons.forEach((icon) => {
    assert.ok(exists(icon.src), '缺少图标 ' + icon.src);
    if (icon.type === 'image/png') {
      const { w, h } = pngSize(icon.src);
      assert.equal(w + 'x' + h, icon.sizes, icon.src + ' 尺寸不符');
    }
  });

  assert.ok(Array.isArray(manifest.screenshots));
  manifest.screenshots.forEach((s) => assert.ok(exists(s.src), '缺少截图 ' + s.src));
  assert.ok(manifest.shortcuts.some((s) => s.url.indexOf('action=add') >= 0));
  assert.ok(manifest.shortcuts.some((s) => s.url.indexOf('action=stats') >= 0));
});

test('Service Worker：预缓存清单完整且文件存在', () => {
  const sw = read('sw.js');
  assert.match(sw, /CACHE_VERSION/);
  assert.match(sw, /addEventListener\('fetch'/);
  const m = /const PRECACHE = \[([\s\S]*?)\];/.exec(sw);
  assert.ok(m, '找不到 PRECACHE');
  const files = Array.from(m[1].matchAll(/'([^']+)'/g)).map((x) => x[1]);
  assert.ok(files.includes('./index.html'));
  assert.ok(files.includes('./manifest.webmanifest'));
  assert.ok(files.includes('./assets/app.js'));
  assert.ok(files.includes('./assets/core.js'));
  assert.ok(files.includes('./assets/charts.js'));
  assert.ok(files.includes('./assets/xlsx.js'));
  assert.ok(files.includes('./assets/app.css'));
  files.forEach((f) => {
    const rel = f === './' ? 'index.html' : f.replace(/^\.\//, '');
    assert.ok(exists(rel), '预缓存文件不存在: ' + f);
  });
});

test('HTML 接入：manifest、apple-touch-icon、SW 注册', () => {
  const html = read('index.html');
  assert.match(html, /<link rel="manifest" href="manifest\.webmanifest">/);
  assert.match(html, /apple-touch-icon[^>]*apple-touch-icon\.png/);
  assert.match(html, /viewport-fit=cover/);
  assert.match(html, /apple-mobile-web-app-capable/);
  assert.match(read('assets/app.js'), /navigator\.serviceWorker\.register\('\.\/sw\.js'\)/);
});

test('不依赖任何外部网络资源', () => {
  const files = ['index.html', 'assets/app.css', 'assets/app.js', 'assets/core.js', 'assets/charts.js'];
  files.forEach((f) => {
    const text = read(f);
    assert.ok(!/<script[^>]+src="https?:/.test(text), f + ' 引用了外部脚本');
    assert.ok(!/<link[^>]+href="https?:/.test(text), f + ' 引用了外部样式');
    assert.ok(!/url\(\s*['"]?https?:/.test(text), f + ' 引用了外部图片');
  });
});
