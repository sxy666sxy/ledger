/*
 * 星空记账 · 图表
 * 内联 SVG：环形占比、柱状图（支持负数）、折线、收支桑基图。
 */
(function (root) {
  'use strict';

  const FONT = "-apple-system, BlinkMacSystemFont, 'PingFang SC', 'Noto Sans SC', system-ui, sans-serif";
  let gradSeq = 0;

  function sizeOf(el, fallbackW, fallbackH) {
    const w = Math.round(el.clientWidth || (el.getBoundingClientRect && el.getBoundingClientRect().width) || fallbackW);
    const h = Math.round(el.clientHeight || (el.getBoundingClientRect && el.getBoundingClientRect().height) || fallbackH);
    return { w: Math.max(80, w), h: Math.max(60, h) };
  }

  function svgOpen(w, h) {
    return '<svg viewBox="0 0 ' + w + ' ' + h + '" width="100%" height="100%" role="img" ' +
      'font-family="' + FONT + '" xmlns="http://www.w3.org/2000/svg">';
  }

  function roundRect(x, y, w, h, r) {
    const rr = Math.max(0, Math.min(r, Math.abs(w) / 2, Math.abs(h) / 2));
    return 'M' + (x + rr) + ',' + y +
      ' H' + (x + w - rr) + ' A' + rr + ',' + rr + ' 0 0 1 ' + (x + w) + ',' + (y + rr) +
      ' V' + (y + h) +
      ' H' + x + ' V' + (y + rr) + ' A' + rr + ',' + rr + ' 0 0 1 ' + (x + rr) + ',' + y + ' Z';
  }

  function compact(n) {
    const v = Number(n) || 0;
    const a = Math.abs(v);
    if (a >= 100000) return (v / 10000).toFixed(0) + '万';
    if (a >= 10000) return (v / 10000).toFixed(1) + '万';
    if (a >= 1000) return (v / 1000).toFixed(1) + 'k';
    return String(Math.round(v));
  }

  function niceStep(raw) {
    const exp = Math.pow(10, Math.floor(Math.log10(Math.max(Math.abs(raw), 1e-6))));
    const n = Math.abs(raw) / exp;
    const base = n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10;
    return base * exp;
  }

  function xmlEscape(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function donut(el, items, opts) {
    if (!el) return;
    const o = opts || {};
    const { w, h } = sizeOf(el, 176, 176);
    const cx = w / 2, cy = h / 2;
    const thickness = o.thickness || Math.max(12, Math.min(w, h) * 0.115);
    const radius = Math.min(w, h) / 2 - thickness / 2 - 3;
    const total = items.reduce((s, it) => s + (Number(it.value) || 0), 0);
    const emptyColor = o.emptyColor || 'rgba(148,163,184,.18)';
    let inner = '';

    if (!total) {
      inner = '<circle cx="' + cx + '" cy="' + cy + '" r="' + radius + '" fill="none" stroke="' + emptyColor +
        '" stroke-width="' + thickness + '"/>';
    } else {
      const start = -Math.PI / 2;
      const gap = items.length > 1 ? Math.min(0.035, Math.PI * 0.012) : 0;
      let angle = start;
      items.forEach((it) => {
        const value = Math.max(0, Number(it.value) || 0);
        if (!value) return;
        const sweep = (value / total) * Math.PI * 2;
        const a1 = angle + gap / 2;
        const a2 = angle + sweep - gap / 2;
        if (a2 > a1) {
          const x1 = cx + radius * Math.cos(a1);
          const y1 = cy + radius * Math.sin(a1);
          const x2 = cx + radius * Math.cos(a2);
          const y2 = cy + radius * Math.sin(a2);
          const large = sweep > Math.PI ? 1 : 0;
          inner += '<path d="M' + x1.toFixed(2) + ',' + y1.toFixed(2) +
            ' A' + radius + ',' + radius + ' 0 ' + large + ' 1 ' + x2.toFixed(2) + ',' + y2.toFixed(2) + '" ' +
            'fill="none" stroke="' + (it.color || '#0e9f6e') + '" stroke-width="' + thickness + '" stroke-linecap="butt"/>';
        }
        angle += sweep;
      });
    }
    el.innerHTML = svgOpen(w, h) + inner + '</svg>';
  }

  /** 柱状图，支持负值（结余）、数值标签、Y 轴刻度。 */
  function bars(el, data, opts) {
    if (!el) return;
    const o = opts || {};
    const { w, h } = sizeOf(el, 340, 170);
    const values = data.values.map((v) => Number(v) || 0);
    const n = values.length;
    const showValues = !!o.showValues;
    const axis = !!o.axis;
    const padL = axis ? 32 : 6;
    const padR = 8;
    const padTop = showValues ? 24 : 18;
    const padBottom = 22;
    const plotW = w - padL - padR;
    const plotH = h - padTop - padBottom;
    const maxV = Math.max(0, Math.max.apply(null, values.concat([0])));
    const minV = Math.min(0, Math.min.apply(null, values.concat([0])));
    const maxAbs = Math.max(Math.abs(maxV), Math.abs(minV), 1);
    const step = niceStep(maxAbs / 3);
    const top = Math.max(step, Math.ceil(maxV / step) * step);
    const bottom = minV < 0 ? -Math.max(step, Math.ceil(-minV / step) * step) : 0;
    const domain = Math.max(top - bottom, step);
    const zeroY = padTop + plotH - ((0 - bottom) / domain) * plotH;
    const yOf = (v) => padTop + plotH - ((v - bottom) / domain) * plotH;
    const gridColor = o.gridColor || 'rgba(148,163,184,.18)';
    const labelColor = o.labelColor || 'rgba(100,116,139,.85)';
    const textColor = o.textColor || '#101c16';
    const negativeColor = o.negativeColor || '#e5484d';
    const highlight = data.highlight == null ? n - 1 : data.highlight;
    const nLabel = n <= 12 ? 1 : (o.labelEvery || 2);
    let inner = '';

    // 横向网格 / Y 轴刻度
    for (let i = 0; i <= 4; i++) {
      const v = bottom + (domain * i) / 4;
      const y = yOf(v);
      inner += '<line x1="' + padL + '" y1="' + y.toFixed(1) + '" x2="' + (w - padR) + '" y2="' + y.toFixed(1) +
        '" stroke="' + gridColor + '" stroke-width="1" stroke-dasharray="3 5"/>';
      if (axis) {
        inner += '<text x="' + (padL - 5) + '" y="' + (y + 3).toFixed(1) + '" text-anchor="end" font-size="9" fill="' + labelColor + '">' +
          compact(v) + '</text>';
      }
    }
    if (bottom < 0) {
      inner += '<line x1="' + padL + '" y1="' + zeroY.toFixed(1) + '" x2="' + (w - padR) + '" y2="' + zeroY.toFixed(1) +
        '" stroke="' + (o.zeroColor || 'rgba(100,116,139,.35)') + '" stroke-width="1"/>';
    }

    const slot = plotW / Math.max(n, 1);
    const barW = Math.min(o.barWidth || 22, slot * 0.56);
    values.forEach((v, i) => {
      const x = padL + slot * i + (slot - barW) / 2;
      const y = yOf(Math.max(v, 0));
      const yTop = Math.min(yOf(0), yOf(v));
      const bh = Math.max(Math.abs(yOf(v) - yOf(0)), v === 0 ? 0 : 2);
      const hot = i === highlight;
      let color = v < 0 ? negativeColor : (hot ? (o.color || '#0e9f6e') : (o.mutedColor || 'rgba(14,159,110,.28)'));
      if (bh > 0) {
        inner += '<path d="' + roundRect(x, yTop, barW, bh, Math.min(6, barW / 2)) + '" fill="' + color + '"/>';
      }
      if (showValues && n <= 16 && v !== 0) {
        const labelY = v >= 0 ? Math.max(11, yTop - 6) : Math.min(h - 4, yTop + bh + 12);
        inner += '<text x="' + (x + barW / 2) + '" y="' + labelY + '" text-anchor="middle" font-size="9.5" font-weight="600" fill="' +
          (v < 0 ? negativeColor : textColor) + '">' + compact(v) + '</text>';
      }
      if (i % nLabel === 0 || i === n - 1) {
        inner += '<text x="' + (x + barW / 2) + '" y="' + (h - 5) + '" text-anchor="middle" font-size="9.5" font-weight="' +
          (hot ? 600 : 500) + '" fill="' + labelColor + '">' + xmlEscape(data.labels[i] || '') + '</text>';
      }
    });

    el.innerHTML = svgOpen(w, h) + inner + '</svg>';
  }

  /** 折线图；domain='minmax' 用于资产走势。 */
  function line(el, data, opts) {
    if (!el) return;
    const o = opts || {};
    const { w, h } = sizeOf(el, 340, 130);
    const axis = !!o.axis;
    const padL = axis ? 34 : 8;
    const padR = 8, padTop = 14, padBottom = 18;
    const plotW = w - padL - padR;
    const plotH = h - padTop - padBottom;
    const values = data.values.map((v) => Number(v) || 0);
    let minV = 0;
    let maxV = Math.max.apply(null, values.concat([1]));
    if (o.domain === 'minmax') {
      minV = Math.min.apply(null, values);
      maxV = Math.max.apply(null, values);
      const pad = (maxV - minV || 1) * 0.08;
      minV -= pad;
      maxV += pad;
    }
    const range = Math.max(maxV - minV, 1e-6);
    const n = values.length;
    const pts = values.map((v, i) => ({
      x: padL + (n === 1 ? plotW / 2 : (plotW * i) / (n - 1)),
      y: padTop + plotH - ((v - minV) / range) * plotH
    }));
    const id = 'grad' + (++gradSeq);
    const color = o.color || '#0e9f6e';
    const gridColor = o.gridColor || 'rgba(148,163,184,.16)';
    const labelColor = o.labelColor || 'rgba(100,116,139,.8)';

    let inner = '<defs><linearGradient id="' + id + '" x1="0" y1="0" x2="0" y2="1">' +
      '<stop offset="0" stop-color="' + color + '" stop-opacity="0.22"/>' +
      '<stop offset="1" stop-color="' + color + '" stop-opacity="0"/>' +
      '</linearGradient></defs>';

    if (axis) {
      for (let i = 0; i <= 3; i++) {
        const v = minV + (range * i) / 3;
        const y = padTop + plotH - (plotH * i) / 3;
        inner += '<line x1="' + padL + '" y1="' + y.toFixed(1) + '" x2="' + (w - padR) + '" y2="' + y.toFixed(1) +
          '" stroke="' + gridColor + '" stroke-width="1" stroke-dasharray="3 5"/>' +
          '<text x="' + (padL - 5) + '" y="' + (y + 3).toFixed(1) + '" text-anchor="end" font-size="8.5" fill="' + labelColor + '">' +
          compact(v) + '</text>';
      }
    }

    const lineD = pts.map((p, i) => {
      if (i === 0) return 'M' + p.x.toFixed(1) + ',' + p.y.toFixed(1);
      const prev = pts[i - 1];
      const mx = (prev.x + p.x) / 2;
      return 'C' + mx.toFixed(1) + ',' + prev.y.toFixed(1) + ' ' + mx.toFixed(1) + ',' + p.y.toFixed(1) +
        ' ' + p.x.toFixed(1) + ',' + p.y.toFixed(1);
    }).join(' ');
    const areaPath = lineD + ' L' + pts[n - 1].x.toFixed(1) + ',' + (padTop + plotH) +
      ' L' + pts[0].x.toFixed(1) + ',' + (padTop + plotH) + ' Z';

    inner += '<path d="' + areaPath + '" fill="url(#' + id + ')"/>' +
      '<path d="' + lineD + '" fill="none" stroke="' + color + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>';

    let maxIdx = 0, minIdx = 0;
    values.forEach((v, i) => {
      if (v > values[maxIdx]) maxIdx = i;
      if (v < values[minIdx]) minIdx = i;
    });
    if (o.dot !== false) {
      const p = pts[maxIdx];
      inner += '<circle cx="' + p.x.toFixed(1) + '" cy="' + p.y.toFixed(1) + '" r="3.2" fill="' + color + '" stroke="#fff" stroke-width="1.3"/>';
    }
    inner += '<text x="' + padL + '" y="' + (h - 4) + '" font-size="9.5" fill="' + labelColor + '">' + xmlEscape(data.labels[0] || '') + '</text>' +
      '<text x="' + (w - padR) + '" y="' + (h - 4) + '" text-anchor="end" font-size="9.5" fill="' + labelColor + '">' +
      xmlEscape(data.labels[data.labels.length - 1] || '') + '</text>';

    el.innerHTML = svgOpen(w, h) + inner + '</svg>';
  }

  /** 收支桑基图：收入 → 支出分类 + 结余。 */
  function sankey(el, data, opts) {
    if (!el) return;
    const o = opts || {};
    const { w, h } = sizeOf(el, 340, 220);
    const income = Math.max(0, Number(data.income) || 0);
    const expense = Math.max(0, Number(data.expense) || 0);
    const balance = Math.max(0, income - expense);
    const nodes = (data.nodes || []).filter((n) => n && Number(n.value) > 0);
    if (balance > 0) nodes.push({ name: '结余', value: balance, color: '#0e9f6e', balance: true });
    if (!nodes.length && !income) {
      el.innerHTML = svgOpen(w, h) + '<text x="' + (w / 2) + '" y="' + (h / 2) + '" text-anchor="middle" font-size="12" fill="#93a29a">本月没有收支数据</text></svg>';
      return;
    }
    const totalOut = nodes.reduce((s, n) => s + Number(n.value), 0) || expense;
    const scaleTotal = Math.max(income, totalOut, 1);
    const padTop = 30, padBottom = 18;
    const plotH = h - padTop - padBottom;
    const gap = 7;
    const avail = plotH - gap * Math.max(0, nodes.length - 1);
    const scale = Math.max(0.0001, avail / scaleTotal);
    const leftX = 8, leftW = 9;
    const centerX = Math.round(w * 0.44), centerW = 12;
    const rightX = w - 34, rightW = 8;
    const leftH = Math.max(1, income * scale);
    const leftY = padTop + (plotH - leftH) / 2;
    const centerTop = padTop;
    const centerH = Math.max(1, totalOut * scale) + gap * Math.max(0, nodes.length - 1);
    const centerY = padTop + (plotH - centerH) / 2;

    let inner = '';
    // 左：收入 → 中央
    inner += '<path d="M' + (leftX + leftW) + ',' + leftY.toFixed(1) +
      ' C' + (centerX - 22) + ',' + leftY.toFixed(1) + ' ' + (centerX - 22) + ',' + centerTop.toFixed(1) +
      ' ' + centerX + ',' + centerTop.toFixed(1) +
      ' L' + centerX + ',' + (centerTop + centerH).toFixed(1) +
      ' C' + (centerX - 22) + ',' + (centerTop + centerH).toFixed(1) + ' ' + (centerX - 22) + ',' + (leftY + leftH).toFixed(1) +
      ' ' + (leftX + leftW) + ',' + (leftY + leftH).toFixed(1) + ' Z" fill="rgba(14,159,110,.18)"/>';
    inner += '<rect x="' + leftX + '" y="' + leftY.toFixed(1) + '" width="' + leftW + '" height="' + leftH.toFixed(1) +
      '" rx="4" fill="#0e9f6e"/>';
    inner += '<text x="' + leftX + '" y="' + (padTop - 12) + '" font-size="9" fill="#5b6d64">收入</text>' +
      '<text x="' + leftX + '" y="' + (padTop - 2) + '" font-size="10" font-weight="700" fill="#0e9f6e">¥' + compact(income) + '</text>';

    // 中：汇总条
    inner += '<rect x="' + centerX + '" y="' + centerY.toFixed(1) + '" width="' + centerW + '" height="' + centerH.toFixed(1) +
      '" rx="3" fill="#0e9f6e"/>' +
      '<text x="' + (centerX + centerW / 2) + '" y="' + (padTop - 12) + '" text-anchor="middle" font-size="9" fill="#5b6d64">支出</text>' +
      '<text x="' + (centerX + centerW / 2) + '" y="' + (padTop - 2) + '" text-anchor="middle" font-size="10" font-weight="700" fill="#e5484d">¥' + compact(expense) + '</text>';

    // 右：分类 / 结余
    let rightY = padTop;
    let centerCursor = centerY;
    nodes.forEach((node, i) => {
      const nh = Math.max(1, Number(node.value) * scale);
      const nodeColor = node.color || (node.balance ? '#0e9f6e' : '#f59e0b');
      const ny = rightY;
      const startY = centerCursor;
      const endY = centerCursor + nh;
      centerCursor = endY + gap;
      rightY += nh + gap;
      // 流带
      const x1 = centerX + centerW;
      const x2 = rightX;
      inner += '<path d="M' + x1 + ',' + startY.toFixed(1) +
        ' C' + (x1 + 30) + ',' + startY.toFixed(1) + ' ' + (x2 - 30) + ',' + ny.toFixed(1) + ' ' + x2 + ',' + ny.toFixed(1) +
        ' L' + x2 + ',' + (ny + nh).toFixed(1) +
        ' C' + (x2 - 30) + ',' + (ny + nh).toFixed(1) + ' ' + (x1 + 30) + ',' + endY.toFixed(1) + ' ' + x1 + ',' + endY.toFixed(1) + ' Z" ' +
        'fill="' + nodeColor + '" fill-opacity="' + (node.balance ? '0.32' : '0.22') + '"/>';
      inner += '<rect x="' + rightX + '" y="' + ny.toFixed(1) + '" width="' + rightW + '" height="' + nh.toFixed(1) +
        '" rx="3" fill="' + nodeColor + '"/>';
    });

    if (expense > income) {
      inner += '<text x="' + (w - 8) + '" y="' + (h - 3) + '" text-anchor="end" font-size="9" fill="#e5484d">本月超支 ¥' +
        (expense - income).toFixed(2) + '</text>';
    }
    el.innerHTML = svgOpen(w, h) + inner + '</svg>';
  }

  root.LedgerCharts = { donut, bars, line, sankey };
})(typeof self !== 'undefined' ? self : this);
