/*
 * 星空记账 · Excel (.xlsx) 读写
 * 不依赖任何第三方库：自己写 ZIP（store）+ SpreadsheetML XML。
 * 导出使用保留压缩方式，任何 Excel/WPS 都能打开；导入依赖浏览器
 * 的 DecompressionStream('deflate-raw') 解压 Excel 生成的 xlsx。
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.LedgerXlsx = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* ------------------------------------------------------------------ *
   * CRC32 / ZIP（store）
   * ------------------------------------------------------------------ */

  const CRC_TABLE = (function () {
    const table = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      table[n] = c >>> 0;
    }
    return table;
  })();

  function crc32(bytes) {
    let c = 0xFFFFFFFF;
    for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    return (c ^ 0xFFFFFFFF) >>> 0;
  }

  function zipStore(files) {
    const encoder = new TextEncoder();
    const locals = [];
    const centrals = [];
    let offset = 0;
    // 1980-01-01 00:00
    const dosTime = 0;
    const dosDate = (1 << 5) | 1;

    files.forEach((file) => {
      const name = encoder.encode(file.name);
      const data = file.data;
      const crc = crc32(data);
      const local = new Uint8Array(30 + name.length + data.length);
      const lv = new DataView(local.buffer);
      lv.setUint32(0, 0x04034B50, true);
      lv.setUint16(4, 20, true);
      lv.setUint16(6, 0x0800, true);
      lv.setUint16(8, 0, true);
      lv.setUint16(10, dosTime, true);
      lv.setUint16(12, dosDate, true);
      lv.setUint32(14, crc, true);
      lv.setUint32(18, data.length, true);
      lv.setUint32(22, data.length, true);
      lv.setUint16(26, name.length, true);
      lv.setUint16(28, 0, true);
      local.set(name, 30);
      local.set(data, 30 + name.length);
      locals.push(local);

      const central = new Uint8Array(46 + name.length);
      const cv = new DataView(central.buffer);
      cv.setUint32(0, 0x02014B50, true);
      cv.setUint16(4, 20, true);
      cv.setUint16(6, 20, true);
      cv.setUint16(8, 0x0800, true);
      cv.setUint16(10, 0, true);
      cv.setUint16(12, dosTime, true);
      cv.setUint16(14, dosDate, true);
      cv.setUint32(16, crc, true);
      cv.setUint32(20, data.length, true);
      cv.setUint32(24, data.length, true);
      cv.setUint16(28, name.length, true);
      cv.setUint16(30, 0, true);
      cv.setUint16(32, 0, true);
      cv.setUint16(34, 0, true);
      cv.setUint16(36, 0, true);
      cv.setUint32(38, 0, true);
      cv.setUint32(42, offset, true);
      central.set(name, 46);
      centrals.push(central);

      offset += local.length;
    });

    const centralSize = centrals.reduce((sum, c) => sum + c.length, 0);
    const end = new Uint8Array(22);
    const ev = new DataView(end.buffer);
    ev.setUint32(0, 0x06054B50, true);
    ev.setUint16(4, 0, true);
    ev.setUint16(6, 0, true);
    ev.setUint16(8, files.length, true);
    ev.setUint16(10, files.length, true);
    ev.setUint32(12, centralSize, true);
    ev.setUint32(16, offset, true);
    ev.setUint16(20, 0, true);

    const total = offset + centralSize + end.length;
    const out = new Uint8Array(total);
    let pos = 0;
    locals.concat(centrals, [end]).forEach((chunk) => {
      out.set(chunk, pos);
      pos += chunk.length;
    });
    return out;
  }

  /* ------------------------------------------------------------------ *
   * XML 工具
   * ------------------------------------------------------------------ */

  function xmlEscape(value) {
    return String(value == null ? '' : value)
      .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  function colLetter(index) {
    let n = index + 1;
    let s = '';
    while (n > 0) {
      const m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = Math.floor((n - 1) / 26);
    }
    return s;
  }

  const CONTENT_TYPES =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
    '</Types>';

  const ROOT_RELS =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
    '</Relationships>';

  const WORKBOOK =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
    '<sheets><sheet name="账单" sheetId="1" r:id="rId1"/></sheets></workbook>';

  const WORKBOOK_RELS =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
    '</Relationships>';

  const STYLES =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    '<fonts count="2">' +
    '<font><sz val="11"/><name val="Calibri"/><family val="2"/></font>' +
    '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>' +
    '</fonts>' +
    '<fills count="3">' +
    '<fill><patternFill patternType="none"/></fill>' +
    '<fill><patternFill patternType="gray125"/></fill>' +
    '<fill><patternFill patternType="solid"><fgColor rgb="FF0E9F6E"/><bgColor indexed="64"/></patternFill></fill>' +
    '</fills>' +
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
    '<cellXfs count="3">' +
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>' +
    '<xf numFmtId="2" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' +
    '</cellXfs>' +
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' +
    '</styleSheet>';

  function sheetXml(headers, rows) {
    const numericCols = {};
    ['金额', '退款', '优惠', '报销金额'].forEach((name) => {
      const idx = headers.indexOf(name);
      if (idx >= 0) numericCols[idx] = true;
    });

    const widths = headers.map((h, i) => {
      let max = String(h).length * 2;
      rows.slice(0, 300).forEach((row) => {
        const v = row[i];
        if (v != null) max = Math.max(max, String(v).length);
      });
      return Math.max(10, Math.min(40, max + 2));
    });

    let xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
      '<dimension ref="A1:' + colLetter(headers.length - 1) + (rows.length + 1) + '"/>' +
      '<sheetViews><sheetView tabSelected="1" workbookViewId="0">' +
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>' +
      '</sheetView></sheetViews>' +
      '<sheetFormatPr defaultRowHeight="16"/>' +
      '<cols>' + widths.map((w, i) => '<col min="' + (i + 1) + '" max="' + (i + 1) + '" width="' + w + '" customWidth="1"/>').join('') + '</cols>' +
      '<sheetData>';

    function cell(ref, value, style) {
      if (value == null || value === '') return '';
      if (typeof value === 'number' && isFinite(value)) {
        return '<c r="' + ref + '" s="' + style + '"><v>' + value + '</v></c>';
      }
      return '<c r="' + ref + '" s="' + style + '" t="inlineStr"><is><t xml:space="preserve">' + xmlEscape(value) + '</t></is></c>';
    }

    xml += '<row r="1" ht="22" customHeight="1">' +
      headers.map((h, i) => cell(colLetter(i) + '1', h, 1)).join('') + '</row>';

    rows.forEach((row, r) => {
      const rowNumber = r + 2;
      let rowXml = '<row r="' + rowNumber + '">';
      let hasValue = false;
      for (let i = 0; i < headers.length; i++) {
        const value = row[i];
        if (value == null || value === '') continue;
        hasValue = true;
        rowXml += cell(colLetter(i) + rowNumber, value, numericCols[i] ? 2 : 0);
      }
      rowXml += '</row>';
      if (hasValue) xml += rowXml;
    });

    xml += '</sheetData><autoFilter ref="A1:' + colLetter(headers.length - 1) + '1"/></worksheet>';
    return xml;
  }

  function buildWorkbook(headers, rows, sheetName) {
    const encoder = new TextEncoder();
    const sheet = sheetXml(headers, rows || []);
    const files = [
      { name: '[Content_Types].xml', data: encoder.encode(CONTENT_TYPES) },
      { name: '_rels/.rels', data: encoder.encode(ROOT_RELS) },
      { name: 'xl/workbook.xml', data: encoder.encode(WORKBOOK) },
      { name: 'xl/_rels/workbook.xml.rels', data: encoder.encode(WORKBOOK_RELS) },
      { name: 'xl/styles.xml', data: encoder.encode(STYLES) },
      { name: 'xl/worksheets/sheet1.xml', data: encoder.encode(sheet) }
    ];
    return zipStore(files);
  }

  /* ------------------------------------------------------------------ *
   * 解压 / 解析
   * ------------------------------------------------------------------ */

  function u16(view, offset) { return view.getUint16(offset, true); }
  function u32(view, offset) { return view.getUint32(offset, true); }

  async function inflateRaw(bytes) {
    if (typeof DecompressionStream === 'undefined') {
      throw new Error('当前浏览器不支持解压 Excel，请使用新版 Chrome / WebView');
    }
    const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
    return new Uint8Array(await new Response(stream).arrayBuffer());
  }

  async function unzip(buffer) {
    const bytes = new Uint8Array(buffer);
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    let eocd = -1;
    const min = Math.max(0, bytes.length - 65557);
    for (let i = bytes.length - 22; i >= min; i--) {
      if (view.getUint32(i, true) === 0x06054B50) { eocd = i; break; }
    }
    if (eocd < 0) throw new Error('不是有效的 xlsx / zip 文件');
    const count = u16(view, eocd + 10);
    const centralOffset = u32(view, eocd + 16);
    const files = {};
    let pos = centralOffset;
    for (let i = 0; i < count; i++) {
      if (u32(view, pos) !== 0x02014B50) throw new Error('xlsx 目录损坏');
      const method = u16(view, pos + 10);
      const compSize = u32(view, pos + 20);
      const nameLen = u16(view, pos + 28);
      const extraLen = u16(view, pos + 30);
      const commentLen = u16(view, pos + 32);
      const localOffset = u32(view, pos + 42);
      const name = new TextDecoder('utf-8').decode(bytes.subarray(pos + 46, pos + 46 + nameLen));
      const localNameLen = u16(view, localOffset + 26);
      const localExtraLen = u16(view, localOffset + 28);
      const dataStart = localOffset + 30 + localNameLen + localExtraLen;
      const raw = bytes.subarray(dataStart, dataStart + compSize);
      files[name] = { method: method, data: raw };
      pos += 46 + nameLen + extraLen + commentLen;
    }
    const out = {};
    for (const name of Object.keys(files)) {
      const entry = files[name];
      if (entry.method === 0) out[name] = entry.data;
      else if (entry.method === 8) out[name] = await inflateRaw(entry.data);
      else throw new Error('不支持的压缩方式: ' + entry.method);
    }
    return out;
  }

  function parseXml(text) {
    const parser = new DOMParser();
    const doc = parser.parseFromString(text, 'application/xml');
    const err = doc.getElementsByTagName('parsererror');
    if (err && err.length) throw new Error('xlsx 中的 XML 解析失败');
    return doc;
  }

  function textOf(node) {
    if (!node) return '';
    const parts = node.getElementsByTagName('t');
    let out = '';
    for (let i = 0; i < parts.length; i++) out += parts[i].textContent || '';
    return out;
  }

  function colIndex(ref) {
    const m = /^([A-Z]+)/.exec(String(ref || ''));
    if (!m) return 0;
    let n = 0;
    for (let i = 0; i < m[1].length; i++) n = n * 26 + (m[1].charCodeAt(i) - 64);
    return n - 1;
  }

  function excelDate(serial) {
    const whole = Math.floor(serial);
    const frac = serial - whole;
    const ms = Math.round((whole - 25569) * 86400000 + Math.round(frac * 86400) * 1000);
    const d = new Date(ms);
    if (isNaN(d.getTime())) return null;
    return d.getUTCFullYear() + '-' +
      String(d.getUTCMonth() + 1).padStart(2, '0') + '-' +
      String(d.getUTCDate()).padStart(2, '0');
  }

  async function parseWorkbook(buffer) {
    const files = await unzip(buffer);
    const shared = {};
    if (files['xl/sharedStrings.xml']) {
      const doc = parseXml(new TextDecoder('utf-8').decode(files['xl/sharedStrings.xml']));
      const items = doc.getElementsByTagName('si');
      for (let i = 0; i < items.length; i++) shared[i] = textOf(items[i]);
    }

    let sheetPath = 'xl/worksheets/sheet1.xml';
    if (!files[sheetPath]) {
      sheetPath = Object.keys(files).find((n) => /^xl\/worksheets\/.*\.xml$/.test(n)) || '';
    }
    if (!sheetPath || !files[sheetPath]) throw new Error('xlsx 中没有工作表');

    const doc = parseXml(new TextDecoder('utf-8').decode(files[sheetPath]));
    const rowNodes = doc.getElementsByTagName('row');
    const rows = [];
    for (let r = 0; r < rowNodes.length; r++) {
      const cells = rowNodes[r].getElementsByTagName('c');
      const row = [];
      for (let c = 0; c < cells.length; c++) {
        const cell = cells[c];
        const ref = cell.getAttribute('r');
        const idx = ref ? colIndex(ref) : c;
        const type = cell.getAttribute('t') || '';
        let value = '';
        if (type === 'inlineStr') {
          value = textOf(cell);
        } else {
          const v = cell.getElementsByTagName('v')[0];
          if (v) {
            if (type === 's') value = shared[Number(v.textContent)] || '';
            else if (type === 'b') value = v.textContent === '1' ? 'TRUE' : 'FALSE';
            else if (type === 'str') value = v.textContent;
            else {
              const num = Number(v.textContent);
              value = isFinite(num) ? num : v.textContent;
            }
          }
        }
        row[idx] = value;
      }
      if (row.some((v) => v !== '' && v != null)) rows.push(row);
    }

    const headers = (rows.shift() || []).map((v) => String(v || '').trim());
    const dateIdx = headers.indexOf('日期');
    if (dateIdx >= 0) {
      rows.forEach((row) => {
        const v = row[dateIdx];
        if (typeof v === 'number' && v > 0) {
          const iso = excelDate(v);
          if (iso) row[dateIdx] = iso;
        }
      });
    }
    return { headers: headers, rows: rows };
  }

  return { buildWorkbook, parseWorkbook, zipStore, crc32 };
});
