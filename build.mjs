/*
 * 构建单文件 HTML：把 CSS / JS / 图标全部内联，
 * 生成 dist/星空记账.html，可直接发给别人、离线打开。
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

let html = read('index.html');
const css = read('assets/app.css');
const core = read('assets/core.js');
const charts = read('assets/charts.js');
const xlsx = read('assets/xlsx.js');
const app = read('assets/app.js');
const icon = read('assets/icon.svg');

for (const [name, src] of [['core', core], ['charts', charts], ['xlsx', xlsx], ['app', app]]) {
  if (src.includes('</script')) throw new Error('assets/' + name + '.js contains </script>, cannot inline');
}

const iconUri = 'data:image/svg+xml;base64,' + Buffer.from(icon).toString('base64');

html = html
  .replace('<link rel="icon" href="assets/icon.svg" type="image/svg+xml">', '<link rel="icon" href="' + iconUri + '">')
  .replace('  <link rel="icon" type="image/png" sizes="192x192" href="assets/icons/icon-192.png">\n', '')
  .replace('  <link rel="apple-touch-icon" sizes="180x180" href="assets/icons/apple-touch-icon.png">\n', '')
  .replace('  <link rel="manifest" href="manifest.webmanifest">\n', '')
  .replace('<link rel="stylesheet" href="assets/app.css">', () => '<style>\n' + css + '\n</style>')
  .replace('<script src="assets/core.js"></script>', () => '<script>\n' + core + '\n</script>')
  .replace('<script src="assets/charts.js"></script>', () => '<script>\n' + charts + '\n</script>')
  .replace('<script src="assets/xlsx.js"></script>', () => '<script>\n' + xlsx + '\n</script>')
  .replace('<script src="assets/app.js"></script>', () => '<script>\n' + app + '\n</script>');

fs.mkdirSync(path.join(root, 'dist'), { recursive: true });
const out = path.join(root, 'dist', '星空记账.html');
fs.writeFileSync(out, html, 'utf8');
console.log('built ' + out + ' (' + (Buffer.byteLength(html) / 1024).toFixed(1) + ' KB)');
