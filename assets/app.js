/*
 * 星空记账 · 界面与交互
 * 原生 JS，无框架、无外部资源，离线可用。
 */
(function () {
  'use strict';

  const C = window.LedgerCore;
  const CH = window.LedgerCharts;
  const STORAGE_KEY = 'xingkong.ledger.v4';
  const VERSION_TEXT = '2.1.13';
  const THEMES = [
    { id: 'auto', name: '跟随系统', desc: '自动切换浅色 / 深色', emoji: '🌓', sw: 'auto' },
    { id: 'light', name: '星空浅色', desc: '靛蓝星夜', emoji: '✦', sw: 'light' },
    { id: 'dark', name: '星空深色', desc: '深夜银河', emoji: '🌌', sw: 'dark' },
    { id: 'grass', name: '草原', desc: '风吹草低', emoji: '🌿', sw: 'grass' },
    { id: 'sky', name: '天空', desc: '晴空万里', emoji: '☁️', sw: 'sky' },
    { id: 'cloud', name: '白云', desc: '云朵与风', emoji: '☁️', sw: 'cloud' },
    { id: 'castle', name: '粉色城堡', desc: '玫瑰与塔楼', emoji: '🏰', sw: 'castle' },
    { id: 'wheat', name: '麦田', desc: '金色麦浪', emoji: '🌾', sw: 'wheat' },
    { id: 'snow', name: '白雪', desc: '雪落无声', emoji: '❄️', sw: 'snow' },
    { id: 'storm', name: '闪电', desc: '雷雨夜行', emoji: '⚡', sw: 'storm' },
    { id: 'wave', name: '波浪', desc: '潮汐海岸', emoji: '🌊', sw: 'wave' },
    { id: 'ocean', name: '海底', desc: '深海微光', emoji: '🐚', sw: 'ocean' },
    { id: 'custom', name: '自定义图片', desc: '导入一张图片作为背景', emoji: '🖼️', sw: 'custom' }
  ];
  const THEME_META = {
    light: { dark: false, color: '#5b6cff' }, dark: { dark: true, color: '#070a17' },
    grass: { dark: false, color: '#2e8b57' }, sky: { dark: false, color: '#2f80ed' },
    cloud: { dark: false, color: '#6c8ab8' }, castle: { dark: false, color: '#d65a9a' },
    wheat: { dark: false, color: '#c08a2e' }, snow: { dark: false, color: '#5b8ec9' },
    storm: { dark: true, color: '#141821' }, wave: { dark: false, color: '#168a9e' },
    ocean: { dark: true, color: '#071a2c' },
    custom: { dark: false, color: '#5b6cff' }
  };
  function themeById(id) { return THEMES.find((t) => t.id === id) || THEMES[0]; }
  function isDarkTheme(id) { return !!(THEME_META[id] && THEME_META[id].dark); }

  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.prototype.slice.call((root || document).querySelectorAll(sel));

  const appEl = document.getElementById('app');
  const appbarEl = document.getElementById('appbar');
  const viewEl = document.getElementById('view');
  const tabbarEl = document.getElementById('tabbar');
  const overlayRoot = document.getElementById('overlay-root');
  const toastRoot = document.getElementById('toast-root');
  const lockEl = document.getElementById('lock-screen');

  /* ------------------------------------------------------------------ *
   * 小工具
   * ------------------------------------------------------------------ */

  function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, (ch) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[ch]));
  }

  function alpha(hex, a) {
    const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(String(hex || ''));
    if (!m) return 'rgba(148,163,184,' + (a == null ? 0.12 : a) + ')';
    return 'rgba(' + parseInt(m[1], 16) + ',' + parseInt(m[2], 16) + ',' + parseInt(m[3], 16) + ',' + (a == null ? 0.12 : a) + ')';
  }

  function pad2(n) { return (n < 10 ? '0' : '') + n; }

  function shortMoney(v) {
    const n = Math.round(Number(v) || 0);
    if (n >= 100000) return (n / 10000).toFixed(0) + '万';
    if (n >= 10000) return (n / 10000).toFixed(1) + '万';
    return String(n);
  }

  function compactMoney(v) {
    const n = Number(v) || 0;
    if (n >= 100000) return (n / 10000).toFixed(0) + '万';
    if (n >= 10000) return (n / 10000).toFixed(1) + '万';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'k';
    return String(Math.round(n));
  }

  const ICONS = {
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.6-3.6"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18"/><path d="M8 14h2M14 14h2M8 17.5h2M14 17.5h2"/>',
    settings: '<path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/>',
    list: '<path d="M9 6h12M9 12h12M9 18h12"/><circle cx="4.5" cy="6" r="1.3" fill="currentColor" stroke="none"/><circle cx="4.5" cy="12" r="1.3" fill="currentColor" stroke="none"/><circle cx="4.5" cy="18" r="1.3" fill="currentColor" stroke="none"/>',
    pie: '<path d="M12 3.2a8.8 8.8 0 1 0 8.8 8.8H12V3.2Z"/><path d="M15 3.6A8.8 8.8 0 0 1 20.4 9H15V3.6Z"/>',
    wallet: '<rect x="3" y="6" width="18" height="14" rx="3"/><path d="M3 10h18"/><path d="M16.5 15.2h2"/>',
    user: '<circle cx="12" cy="8" r="3.5"/><path d="M4.8 20c1.2-3.5 3.9-5.3 7.2-5.3s6 1.8 7.2 5.3"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    close: '<path d="m6 6 12 12M18 6 6 18"/>',
    left: '<path d="m15 5-7 7 7 7"/>',
    right: '<path d="m9 5 7 7-7 7"/>',
    down: '<path d="m6 9 6 6 6-6"/>',
    swap: '<path d="M7 7h12l-3.2-3.2M17 17H5l3.2 3.2"/>',
    trash: '<path d="M4 7h16M9.5 7V5h5v2M6.5 7 7.5 20h9L17.5 7"/><path d="M10 11v5M14 11v5"/>',
    download: '<path d="M12 4v11M7.5 11l4.5 4.5L16.5 11"/><path d="M4.5 19.5h15"/>',
    upload: '<path d="M12 19V8M7.5 12 12 7.5 16.5 12"/><path d="M4.5 4.5h15"/>',
    tag: '<path d="M4 5h9l7 7-8 8-8-8V5Z"/><circle cx="8.5" cy="9.5" r="1.3"/>',
    check: '<path d="m5 12.5 4.5 4.5L19 6.5"/>',
    edit: '<path d="M4 20h4L19.5 8.5a2.1 2.1 0 0 0-3-3L5 17v3Z"/><path d="m14.5 5.5 3 3"/>',
    lock: '<rect x="4.5" y="10" width="15" height="10" rx="3"/><path d="M8 10V7.5a4 4 0 0 1 8 0V10"/>',
    spark: '<path d="M12 3.5 13.8 9l5.7 1.8-5.7 1.8L12 18l-1.8-5.4L4.5 10.8 10.2 9 12 3.5Z"/>',
    repeat: '<path d="M4.5 9.5A5 5 0 0 1 9.5 4.5H19l-3-3M19.5 14.5a5 5 0 0 1-5 5H4.5l3 3"/>',
    grid: '<rect x="4" y="4" width="6.5" height="6.5" rx="2"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="2"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="2"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="2"/>',
    info: '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.8v.4"/>',
    moon: '<path d="M19 14.5A7.5 7.5 0 0 1 9.5 5 8 8 0 1 0 19 14.5Z"/>',
    more: '<circle cx="12" cy="5" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="19" r="1.6" fill="currentColor" stroke="none"/>',
    book: '<path d="M5 4.5h11a3 3 0 0 1 3 3V20H8a3 3 0 0 1-3-3V4.5Z"/><path d="M5 16.5h14"/>'
  };

  function svg(name, size) {
    return '<svg viewBox="0 0 24 24" width="' + (size || 22) + '" height="' + (size || 22) +
      '" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      (ICONS[name] || '') + '</svg>';
  }

  function cssVar(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || '#0e9f6e';
  }

  /* ------------------------------------------------------------------ *
   * 全局状态
   * ------------------------------------------------------------------ */

  const state = {
    data: null,
    route: 'home',
    month: C.thisMonthKey(),
    statsMonth: C.thisMonthKey(),
    statsMode: 'month',
    statsType: 'expense',
    statsShareType: 'expense',
    statsSankey: 'category',
    statsYear: Number(C.thisMonthKey().slice(0, 4)),
    statsYearAll: false,
    statsChartType: 'bar',
    statsHeatType: 'expense',
    statsSummaryOpen: false,
    statsCustomFrom: C.addDaysISO(C.todayISO(), -6),
    statsCustomTo: C.todayISO(),
    statsSwipe: 0,
    calendarMonth: C.thisMonthKey(),
    calendarSelected: C.todayISO(),
    selectMode: false,
    selectedIds: [],
    suppressClickUntil: 0,
    chartSig: ''
  };

  function saveData() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state.data));
      return true;
    } catch (err) {
      toast('保存失败：本地存储空间不足', 'error');
      return false;
    }
  }

  function loadData() {
    let raw = null;
    try { raw = localStorage.getItem(STORAGE_KEY); } catch (err) { raw = null; }
    if (raw) {
      try {
        const parsed = JSON.parse(raw);
        const migrated = C.migrateData(parsed);
        if (migrated) return migrated;
      } catch (err) { /* 损坏则重新开始 */ }
    }
    const data = C.createDefaultData({ demo: true });
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(data)); } catch (err) { /* ignore */ }
    return data;
  }

  function resolveTheme() {
    const setting = state.data.settings.theme;
    if (setting === 'auto') {
      return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    if (THEMES.some((t) => t.id === setting)) return setting;
    return 'light';
  }

  function applyTheme() {
    const theme = resolveTheme();
    document.documentElement.setAttribute('data-theme', theme);
    try {
      const img = state.data && state.data.settings && state.data.settings.customThemeImage;
      if (theme === 'custom' && img) document.documentElement.style.setProperty('--custom-image', 'url("' + img + '")');
      else document.documentElement.style.removeProperty('--custom-image');
    } catch (err) { /* ignore */ }
    document.documentElement.setAttribute('data-dark', isDarkTheme(theme) ? '1' : '0');
    const meta = document.getElementById('themeColor');
    const metaInfo = THEME_META[theme] || THEME_META.light;
    if (meta) meta.setAttribute('content', metaInfo.color);
    try {
      if (window.AndroidBridge && window.AndroidBridge.setSystemBars) window.AndroidBridge.setSystemBars(metaInfo.dark);
    } catch (err) { /* 非 Android 环境 */ }
    state.chartSig = '';
  }

  function themeEmptyIcon() {
    const theme = resolveTheme();
    const map = {
      grass: '🌿', sky: '☁️', cloud: '☁️', castle: '🏰', wheat: '🌾',
      snow: '❄️', storm: '⚡', wave: '🌊', ocean: '🐚', custom: '🖼️'
    };
    return map[theme] || '✦';
  }

  function applyInsets() {
    try {
      if (!window.AndroidBridge) return;
      const st = window.AndroidBridge.getStatusBarHeight ? window.AndroidBridge.getStatusBarHeight() : 0;
      const nb = window.AndroidBridge.getNavigationBarHeight ? window.AndroidBridge.getNavigationBarHeight() : 0;
      // 原生返回的是物理像素；CSS 需要 dp/CSS px，必须除以 devicePixelRatio。
      const dpr = window.devicePixelRatio || 1;
      if (st > 0) document.documentElement.style.setProperty('--safe-t', Math.round(st / dpr) + 'px');
      if (nb > 0) document.documentElement.style.setProperty('--safe-b', Math.round(nb / dpr) + 'px');
    } catch (err) { /* web */ }
  }

  function toast(message, type) {
    const node = document.createElement('div');
    node.className = 'toast' + (type ? ' ' + type : '');
    node.textContent = message;
    toastRoot.appendChild(node);
    window.setTimeout(() => {
      node.style.transition = 'opacity .25s, transform .25s';
      node.style.opacity = '0';
      node.style.transform = 'translateY(6px)';
      window.setTimeout(() => node.remove(), 260);
    }, 2100);
  }

  function openSheet(opts) {
    const o = opts || {};
    const backdrop = document.createElement('div');
    backdrop.className = 'sheet-backdrop';
    backdrop.innerHTML =
      '<div class="sheet ' + (o.className || '') + '" role="dialog" aria-modal="true">' +
        '<div class="sheet-grab"></div>' +
        '<div class="sheet-head">' +
          '<div class="grow"><div class="sheet-title">' + (o.title || '') + '</div>' +
          (o.subtitle ? '<div class="sheet-sub">' + o.subtitle + '</div>' : '') + '</div>' +
          '<button class="icon-btn small" data-close aria-label="关闭">' + svg('close', 18) + '</button>' +
        '</div>' +
        '<div class="sheet-body' + (o.flush ? ' flush' : '') + '">' + (o.content || '') + '</div>' +
        (o.footer ? '<div class="sheet-actions">' + o.footer + '</div>' : '') +
      '</div>';
    overlayRoot.appendChild(backdrop);
    document.body.classList.add('no-scroll');

    const sheet = backdrop.querySelector('.sheet');
    let closed = false;
    function close() {
      if (closed) return;
      closed = true;
      backdrop.remove();
      if (!overlayRoot.children.length) document.body.classList.remove('no-scroll');
      if (o.onClose) o.onClose();
    }
    backdrop.addEventListener('click', (e) => { if (e.target === backdrop) close(); });
    sheet.querySelector('[data-close]').addEventListener('click', close);
    if (o.onMount) o.onMount(sheet, close, backdrop);
    return { close, sheet, backdrop };
  }

  function confirmDialog(opts) {
    const o = opts || {};
    return new Promise((resolve) => {
      const backdrop = document.createElement('div');
      backdrop.className = 'modal-backdrop';
      backdrop.innerHTML =
        '<div class="modal">' +
          '<h3>' + esc(o.title || '请确认') + '</h3>' +
          '<p>' + (o.message || '') + '</p>' +
          '<div class="modal-actions">' +
            '<button class="btn ghost" data-no>' + esc(o.cancelText || '取消') + '</button>' +
            '<button class="btn ' + (o.danger ? 'danger' : 'primary') + '" data-yes>' + esc(o.confirmText || '确定') + '</button>' +
          '</div>' +
        '</div>';
      overlayRoot.appendChild(backdrop);
      document.body.classList.add('no-scroll');
      const done = (value) => {
        backdrop.remove();
        if (!overlayRoot.children.length) document.body.classList.remove('no-scroll');
        resolve(value);
      };
      backdrop.addEventListener('click', (e) => { if (e.target === backdrop) done(false); });
      backdrop.querySelector('[data-no]').addEventListener('click', () => done(false));
      backdrop.querySelector('[data-yes]').addEventListener('click', () => done(true));
    });
  }

  function download(filename, content, mime) {
    try {
      let blob;
      if (content instanceof Blob) blob = content;
      else if (content instanceof Uint8Array) blob = new Blob([content], { type: mime || 'application/octet-stream' });
      else blob = new Blob([content], { type: mime || 'text/plain;charset=utf-8' });

      // Android WebView 壳：通过 SAF 保存文件
      if (window.AndroidBridge && window.AndroidBridge.saveFile) {
        const reader = new FileReader();
        reader.onload = function () {
          const raw = String(reader.result || '');
          const comma = raw.indexOf(',');
          const cleanMime = (mime || 'application/octet-stream').split(';')[0];
          window.AndroidBridge.saveFile(filename, comma >= 0 ? raw.slice(comma + 1) : raw, cleanMime);
        };
        reader.readAsDataURL(blob);
        return true;
      }
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.style.display = 'none';
      document.body.appendChild(a);
      a.click();
      window.setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 2000);
      return true;
    } catch (err) {
      toast('导出失败：' + err.message, 'error');
      return false;
    }
  }

  function todayText() {
    return C.fullDateLabel(C.todayISO()) + ' · ' + C.weekdayCN(C.todayISO());
  }

  /* ------------------------------------------------------------------ *
   * 框架渲染
   * ------------------------------------------------------------------ */

  function appbarHTML(route, statsMode) {
    if (route === 'calendar' || route === 'profile' || route === 'assets') return null;
    if (route === 'home') {
      const book = C.activeBook(state.data);
      return '<div class="appbar-inner">' +
          '<button class="book-chip" data-act="open-books" aria-label="切换账本">' +
            '<span class="emoji">' + book.icon + '</span>' +
            '<span class="ellipsis">' + esc(book.name) + '</span>' +
            '<span class="chev">▼</span>' +
          '</button>' +
          '<div class="appbar-actions">' +
            '<button class="icon-btn" data-act="open-search" aria-label="搜索账单">' + svg('search', 21) + '</button>' +
            '<button class="icon-btn" data-act="open-calendar" aria-label="账单日历">' + svg('calendar', 21) + '</button>' +
          '</div>' +
        '</div>';
    }
    if (route === 'stats') {
      const tabs = [['daily', '日常'], ['month', '月统计'], ['year', '年统计'], ['custom', '自定义']];
      return '<div class="appbar-inner stats-appbar">' +
          '<div class="stats-tabs">' + tabs.map((t) => (
            '<button class="stats-tab' + (statsMode === t[0] ? ' active' : '') + '" data-act="stats-mode" data-mode="' + t[0] + '">' + t[1] + '</button>'
          )).join('') + '</div>' +
          '<button class="icon-btn small" data-act="open-stats-menu" aria-label="统计说明">' + svg('more', 19) + '</button>' +
        '</div>';
    }
    return null;
  }

  function renderAppbar() {
    appbarEl.style.visibility = '';
    const html = appbarHTML(state.route, state.statsMode);
    if (html == null) {
      appbarEl.hidden = true;
      appbarEl.innerHTML = '';
      return;
    }
    appbarEl.hidden = false;
    appbarEl.innerHTML = html;
  }

  function renderTabbar() {
    const tabs = [
      ['home', '明细', 'list'],
      ['calendar', '日历', 'calendar'],
      ['stats', '统计', 'pie'],
      ['assets', '资产', 'wallet'],
      ['profile', '我的', 'user']
    ];
    tabbarEl.innerHTML = tabs.map((t) => {
      const active = state.route === t[0];
      return '<button class="tab' + (active ? ' active' : '') + '" data-act="go" data-route="' + t[0] + '">' +
        svg(t[2], 21) + '<span>' + t[1] + '</span></button>';
    }).join('') + (state.selectMode || state.route !== 'home' ? '' :
      '<button class="fab-add" data-act="open-entry" aria-label="记一笔">' + svg('plus', 25) + '</button>');
  }

  function statsCarouselHTML() {
    const modes = ['daily', 'month', 'year', 'custom'];
    const index = Math.max(0, modes.indexOf(state.statsMode));
    return '<div class="stats-carousel" data-stats-carousel>' +
      '<div class="stats-track" data-stats-track style="transform:translate3d(-' + (index * 25) + '%,0,0)">' +
        modes.map((m) => '<div class="stats-pane" data-stats-pane="' + m + '">' + statsHTML(m, '-' + m) + '</div>').join('') +
      '</div>' +
    '</div>';
  }

  function statsCarouselHeight() {
    const carousel = document.querySelector('[data-stats-carousel]');
    if (!carousel) return;
    const active = carousel.querySelector('[data-stats-pane="' + state.statsMode + '"]');
    if (active) carousel.style.height = active.offsetHeight + 'px';
  }

  function mountStatsCarousel() {
    ['daily', 'month', 'year', 'custom'].forEach((m) => mountStatsCharts(m, '-' + m));
    wireStatsSwipe();
    window.requestAnimationFrame(() => {
      statsCarouselHeight();
      window.setTimeout(statsCarouselHeight, 80);
    });
  }

  function remountStatsPanes() {
    if (state.route !== 'stats') return;
    ['daily', 'month', 'year', 'custom'].forEach((m) => mountStatsCharts(m, '-' + m));
    statsCarouselHeight();
  }

  function wireStatsSwipe() {
    const carousel = document.querySelector('[data-stats-carousel]');
    const track = carousel && carousel.querySelector('[data-stats-track]');
    if (!carousel || !track || carousel.dataset.swiped === '1') return;
    carousel.dataset.swiped = '1';
    const modes = ['daily', 'month', 'year', 'custom'];
    let index = Math.max(0, modes.indexOf(state.statsMode));
    let sx = null, sy = null, dx = 0, horizontal = false, animating = false;
    const width = () => carousel.clientWidth || 320;

    function apply(i, extra) {
      track.style.transform = 'translate3d(calc(-' + (i * 25) + '% + ' + (extra || 0) + 'px),0,0)';
    }
    function reset() {
      track.style.transition = 'transform .22s cubic-bezier(.22,.8,.28,1)';
      apply(index, 0);
      horizontal = false;
    }

    carousel.addEventListener('touchstart', (e) => {
      if (animating) return;
      if (e.target.closest('button, input, .month-rail, .stats-chart-controls, .stats-chart-type, .stats-tabs, .heat-year-grid, .sheet, .stats-table')) return;
      sx = e.touches[0].clientX; sy = e.touches[0].clientY; dx = 0; horizontal = false;
      track.style.transition = 'none';
    }, { passive: true });

    carousel.addEventListener('touchmove', (e) => {
      if (sx == null || animating) return;
      dx = e.touches[0].clientX - sx;
      const dy = e.touches[0].clientY - sy;
      if (Math.abs(dx) > 9 && Math.abs(dx) > Math.abs(dy)) {
        horizontal = true;
      }
      if (!horizontal) return;
      if ((index === 0 && dx > 0) || (index === modes.length - 1 && dx < 0)) return;
      if (e.cancelable) e.preventDefault();
      const max = width() * 0.86;
      const clamped = Math.max(-max, Math.min(max, dx));
      apply(index, clamped);
    }, { passive: false });

    carousel.addEventListener('touchend', () => {
      if (sx == null) return;
      if (horizontal && ((index === 0 && dx > 0) || (index === modes.length - 1 && dx < 0))) {
        sx = null; sy = null; horizontal = false;
        return;
      }
      const threshold = Math.min(72, width() * 0.18);
      const target = dx < 0 ? Math.min(modes.length - 1, index + 1) : Math.max(0, index - 1);
      const should = horizontal && Math.abs(dx) > threshold && target !== index;
      sx = null; sy = null;
      if (!should) {
        if (target !== index) { reset(); return; }
        reset(); return;
      }
      animating = true;
      state.suppressClickUntil = Date.now() + 450;
      track.style.transition = 'transform .24s cubic-bezier(.22,.8,.28,1)';
      apply(target, 0);
      window.setTimeout(() => {
        animating = false;
        index = target;
        state.statsMode = modes[target];
        renderAppbar();
        statsCarouselHeight();
        window.scrollTo(0, 0);
      }, 245);
      horizontal = false;
    }, { passive: true });
  }

  function renderView() {
    if (state.route === 'home') viewEl.innerHTML = homeHTML();
    else if (state.route === 'calendar') { viewEl.innerHTML = calendarHTML(); wireCalendarSwipe(); }
    else if (state.route === 'stats') { viewEl.innerHTML = statsCarouselHTML(); statsCarouselHeight(); mountStatsCarousel(); }
    else if (state.route === 'assets') viewEl.innerHTML = assetsHTML();
    else viewEl.innerHTML = profileHTML();
  }

  function render() {
    document.body.dataset.route = state.route;
    renderAppbar();
    renderTabbar();
    renderView();
  }

  function go(route, dir) {
    if (!route || route === state.route) {
      window.scrollTo(0, 0);
      return;
    }
    let ghost = null;
    if (dir && viewEl.innerHTML) {
      try {
        const rect = viewEl.getBoundingClientRect();
        ghost = document.createElement('div');
        ghost.className = 'page-ghost ' + (dir > 0 ? 'to-left' : 'to-right');
        ghost.style.top = Math.max(0, rect.top) + 'px';
        ghost.style.height = 'calc(100vh - ' + Math.max(0, rect.top) + 'px)';
        const clone = viewEl.cloneNode(true);
        clone.removeAttribute('id');
        clone.style.transform = 'translateY(' + (-window.scrollY) + 'px)';
        ghost.appendChild(clone);
        document.body.appendChild(ghost);
      } catch (err) { ghost = null; }
    }
    state.selectMode = false;
    state.selectedIds = [];
    state.route = route;
    render();
    window.scrollTo(0, 0);
    if (dir) {
      viewEl.classList.remove('page-slide-next', 'page-slide-prev');
      void viewEl.offsetWidth;
      viewEl.classList.add(dir > 0 ? 'page-slide-next' : 'page-slide-prev');
      window.setTimeout(() => viewEl.classList.remove('page-slide-next', 'page-slide-prev'), 330);
      if (ghost) window.setTimeout(() => ghost.remove(), 340);
    } else if (ghost) {
      ghost.remove();
    }
  }

  /* ------------------------------------------------------------------ *
   * 首页
   * ------------------------------------------------------------------ */

  function groupByDay(list) {
    const groups = [];
    let cur = null;
    list.forEach((t) => {
      if (!cur || cur.date !== t.date) {
        cur = { date: t.date, items: [], expense: 0, income: 0 };
        groups.push(cur);
      }
      cur.items.push(t);
      if (t.type === 'expense') cur.expense += C.toCents(t.amount);
      if (t.type === 'income') cur.income += C.toCents(t.amount);
    });
    groups.forEach((g) => {
      g.expense = C.fromCents(g.expense);
      g.income = C.fromCents(g.income);
    });
    return groups;
  }

  function txRowHTML(t, opts) {
    const cm = C.categoryMap(state.data);
    const am = C.accountMap(state.data);
    const o = opts || {};
    const isTransfer = t.type === 'transfer';
    const cat = cm[t.categoryId] || { name: '未分类', icon: '🏷️', color: '#94a3b8' };
    const acc = am[t.accountId];
    const to = am[t.toAccountId];
    const catLabel = isTransfer ? '转账' : (cat.name + (t.subcategory ? ' · ' + t.subcategory : ''));
    let tag = t.tags && t.tags[0] ? '<span class="tx-tag">' + esc(t.tags[0]) + '</span>' : '';
    if (t.attachments && t.attachments.length) {
      tag += '<span class="tx-tag">📎' + t.attachments.length + '</span>';
    }
    if (t.reimburseAmount > 0) tag += '<span class="tx-tag">报销</span>';
    const selecting = !!state.selectMode;
    const selected = selecting && state.selectedIds.indexOf(t.id) >= 0;
    const bits = [];
    if (o.showDate) bits.push(esc(C.dateLabel(t.date)));
    bits.push('<span class="tx-time">' + esc(t.time || '12:00') + '</span>');
    if (t.note) bits.push(esc(t.note));
    if (t.currency) bits.push(esc(t.currency + (t.foreignAmount ? ' ' + C.money(t.foreignAmount) : '')));
    if (isTransfer) bits.push(esc((acc ? acc.name : '?') + ' → ' + (to ? to.name : '?')));
    else if (acc) bits.push(esc(acc.name));
    if (o.showBook) {
      const book = state.data.books.find((b) => b.id === t.bookId);
      if (book) bits.push(esc(book.name));
    }
    const sign = t.type === 'expense' ? '-' : t.type === 'income' ? '+' : '';
    return '<button class="tx' + (selected ? ' selected' : '') + '" data-act="edit-tx" data-id="' + t.id + '">' +
      (selecting ? '<span class="tx-check"></span>' : '') +
      '<span class="tx-icon" style="background:' + alpha(isTransfer ? '#64748b' : cat.color, 0.13) + '">' +
        (isTransfer ? '🔁' : cat.icon) + '</span>' +
      '<span class="tx-main">' +
        '<span class="tx-cat"><span class="tx-cat-text">' + esc(catLabel) + '</span>' + tag + '</span>' +
        '<span class="tx-note">' + (bits.join(' · ') || '&nbsp;') + '</span>' +
      '</span>' +
      '<span class="tx-amount ' + t.type + '">' + (sign ? sign + '¥' : '¥') + C.money(t.amount) + '</span>' +
    '</button>';
  }

  function dayGroupsHTML(groups) {
    return groups.map((g) => {
      const rel = C.relativeDay(g.date);
      return '<div class="day">' +
        '<div class="day-head">' +
          '<span class="day-date">' + C.parseISO(g.date).getDate() + '</span>' +
          '<span class="day-week">' + (C.parseISO(g.date).getMonth() + 1) + '月 · ' + C.weekdayCN(g.date) + (rel ? ' · ' + rel : '') + '</span>' +
          '<span class="day-total">' +
            (g.expense ? '支出 <b>¥' + C.money(g.expense) + '</b>' : '') +
            (g.expense && g.income ? ' · ' : '') +
            (g.income ? '收入 <b>¥' + C.money(g.income) + '</b>' : '') +
          '</span>' +
        '</div>' +
        '<div class="tx-list">' + g.items.map((t) => txRowHTML(t)).join('') + '</div>' +
      '</div>';
    }).join('');
  }

  function selectionBarHTML(total) {
    if (!state.selectMode) return '';
    const n = state.selectedIds.length;
    return '<div class="select-bar liquid">' +
      '<span class="sel-count"><b>' + n + '</b> 已选</span>' +
      '<button class="btn ghost" data-act="select-all">' + (n === total && total > 0 ? '取消全选' : '全选') + '</button>' +
      '<button class="btn primary" data-act="select-export">导出</button>' +
      '<button class="btn danger" data-act="select-delete">删除</button>' +
      '<button class="sel-close" data-act="select-cancel">取消</button>' +
    '</div>';
  }

  function homeHTML() {
    const book = C.activeBook(state.data);
    const bookId = book.id;
    const month = state.month;
    const totals = C.monthTotals(state.data, bookId, month);
    const budget = C.budgetStatus(state.data, bookId, month);
    const list = C.bookTransactions(state.data, bookId).filter((t) => C.monthKeyOf(t.date) === month);
    const groups = groupByDay(list);
    const isCurrent = month === C.thisMonthKey();
    const p = C.amountParts(totals.expense);
    const balanceParts = C.amountParts(totals.balance);
    const pct = budget.total ? Math.min(100, Math.round((budget.spent / budget.total) * 100)) : 0;
    const fillClass = budget.total && budget.spent > budget.total ? 'over' : (pct >= 80 ? 'warn' : '');

    let budgetHTML = '';
    if (budget.total > 0) {
      budgetHTML =
        '<div class="hero-budget">' +
          '<div class="hero-budget-head">' +
            '<span>月预算 ¥' + C.money(budget.total, 0) + ' · 已用 ' + pct + '%</span>' +
            '<span>' + (budget.remain >= 0 ? '剩余 <b>¥' + C.money(budget.remain) + '</b>' : '超支 <b>¥' + C.money(-budget.remain) + '</b>') + '</span>' +
          '</div>' +
          '<div class="budget-track"><div class="budget-fill ' + fillClass + '" style="width:' + pct + '%"></div></div>' +
        '</div>';
    } else {
      budgetHTML =
        '<div class="hero-budget">' +
          '<button class="hero-budget-hint" data-act="open-budget">' +
            '<span>' + (budget.categories.length ? '已设置分类预算' : '还没有设置月预算') + '</span><span class="go">设置预算 ›</span>' +
          '</button>' +
        '</div>';
    }

    const monthBar = isCurrent ? '' :
      '<div class="month-bar"><span class="m">' + C.monthLabel(month) + '账单</span>' +
      '<button class="chip-back" data-act="reset-month">回到本月</button></div>';

    const body = groups.length
      ? dayGroupsHTML(groups)
      : '<div class="empty">' +
          '<div class="empty-emoji theme-symbol">' + themeEmptyIcon() + '</div>' +
          '<div class="empty-title">这个月还没有记账</div>' +
          '<div class="empty-text">每一笔小记录，都会长成清楚的消费轮廓。<br>点击下方的加号开始吧。</div>' +
        '</div>';

    return '<div class="home">' +
      '<section class="hero">' +
        '<div class="hero-top">' +
          '<div class="hero-label">' + (isCurrent ? '本月支出' : '当月支出') + '</div>' +
          '<div class="hero-nav">' +
            '<button data-act="prev-month" aria-label="上个月">‹</button>' +
            '<span class="m">' + C.monthLabel(month) + '</span>' +
            '<button data-act="next-month" aria-label="下个月">›</button>' +
          '</div>' +
        '</div>' +
        '<div class="hero-amount' + (totals.balance < 0 ? ' negative' : '') + '">' +
          '<span class="cur">¥</span>' + p.int + '<span class="dec">.' + p.dec + '</span>' +
        '</div>' +
        '<div class="hero-meta">' +
          '<div class="hero-meta-item"><span>' + (isCurrent ? '本月收入' : '当月收入') + '</span><b>+¥' + C.money(totals.income) + '</b></div>' +
          '<div class="hero-meta-item"><span>' + (isCurrent ? '本月结余' : '当月结余') + '</span><b>' + (totals.balance < 0 ? '-' : '') + '¥' + C.money(Math.abs(totals.balance)) + '</b></div>' +
          '<div class="hero-meta-item"><span>记账</span><b>' + totals.count + ' 笔</b></div>' +
        '</div>' +
        budgetHTML +
      '</section>' +
      (budget.categories.length && budget.total <= 0 ? renderBudgetBars(budget) : '') +
      monthBar +
      body +
      selectionBarHTML(list.length) +
      '<div class="footer-space"></div>' +
    '</div>';
  }

  function renderBudgetBars(budget) {
    return '<div class="card">' +
      '<div class="card-title">分类预算<span>本月</span></div>' +
      budget.categories.map((c) => {
        const pct = Math.min(100, Math.round(c.percent * 100));
        return '<div style="margin:9px 0">' +
          '<div class="row-between" style="font-size:12px;margin-bottom:5px">' +
            '<span>' + c.icon + ' ' + esc(c.name) + '</span>' +
            '<span class="muted num">¥' + C.money(c.spent, 0) + ' / ¥' + C.money(c.budget, 0) + '</span>' +
          '</div>' +
          '<div class="budget-track" style="background:var(--surface-3)"><div class="budget-fill" style="width:' + pct + '%;background:' + (c.percent > 1 ? 'var(--danger)' : 'var(--primary)') + '"></div></div>' +
        '</div>';
      }).join('') +
    '</div>';
  }

  /* ------------------------------------------------------------------ *
   * 图表页
   * ------------------------------------------------------------------ */

  function calendarHeatStyle(expense, income, maxExpense, maxIncome, selected, heat) {
    if (selected) return 'background:var(--primary);color:#fff';
    if (!heat) return '';
    const e = expense ? 0.05 + 0.2 * (expense / Math.max(maxExpense, 1)) : 0;
    const i = income ? 0.05 + 0.2 * (income / Math.max(maxIncome, 1)) : 0;
    if (e > 0 && i > 0) {
      return 'background:linear-gradient(135deg, rgba(229,72,77,' + e.toFixed(3) + ') 0%, rgba(14,159,110,' + i.toFixed(3) + ') 100%)';
    }
    if (e > 0) return 'background:rgba(229,72,77,' + e.toFixed(3) + ')';
    if (i > 0) return 'background:rgba(14,159,110,' + i.toFixed(3) + ')';
    return '';
  }

  function calendarPageHTML(month, data, book, selected, showLunar, heat, today, center) {
    const daily = C.dayTotals(data, book.id, month);
    const maxExpense = Object.keys(daily).reduce((m, d) => Math.max(m, daily[d].expense || 0), 0);
    const maxIncome = Object.keys(daily).reduce((m, d) => Math.max(m, daily[d].income || 0), 0);
    const dim = C.daysInMonth(Number(month.slice(0, 4)), Number(month.slice(5, 7)));
    const first = C.weekdayIndex(month + '-01');
    let cells = '';
    for (let i = 0; i < 42; i++) {
      const dayNum = i - first + 1;
      if (dayNum < 1 || dayNum > dim) { cells += '<span class="cal-cell empty"></span>'; continue; }
      const day = month + '-' + pad2(dayNum);
      const rec = daily[dayNum] || { expense: 0, income: 0, count: 0 };
      const lab = C.calendarLabel(day);
      const isToday = day === today;
      const isSelected = center && day === selected;
      const displayLabel = showLunar ? lab.text : (lab.festival || lab.term);
      const weekday = C.weekdayIndex(day);
      const style = calendarHeatStyle(rec.expense, rec.income, maxExpense, maxIncome, isSelected, heat);
      const classes = ['cal-cell'];
      if (isToday) classes.push('today');
      if (isSelected) classes.push('selected');
      if (weekday === 0 || weekday === 6) classes.push('weekend');
      if (lab.holiday) classes.push('festival');
      if (rec.count) classes.push('has');
      cells += '<button class="' + classes.join(' ') + '" style="' + style + '" data-act="calendar-select" data-day="' + day + '">' +
        '<span class="cc-day">' + dayNum + '</span>' +
        (displayLabel ? '<span class="cc-lunar">' + esc(displayLabel) + '</span>' : '') +
        '<span class="cc-amounts"><i class="out">-' + shortMoney(rec.expense) + '</i><i class="in">+' + shortMoney(rec.income) + '</i></span>' +
      '</button>';
    }
    return '<div class="cal-slide' + (center ? ' center' : ' side') + '">' +
      '<div class="cal-slide-month">' + C.monthLabel(month) + '</div>' +
      '<div class="cal-week"><span>日</span><span>一</span><span>二</span><span>三</span><span>四</span><span>五</span><span>六</span></div>' +
      '<div class="cal-grid">' + cells + '</div>' +
    '</div>';
  }

  function calendarHTML() {
    const data = state.data;
    const book = C.activeBook(data);
    const month = state.calendarMonth;
    let selected = state.calendarSelected;
    if (C.monthKeyOf(selected) !== month) {
      selected = month === C.thisMonthKey() ? C.todayISO() : month + '-01';
      state.calendarSelected = selected;
    }
    const totals = C.monthTotals(data, book.id, month);
    const today = C.todayISO();
    const currentMonth = C.thisMonthKey();
    const heat = data.settings.calendarHeat !== false;
    const showLunar = data.settings.calendarLunar !== false;
    const dayList = C.sortTransactions(data.transactions.filter((t) => t.bookId === book.id && t.date === selected));
    let selectedExpense = 0, selectedIncome = 0;
    dayList.forEach((t) => {
      if (t.type === 'expense') selectedExpense += C.toCents(t.amount);
      if (t.type === 'income') selectedIncome += C.toCents(t.amount);
    });
    const pages = [C.addMonthsKey(month, -1), month, C.addMonthsKey(month, 1)]
      .map((m, i) => calendarPageHTML(m, data, book, selected, showLunar, heat, today, i === 1)).join('');

    const dayTxHTML = dayList.length
      ? '<div class="tx-list">' + dayList.map((t) => txRowHTML(t)).join('') + '</div>'
      : '<div class="empty" style="padding:28px 10px 24px"><div class="empty-emoji theme-symbol">' + themeEmptyIcon() + '</div><div class="empty-title">这天还没有账单</div></div>';

    return '<div class="calendar-page">' +
      '<section class="calendar-glass liquid">' +
        '<div class="cal-titlebar">' +
          '<button class="cal-arrow" data-act="calendar-prev" aria-label="上个月">‹</button>' +
          '<button class="cal-title" data-act="calendar-month-picker">' + C.monthLabel(month) + '</button>' +
          '<button class="cal-arrow" data-act="calendar-next" aria-label="下个月">›</button>' +
          (month === currentMonth ? '' : '<button class="cal-today" data-act="calendar-today">今天</button>') +
          '<span class="grow"></span>' +
          '<button class="icon-btn small" data-act="calendar-settings" aria-label="日历设置">' + svg('settings', 20) + '</button>' +
          '<button class="icon-btn small accent" data-act="calendar-add" aria-label="添加账单">' + svg('plus', 20) + '</button>' +
        '</div>' +
        '<div class="cal-totals">' +
          '<div><span>收</span><b class="in">¥' + C.money(totals.income) + '</b></div>' +
          '<div><span>支</span><b class="out">¥' + C.money(totals.expense) + '</b></div>' +
          '<div><span>余</span><b>¥' + C.money(totals.balance) + '</b></div>' +
        '</div>' +
      '</section>' +
      '<section class="calendar-grid-card">' +
        '<div class="calendar-track" data-calendar-track>' + pages + '</div>' +
      '</section>' +
      '<section class="calendar-day-panel">' +
        '<div class="cal-day-head">' +
          '<div><b>' + C.dateLabel(selected) + '</b><span>' + C.weekdayCN(selected) + (selected === today ? ' · 今天' : '') + '</span></div>' +
          '<div class="cal-day-totals"><span>收 ¥' + C.money(C.fromCents(selectedIncome)) + '</span><span>支 ¥' + C.money(C.fromCents(selectedExpense)) + '</span></div>' +
          '<button class="icon-btn small" data-act="calendar-add" aria-label="添加账单">' + svg('plus', 19) + '</button>' +
        '</div>' +
        dayTxHTML +
      '</section>' +
    '</div>';
  }

  function openCalendarSettings() {
    const heat = state.data.settings.calendarHeat !== false;
    openSheet({
      title: '日历设置', subtitle: '让每一天的颜色说话', content:
        '<label class="list-item" style="border:0;padding-left:0;padding-right:0">' +
          '<span class="grow"><span class="t" style="display:block">热力背景</span>' +
            '<span class="s" style="display:block">支出越多越红，收入越多越绿</span></span>' +
          '<span class="switch"><input type="checkbox" data-heat' + (heat ? ' checked' : '') + '><span class="switch-track"></span></span>' +
        '</label>' +
        '<label class="list-item" style="border:0;padding-left:0;padding-right:0">' +
          '<span class="grow"><span class="t" style="display:block">显示农历</span>' +
            '<span class="s" style="display:block">关闭后只保留节日与节气</span></span>' +
          '<span class="switch"><input type="checkbox" data-lunar' + (state.data.settings.calendarLunar !== false ? ' checked' : '') + '><span class="switch-track"></span></span>' +
        '</label>' +
        '<div class="hint-box" style="margin-top:12px">热力背景关闭后日历恢复纯白；农历关闭后仍显示节日和节气。</div>',
      onMount(root, close) {
        const heatInput = root.querySelector('[data-heat]');
        const lunarInput = root.querySelector('[data-lunar]');
        heatInput.addEventListener('change', () => {
          state.data.settings.calendarHeat = heatInput.checked;
          saveData();
          close();
          render();
          toast(heatInput.checked ? '已开启热力背景' : '已关闭热力背景');
        });
        lunarInput.addEventListener('change', () => {
          state.data.settings.calendarLunar = lunarInput.checked;
          saveData();
          close();
          render();
          toast(lunarInput.checked ? '已显示农历' : '已隐藏农历，保留节日节气');
        });
      }
    });
  }

  function openCalendarMonthPicker() {
    let year = Number(state.calendarMonth.slice(0, 4));
    openSheet({
      title: '选择月份', subtitle: '日历月份', content: '<div data-picker></div>',
      onMount(root, close) {
        const body = root.querySelector('[data-picker]');
        function paint() {
          const current = state.calendarMonth;
          body.innerHTML =
            '<div class="stats-month-picker-head"><button data-picker-year="-1">‹</button><b>' + year + ' 年</b><button data-picker-year="1">›</button></div>' +
            '<div class="stats-month-picker-grid">' + Array.from({ length: 12 }, (_, i) => {
              const key = year + '-' + pad2(i + 1);
              return '<button class="' + (key === current ? 'active' : '') + '" data-picker-month="' + key + '">' + (i + 1) + '月' +
                (key === C.thisMonthKey() ? '<small>本月</small>' : '') + '</button>';
            }).join('') + '</div>';
        }
        paint();
        body.addEventListener('click', (e) => {
          const step = e.target.closest('[data-picker-year]');
          if (step) { year += Number(step.dataset.pickerYear); paint(); return; }
          const month = e.target.closest('[data-picker-month]');
          if (!month) return;
          state.calendarMonth = month.dataset.pickerMonth;
          state.calendarSelected = month.dataset.pickerMonth === C.thisMonthKey() ? C.todayISO() : month.dataset.pickerMonth + '-01';
          close();
          render();
          window.scrollTo(0, 0);
        });
      }
    });
  }

  function calendarStep(delta) {
    state.calendarMonth = C.addMonthsKey(state.calendarMonth, delta);
    state.calendarSelected = state.calendarMonth === C.thisMonthKey() ? C.todayISO() : state.calendarMonth + '-01';
    render();
    window.scrollTo(0, 0);
  }

  function wireCalendarSwipe() {
    const card = document.querySelector('.calendar-grid-card');
    const track = card && card.querySelector('[data-calendar-track]');
    if (!card || !track || card.dataset.swiped === '1') return;
    card.dataset.swiped = '1';
    let sx = null, sy = null, dx = 0, horizontal = false, animating = false;
    let timer = null;
    const center = 'translate3d(-33.3333%,0,0)';
    const width = () => card.clientWidth || 320;

    function reset() {
      track.style.transition = 'transform .22s cubic-bezier(.22,.8,.28,1)';
      track.style.transform = center;
      horizontal = false;
    }

    card.addEventListener('touchstart', (e) => {
      if (animating) return;
      if (timer) { clearTimeout(timer); timer = null; }
      sx = e.touches[0].clientX; sy = e.touches[0].clientY; dx = 0; horizontal = false;
      track.style.transition = 'none';
    }, { passive: true });

    card.addEventListener('touchmove', (e) => {
      if (sx == null || animating) return;
      dx = e.touches[0].clientX - sx;
      const dy = e.touches[0].clientY - sy;
      if (Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy)) {
        horizontal = true;
        if (e.cancelable) e.preventDefault();
      }
      if (!horizontal) return;
      const max = width() * 0.86;
      const clamped = Math.max(-max, Math.min(max, dx));
      track.style.transform = 'translate3d(calc(-33.3333% + ' + clamped.toFixed(1) + 'px),0,0)';
    }, { passive: false });

    card.addEventListener('touchend', () => {
      if (sx == null) return;
      const threshold = Math.min(72, width() * 0.18);
      const should = horizontal && Math.abs(dx) > threshold;
      sx = null; sy = null;
      if (!should) { reset(); return; }
      animating = true;
      const dir = dx < 0 ? 1 : -1;
      state.suppressClickUntil = Date.now() + 450;
      track.style.transition = 'transform .24s cubic-bezier(.22,.8,.28,1)';
      track.style.transform = dir > 0 ? 'translate3d(-66.6667%,0,0)' : 'translate3d(0%,0,0)';
      timer = window.setTimeout(() => {
        animating = false; timer = null;
        calendarStep(dir);
      }, 245);
    }, { passive: true });
  }

  function daysBetweenInclusive(from, to) {
    return Math.max(1, Math.round((C.parseISO(to) - C.parseISO(from)) / 86400000) + 1);
  }

  function statsBarValue(row, type) {
    if (type === 'income') return row ? row.income : 0;
    if (type === 'balance') return row ? row.balance : 0;
    return row ? row.expense : 0;
  }

  function statsSankeyNodes(c) {
    let list;
    if (state.statsSankey === 'category') {
      list = c.expenseBreakdown.map((x) => ({ name: x.name, value: x.value, color: x.color }));
    } else {
      const cats = C.categoryMap(c.data);
      const map = {};
      c.data.transactions.forEach((t) => {
        if (t.bookId !== c.book.id || t.type !== 'expense' || t.date < c.from || t.date > c.to) return;
        const cat = cats[t.categoryId] || { name: '未分类', color: '#94a3b8' };
        const key = t.subcategory ? cat.name + ' / ' + t.subcategory : cat.name;
        if (!map[key]) map[key] = { name: key, value: 0, color: cat.color };
        map[key].value += C.toCents(t.amount);
      });
      list = Object.keys(map).map((key) => ({
        name: map[key].name, value: C.fromCents(map[key].value), color: map[key].color
      })).sort((a, b) => b.value - a.value);
    }
    const top = list.slice(0, 3);
    const rest = list.slice(3).reduce((sum, x) => sum + x.value, 0);
    if (rest > 0) top.push({ name: '其它', value: C.round2(rest), color: '#94a3b8' });
    return top;
  }

  function statsContext(modeOverride) {
    const data = state.data;
    const book = C.activeBook(data);
    const today = C.todayISO();
    const currentMonth = C.thisMonthKey();
    const mode = modeOverride || state.statsMode;
    let from, to, monthKey = null, year = null, yearAll = false;
    if (mode === 'month') {
      monthKey = state.statsMonth;
      from = monthKey + '-01';
      to = C.monthEnd(monthKey);
    } else if (mode === 'year') {
      yearAll = !!state.statsYearAll;
      const currentYear = Number(currentMonth.slice(0, 4));
      const dataYears = data.transactions
        .filter((t) => t.bookId === book.id)
        .map((t) => Number(t.date.slice(0, 4)))
        .filter((y) => Number.isFinite(y));
      const minYear = dataYears.length ? Math.min.apply(null, dataYears) : currentYear;
      const maxYear = dataYears.length ? Math.max.apply(null, dataYears) : currentYear;
      year = yearAll ? null : state.statsYear;
      from = yearAll ? minYear + '-01-01' : year + '-01-01';
      to = yearAll ? maxYear + '-12-31' : year + '-12-31';
    } else if (mode === 'custom') {
      from = state.statsCustomFrom;
      to = state.statsCustomTo;
      if (from > to) { const swap = from; from = to; to = swap; }
    } else {
      to = today;
      from = C.addDaysISO(today, -6);
    }

    const totals = C.rangeTotals(data, book.id, from, to);
    const dayRows = C.dailyRows(data, book.id, from, to);
    const dayMap = {};
    dayRows.forEach((row) => { dayMap[row.date] = row; });
    const rangeDays = daysBetweenInclusive(from, to);
    const expenseBreakdown = C.categoryBreakdownRange(data, book.id, from, to, 'expense');
    const breakdown = C.categoryBreakdownRange(data, book.id, from, to, state.statsShareType);
    let labels = [], values = [], tableRows = [], tableLabel = '日期', series = null;
    let showValues = false, labelEvery = 1, highlight = -1, asset = null;
    let avgBase = rangeDays;

    if (mode === 'month') {
      const dim = C.daysInMonth(Number(monthKey.slice(0, 4)), Number(monthKey.slice(5, 7)));
      const exp = C.monthDailySeries(data, book.id, monthKey, 'expense');
      const inc = C.monthDailySeries(data, book.id, monthKey, 'income');
      const net = exp.map((v, i) => C.round2(inc[i] - v));
      labels = Array.from({ length: dim }, (_, i) => String(i + 1));
      values = state.statsType === 'income' ? inc : state.statsType === 'balance' ? net : exp;
      series = state.statsType === 'all' ? [
        { values: exp, color: '#ef6c5a', name: '支出' },
        { values: inc, color: '#0e9f6e', name: '收入' }
      ] : null;
      tableRows = dayRows.map((r) => ({
        label: r.date.slice(5), date: r.date, income: r.income, expense: r.expense,
        balance: r.balance, count: r.count
      }));
      highlight = monthKey === currentMonth ? Math.min(Number(today.slice(8, 10)), dim) - 1 : -1;
      labelEvery = 2;
      avgBase = dim;
      asset = C.assetSeries(data, monthKey);
    } else if (mode === 'daily' || (mode === 'custom' && rangeDays <= 31)) {
      for (let i = 0; i < rangeDays; i++) {
        const date = C.addDaysISO(from, i);
        const row = dayMap[date];
        labels.push(date.slice(5).replace('-', '/'));
        values.push(statsBarValue(row, state.statsType));
      }
      tableRows = dayRows.map((r) => ({
        label: r.date.slice(5), date: r.date, income: r.income, expense: r.expense,
        balance: r.balance, count: r.count
      }));
      showValues = rangeDays <= 10;
      labelEvery = rangeDays > 14 ? 2 : 1;
      highlight = rangeDays - 1;
      avgBase = rangeDays;
      if (state.statsType === 'all') {
        series = [
          { values: Array.from({ length: rangeDays }, (_, i) => { const row = dayMap[C.addDaysISO(from, i)]; return row ? row.expense : 0; }), color: '#ef6c5a', name: '支出' },
          { values: Array.from({ length: rangeDays }, (_, i) => { const row = dayMap[C.addDaysISO(from, i)]; return row ? row.income : 0; }), color: '#0e9f6e', name: '收入' }
        ];
      }
    } else if (mode === 'year') {
      if (yearAll) {
        const currentYear = Number(currentMonth.slice(0, 4));
        const reportRows = C.yearRows(data, book.id, currentYear - 9, currentYear);
        labels = reportRows.map((r) => String(r.year));
        const expValues = reportRows.map((r) => r.expense);
        const incValues = reportRows.map((r) => r.income);
        const balValues = reportRows.map((r) => r.balance);
        if (state.statsType === 'all') {
          values = expValues;
          series = [
            { values: expValues, color: '#ef6c5a', name: '支出' },
            { values: incValues, color: '#0e9f6e', name: '收入' }
          ];
        } else {
          values = state.statsType === 'income' ? incValues : state.statsType === 'balance' ? balValues : expValues;
        }
        tableRows = reportRows.map((r) => ({
          label: r.year + '年', year: r.year, income: r.income, expense: r.expense,
          balance: r.balance, count: r.count
        }));
        tableLabel = '年份';
        showValues = state.statsType !== 'all';
        highlight = -1;
      } else {
        const ms = C.yearMonths(data, book.id, year);
        labels = ms.map((m) => m.month + '月');
        const expValues = ms.map((m) => m.expense);
        const incValues = ms.map((m) => m.income);
        const balValues = ms.map((m) => m.balance);
        if (state.statsType === 'all') {
          values = expValues;
          series = [
            { values: expValues, color: '#ef6c5a', name: '支出' },
            { values: incValues, color: '#0e9f6e', name: '收入' }
          ];
        } else {
          values = state.statsType === 'income' ? incValues : state.statsType === 'balance' ? balValues : expValues;
        }
        tableRows = ms.map((m) => ({
          label: m.month + '月', month: m.month, income: m.income, expense: m.expense,
          balance: m.balance, count: m.count
        }));
        tableLabel = '月份';
        showValues = state.statsType !== 'all';
        highlight = year === Number(currentMonth.slice(0, 4)) ? Number(currentMonth.slice(5, 7)) - 1 : -1;
      }
      avgBase = 12;
      asset = C.assetSeriesRange(data, from, to);
    } else {
      // 自定义长区间：按月汇总柱状图
      let cursor = C.monthKeyOf(from);
      const endMonth = C.monthKeyOf(to);
      let guard = 0;
      while (cursor <= endMonth && guard++ < 60) {
        const mt = C.monthTotals(data, book.id, cursor);
        labels.push(Number(cursor.slice(5, 7)) + '月');
        values.push(state.statsType === 'income' ? mt.income : state.statsType === 'balance' ? mt.balance : mt.expense);
        tableRows.push({
          label: cursor.slice(0, 4) + '-' + cursor.slice(5, 7),
          month: cursor, income: mt.income, expense: mt.expense, balance: mt.balance, count: mt.count
        });
        cursor = C.addMonthsKey(cursor, 1);
      }
      tableRows = tableRows.filter((r) => r.count > 0);
      tableLabel = '月份';
      showValues = false;
      avgBase = rangeDays;
    }

    const prev = mode === 'month' ? C.monthTotals(data, book.id, C.addMonthsKey(monthKey, -1)) : null;
    const rangeLabel = mode === 'month' ? C.monthLabel(monthKey)
      : mode === 'year' ? (yearAll ? '全部年份' : year + '年')
      : mode === 'custom' ? from.slice(5).replace('-', '.') + ' - ' + to.slice(5).replace('-', '.')
      : from.slice(5).replace('-', '/') + ' - ' + to.slice(5).replace('-', '/');
    const extended = C.extendedRangeStats(data, book.id, from, to);

    return {
      data, book, mode, from, to, monthKey, year, yearAll, totals, dayRows,
      expenseBreakdown, breakdown, labels, values, series, tableRows, tableLabel,
      showValues, labelEvery, highlight, asset, prev, rangeLabel, extended,
      rangeDays, avg: totals.expense / Math.max(mode === 'year' && yearAll ? (extended.months || 1) : avgBase, 1),
      daysWith: mode === 'year' ? tableRows.filter((r) => r.count > 0).length : dayRows.length,
      monthsWith: mode === 'year' && !yearAll ? C.yearMonths(data, book.id, year).filter((m) => m.count > 0).length : 0,
      yearsWith: mode === 'year' ? tableRows.filter((r) => r.count > 0).length : 0,
      sankeyNodes: statsSankeyNodes({ data, book, from, to, expenseBreakdown })
    };
  }

  function statsModeLabel(mode) {
    return { daily: '近 7 天', month: '月统计', year: '年统计', custom: '自定义' }[mode] || '统计';
  }

  function statsToggleHTML(current, items, action) {
    return '<div class="stats-mini-seg">' + items.map((it) => (
      '<button class="' + (current === it[0] ? 'active' : '') + '" data-act="' + action + '" data-type="' + it[0] + '">' + it[1] + '</button>'
    )).join('') + '</div>';
  }

  function statsDatebarHTML(c) {
    if (c.mode === 'month') {
      const current = C.thisMonthKey();
      const months = [];
      for (let i = 0; i < 12; i++) months.push(C.addMonthsKey(c.monthKey, -i));
      const chips = months.map((key, i) => {
        const m = Number(key.slice(5, 7));
        let label = m + '月';
        if (key === current) label = '本月';
        else if (key === C.addMonthsKey(current, -1)) label = '上月';
        return '<button class="month-chip' + (i === 0 ? ' selected' : '') + '" data-act="stats-set-month" data-month="' + key + '">' + label + '</button>';
      }).join('');
      return '<div class="stats-datebar month-bar">' +
        '<button class="year-btn" data-act="stats-year-picker" aria-label="选择年月">' + c.monthKey.slice(0, 4) + '</button>' +
        '<div class="month-rail-wrap">' +
          '<div class="month-rail' + (state.statsSwipe > 0 ? ' swipe-next' : state.statsSwipe < 0 ? ' swipe-prev' : '') + '" data-month-rail>' + chips + '</div>' +
          '<span class="rail-arrow" aria-hidden="true">▲</span>' +
        '</div>' +
        '<div class="month-stepper">' +
          '<button data-act="stats-month-step" data-step="-1" aria-label="上个月">‹</button>' +
          '<button data-act="stats-month-step" data-step="1" aria-label="下个月">›</button>' +
        '</div>' +
        (c.monthKey === current ? '' : '<button class="chip-back" data-act="stats-reset-month">本月</button>') +
      '</div>';
    }
    if (c.mode === 'year') {
      const currentYear = Number(C.thisMonthKey().slice(0, 4));
      const baseYear = c.yearAll ? currentYear : c.year;
      const chips = Array.from({ length: 10 }, (_, i) => {
        const y = baseYear - i;
        const label = y === currentYear ? '今年' : y === currentYear - 1 ? '去年' : y + '年';
        return '<button class="month-chip year-chip' + (!c.yearAll && y === c.year ? ' selected' : '') + '" data-act="stats-set-year" data-year="' + y + '">' + label + '</button>';
      }).join('');
      return '<div class="stats-datebar year-rail-bar">' +
        '<button class="year-all' + (c.yearAll ? ' active' : '') + '" data-act="stats-year-all">所有</button>' +
        '<div class="month-rail-wrap">' +
          '<div class="month-rail" data-year-rail>' + chips + '</div>' +
          (c.yearAll ? '' : '<span class="rail-arrow" aria-hidden="true">▲</span>') +
        '</div>' +
      '</div>';
    }
    if (c.mode === 'custom') {
      return '<div class="stats-datebar custom-bar">' +
        '<button class="date-pill" data-act="stats-custom-start">' + c.from.slice(5).replace('-', '.') + '</button>' +
        '<span class="date-dash">→</span>' +
        '<button class="date-pill" data-act="stats-custom-end">' + c.to.slice(5).replace('-', '.') + '</button>' +
      '</div>' +
      '<div class="chips preset-row">' +
        '<button class="chip" data-act="stats-preset" data-preset="7">近 7 天</button>' +
        '<button class="chip" data-act="stats-preset" data-preset="30">近 30 天</button>' +
        '<button class="chip" data-act="stats-preset" data-preset="month">本月</button>' +
        '<button class="chip" data-act="stats-preset" data-preset="year">今年</button>' +
      '</div>';
    }
    return '<div class="stats-datebar daily-bar">' +
      '<div class="db-title">近 7 天</div><div class="db-sub">' + c.rangeLabel + '</div>' +
    '</div>';
  }

  function signedMoneyText(n) {
    const v = C.round2(n);
    return (v < 0 ? '-' : '') + '¥' + C.money(Math.abs(v));
  }

  function statsSummaryBoxHTML(c) {
    const prefix = c.mode === 'month' ? '月' : c.mode === 'year' ? (c.yearAll ? '全部' : '年') : c.mode === 'daily' ? '近7天' : '区间';
    const detail = c.mode === 'year' || c.mode === 'month';
    const open = detail && state.statsSummaryOpen;
    let extra = '';
    if (detail) {
      const ex = c.extended || {};
      const divisor = c.mode === 'month' ? Math.max(1, c.rangeDays) : (c.yearAll ? Math.max(1, ex.months || 1) : 12);
      const avgName = c.mode === 'month' ? '日均' : '月均';
      const metrics = [
        [avgName + '支出', '¥' + C.money(c.totals.expense / divisor)],
        [avgName + '收入', '¥' + C.money(c.totals.income / divisor)],
        [avgName + '结余', signedMoneyText(c.totals.balance / divisor)],
        ['转账', '¥' + C.money(ex.transfer)],
        ['还款', '¥' + C.money(ex.repay)],
        ['收款', '¥' + C.money(ex.receive)],
        ['应付/借入', '¥' + C.money(ex.payable)],
        ['应收/借出', '¥' + C.money(ex.receivable)],
        ['手续费', '¥' + C.money(ex.fee)],
        ['报销', '¥' + C.money(ex.reimburse)],
        ['报销到账', '¥' + C.money(ex.reimburseReceived)],
        ['待报销', '¥' + C.money(ex.reimbursePending)],
        ['退款', '¥' + C.money(ex.refund)],
        ['退款收入', '¥' + C.money(ex.refundIncome)],
        ['退款支出', '¥' + C.money(ex.refundExpense)],
        ['支出优惠', '¥' + C.money(ex.discountExpense)],
        ['收入优惠', '¥' + C.money(ex.discountIncome)]
      ];
      extra = '<div class="ss-extra' + (open ? ' open' : '') + '">' + metrics.map((m) => (
        '<div class="ss-metric"><span>' + m[0] + '</span><b>' + m[1] + '</b></div>'
      )).join('') + '</div>';
    }
    return '<section class="stats-summary' + (open ? ' open' : '') + '">' +
      '<div class="ss-cell"><span>' + prefix + '支出</span><b>¥' + C.money(c.totals.expense) + '</b></div>' +
      '<div class="ss-cell"><span>' + prefix + '收入</span><b>¥' + C.money(c.totals.income) + '</b></div>' +
      '<div class="ss-cell"><span>' + prefix + '结余</span><b>' + signedMoneyText(c.totals.balance) + '</b></div>' +
      (detail ? '<button class="ss-toggle" data-act="stats-summary-toggle" aria-label="展开更多数据">' + (open ? '收起' : '更多数据') + ' <span>' + (open ? '⌃' : '⌄') + '</span></button>' : '') +
      '<div class="ss-foot">' + c.rangeLabel + ' · ' + c.totals.count + ' 笔</div>' +
      extra +
    '</section>';
  }

  function statsTableHTML(c) {
    if (!c.tableRows.length) {
      return '<section class="card"><div class="card-title">报表统计<span>按' + c.tableLabel + '排序</span></div>' +
        '<div class="empty" style="padding:24px 8px"><div class="empty-text">这个区间还没有账单</div></div></section>';
    }
    return '<section class="card stats-table-card">' +
      '<div class="card-title">报表统计<span>按' + c.tableLabel + '排序</span></div>' +
      '<div class="stats-table">' +
        '<div class="st-row st-head"><span>' + c.tableLabel + '</span><span>收入</span><span>支出</span><span>结余</span></div>' +
        c.tableRows.map((r) => (
          '<div class="st-row">' +
            '<span class="st-date">' + r.label + '</span>' +
            '<span class="st-income">' + (r.income ? C.money(r.income) : '0.00') + '</span>' +
            '<span class="st-expense">' + (r.expense ? C.money(r.expense) : '0.00') + '</span>' +
            '<span class="' + (r.balance < 0 ? 'st-negative' : 'st-balance') + '">' + C.money(r.balance) + '</span>' +
          '</div>'
        )).join('') +
      '</div>' +
    '</section>';
  }

  function statsShareHTML(c, sfx) {
    const typeCN = state.statsShareType === 'income' ? '收入' : '支出';
    const list = c.breakdown;
    const top = list.slice(0, 6);
    const rest = list.slice(6).reduce((sum, x) => sum + x.value, 0);
    const items = top.slice();
    if (rest > 0) items.push({ name: '其它', value: C.round2(rest), color: '#94a3b8', count: 0, pct: c.totals[state.statsShareType] ? rest / c.totals[state.statsShareType] : 0 });
    const total = list.reduce((sum, x) => sum + x.value, 0);
    const count = list.reduce((sum, x) => sum + x.count, 0);
    return '<section class="card stats-share-card">' +
      '<div class="card-title">' + typeCN + '占比' + statsToggleHTML(state.statsShareType, [['expense', '支出'], ['income', '收入']], 'stats-share-type') + '</div>' +
      (items.length ? '<div class="donut-box stats-donut-box">' +
        '<div class="donut-svg" id="statsDonut' + sfx + '"></div>' +
        '<div class="donut-center"><span class="t">总' + typeCN + '</span><span class="v">¥' + (total >= 1000000 ? compactMoney(total) : C.money(total, 2)) + '</span><span class="s">' + count + ' 笔</span></div>' +
      '</div>' +
      '<div class="stats-share-legend">' + items.map((x) => (
        '<div class="share-row"><span class="legend-dot" style="background:' + x.color + '"></span>' +
          '<span class="share-name">' + esc(x.name) + '</span>' +
          '<span class="share-pct">' + Math.round((x.pct || 0) * 100) + '%</span>' +
          '<span class="share-amount">¥' + C.money(x.value, 0) + '</span></div>'
      )).join('') + '</div>' : '<div class="empty" style="padding:26px 8px"><div class="empty-text">暂无数据</div></div>') +
    '</section>';
  }

  function statsRankHTML(c) {
    const typeCN = state.statsShareType === 'income' ? '收入' : '支出';
    const list = c.breakdown.slice(0, 5);
    if (!list.length) return '';
    return '<section class="card">' +
      '<div class="card-title">' + typeCN + '排行<span>Top 5</span></div>' +
      list.map((x, i) => (
        '<div class="rank-row">' +
          '<span class="rank-idx' + (i === 0 ? ' top' : '') + '">' + (i + 1) + '</span>' +
          '<span class="tx-icon" style="width:30px;height:30px;border-radius:9px;font-size:15px;background:' + alpha(x.color, 0.13) + '">' + x.icon + '</span>' +
          '<span class="grow"><span class="rank-name" style="display:block">' + esc(x.name) + '</span>' +
            '<span class="rank-sub">' + x.count + ' 笔 · 占比 ' + Math.round(x.pct * 100) + '%</span>' +
            '<span class="rank-bar"><i style="width:' + Math.max(2, Math.round(x.pct * 100)) + '%;background:' + x.color + '"></i></span></span>' +
          '<span class="rank-amt">¥' + C.money(x.value, 0) + '</span>' +
        '</div>'
      )).join('') +
    '</section>';
  }

  function statsSummaryCardHTML(c) {
    const top = c.expenseBreakdown[0];
    const title = c.mode === 'month' ? '月份总结' : c.mode === 'year' ? (c.yearAll ? '全部年份总结' : '年度总结') : c.mode === 'daily' ? '近 7 天小结' : '区间小结';
    const lines = [];
    lines.push('支出 <b>¥' + C.money(c.totals.expense) + '</b>，收入 <b>¥' + C.money(c.totals.income) + '</b>，结余 <b>' + signedMoneyText(c.totals.balance) + '</b>。');
    if (top) {
      lines.push('支出最多的是「' + esc(top.name) + '」¥' + C.money(top.value) + '，占 ' + Math.round(top.pct * 100) + '%。');
    }
    if (c.mode === 'month') {
      lines.push('日均支出 ¥' + C.money(c.avg) + '；本月记账 <b>' + c.daysWith + '</b> 天、<b>' + c.totals.count + '</b> 笔。');
      if (c.prev) {
        const diff = C.round2(c.totals.expense - c.prev.expense);
        if (c.prev.expense > 0) {
          const pct = Math.abs(diff / c.prev.expense * 100).toFixed(1);
          lines.push('支出较上月 ' + (diff >= 0 ? '增加' : '减少') + ' ¥' + C.money(Math.abs(diff)) + '（' + pct + '%）。');
        } else {
          lines.push('上月没有支出记录。');
        }
      }
    } else if (c.mode === 'year') {
      if (c.yearAll) {
        lines.push('月均支出 ¥' + C.money(c.avg) + '；有记账的年份 <b>' + c.yearsWith + '</b> 个。');
      } else {
        lines.push('月均支出 ¥' + C.money(c.totals.expense / 12) + '；有记账的月份 <b>' + c.monthsWith + '</b> 个。');
      }
    } else {
      lines.push('日均支出 ¥' + C.money(c.avg) + '；区间内记账 <b>' + c.daysWith + '</b> 天。');
    }
    return '<section class="card stats-summary-card">' +
      '<div class="summary-leaf">🌿</div>' +
      '<div class="grow"><div class="summary-title">' + title + '</div>' +
        lines.map((line) => '<p>' + line + '</p>').join('') +
      '</div>' +
    '</section>';
  }

  function statsChartControlsHTML() {
    return '<div class="stats-chart-controls">' +
      statsToggleHTML(state.statsType, [['expense', '支出'], ['income', '收入'], ['balance', '结余'], ['all', '全部']], 'stats-type') +
      '<div class="stats-chart-type">' +
        '<button class="' + (state.statsChartType !== 'line' ? 'active' : '') + '" data-act="stats-chart-type" data-value="bar" aria-label="柱状图">▥</button>' +
        '<button class="' + (state.statsChartType === 'line' ? 'active' : '') + '" data-act="stats-chart-type" data-value="line" aria-label="曲线图">〰</button>' +
      '</div>' +
    '</div>';
  }

  function statsExpenseDataHTML(c) {
    const txs = c.data.transactions.filter((t) => t.bookId === c.book.id && t.type === 'expense' && t.date >= c.from && t.date <= c.to);
    const maxTx = txs.reduce((m, t) => (Number(t.amount) > Number(m.amount || 0) ? t : m), {});
    const top = c.expenseBreakdown[0];
    const avgLabel = c.mode === 'month' || c.mode === 'daily' ? '日均支出' : '月均支出';
    return '<section class="card stats-data-card">' +
      '<div class="card-title">支出数据<span>' + c.rangeLabel + '</span></div>' +
      '<div class="stats-data-grid">' +
        '<div><span>' + avgLabel + '</span><b>¥' + C.money(c.avg) + '</b></div>' +
        '<div><span>支出笔数</span><b>' + txs.length + '</b></div>' +
        '<div><span>最大单笔</span><b>¥' + C.money(maxTx.amount || 0) + '</b></div>' +
      '</div>' +
      (top ? '<div class="hint-box">最大分类「' + esc(top.name) + '」¥' + C.money(top.value) + '，占 ' + Math.round(top.pct * 100) + '%。</div>' : '') +
    '</section>';
  }

  function heatStyle(value, max, type) {
    if (!value) return '';
    const alpha = 0.08 + 0.55 * (value / Math.max(max, 1));
    return 'background:' + (type === 'income' ? 'rgba(14,159,110,' : 'rgba(229,72,77,') + alpha.toFixed(3) + ')';
  }

  function compactHeatMonth(data, bookId, year, month, type, max) {
    const key = year + '-' + pad2(month);
    const daily = C.dayTotals(data, bookId, key);
    const dim = C.daysInMonth(year, month);
    let cells = '';
    // 紧凑热力图不按星期排，固定 5 行 x 7 列，12 个月高度完全一致。
    for (let day = 1; day <= 35; day++) {
      if (day > dim) { cells += '<span class="heat-dot empty"></span>'; continue; }
      const rec = daily[day] || { expense: 0, income: 0 };
      const value = type === 'income' ? rec.income : rec.expense;
      cells += '<span class="heat-dot" style="' + heatStyle(value, max, type) + '" title="' + day + '日 ¥' + C.money(value) + '"></span>';
    }
    return '<div class="heat-month"><div class="heat-month-label">' + month + '月</div><div class="heat-mini">' + cells + '</div></div>';
  }

  function yearHeatmapHTML(c) {
    if (!c.year || c.yearAll) return '';
    const type = state.statsHeatType;
    let max = 0;
    for (let m = 1; m <= 12; m++) {
      const daily = C.dayTotals(c.data, c.book.id, c.year + '-' + pad2(m));
      Object.keys(daily).forEach((d) => { max = Math.max(max, type === 'income' ? daily[d].income : daily[d].expense); });
    }
    let months = '';
    for (let m = 1; m <= 12; m++) months += compactHeatMonth(c.data, c.book.id, c.year, m, type, max);
    return '<section class="card heat-card">' +
      '<div class="card-title">每月收支热力' +
        statsToggleHTML(type, [['expense', '支出'], ['income', '收入']], 'stats-heat-type') +
      '</div>' +
      '<div class="heat-year-grid" data-act="open-year-heatmap">' + months + '</div>' +
      '<button class="heat-expand" data-act="open-year-heatmap">点击放大热力图 <span>↗</span></button>' +
    '</section>';
  }

  function fullHeatMonth(c, year, month, type) {
    const key = year + '-' + pad2(month);
    const daily = C.dayTotals(c.data, c.book.id, key);
    const dim = C.daysInMonth(year, month);
    let max = 0;
    Object.keys(daily).forEach((d) => { max = Math.max(max, type === 'income' ? daily[d].income : daily[d].expense); });
    let cells = '';
    // 统一 5 行 x 7 列，按 1—31 日顺序排列，避免每周起始不同导致空白和长短不齐。
    for (let day = 1; day <= 35; day++) {
      if (day > dim) { cells += '<span class="heat-full-cell empty"></span>'; continue; }
      const rec = daily[day] || { expense: 0, income: 0 };
      const value = type === 'income' ? rec.income : rec.expense;
      cells += '<span class="heat-full-cell" style="' + heatStyle(value, max, type) + '"><b>' + day + '</b><i>' + (value ? (type === 'income' ? '+' : '-') + C.money(value, 0) : '') + '</i></span>';
    }
    return '<section class="heat-full-month"><h4>' + year + '年' + month + '月</h4>' +
      '<div class="heat-full-grid">' + cells + '</div></section>';
  }

  function openYearHeatmap() {
    const c = statsContext();
    if (!c.year || c.yearAll) return;
    const type = state.statsHeatType;
    const typeCN = type === 'income' ? '收入' : '支出';
    let months = '';
    for (let m = 1; m <= 12; m++) months += fullHeatMonth(c, c.year, m, type);
    openSheet({
      title: c.year + '年 每月收支热力', subtitle: '颜色越深，' + typeCN + '越高', className: 'heatmap-sheet', content:
        '<div class="heat-full">' + months + '</div>',
      onMount(root, close) { /* 静态热力展示，滚动查看 12 个月 */ }
    });
  }

  function statsHTML(paneMode, suffix) {
    const c = statsContext(paneMode);
    const sfx = suffix || '';
    const parts = [statsDatebarHTML(c), statsSummaryBoxHTML(c)];
    if (!c.totals.count) {
      parts.push('<div class="card"><div class="empty" style="padding:34px 16px"><div class="empty-emoji theme-symbol">' + themeEmptyIcon() + '</div>' +
        '<div class="empty-title">这个区间还没有账单</div><div class="empty-text">换个时间，或先记一笔再回来看看。</div></div></div>');
      parts.push(statsSummaryCardHTML(c));
      return '<div class="stats">' + parts.join('') + '</div>';
    }

    const chartTitle = c.mode === 'year' ? (c.yearAll ? '近十年收支' : c.year + ' 年 · 月度收支') : c.mode === 'month' ? '收支统计' : c.mode === 'daily' ? '近 7 天收支' : '区间收支';
    parts.push('<section class="card stats-chart-card">' +
      '<div class="stats-chart-head"><div class="card-title">' + chartTitle + '</div>' + statsChartControlsHTML() + '</div>' +
      '<div class="chart-bars stats-bars" id="statsBars' + sfx + '"></div>' +
      '<div class="chart-note">单位：' + (c.mode === 'year' && c.yearAll ? '年' : c.mode === 'year' || (c.mode === 'custom' && c.rangeDays > 31) ? '月' : '日') + ' · 点击柱/点查看明细</div>' +
    '</section>');

    if (c.mode === 'year' && !c.yearAll) parts.push(yearHeatmapHTML(c));

    if (c.mode === 'month' || c.mode === 'year') {
      parts.push('<section class="card">' +
        '<div class="card-title">资产走势<span>' + (c.mode === 'year' ? '每日净资产' : '每日净资产') + '</span></div>' +
        '<div class="chart-line stats-line" id="assetChart' + sfx + '"></div>' +
      '</section>');
      parts.push('<section class="card">' +
        '<div class="card-title">收支对比' +
          '<div class="stats-mini-seg"><button class="' + (state.statsSankey === 'category' ? 'active' : '') + '" data-act="stats-sankey" data-value="category">一级分类</button>' +
          '<button class="' + (state.statsSankey === 'all' ? 'active' : '') + '" data-act="stats-sankey" data-value="all">全部</button></div>' +
        '</div>' +
        '<div class="sankey-chart" id="sankeyChart' + sfx + '"></div>' +
        '<div class="sankey-legend">' + c.sankeyNodes.map((n) => (
          '<span><i style="background:' + n.color + '"></i>' + esc(n.name) + '<b>¥' + C.money(n.value, 0) + '</b></span>'
        )).join('') +
        (c.totals.balance > 0 ? '<span><i style="background:#0e9f6e"></i>结余<b>¥' + C.money(c.totals.balance, 0) + '</b></span>' : '') +
        (c.totals.balance < 0 ? '<span><i style="background:#e5484d"></i>超支<b>¥' + C.money(-c.totals.balance, 0) + '</b></span>' : '') +
        '</div>' +
      '</section>');
    }

    parts.push(statsShareHTML(c, sfx));
    parts.push(statsExpenseDataHTML(c));
    parts.push(statsRankHTML(c));
    parts.push(statsTableHTML(c));
    parts.push(statsSummaryCardHTML(c));
    return '<div class="stats">' + parts.join('') + '</div>';
  }

  function openStatsBills(c, idx) {
    const data = c.data;
    const labels = c.labels;
    let from = c.from;
    let to = c.to;
    let title = labels[idx] || '账单明细';
    if (c.mode === 'year') {
      if (c.yearAll) {
        const y = Number(labels[idx]);
        if (!Number.isFinite(y)) return;
        from = y + '-01-01';
        to = y + '-12-31';
        title = y + '年账单';
      } else {
        const m = idx + 1;
        from = c.year + '-' + pad2(m) + '-01';
        to = C.monthEnd(c.year + '-' + pad2(m));
        title = c.year + '年' + m + '月账单';
      }
    } else if (c.mode === 'month') {
      const date = c.monthKey + '-' + pad2(idx + 1);
      from = date; to = date; title = C.dateLabel(date) + '账单';
    } else if (c.mode === 'daily') {
      const date = C.addDaysISO(c.from, idx);
      from = date; to = date; title = C.dateLabel(date) + '账单';
    } else if (c.mode === 'custom') {
      if (c.rangeDays <= 31) {
        const date = C.addDaysISO(c.from, idx);
        from = date; to = date; title = C.dateLabel(date) + '账单';
      } else {
        const key = C.addMonthsKey(C.monthKeyOf(c.from), idx);
        from = key + '-01'; to = C.monthEnd(key); title = C.monthLabel(key) + '账单';
      }
    }
    const txs = C.sortTransactions(data.transactions.filter((t) => t.bookId === c.book.id && t.date >= from && t.date <= to));
    const totals = C.rangeTotals(data, c.book.id, from, to);
    openSheet({
      title, subtitle: '支出 ¥' + C.money(totals.expense) + ' · 收入 ¥' + C.money(totals.income) + ' · 结余 ¥' + C.money(totals.balance),
      className: 'bill-sheet', content:
        '<div class="bill-summary">' +
          '<div><span>支出</span><b>¥' + C.money(totals.expense) + '</b></div>' +
          '<div><span>收入</span><b>¥' + C.money(totals.income) + '</b></div>' +
          '<div><span>结余</span><b>' + signedMoneyText(totals.balance) + '</b></div>' +
        '</div>' +
        (txs.length ? '<div class="tx-list">' + txs.map((t) => txRowHTML(t)).join('') + '</div>'
          : '<div class="empty" style="padding:30px 10px"><div class="empty-emoji theme-symbol">' + themeEmptyIcon() + '</div><div class="empty-title">这个单位下还没有账单</div></div>')
    });
  }

  function attachChartNav(el, c) {
    if (!el) return;
    el.style.position = 'relative';
    el.onclick = (e) => {
      const rect = el.getBoundingClientRect();
      const x = Math.max(0, Math.min(rect.width, e.clientX - rect.left));
      const n = c.labels.length;
      let idx = 0;
      if (state.statsChartType === 'line') idx = Math.round((x / Math.max(rect.width, 1)) * (n - 1));
      else idx = Math.floor((x / Math.max(rect.width, 1)) * n);
      idx = Math.max(0, Math.min(n - 1, idx));
      openStatsBills(c, idx);
    };
  }

  function mountStatsCharts(paneMode, suffix) {
    const c = statsContext(paneMode);
    const sfx = suffix || '';
    const theme = document.documentElement.getAttribute('data-theme');
    const dark = isDarkTheme(theme);
    const labelColor = dark ? 'rgba(200,208,230,.85)' : 'rgba(91,109,100,.85)';
    const textColor = dark ? '#eef2ff' : '#101c16';
    const gridColor = dark ? 'rgba(255,255,255,.09)' : 'rgba(16,28,22,.08)';
    const barColor = state.statsType === 'income' ? '#0e9f6e' : state.statsType === 'balance' ? '#3b82f6' : '#ef6c5a';

    const barsEl = document.getElementById('statsBars' + sfx);
    if (barsEl) {
      const chartData = c.series ? { labels: c.labels, series: c.series, highlight: c.highlight } : { labels: c.labels, values: c.values, highlight: c.highlight };
      if (state.statsChartType === 'line') {
        CH.line(barsEl, chartData, {
          color: barColor,
          axis: true,
          domain: state.statsType === 'balance' ? 'minmax' : undefined,
          fillTop: 'rgba(239,108,90,.18)',
          fillBottom: 'rgba(239,108,90,0)',
          labelColor, gridColor
        });
      } else {
        CH.bars(barsEl, chartData, {
          color: barColor,
          mutedColor: alpha(barColor, 0.65),
          negativeColor: '#e5484d',
          showValues: c.showValues && state.statsType !== 'all',
          labelEvery: c.labelEvery,
          axis: true,
          labelColor, textColor, gridColor,
          barWidth: c.labels.length > 20 ? 10 : 20
        });
      }
      attachChartNav(barsEl, c);
    }

    const donutEl = document.getElementById('statsDonut' + sfx);
    if (donutEl) {
      const list = c.breakdown.slice(0, 6).map((x) => ({ value: x.value, color: x.color }));
      const rest = c.breakdown.slice(6).reduce((sum, x) => sum + x.value, 0);
      if (rest > 0) list.push({ value: rest, color: '#94a3b8' });
      CH.donut(donutEl, list, { emptyColor: dark ? 'rgba(255,255,255,.08)' : 'rgba(148,163,184,.16)' });
    }

    if (c.mode === 'month' || c.mode === 'year') {
      const assetEl = document.getElementById('assetChart' + sfx);
      if (assetEl && c.asset) {
        const first = c.mode === 'month' ? '1 日' : (c.asset[0] ? c.asset[0].date.slice(5) : '');
        const last = c.mode === 'month' ? c.asset.length + ' 日' : (c.asset[c.asset.length - 1] ? c.asset[c.asset.length - 1].date.slice(5) : '');
        CH.line(assetEl, {
          labels: [first, last],
          values: c.asset.map((x) => x.value)
        }, {
          color: '#0ea5e9', axis: true, domain: 'minmax',
          fillTop: 'rgba(14,165,233,.22)', fillBottom: 'rgba(14,165,233,0)',
          labelColor, gridColor
        });
      }
      const sankeyEl = document.getElementById('sankeyChart' + sfx);
      if (sankeyEl) {
        CH.sankey(sankeyEl, {
          income: c.totals.income,
          expense: c.totals.expense,
          nodes: c.sankeyNodes
        }, {});
      }
    }

    window.setTimeout(wireMonthRail, 80);
    window.setTimeout(wireYearRail, 80);
  }

  function stepStatsMonth(delta) {
    state.statsMonth = C.addMonthsKey(state.statsMonth, delta);
    state.statsYear = Number(state.statsMonth.slice(0, 4));
    state.statsSwipe = delta;
    renderView();
    window.scrollTo(0, 0);
    window.setTimeout(() => { state.statsSwipe = 0; }, 260);
  }

  function stepStatsYear(delta) {
    state.statsYearAll = false;
    state.statsYear += delta;
    renderView();
    window.scrollTo(0, 0);
  }

  function wireYearRail() {
    const rail = document.querySelector('[data-year-rail]');
    if (!rail || rail.dataset.wired === '1') return;
    rail.dataset.wired = '1';
    let startX = null, startY = null, horizontal = false;
    rail.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX; startY = e.touches[0].clientY; horizontal = false;
    }, { passive: true });
    rail.addEventListener('touchmove', (e) => {
      if (startX == null) return;
      const dx = e.touches[0].clientX - startX;
      const dy = e.touches[0].clientY - startY;
      if (Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy)) {
        horizontal = true;
        if (e.cancelable) e.preventDefault();
      }
      if (horizontal) {
        rail.style.transition = 'none';
        rail.style.transform = 'translateX(' + Math.max(-90, Math.min(90, dx * 0.7)).toFixed(1) + 'px)';
      }
    }, { passive: false });
    rail.addEventListener('touchend', (e) => {
      if (startX == null) return;
      const dx = e.changedTouches[0].clientX - startX;
      const dy = e.changedTouches[0].clientY - startY;
      startX = null; startY = null;
      rail.style.transition = 'transform .18s ease';
      rail.style.transform = 'translateX(0)';
      if (horizontal && Math.abs(dx) > 30 && Math.abs(dx) > Math.abs(dy) * 1.2) {
        state.suppressClickUntil = Date.now() + 300;
        stepStatsYear(dx < 0 ? -1 : 1);
      }
      horizontal = false;
    }, { passive: true });
  }

  function wireMonthRail() {
    const rail = document.querySelector('[data-month-rail]');
    if (!rail || rail.dataset.wired === '1') return;
    rail.dataset.wired = '1';
    let startX = null;
    let startY = null;
    let horizontal = false;
    rail.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX;
      startY = e.touches[0].clientY;
      horizontal = false;
    }, { passive: true });
    rail.addEventListener('touchmove', (e) => {
      if (startX == null) return;
      const dx = e.touches[0].clientX - startX;
      const dy = e.touches[0].clientY - startY;
      if (Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy)) {
        horizontal = true;
        if (e.cancelable) e.preventDefault();
      }
      if (horizontal) {
        rail.style.transition = 'none';
        rail.style.transform = 'translateX(' + Math.max(-90, Math.min(90, dx * 0.7)).toFixed(1) + 'px)';
      }
    }, { passive: false });
    rail.addEventListener('touchend', (e) => {
      if (startX == null) return;
      const dx = e.changedTouches[0].clientX - startX;
      const dy = e.changedTouches[0].clientY - startY;
      startX = null;
      startY = null;
      rail.style.transition = 'transform .18s ease';
      rail.style.transform = 'translateX(0)';
      if (horizontal && Math.abs(dx) > 30 && Math.abs(dx) > Math.abs(dy) * 1.2) {
        state.suppressClickUntil = Date.now() + 300;
        // 手指向左 → 上个月；向右 → 下个月，每次只走一格
        stepStatsMonth(dx < 0 ? -1 : 1);
      }
      horizontal = false;
    }, { passive: true });
  }

  function openStatsMonthPicker() {
    let year = Number(state.statsMonth.slice(0, 4));
    openSheet({
      title: '选择年月', subtitle: '统计月份', content: '<div data-picker></div>',
      onMount(root, close) {
        const body = root.querySelector('[data-picker]');
        function paint() {
          const current = state.statsMonth;
          body.innerHTML =
            '<div class="stats-month-picker-head">' +
              '<button data-picker-year="-1">‹</button><b>' + year + ' 年</b><button data-picker-year="1">›</button>' +
            '</div>' +
            '<div class="stats-month-picker-grid">' + Array.from({ length: 12 }, (_, i) => {
              const key = year + '-' + pad2(i + 1);
              const active = key === current;
              return '<button class="' + (active ? 'active' : '') + '" data-picker-month="' + key + '">' + (i + 1) + '月' +
                (key === C.thisMonthKey() ? '<small>本月</small>' : '') + '</button>';
            }).join('') + '</div>';
        }
        paint();
        body.addEventListener('click', (e) => {
          const step = e.target.closest('[data-picker-year]');
          if (step) { year += Number(step.dataset.pickerYear); paint(); return; }
          const month = e.target.closest('[data-picker-month]');
          if (!month) return;
          state.statsMonth = month.dataset.pickerMonth;
          state.statsYear = Number(month.dataset.pickerMonth.slice(0, 4));
          state.statsMode = 'month';
          close();
          render();
          window.scrollTo(0, 0);
        });
      }
    });
  }

  function openStatsDate(which) {
    const current = which === 'start' ? state.statsCustomFrom : state.statsCustomTo;
    openDatePicker(current, (day) => {
      if (which === 'start') {
        state.statsCustomFrom = day;
        if (state.statsCustomTo < day) state.statsCustomTo = day;
      } else {
        state.statsCustomTo = day;
        if (state.statsCustomFrom > day) state.statsCustomFrom = day;
      }
      renderView();
    });
  }

  function openStatsMenu() {
    const book = C.activeBook(state.data);
    openSheet({
      title: '统计说明', subtitle: '当前账本：' + esc(book.name), content:
        '<div class="menu">' +
          '<div class="menu-row"><span class="menu-icon">📅</span><span class="menu-label">日常</span><span class="menu-value">最近 7 天</span></div>' +
          '<div class="menu-row"><span class="menu-icon">📊</span><span class="menu-label">月统计</span><span class="menu-value">按日 · 含资产走势</span></div>' +
          '<div class="menu-row"><span class="menu-icon">🗓️</span><span class="menu-label">年统计</span><span class="menu-value">按月</span></div>' +
          '<div class="menu-row"><span class="menu-icon">🎯</span><span class="menu-label">自定义</span><span class="menu-value">任意日期区间</span></div>' +
        '</div>' +
        '<div class="hint-box" style="margin-top:14px">统计只计算当前账本。资产走势按每日结束时的净资产计算；转账不计入收支。报表只列出有记账的日期。</div>' +
        '<button class="btn ghost block" data-stats-switch style="margin-top:14px">切换账本</button>' +
        '<button class="btn ghost block" data-stats-data style="margin-top:8px">导出 Excel / 备份</button>',
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          if (e.target.closest('[data-stats-switch]')) { close(); openBooks(); }
          if (e.target.closest('[data-stats-data]')) { close(); openData(); }
        });
      }
    });
  }

  function openBookkeepingAccounts() {
    const rows = state.data.accounts.map((a) => (
      '<label class="list-item" style="border:0;padding-left:0;padding-right:0">' +
        '<span class="ic" style="background:' + alpha(a.color, 0.14) + '">' + a.icon + '</span>' +
        '<span class="grow"><span class="t" style="display:block">' + esc(a.name) + '</span>' +
          '<span class="s" style="display:block">' + (a.bookkeeping === false ? '未启用 · 不出现在记账选择里' : '已启用记账') + '</span></span>' +
        '<span class="switch"><input type="checkbox" data-bookkeeping-account="' + a.id + '"' + (a.bookkeeping !== false ? ' checked' : '') + '><span class="switch-track"></span></span>' +
      '</label>'
    )).join('');
    openSheet({
      title: '记账账户', subtitle: '关闭后不再出现在记账与转账选择中', content:
        '<div class="list-plain">' + rows + '</div>' +
        '<div class="hint-box" style="margin-top:12px">已有账单不会消失；重新开启后账户会回到记账选择里。可全部关闭。</div>',
      footer: '<button class="btn primary block" data-close-bookkeeping>完成</button>',
      onMount(root, close) {
        root.addEventListener('change', (e) => {
          const input = e.target.closest('[data-bookkeeping-account]');
          if (!input) return;
          const account = state.data.accounts.find((a) => a.id === input.dataset.bookkeepingAccount);
          if (!account) return;
          account.bookkeeping = input.checked;
          saveData();
          const caption = input.closest('label').querySelector('.s');
          if (caption) caption.textContent = input.checked ? '已启用记账' : '未启用 · 不出现在记账选择里';
          toast(input.checked ? '已启用记账' : '已关闭记账');
        });
        root.addEventListener('click', (e) => {
          if (!e.target.closest('[data-close-bookkeeping]')) return;
          close();
          render();
        });
      }
    });
  }

  function openBalanceEditor(account) {
    if (!account) return;
    const current = (C.accountBalances(state.data)[account.id] || 0);
    openSheet({
      title: '编辑余额', subtitle: account.name + ' · 当前余额', content:
        '<div class="field"><div class="field-label">新的余额<span>修改初始余额，账单保持不变</span></div>' +
          '<input class="input num" inputmode="decimal" data-balance value="' + C.round2(current) + '"></div>' +
        '<div class="hint-box">当前余额 = 初始余额 + 收入 − 支出 + 转入 − 转出。保存后会反推初始余额，已有账单不变。</div>',
      footer: '<button class="btn primary block" data-save-balance>保存余额</button>',
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          if (!e.target.closest('[data-save-balance]')) return;
          const value = Number($('[data-balance]', root).value);
          if (!isFinite(value)) { toast('请输入正确金额'); return; }
          const diff = C.round2(value - current);
          account.initial = C.round2(account.initial + diff);
          if (!saveData()) return;
          close();
          render();
          toast('余额已更新', 'success');
        });
      }
    });
  }

  function deleteAccountWithBills(account) {
    if (!account) return;
    if (state.data.accounts.length <= 1) { toast('至少保留一个账户'); return; }
    const txs = state.data.transactions.filter((t) => t.accountId === account.id || t.toAccountId === account.id);
    const rules = state.data.recurring.filter((r) => r.accountId === account.id);
    const detail = txs.length || rules.length
      ? '该账户关联 ' + txs.length + ' 笔账单' + (rules.length ? '、' + rules.length + ' 条周期规则' : '') + '，删除账户会一并删除这些记录。'
      : '删除后不可恢复。';
    confirmDialog({
      title: '删除账户「' + account.name + '」？',
      message: detail,
      confirmText: '删除', danger: true
    }).then((ok) => {
      if (!ok) return;
      state.data.accounts = state.data.accounts.filter((a) => a.id !== account.id);
      state.data.transactions = state.data.transactions.filter((t) => t.accountId !== account.id && t.toAccountId !== account.id);
      state.data.recurring = state.data.recurring.filter((r) => r.accountId !== account.id);
      if (!saveData()) return;
      render();
      toast('账户已删除');
    });
  }

  function assetsHTML() {
    const data = state.data;
    const balances = C.accountBalances(data);
    const totals = C.totalAssets(data);
    const month = C.thisMonthKey();
    const assetAccounts = data.accounts.filter((a) => !(C.ACCOUNT_TYPES[a.type] && C.ACCOUNT_TYPES[a.type].liability));
    const debtAccounts = data.accounts.filter((a) => (C.ACCOUNT_TYPES[a.type] && C.ACCOUNT_TYPES[a.type].liability));

    function rows(list) {
      if (!list.length) return '<div class="empty" style="padding:22px 10px 26px;font-size:12px">还没有账户</div>';
      return list.map((a) => {
        const flow = C.accountMonthFlow(data, a.id, month);
        const bal = balances[a.id] || 0;
        return '<button class="acct-row" data-act="edit-account" data-id="' + a.id + '">' +
          '<span class="acct-icon" style="background:' + alpha(a.color, 0.14) + '">' + a.icon + '</span>' +
          '<span class="grow">' +
            '<span class="acct-name">' + esc(a.name) +
              (a.name === (C.ACCOUNT_TYPES[a.type] || C.ACCOUNT_TYPES.other).name ? '' : '<span class="acct-type">' + (C.ACCOUNT_TYPES[a.type] || C.ACCOUNT_TYPES.other).name + '</span>') +
              (a.bookkeeping === false ? '<span class="acct-tag">未启用记账</span>' : '') +
            '</span>' +
            '<span class="acct-sub">本月支出 ¥' + C.money(flow.outflow, 0) + (flow.inflow ? ' · 流入 ¥' + C.money(flow.inflow, 0) : '') + '</span>' +
          '</span>' +
          '<span class="acct-balance' + (bal < 0 ? ' neg' : '') + '" data-act="edit-balance" data-id="' + a.id + '" title="点击修改余额">' +
            (bal < 0 ? '-' : '') + '¥' + C.money(Math.abs(bal)) + '<small>余额 ✎</small></span>' +
        '</button>';
      }).join('');
    }

    return '<div class="assets">' +
      '<section class="asset-hero">' +
        '<div class="k">净资产</div>' +
        '<div class="big"><span class="cur">¥</span>' + C.money(totals.net) + '</div>' +
        '<div class="asset-break">' +
          '<div><span>总资产</span><b>¥' + C.money(totals.assets) + '</b></div>' +
          '<div><span>总负债</span><b>¥' + C.money(Math.abs(totals.debts)) + '</b></div>' +
          '<div><span>账户</span><b>' + data.accounts.length + ' 个</b></div>' +
        '</div>' +
      '</section>' +
      '<div class="action-row">' +
        '<button class="action-btn primary" data-act="open-transfer">' + svg('swap', 18) + '转账</button>' +
        '<button class="action-btn" data-act="add-account">' + svg('plus', 18) + '新增账户</button>' +
      '</div>' +
      '<button class="bookkeeping-bar" data-act="open-account-bookkeeping">' +
        '<span class="bb-icon">📒</span><span class="grow"><b>记账账户</b><small>' +
          data.accounts.filter((a) => a.bookkeeping !== false).length + ' / ' + data.accounts.length + ' 个启用</small></span>' +
        '<span class="chev">›</span></button>' +
      '<div class="acct-group">' +
        '<div class="acct-head"><span>资金账户</span><span>' + assetAccounts.length + ' 个</span></div>' +
        '<div class="acct-list">' + rows(assetAccounts) + '</div>' +
      '</div>' +
      (debtAccounts.length ? '<div class="acct-group">' +
        '<div class="acct-head"><span>信用负债</span><span>' + debtAccounts.length + ' 个</span></div>' +
        '<div class="acct-list">' + rows(debtAccounts) + '</div>' +
      '</div>' : '') +
      '<div class="hint-box">点击账户可修改名称与图标；点余额可直接改当前余额。长按账户可删除账户及关联账单。</div>' +
      '<div class="footer-space"></div>' +
    '</div>';
  }

  /* ------------------------------------------------------------------ *
   * 我的页
   * ------------------------------------------------------------------ */

  function profileHTML() {
    const data = state.data;
    const stats = C.overallStats(data);
    const book = C.activeBook(data);
    const themeText = themeById(data.settings.theme).name;
    return '<div class="profile">' +
      '<section class="profile-brand">' +
        '<span class="profile-brand-logo">✦</span>' +
        '<div class="grow"><div class="profile-brand-name">星空记账</div>' +
          '<div class="profile-brand-sub">本地记账 · 数据自持 · 离线可用</div></div>' +
        '<span class="profile-brand-badge">v' + VERSION_TEXT + '</span>' +
      '</section>' +
      '<div class="stat-strip">' +
        '<div><b>' + stats.count + '</b><span>记账笔数</span></div>' +
        '<div><b>' + stats.days + '</b><span>记账天数</span></div>' +
        '<div><b>' + stats.streak + '</b><span>连续天数</span></div>' +
      '</div>' +
      '<div class="menu-group">' +
        '<div class="menu-group-title">账本</div>' +
        '<div class="menu">' +
          '<button class="menu-row" data-act="open-books"><span class="menu-icon">' + book.icon + '</span>' +
            '<span class="menu-label">账本管理</span><span class="menu-value">' + esc(book.name) + '<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-act="open-categories"><span class="menu-icon">🏷️</span>' +
            '<span class="menu-label">分类管理</span><span class="menu-value">' + data.categories.length + ' 个<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-act="open-budget"><span class="menu-icon">🎯</span>' +
            '<span class="menu-label">预算设置</span><span class="menu-value">' + (book.budget.total > 0 ? '¥' + C.money(book.budget.total, 0) : '未设置') + '<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-act="open-recurring"><span class="menu-icon">🔁</span>' +
            '<span class="menu-label">周期记账</span><span class="menu-value">' + data.recurring.length + ' 条<span class="chev">›</span></span></button>' +
        '</div>' +
      '</div>' +
      '<div class="menu-group">' +
        '<div class="menu-group-title">数据</div>' +
        '<div class="menu">' +
          '<button class="menu-row" data-act="open-data"><span class="menu-icon">🗂️</span>' +
            '<span class="menu-label">数据与备份</span><span class="menu-value">导出 / 导入<span class="chev">›</span></span></button>' +
        '</div>' +
      '</div>' +
      '<div class="menu-group">' +
        '<div class="menu-group-title">偏好</div>' +
        '<div class="menu">' +
          '<button class="menu-row" data-act="open-theme"><span class="menu-icon">🎨</span>' +
            '<span class="menu-label">外观主题</span><span class="menu-value">' + themeText + '<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-act="open-pin"><span class="menu-icon">🔒</span>' +
            '<span class="menu-label">隐私锁</span><span class="menu-value">' + (data.settings.pinHash ? '已开启' : '未开启') + '<span class="chev">›</span></span></button>' +
          (data.settings.pinHash ? '<button class="menu-row" data-act="lock-now"><span class="menu-icon">🔐</span>' +
            '<span class="menu-label">立即锁定</span><span class="chev">›</span></button>' : '') +
        '</div>' +
      '</div>' +
      '<div class="menu-group">' +
        '<div class="menu-group-title">关于</div>' +
        '<div class="menu">' +
          '<button class="menu-row" data-act="open-about"><span class="menu-icon">🌌</span>' +
            '<span class="menu-label">关于星空记账</span><span class="menu-value">v' + VERSION_TEXT + '<span class="chev">›</span></span></button>' +
        '</div>' +
      '</div>' +
      '<div class="about-note">星空记账 · 极简本地记账<br>所有数据存放于浏览器 localStorage，不上传任何服务器</div>' +
      '<div class="footer-space"></div>' +
    '</div>';
  }

  /* ------------------------------------------------------------------ *
   * 记一笔
   * ------------------------------------------------------------------ */

  const BOOK_ICONS = ['📒', '🏠', '✈️', '🎒', '💼', '🏝️', '🚗', '🎓', '🐱', '🌱', '💍', '🎯'];
  const CAT_ICONS = ['🍜', '🍔', '☕', '🍰', '🍺', '🚌', '🚗', '🚲', '✈️', '🚄', '🛍️', '👕', '👟', '💄', '🏠', '🛋️', '💡', '📱', '💻', '🎮', '🎬', '🎵', '📚', '✏️', '🏀', '⚽', '🐶', '🐱', '💊', '🧸', '🎁', '🧾', '💰', '💼', '📈', '🧧', '🏦', '🚿', '🛒', '🍎', '🌱', '🧴', '🔧', '📷', '🎨', '🏷️'];
  const ACCOUNT_ICONS = ['💵', '💠', '🟢', '🏦', '💳', '📈', '👛', '🎫', '🪙', '🏧'];
  const CAT_COLORS = ['#f97316', '#ef4444', '#ec4899', '#8b5cf6', '#6366f1', '#3b82f6', '#0ea5e9', '#14b8a6', '#10b981', '#84cc16', '#eab308', '#f59e0b', '#64748b', '#94a3b8'];
  const BOOK_COLORS = ['#0e9f6e', '#3b82f6', '#f59e0b', '#ec4899', '#8b5cf6', '#14b8a6'];

  function catGridHTML(type) {
    const cats = C.categoriesOf(state.data, type);
    return '<div class="cat-grid">' + cats.map((c) => (
      '<button class="cat-cell" data-cat="' + c.id + '">' +
        '<span class="cat-ico" style="background:' + alpha(c.color, 0.13) + '">' + c.icon + '</span>' +
        '<span class="cat-name">' + esc(c.name) + '</span>' +
      '</button>'
    )).join('') +
      '<button class="cat-cell manage" data-manage-cats>' +
        '<span class="cat-ico">⚙️</span><span class="cat-name">管理</span>' +
      '</button>' +
    '</div>';
  }

  function transferPanelHTML(draft) {
    const am = C.accountMap(state.data);
    const from = am[draft.accountId];
    const to = am[draft.toAccountId];
    return '<div class="transfer-panel">' +
      '<button class="account-pick" data-pick="from">' +
        '<span class="ic">' + (from ? from.icon : '👛') + '</span>' +
        '<span class="grow"><span class="t">转出账户</span><span class="v">' + (from ? esc(from.name) : '请选择') + '</span></span>' +
        '<span class="chev">›</span>' +
      '</button>' +
      '<div class="arrow-down">↓</div>' +
      '<button class="account-pick" data-pick="to">' +
        '<span class="ic">' + (to ? to.icon : '👛') + '</span>' +
        '<span class="grow"><span class="t">转入账户</span><span class="v">' + (to ? esc(to.name) : '请选择') + '</span></span>' +
        '<span class="chev">›</span>' +
      '</button>' +
      '<div class="hint-box" style="margin-top:4px">转账不计入收支，只改变账户余额。</div>' +
    '</div>';
  }

  function entryHTML(draft, editing) {
    const isTransfer = draft.type === 'transfer';
    const am = C.accountMap(state.data);
    const acc = am[draft.accountId];
    const keys = ['7', '8', '9', 'date', '4', '5', '6', '+', '1', '2', '3', '-', '.', '0', 'del', 'ok'];
    return '<div class="sheet entry">' +
      '<div class="sheet-grab"></div>' +
      '<div class="sheet-head">' +
        '<div class="grow">' +
          '<div class="sheet-title">' + (editing ? '编辑账单' : '记一笔') + '</div>' +
          '<div class="sheet-sub" data-sub>' + C.fullDateLabel(draft.date) + ' · ' + C.weekdayCN(draft.date) + '</div>' +
        '</div>' +
        '<button class="btn ghost" data-more style="height:30px;padding:0 10px;font-size:12px;margin-left:auto">更多信息<span data-morecount style="margin-left:2px"></span></button>' +
        '<button class="icon-btn small" data-close aria-label="关闭">' + svg('close', 18) + '</button>' +
      '</div>' +
      '<div class="entry-tabs">' +
        ['expense', 'income', 'transfer'].map((t) => (
          '<button class="entry-tab' + (draft.type === t ? ' active ' + t : '') + '" data-type="' + t + '">' + C.TYPE_CN[t] + '</button>'
        )).join('') +
      '</div>' +
      '<div class="entry-body">' +
        '<div class="cat-wrap" data-cats>' + (isTransfer ? transferPanelHTML(draft) : catGridHTML(draft.type)) + '</div>' +
        '<div class="entry-display">' +
          '<div class="entry-line"><span class="entry-expr" data-expr></span><div class="entry-amount" data-amount></div></div>' +
          '<div class="entry-meta">' +
            '<button class="meta-btn" data-date>📅 <b>' + C.dateLabel(draft.date) + '</b></button>' +
            '<button class="meta-btn" data-account' + (isTransfer ? ' style="display:none"' : '') + '>' +
              (acc ? acc.icon : '👛') + ' <b>' + (acc ? esc(acc.name) : '账户') + '</b></button>' +
            '<input class="note-input" data-note placeholder="备注一下…" maxlength="40" value="' + esc(draft.note) + '">' +
            '<button class="meta-btn" data-tags>🏷️ <b data-tagcount>' + (draft.tags.length ? draft.tags.length : '标签') + '</b></button>' +
            '<button class="meta-btn" data-more>⋯ <b data-morecount>更多</b></button>' +
          '</div>' +
        '</div>' +
        '<div class="keypad">' + keys.map((k) => {
          if (k === 'ok') return '<button class="key ok" data-key="ok">完成</button>';
          if (k === 'date') return '<button class="key fn" data-key="date">日期</button>';
          if (k === 'del') return '<button class="key del" data-key="del">⌫</button>';
          if (k === '+' || k === '-') return '<button class="key op" data-key="' + k + '">' + k + '</button>';
          return '<button class="key" data-key="' + k + '">' + k + '</button>';
        }).join('') + '</div>' +
        (editing ? '<div class="entry-delete"><button class="btn danger block" data-delete>' + svg('trash', 15) + ' 删除这笔账单</button></div>' : '') +
      '</div>' +
    '</div>';
  }

  function openEntry(txId, options) {
    const opts = options || {};
    const tx = txId ? state.data.transactions.find((t) => t.id === txId) : null;
    const cats = C.categoriesOf(state.data, 'expense');
    const accounts = state.data.accounts.filter((a) => a.bookkeeping !== false || (tx && (tx.accountId === a.id || tx.toAccountId === a.id)));
    if (!accounts.length) { toast('没有启用记账的账户，请先到资产页开启'); return; }
    const draft = {
      type: opts.type || (tx ? tx.type : 'expense'),
      amountStr: tx ? String(tx.amount) : '',
      catId: tx && tx.categoryId ? tx.categoryId : (cats[0] ? cats[0].id : null),
      accountId: tx && tx.accountId ? tx.accountId : (accounts[0] ? accounts[0].id : null),
      toAccountId: tx && tx.toAccountId ? tx.toAccountId : (accounts[1] ? accounts[1].id : (accounts[0] ? accounts[0].id : null)),
      date: tx ? tx.date : (opts.date || C.todayISO()),
      note: tx ? tx.note || '' : '',
      tags: tx ? (tx.tags || []).slice() : [],
      subcategory: tx ? tx.subcategory || '' : '',
      refund: tx ? tx.refund || 0 : 0,
      discount: tx ? tx.discount || 0 : 0,
      reimburseAccount: tx ? tx.reimburseAccount || '' : '',
      reimburseAmount: tx ? tx.reimburseAmount || 0 : 0,
      reimburseNote: tx ? tx.reimburseNote || '' : '',
      currency: tx ? tx.currency || '' : '',
      foreignAmount: tx ? tx.foreignAmount || 0 : 0,
      location: tx ? tx.location || '' : '',
      creator: tx ? tx.creator || '' : '我',
      extra: tx ? tx.extra || '' : '',
      attachments: tx && tx.attachments ? tx.attachments.map((a) => ({
        name: a.name, dataUrl: a.dataUrl || null, type: a.type || ''
      })) : []
    };

    const backdrop = document.createElement('div');
    backdrop.className = 'sheet-backdrop';
    backdrop.innerHTML = entryHTML(draft, !!tx);
    overlayRoot.appendChild(backdrop);
    document.body.classList.add('no-scroll');

    const root = backdrop.querySelector('.sheet');
    const catsEl = $('[data-cats]', root);
    const exprEl = $('[data-expr]', root);
    const amountEl = $('[data-amount]', root);
    const dateBtn = $('[data-date]', root);
    const acctBtn = $('[data-account]', root);
    const noteEl = $('[data-note]', root);
    const tagBtn = $('[data-tags]', root);
    const tagCount = $('[data-tagcount]', root);
    const moreCount = $('[data-morecount]', root);
    const subEl = $('[data-sub]', root);
    const tabs = $$('[data-type]', root);

    function close() {
      document.removeEventListener('keydown', onKey);
      backdrop.remove();
      if (!overlayRoot.children.length) document.body.classList.remove('no-scroll');
    }

    backdrop.addEventListener('click', (e) => { if (e.target === backdrop) close(); });

    function currentNumber() {
      const parts = draft.amountStr.split(/[+\-]/);
      return parts[parts.length - 1];
    }

    function updateAmount() {
      const cleaned = draft.amountStr.replace(/[+\-]+$/, '');
      const value = C.parseAmountExpr(cleaned);
      const v = isFinite(value) && value > 0 ? value : 0;
      const parts = C.amountParts(v);
      amountEl.innerHTML = '<span class="cur">¥</span>' + parts.int + '<span class="dec">.' + parts.dec + '</span>';
      const hasOp = /[+\-]/.test(draft.amountStr.replace(/^\-/, ''));
      exprEl.textContent = hasOp ? draft.amountStr.replace(/\+/g, ' + ').replace(/-/g, ' − ') : '';
    }

    function updateMeta() {
      const am = C.accountMap(state.data);
      const acc = am[draft.accountId];
      dateBtn.innerHTML = '📅 <b>' + C.dateLabel(draft.date) + '</b>';
      acctBtn.innerHTML = (acc ? acc.icon : '👛') + ' <b>' + (acc ? esc(acc.name) : '账户') + '</b>';
      tagCount.textContent = draft.tags.length ? String(draft.tags.length) : '标签';
      const extras = [
        draft.subcategory, draft.refund > 0, draft.discount > 0,
        draft.reimburseAccount, draft.reimburseAmount > 0, draft.currency,
        draft.location, draft.extra, draft.attachments.length
      ].filter(Boolean).length;
      $$('[data-morecount]', root).forEach((el) => {
        el.textContent = extras ? ' ' + extras + ' 项' : '';
      });
      subEl.textContent = C.fullDateLabel(draft.date) + ' · ' + C.weekdayCN(draft.date);
    }

    function paintCats() {
      catsEl.innerHTML = draft.type === 'transfer'
        ? transferPanelHTML(draft)
        : catGridHTML(draft.type);
      if (draft.type === 'transfer') {
        acctBtn.style.display = 'none';
      } else {
        acctBtn.style.display = '';
        $$('[data-cat]', catsEl).forEach((cell) => {
          cell.classList.toggle('active', cell.dataset.cat === draft.catId);
        });
      }
      noteEl.value = draft.note;
      updateMeta();
    }

    function setType(type) {
      if (draft.type === type) return;
      draft.type = type;
      tabs.forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.type === type);
        tab.classList.toggle(type, tab.dataset.type === type);
      });
      if (type !== 'transfer') {
        const list = C.categoriesOf(state.data, type);
        if (!list.some((c) => c.id === draft.catId)) draft.catId = list[0] ? list[0].id : null;
      }
      paintCats();
    }

    function appendKey(key) {
      if (key === 'del') {
        draft.amountStr = draft.amountStr.slice(0, -1);
      } else if (key === '.' ) {
        const cur = currentNumber();
        if (cur.indexOf('.') >= 0) return;
        draft.amountStr += cur === '' ? '0.' : '.';
      } else if (key === '+' || key === '-') {
        if (!draft.amountStr) return;
        if (/[+\-]$/.test(draft.amountStr)) return;
        if (draft.amountStr.length >= 18) return;
        draft.amountStr += key;
      } else if (/^[0-9]$/.test(key)) {
        const cur = currentNumber();
        if (cur.indexOf('.') >= 0 && cur.split('.')[1].length >= 2) return;
        if (cur.indexOf('.') < 0 && cur.replace(/^0+(?=\d)/, '').length >= 9) return;
        if (draft.amountStr.length >= 18) return;
        if (cur === '0') draft.amountStr = draft.amountStr.slice(0, -1) + key;
        else draft.amountStr += key;
      }
      updateAmount();
    }

    function save() {
      const amount = C.parseAmountExpr(draft.amountStr);
      if (!isFinite(amount) || amount <= 0) { toast('请输入有效金额'); return; }
      if (amount > 99999999.99) { toast('金额过大'); return; }
      if (draft.type === 'transfer') {
        if (!draft.accountId || !draft.toAccountId) { toast('请选择转出和转入账户'); return; }
        if (draft.accountId === draft.toAccountId) { toast('转出与转入账户不能相同'); return; }
      } else {
        if (!draft.catId) { toast('请选择分类'); return; }
        if (!draft.accountId) { toast('请选择账户'); return; }
      }
      const now = new Date();
      const base = {
        type: draft.type,
        amount: C.round2(amount),
        categoryId: draft.type === 'transfer' ? null : draft.catId,
        accountId: draft.accountId,
        toAccountId: draft.type === 'transfer' ? draft.toAccountId : null,
        date: draft.date,
        time: tx ? tx.time : pad2(now.getHours()) + ':' + pad2(now.getMinutes()),
        note: draft.note.trim(),
        tags: draft.tags.slice(),
        subcategory: draft.type === 'transfer' ? '' : String(draft.subcategory || '').trim().slice(0, 20),
        refund: C.round2(draft.refund || 0),
        discount: C.round2(draft.discount || 0),
        reimburseAccount: String(draft.reimburseAccount || '').trim(),
        reimburseAmount: C.round2(draft.reimburseAmount || 0),
        reimburseNote: String(draft.reimburseNote || '').trim(),
        currency: String(draft.currency || '').trim(),
        foreignAmount: C.round2(draft.foreignAmount || 0),
        location: String(draft.location || '').trim(),
        creator: String(draft.creator || '').trim(),
        extra: String(draft.extra || '').trim(),
        attachments: draft.attachments.slice(0, 5).map((a) => ({
          name: String(a.name || '').slice(0, 120),
          dataUrl: a.dataUrl || null,
          type: a.type || ''
        })),
        updatedAt: new Date().toISOString()
      };
      if (tx) {
        Object.assign(tx, base);
      } else {
        state.data.transactions.push(Object.assign({
          id: C.uid('t'), bookId: state.data.activeBookId,
          recurringId: null, createdAt: new Date().toISOString()
        }, base));
      }
      draft.tags.forEach((tag) => { if (state.data.tags.indexOf(tag) < 0) state.data.tags.push(tag); });
      if (!saveData()) return;
      close();
      state.month = C.monthKeyOf(draft.date);
      state.route = 'home';
      render();
      window.scrollTo(0, 0);
      toast((tx ? '已保存修改' : '已记一笔 ¥' + C.money(base.amount)), 'success');
    }

    function onKey(e) {
      if (overlayRoot.lastElementChild !== backdrop) return;
      const tag = e.target && e.target.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
      if (/^[0-9]$/.test(e.key)) { e.preventDefault(); appendKey(e.key); }
      else if (e.key === '+' || e.key === '-' || e.key === '.') { e.preventDefault(); appendKey(e.key); }
      else if (e.key === 'Backspace') { e.preventDefault(); appendKey('del'); }
      else if (e.key === 'Enter') { e.preventDefault(); save(); }
    }

    root.addEventListener('click', (e) => {
      if (e.target.closest('[data-close]')) { close(); return; }
      const typeBtn = e.target.closest('[data-type]');
      if (typeBtn) { setType(typeBtn.dataset.type); return; }
      const cat = e.target.closest('[data-cat]');
      if (cat) {
        draft.catId = cat.dataset.cat;
        $$('[data-cat]', catsEl).forEach((cell) => cell.classList.toggle('active', cell === cat));
        return;
      }
      if (e.target.closest('[data-manage-cats]')) {
        openCategories(draft.type, () => paintCats());
        return;
      }
      const key = e.target.closest('[data-key]');
      if (key) {
        const k = key.dataset.key;
        if (k === 'ok') save();
        else if (k === 'date') openDatePicker(draft.date, (day) => { draft.date = day; updateMeta(); });
        else appendKey(k);
        return;
      }
      if (e.target.closest('[data-date]')) {
        openDatePicker(draft.date, (day) => { draft.date = day; updateMeta(); });
        return;
      }
      if (e.target.closest('[data-account]')) {
        pickAccount(draft.accountId, null, (id) => { draft.accountId = id; updateMeta(); });
        return;
      }
      const pick = e.target.closest('[data-pick]');
      if (pick) {
        if (pick.dataset.pick === 'from') {
          pickAccount(draft.accountId, draft.toAccountId, (id) => {
            draft.accountId = id;
            catsEl.innerHTML = transferPanelHTML(draft);
            updateMeta();
          });
        } else {
          pickAccount(draft.toAccountId, draft.accountId, (id) => {
            draft.toAccountId = id;
            catsEl.innerHTML = transferPanelHTML(draft);
            updateMeta();
          });
        }
        return;
      }
      if (e.target.closest('[data-tags]')) {
        openTagPicker(draft.tags, (tags) => {
          draft.tags = tags;
          tagCount.textContent = tags.length ? String(tags.length) : '标签';
        });
        return;
      }
      if (e.target.closest('[data-more]')) {
        openMoreFields(draft, updateMeta);
        return;
      }
      if (e.target.closest('[data-delete]') && tx) {
        confirmDialog({
          title: '删除这笔账单？',
          message: '删除后无法恢复，账户余额会同步更新。',
          confirmText: '删除', danger: true
        }).then((ok) => {
          if (!ok) return;
          const idx = state.data.transactions.indexOf(tx);
          if (idx >= 0) state.data.transactions.splice(idx, 1);
          saveData();
          close();
          render();
          toast('已删除');
        });
      }
    });

    noteEl.addEventListener('input', () => { draft.note = noteEl.value; });
    updateAmount();
    paintCats();
    updateMeta();
    document.addEventListener('keydown', onKey);
    window.setTimeout(() => { if (overlayRoot.lastElementChild === backdrop) noteEl.blur(); }, 50);
  }

  function compressImage(file) {
    return new Promise((resolve) => {
      if (!file || !/^image\//.test(file.type || '')) { resolve(null); return; }
      const reader = new FileReader();
      reader.onload = () => {
        const img = new Image();
        img.onload = () => {
          try {
            const max = 600;
            const scale = Math.min(1, max / Math.max(img.width, img.height));
            const w = Math.max(1, Math.round(img.width * scale));
            const h = Math.max(1, Math.round(img.height * scale));
            const canvas = document.createElement('canvas');
            canvas.width = w;
            canvas.height = h;
            const ctx = canvas.getContext('2d');
            if (!ctx) {
              resolve({ name: file.name, dataUrl: null, type: file.type || '' });
              return;
            }
            ctx.fillStyle = '#fff';
            ctx.fillRect(0, 0, w, h);
            ctx.drawImage(img, 0, 0, w, h);
            resolve({
              name: file.name,
              dataUrl: canvas.toDataURL('image/jpeg', 0.58),
              type: 'image/jpeg'
            });
          } catch (err) {
            resolve({ name: file.name, dataUrl: null, type: file.type || '' });
          }
        };
        img.onerror = () => resolve({ name: file.name, dataUrl: null, type: file.type || '' });
        img.src = String(reader.result || '');
      };
      reader.onerror = () => resolve(null);
      reader.readAsDataURL(file);
    });
  }

  function openMoreFields(draft, onSaved) {
    const local = {
      subcategory: draft.subcategory || '',
      refund: draft.refund || 0,
      discount: draft.discount || 0,
      reimburseAccount: draft.reimburseAccount || '',
      reimburseAmount: draft.reimburseAmount || 0,
      reimburseNote: draft.reimburseNote || '',
      currency: draft.currency || '',
      foreignAmount: draft.foreignAmount || 0,
      location: draft.location || '',
      creator: draft.creator || '',
      extra: draft.extra || '',
      attachments: (draft.attachments || []).map((a) => ({
        name: a.name, dataUrl: a.dataUrl || null, type: a.type || ''
      }))
    };
    const suggestions = Array.from(new Set(state.data.transactions
      .filter((t) => t.categoryId === draft.catId && t.subcategory)
      .map((t) => t.subcategory))).slice(0, 10);
    const currencies = ['CNY', 'USD', 'EUR', 'JPY', 'HKD', 'GBP', 'AUD', 'CAD', 'SGD'];
    if (local.currency && currencies.indexOf(local.currency) < 0) currencies.push(local.currency);
    let accountOptions = state.data.accounts.filter((a) => a.bookkeeping !== false).map((a) => (
      '<option value="' + esc(a.name) + '"' + (a.name === local.reimburseAccount ? ' selected' : '') + '>' +
      a.icon + ' ' + esc(a.name) + '</option>'
    )).join('');
    if (local.reimburseAccount && !state.data.accounts.some((a) => a.name === local.reimburseAccount)) {
      accountOptions += '<option value="' + esc(local.reimburseAccount) + '" selected>' + esc(local.reimburseAccount) + '</option>';
    }

    const content =
      '<div class="section-title" style="margin:2px 3px 8px">分类补充</div>' +
      '<div class="field"><div class="field-label">二级分类<span>会导出到「二级分类」列</span></div>' +
        '<input class="input" data-subcategory maxlength="20" placeholder="例如：午餐、打车、房租" value="' + esc(local.subcategory) + '">' +
        (suggestions.length ? '<div class="chips" style="margin-top:8px">' + suggestions.map((x) => (
          '<button class="chip" data-sub-sug="' + esc(x) + '">' + esc(x) + '</button>'
        )).join('') + '</div>' : '') +
      '</div>' +
      '<div class="section-title" style="margin:16px 3px 8px">金额补充</div>' +
      '<div class="input-row">' +
        '<div class="field"><div class="field-label">退款</div><input class="input num" inputmode="decimal" data-refund placeholder="0.00" value="' + (local.refund || '') + '"></div>' +
        '<div class="field"><div class="field-label">优惠</div><input class="input num" inputmode="decimal" data-discount placeholder="0.00" value="' + (local.discount || '') + '"></div>' +
      '</div>' +
      '<div class="section-title" style="margin:16px 3px 8px">报销</div>' +
      '<div class="field"><div class="field-label">报销账户</div><select class="select" data-reimburse-account>' +
        '<option value="">不报销 / 无</option>' + accountOptions +
      '</select></div>' +
      '<div class="field"><div class="field-label">报销金额</div><input class="input num" inputmode="decimal" data-reimburse-amount placeholder="0.00" value="' + (local.reimburseAmount || '') + '"></div>' +
      '<div class="field"><div class="field-label">报销明细</div><input class="input" data-reimburse-note maxlength="100" placeholder="例如：公司团建 / 项目 A" value="' + esc(local.reimburseNote) + '"></div>' +
      '<div class="section-title" style="margin:16px 3px 8px">多币种</div>' +
      '<div class="input-row">' +
        '<div class="field"><div class="field-label">币种</div><select class="select" data-currency><option value="">不使用</option>' +
          currencies.map((c) => '<option value="' + c + '"' + (c === local.currency ? ' selected' : '') + '>' + c + '</option>').join('') +
        '</select></div>' +
        '<div class="field"><div class="field-label">原币金额</div><input class="input num" inputmode="decimal" data-foreign-amount placeholder="0.00" value="' + (local.foreignAmount || '') + '"></div>' +
      '</div>' +
      '<div class="hint-box">主金额仍按人民币计入账户余额；这里的原币金额只用于导出「多币种」列。</div>' +
      '<div class="section-title" style="margin:16px 3px 8px">其他</div>' +
      '<div class="field"><div class="field-label">地址</div><input class="input" data-location maxlength="120" placeholder="例如：公司楼下便利店" value="' + esc(local.location) + '"></div>' +
      '<div class="field"><div class="field-label">创建用户</div><input class="input" data-creator maxlength="20" placeholder="我" value="' + esc(local.creator) + '"></div>' +
      '<div class="field"><div class="field-label">其他</div><textarea class="textarea" data-extra maxlength="200" placeholder="补充说明">' + esc(local.extra) + '</textarea></div>' +
      '<div class="section-title" style="margin:16px 3px 8px">附件</div>' +
      '<div class="att-grid" data-att-grid></div>' +
      '<label class="btn ghost block" style="margin-top:10px;cursor:pointer">+ 添加图片（最多 5 张）' +
        '<input type="file" accept="image/*" multiple data-files hidden>' +
      '</label>' +
      '<div class="hint-box" style="margin-top:10px">图片会压缩到 600px 后保存在本机，并写入 JSON 备份；Excel 只导出文件名。图片较多时注意存储空间。</div>';

    openSheet({
      title: '更多账单信息',
      subtitle: '补充字段会出现在 Excel / CSV 导出中',
      content,
      footer: '<button class="btn primary block" data-save-more>保存更多信息</button>',
      onMount(root, close) {
        const grid = root.querySelector('[data-att-grid]');
        const fileInput = root.querySelector('[data-files]');
        function paintAtts() {
          if (!grid) return;
          if (!local.attachments.length) {
            grid.innerHTML = '<div class="muted small" style="grid-column:1/-1">还没有附件</div>';
            return;
          }
          grid.innerHTML = local.attachments.map((a, i) => (
            '<div class="att-item">' +
              (a.dataUrl ? '<img src="' + a.dataUrl + '" alt="">' : '<span class="att-file">📎</span>') +
              '<button class="att-remove" data-remove-att="' + i + '" aria-label="移除附件">×</button>' +
              '<span class="att-name">' + esc(a.name) + '</span>' +
            '</div>'
          )).join('');
        }
        paintAtts();

        root.addEventListener('click', (e) => {
          const sug = e.target.closest('[data-sub-sug]');
          if (sug) {
            root.querySelector('[data-subcategory]').value = sug.dataset.subSug;
            return;
          }
          const rm = e.target.closest('[data-remove-att]');
          if (rm) {
            local.attachments.splice(Number(rm.dataset.removeAtt), 1);
            paintAtts();
            return;
          }
          if (!e.target.closest('[data-save-more]')) return;
          const value = (sel) => {
            const el = root.querySelector(sel);
            return el ? el.value : '';
          };
          draft.subcategory = value('[data-subcategory]').trim().slice(0, 20);
          draft.refund = Math.max(0, C.round2(Number(value('[data-refund]')) || 0));
          draft.discount = Math.max(0, C.round2(Number(value('[data-discount]')) || 0));
          draft.reimburseAccount = value('[data-reimburse-account]');
          draft.reimburseAmount = Math.max(0, C.round2(Number(value('[data-reimburse-amount]')) || 0));
          draft.reimburseNote = value('[data-reimburse-note]').trim();
          draft.currency = value('[data-currency]');
          draft.foreignAmount = Math.max(0, C.round2(Number(value('[data-foreign-amount]')) || 0));
          draft.location = value('[data-location]').trim();
          draft.creator = value('[data-creator]').trim();
          draft.extra = value('[data-extra]').trim();
          draft.attachments = local.attachments.slice(0, 5).map((a) => ({
            name: a.name, dataUrl: a.dataUrl || null, type: a.type || ''
          }));
          close();
          if (onSaved) onSaved();
          toast('更多信息已保存', 'success');
        });

        if (fileInput) {
          fileInput.addEventListener('change', async () => {
            const files = Array.from(fileInput.files || []);
            fileInput.value = '';
            for (const file of files) {
              if (local.attachments.length >= 5) { toast('最多 5 张附件'); break; }
              if (!/^image\//.test(file.type || '')) { toast('仅支持图片附件'); continue; }
              if (file.size > 15 * 1024 * 1024) { toast('图片过大：' + file.name); continue; }
              const att = await compressImage(file);
              if (att) local.attachments.push(att);
            }
            paintAtts();
          });
        }
      }
    });
  }

  function pickAccount(currentId, excludeId, onPick) {
    const am = C.accountMap(state.data);
    const balances = C.accountBalances(state.data);
    const usable = state.data.accounts.filter((a) => a.bookkeeping !== false);
    if (!usable.length) { toast('没有启用记账的账户'); return; }
    const content = '<div class="list-plain">' + usable.map((a) => (
      '<button class="list-item" data-account-id="' + a.id + '" style="width:100%;text-align:left;background:none"' +
        (a.id === excludeId ? ' disabled' : '') + '>' +
        '<span class="ic" style="background:' + alpha(a.color, 0.14) + '">' + a.icon + '</span>' +
        '<span class="grow"><span class="t" style="display:block">' + esc(a.name) + '</span>' +
          '<span class="s" style="display:block">' + (C.ACCOUNT_TYPES[a.type] || C.ACCOUNT_TYPES.other).name + '</span></span>' +
        '<span class="r">¥' + C.money(balances[a.id] || 0) +
          (a.id === currentId ? ' ' + svg('check', 17) : '') + '</span>' +
      '</button>'
    )).join('') + '</div>';
    openSheet({
      title: '选择账户', subtitle: '账户余额会随记账自动更新', content,
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          const btn = e.target.closest('[data-account-id]');
          if (!btn || btn.disabled) return;
          onPick(btn.dataset.accountId);
          close();
        });
      }
    });
  }

  function openDatePicker(current, onPick) {
    let viewMonth = C.monthKeyOf(current);
    const today = C.todayISO();
    openSheet({
      title: '选择日期',
      subtitle: '账单日期 · ' + C.weekdayCN(current),
      content: '<div data-cal></div>',
      onMount(root, close) {
        const body = $('[data-cal]', root);
        function paint() {
          const firstWeekday = C.weekdayIndex(viewMonth + '-01');
          const days = C.daysInMonth(Number(viewMonth.slice(0, 4)), Number(viewMonth.slice(5, 7)));
          const cells = [];
          for (let i = 0; i < firstWeekday; i++) cells.push('<span class="cal-day empty"></span>');
          for (let d = 1; d <= days; d++) {
            const day = viewMonth + '-' + pad2(d);
            cells.push('<button class="cal-day' + (day === current ? ' sel' : '') + (day === today ? ' today' : '') + '" data-day="' + day + '">' +
              '<span class="d">' + d + '</span></button>');
          }
          body.innerHTML =
            '<div class="cal-head"><button data-nav="-1" aria-label="上个月">‹</button>' +
              '<span class="m">' + C.monthLabel(viewMonth) + '</span>' +
              '<button data-nav="1" aria-label="下个月">›</button></div>' +
            '<div class="cal-dow">' + ['日', '一', '二', '三', '四', '五', '六'].map((w) => '<span>' + w + '</span>').join('') + '</div>' +
            '<div class="cal-grid">' + cells.join('') + '</div>' +
            '<div class="quick-dates">' +
              '<button class="chip" data-quick="' + today + '">今天</button>' +
              '<button class="chip" data-quick="' + C.addDaysISO(today, -1) + '">昨天</button>' +
              '<button class="chip" data-quick="' + C.addDaysISO(today, -2) + '">前天</button>' +
            '</div>';
        }
        paint();
        body.addEventListener('click', (e) => {
          const nav = e.target.closest('[data-nav]');
          if (nav) { viewMonth = C.addMonthsKey(viewMonth, Number(nav.dataset.nav)); paint(); return; }
          const day = e.target.closest('[data-day]');
          if (day) { onPick(day.dataset.day); close(); return; }
          const quick = e.target.closest('[data-quick]');
          if (quick) { onPick(quick.dataset.quick); close(); }
        });
      }
    });
  }

  function openTagPicker(selected, onPick) {
    const tags = Array.from(new Set(state.data.tags.concat(C.recentTags(state.data, 18))));
    const active = selected.slice();
    const content =
      '<div class="chips" data-tag-list>' + (tags.length ? tags.map((t) => (
        '<button class="chip' + (active.indexOf(t) >= 0 ? ' active' : '') + '" data-tag="' + esc(t) + '">' + esc(t) + '</button>'
      )).join('') : '<span class="muted small">还没有用过标签，下面新建一个吧</span>') + '</div>' +
      '<div class="input-row" style="margin-top:14px">' +
        '<input class="input" data-new-tag placeholder="新建标签，如：朋友聚餐" maxlength="12">' +
        '<button class="btn" data-add-tag style="flex:none;width:76px">添加</button>' +
      '</div>' +
      '<div class="hint-box" style="margin-top:12px">标签用来给账单加维度，比如「出差」「装修」。同一个账单可以加多个标签。</div>';
    openSheet({
      title: '标签', subtitle: '给这笔账加个记号', content,
      onMount(root, close) {
        const list = $('[data-tag-list]', root);
        const input = $('[data-new-tag]', root);
        function paint() {
          const all = Array.from(new Set(C.recentTags(state.data, 30).concat(active)));
          list.innerHTML = all.map((t) => (
            '<button class="chip' + (active.indexOf(t) >= 0 ? ' active' : '') + '" data-tag="' + esc(t) + '">' + esc(t) + '</button>'
          )).join('');
        }
        function add() {
          const tag = C.normalizeTag(input.value);
          if (!tag) return;
          if (active.indexOf(tag) < 0) active.push(tag);
          input.value = '';
          paint();
        }
        root.addEventListener('click', (e) => {
          const chip = e.target.closest('[data-tag]');
          if (chip) {
            const tag = chip.dataset.tag;
            const i = active.indexOf(tag);
            if (i >= 0) active.splice(i, 1); else active.push(tag);
            paint();
            return;
          }
          if (e.target.closest('[data-add-tag]')) add();
        });
        input.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); add(); } });
        const footer = document.createElement('div');
        footer.className = 'sheet-actions';
        footer.innerHTML = '<button class="btn primary block" data-done>完成</button>';
        root.appendChild(footer);
        footer.querySelector('[data-done]').addEventListener('click', () => { onPick(active); close(); });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 搜索
   * ------------------------------------------------------------------ */

  let searchTimer = null;

  function openSearch() {
    if (document.getElementById('searchPage')) return;
    const page = document.createElement('div');
    page.className = 'search-page';
    page.id = 'searchPage';
    page.innerHTML =
      '<div class="search-top">' +
        '<div class="search-bar">' + svg('search', 17) +
          '<input id="searchInput" placeholder="搜索备注、分类、账户、金额" autocomplete="off" enterkeyhint="search">' +
        '</div>' +
        '<button class="icon-btn" data-close aria-label="关闭">' + svg('close', 20) + '</button>' +
      '</div>' +
      '<div class="search-filters">' +
        '<div class="chips" data-types style="margin-bottom:8px">' +
          [['', '全部'], ['expense', '支出'], ['income', '收入'], ['transfer', '转账']].map((x) => (
            '<button class="chip' + (x[0] === '' ? ' active' : '') + '" data-type="' + x[0] + '">' + x[1] + '</button>'
          )).join('') +
        '</div>' +
        '<div class="input-row">' +
          '<select class="select" data-cat style="height:38px;padding:0 8px;font-size:12px">' +
            '<option value="">全部分类</option>' +
            ['expense', 'income'].map((t) => '<optgroup label="' + C.TYPE_CN[t] + '">' +
              C.categoriesOf(state.data, t).map((c) => '<option value="' + c.id + '">' + c.icon + ' ' + esc(c.name) + '</option>').join('') +
            '</optgroup>').join('') +
          '</select>' +
          '<select class="select" data-acc style="height:38px;padding:0 8px;font-size:12px">' +
            '<option value="">全部账户</option>' +
            state.data.accounts.map((a) => '<option value="' + a.id + '">' + a.icon + ' ' + esc(a.name) + '</option>').join('') +
          '</select>' +
        '</div>' +
      '</div>' +
      '<div class="search-body" id="searchBody"></div>';
    overlayRoot.appendChild(page);
    document.body.classList.add('no-scroll');

    const q = { text: '', type: '', categoryId: '', accountId: '' };
    const input = $('#searchInput', page);
    const body = $('#searchBody', page);

    function close() {
      page.remove();
      if (!overlayRoot.children.length) document.body.classList.remove('no-scroll');
    }
    function paint() {
      const results = C.filterTransactions(state.data, {
        q: q.text, type: q.type, categoryId: q.categoryId, accountId: q.accountId
      });
      let expense = 0, income = 0;
      results.forEach((t) => {
        if (t.type === 'expense') expense += C.toCents(t.amount);
        if (t.type === 'income') income += C.toCents(t.amount);
      });
      if (!results.length) {
        body.innerHTML = '<div class="empty"><div class="empty-emoji">🔍</div>' +
          '<div class="empty-title">' + (q.text || q.type || q.categoryId || q.accountId ? '没有找到相关账单' : '输入关键词开始搜索') + '</div>' +
          '<div class="empty-text">可以试试分类名、账户名、备注或金额</div></div>';
        return;
      }
      body.innerHTML =
        '<div class="search-summary"><span>找到 <b>' + results.length + '</b> 笔</span>' +
          '<span>支出 <b>¥' + C.money(C.fromCents(expense)) + '</b></span>' +
          '<span>收入 <b>¥' + C.money(C.fromCents(income)) + '</b></span></div>' +
        '<div class="tx-list">' + results.map((t) => txRowHTML(t, { showDate: true, showBook: state.data.books.length > 1 })).join('') + '</div>';
    }
    input.addEventListener('input', () => {
      q.text = input.value.trim();
      window.clearTimeout(searchTimer);
      searchTimer = window.setTimeout(paint, 120);
    });
    page.addEventListener('click', (e) => {
      if (e.target.closest('[data-close]')) { close(); return; }
      const typeBtn = e.target.closest('[data-type]');
      if (typeBtn) {
        q.type = typeBtn.dataset.type;
        $$('[data-type]', page).forEach((b) => b.classList.toggle('active', b === typeBtn));
        paint();
      }
    });
    $('[data-cat]', page).addEventListener('change', (e) => { q.categoryId = e.target.value; paint(); });
    $('[data-acc]', page).addEventListener('change', (e) => { q.accountId = e.target.value; paint(); });
    paint();
    window.setTimeout(() => input.focus(), 120);
  }

  function closeSearchPage() {
    const page = document.getElementById('searchPage');
    if (!page) return;
    page.remove();
    if (!overlayRoot.children.length) document.body.classList.remove('no-scroll');
  }

  /* ------------------------------------------------------------------ *
   * 账单日历
   * ------------------------------------------------------------------ */

  function openCalendar() {
    const book = C.activeBook(state.data);
    let viewMonth = state.month || C.thisMonthKey();
    const today = C.todayISO();
    openSheet({
      title: '账单日历',
      subtitle: '每一天的支出，一眼看清',
      content: '<div data-cal></div>',
      onMount(root, close) {
        const body = $('[data-cal]', root);
        function paint() {
          const totals = C.dayTotals(state.data, book.id, viewMonth);
          const firstWeekday = C.weekdayIndex(viewMonth + '-01');
          const days = C.daysInMonth(Number(viewMonth.slice(0, 4)), Number(viewMonth.slice(5, 7)));
          const cells = [];
          for (let i = 0; i < firstWeekday; i++) cells.push('<span class="cal-day empty"></span>');
          for (let d = 1; d <= days; d++) {
            const day = viewMonth + '-' + pad2(d);
            const t = totals[d];
            const cls = ['cal-day'];
            if (t && t.count) cls.push('has');
            if (day === today) cls.push('today');
            const amt = t && t.expense ? shortMoney(t.expense) : '';
            cells.push('<button class="' + cls.join(' ') + '" data-day="' + day + '">' +
              '<span class="d">' + d + '</span>' +
              (amt ? '<span class="amt">' + amt + '</span>' : '') +
            '</button>');
          }
          let monthExpense = 0;
          Object.keys(totals).forEach((k) => { monthExpense += C.toCents(totals[k].expense); });
          body.innerHTML =
            '<div class="cal-head"><button data-nav="-1" aria-label="上个月">‹</button>' +
              '<span class="m">' + C.monthLabel(viewMonth) + '</span>' +
              '<button data-nav="1" aria-label="下个月">›</button></div>' +
            '<div class="cal-dow">' + ['日', '一', '二', '三', '四', '五', '六'].map((w) => '<span>' + w + '</span>').join('') + '</div>' +
            '<div class="cal-grid">' + cells.join('') + '</div>' +
            '<div class="search-summary" style="padding:14px 4px 0"><span>本月支出 <b>¥' + C.money(C.fromCents(monthExpense)) + '</b></span>' +
              '<span>记账 <b>' + Object.keys(totals).length + '</b> 天</span></div>';
        }
        paint();
        categoryPainter = paint;
        root.addEventListener('click', (e) => {
          const nav = e.target.closest('[data-nav]');
          if (nav) { viewMonth = C.addMonthsKey(viewMonth, Number(nav.dataset.nav)); paint(); return; }
          const day = e.target.closest('[data-day]');
          if (day) openDayDetail(day.dataset.day);
        });
      }
    });
  }

  function openDayDetail(day) {
    const book = C.activeBook(state.data);
    const list = C.sortTransactions(state.data.transactions.filter((t) => t.bookId === book.id && t.date === day));
    let expense = 0, income = 0;
    list.forEach((t) => {
      if (t.type === 'expense') expense += C.toCents(t.amount);
      if (t.type === 'income') income += C.toCents(t.amount);
    });
    const content =
      '<div class="day-detail-total"><span>支出 <b>¥' + C.money(C.fromCents(expense)) + '</b></span>' +
        '<span>收入 <b>¥' + C.money(C.fromCents(income)) + '</b></span>' +
        '<span>共 <b>' + list.length + '</b> 笔</span></div>' +
      (list.length
        ? '<div class="tx-list">' + list.map((t) => txRowHTML(t)).join('') + '</div>'
        : '<div class="empty" style="padding:30px 10px"><div class="empty-emoji theme-symbol">' + themeEmptyIcon() + '</div><div class="empty-title">这天没有记账</div></div>') +
      '<button class="btn primary block" data-add-day style="margin-top:14px">在这一天记一笔</button>';
    openSheet({
      title: C.dateLabel(day) + ' · ' + C.weekdayCN(day),
      subtitle: C.fullDateLabel(day),
      content,
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          if (e.target.closest('[data-add-day]')) {
            const dayForEntry = day;
            closeAllOverlays();
            openEntry(null, { type: 'expense', date: dayForEntry });
          }
        });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 账本
   * ------------------------------------------------------------------ */

  function openBooks() {
    const data = state.data;
    const content = '<div class="list-plain">' + data.books.map((b) => (
      '<div class="list-item">' +
        '<span class="ic">' + b.icon + '</span>' +
        '<button class="grow" data-switch="' + b.id + '" style="text-align:left;background:none;color:inherit">' +
          '<span class="t" style="display:block">' + esc(b.name) + '</span>' +
          '<span class="s" style="display:block">' +
            data.transactions.filter((t) => t.bookId === b.id).length + ' 笔 · ' +
            (b.budget.total ? '预算 ¥' + C.money(b.budget.total, 0) : '未设预算') +
          '</span>' +
        '</button>' +
        (data.activeBookId === b.id ? '<span style="color:var(--primary)">' + svg('check', 18) + '</span>' : '') +
        '<button class="icon-btn small" data-edit-book="' + b.id + '" aria-label="编辑账本">' + svg('edit', 17) + '</button>' +
      '</div>'
    )).join('') + '</div>' +
      '<button class="btn primary block" data-new-book style="margin-top:14px">+ 新建账本</button>' +
      '<div class="hint-box" style="margin-top:12px">不同账本分开统计，例如「日常」「旅行」「装修」。账户是共用的。</div>';
    openSheet({
      title: '账本管理', subtitle: '当前账本：' + esc(C.activeBook(data).name), content,
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          const sw = e.target.closest('[data-switch]');
          if (sw) {
            data.activeBookId = sw.dataset.switch;
            saveData();
            close();
            state.month = C.thisMonthKey();
            render();
            toast('已切换到「' + esc(C.activeBook(data).name) + '」');
            return;
          }
          const edit = e.target.closest('[data-edit-book]');
          if (edit) {
            const book = data.books.find((b) => b.id === edit.dataset.editBook);
            close();
            openBookEditor(book, () => openBooks());
            return;
          }
          if (e.target.closest('[data-new-book]')) {
            close();
            openBookEditor(null, () => openBooks());
          }
        });
      }
    });
  }

  function openBookEditor(book, onDone) {
    const isNew = !book;
    const draft = { name: book ? book.name : '', icon: book ? book.icon : '📒' };
    const footer =
      '<button class="btn primary grow" data-save>保存</button>' +
      (!isNew && state.data.books.length > 1 ? '<button class="btn danger" data-del style="width:46px;padding:0">' + svg('trash', 18) + '</button>' : '');
    openSheet({
      title: isNew ? '新建账本' : '编辑账本',
      subtitle: isNew ? '给这段记账一个名字' : '账本名称与图标',
      content:
        '<div class="field"><div class="field-label">账本名称</div>' +
          '<input class="input" data-name maxlength="12" placeholder="例如：旅行账本" value="' + esc(draft.name) + '"></div>' +
        '<div class="field"><div class="field-label">图标</div><div class="icon-picker">' +
          BOOK_ICONS.map((ic) => '<button data-icon="' + ic + '" class="' + (ic === draft.icon ? 'active' : '') + '">' + ic + '</button>').join('') +
        '</div></div>',
      footer,
      onMount(root, close) {
        const nameEl = $('[data-name]', root);
        root.addEventListener('click', (e) => {
          const ic = e.target.closest('[data-icon]');
          if (ic) {
            draft.icon = ic.dataset.icon;
            $$('[data-icon]', root).forEach((b) => b.classList.toggle('active', b === ic));
            return;
          }
          if (e.target.closest('[data-save]')) {
            const name = nameEl.value.trim();
            if (!name) { toast('请输入账本名称'); return; }
            if (book) {
              book.name = name;
              book.icon = draft.icon;
            } else {
              state.data.books.push({
                id: C.uid('b'), name, icon: draft.icon, color: '#0e9f6e',
                budget: { total: 0, categories: {} }, createdAt: new Date().toISOString()
              });
            }
            saveData();
            close();
            render();
            toast(book ? '账本已更新' : '账本已创建', 'success');
            if (onDone) onDone();
            return;
          }
          if (e.target.closest('[data-del]') && book) {
            confirmDialog({
              title: '删除「' + esc(book.name) + '」？',
              message: '该账本下的全部账单会一并删除，且无法恢复。',
              confirmText: '删除', danger: true
            }).then((ok) => {
              if (!ok) return;
              state.data.books = state.data.books.filter((b) => b.id !== book.id);
              state.data.transactions = state.data.transactions.filter((t) => t.bookId !== book.id);
              state.data.recurring = state.data.recurring.filter((r) => r.bookId !== book.id);
              if (state.data.activeBookId === book.id) state.data.activeBookId = state.data.books[0].id;
              saveData();
              close();
              render();
              toast('账本已删除');
              if (onDone) onDone();
            });
          }
        });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 分类
   * ------------------------------------------------------------------ */

  let categoryPainter = null;

  function openCategories(startType, onDone) {
    let type = startType === 'income' ? 'income' : 'expense';
    const content =
      '<div class="seg" data-seg>' +
        '<button class="seg-btn' + (type === 'expense' ? ' active' : '') + '" data-cat-type="expense">支出分类</button>' +
        '<button class="seg-btn' + (type === 'income' ? ' active' : '') + '" data-cat-type="income">收入分类</button>' +
      '</div>' +
      '<div data-list style="margin-top:10px"></div>' +
      '<button class="btn primary block" data-add-cat style="margin-top:12px">+ 新增分类</button>' +
      '<div class="hint-box" style="margin-top:12px">点击分类可编辑；长按分类可转入其他分类或删除。</div>';
    openSheet({
      title: '分类管理', subtitle: '记账时第一眼看到的东西', content,
      onMount(root, close) {
        const listEl = $('[data-list]', root);
        function paint() {
          const cats = C.categoriesOf(state.data, type);
          listEl.innerHTML = '<div class="list-plain">' + cats.map((c) => {
            const used = state.data.transactions.filter((t) => t.categoryId === c.id).length;
            return '<button class="list-item" data-cat-edit="' + c.id + '" style="width:100%;text-align:left;background:none">' +
              '<span class="ic" style="background:' + alpha(c.color, 0.14) + '">' + c.icon + '</span>' +
              '<span class="grow"><span class="t" style="display:block">' + esc(c.name) + '</span>' +
                '<span class="s" style="display:block">' + used + ' 笔账单' + (c.builtin ? ' · 内置' : ' · 自定义') + '</span></span>' +
              '<span class="chev">›</span>' +
            '</button>';
          }).join('') + '</div>';
        }
        paint();
        categoryPainter = paint;
        root.addEventListener('click', (e) => {
          const t = e.target.closest('[data-cat-type]');
          if (t) {
            type = t.dataset.catType;
            $$('[data-cat-type]', root).forEach((b) => b.classList.toggle('active', b === t));
            paint();
            return;
          }
          const edit = e.target.closest('[data-cat-edit]');
          if (edit) {
            const cat = state.data.categories.find((c) => c.id === edit.dataset.catEdit);
            if (cat) openCategoryEditor(cat, paint);
            return;
          }
          if (e.target.closest('[data-add-cat]')) {
            openCategoryEditor(null, paint, type);
          }
        });
      },
      onClose() {
        categoryPainter = null;
        if (onDone) onDone();
      }
    });
  }

  function openCategoryActions(cat) {
    if (!cat) return;
    const used = state.data.transactions.filter((t) => t.categoryId === cat.id).length;
    openSheet({
      title: cat.name, subtitle: used + ' 笔账单 · ' + (cat.type === 'income' ? '收入分类' : '支出分类'), content:
        '<div class="menu">' +
          '<button class="menu-row" data-cat-move><span class="menu-icon">↪️</span>' +
            '<span class="menu-label">转入其他分类</span><span class="menu-value">保留当前分类<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-cat-delete><span class="menu-icon">🗑️</span>' +
            '<span class="menu-label">删除分类</span><span class="menu-value">' + (used ? '先转入再删除' : '直接删除') + '<span class="chev">›</span></span></button>' +
        '</div>' +
        '<div class="hint-box">删除有账单的分类时，会先选择目标分类，再把账单和周期规则转过去。</div>',
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          if (e.target.closest('[data-cat-move]')) {
            close();
            openCategoryMove(cat, false);
            return;
          }
          if (e.target.closest('[data-cat-delete]')) {
            close();
            if (used > 0) { openCategoryMove(cat, true); return; }
            confirmDialog({ title: '删除分类「' + cat.name + '」？', message: '删除后不可恢复。', confirmText: '删除', danger: true }).then((ok) => {
              if (!ok) return;
              state.data.categories = state.data.categories.filter((c) => c.id !== cat.id);
              saveData();
              if (categoryPainter) categoryPainter();
              render();
              toast('分类已删除');
            });
          }
        });
      }
    });
  }

  function openCategoryMove(cat, removeAfter) {
    const targets = state.data.categories.filter((c) => c.id !== cat.id && c.type === cat.type);
    if (!targets.length) { toast('没有其他同类型分类可转入'); return; }
    openSheet({
      title: removeAfter ? '转入并删除' : '转入其他分类',
      subtitle: '把「' + cat.name + '」的账单转到', content:
        '<div class="list-plain">' + targets.map((c) => {
          const n = state.data.transactions.filter((t) => t.categoryId === cat.id).length;
          return '<button class="list-item" data-cat-target="' + c.id + '" style="width:100%;text-align:left;background:none">' +
            '<span class="ic" style="background:' + alpha(c.color, 0.14) + '">' + c.icon + '</span>' +
            '<span class="grow"><span class="t" style="display:block">' + esc(c.name) + '</span>' +
              '<span class="s" style="display:block">' + (c.builtin ? '内置分类' : '自定义分类') + '</span></span>' +
            '<span class="chev">›</span></button>';
        }).join('') + '</div>',
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          const btn = e.target.closest('[data-cat-target]');
          if (!btn) return;
          const target = state.data.categories.find((c) => c.id === btn.dataset.catTarget);
          if (!target) return;
          let moved = 0;
          state.data.transactions.forEach((t) => {
            if (t.categoryId === cat.id) { t.categoryId = target.id; moved++; }
          });
          state.data.recurring.forEach((r) => { if (r.categoryId === cat.id) r.categoryId = target.id; });
          (state.data.books || []).forEach((b) => {
            if (b.budget && b.budget.categories && b.budget.categories[cat.id]) {
              b.budget.categories[target.id] = C.round2((b.budget.categories[target.id] || 0) + b.budget.categories[cat.id]);
              delete b.budget.categories[cat.id];
            }
          });
          if (removeAfter) state.data.categories = state.data.categories.filter((c) => c.id !== cat.id);
          saveData();
          close();
          if (categoryPainter) categoryPainter();
          render();
          toast('已转入「' + target.name + '」' + (moved ? '，共 ' + moved + ' 笔' : '') + (removeAfter ? '，原分类已删除' : ''));
        });
      }
    });
  }

  function openCategoryEditor(cat, onSaved, presetType) {
    const isNew = !cat;
    const type = cat ? cat.type : (presetType || 'expense');
    const draft = {
      name: cat ? cat.name : '',
      icon: cat ? cat.icon : '🏷️',
      color: cat ? cat.color : CAT_COLORS[0]
    };
    const used = cat ? state.data.transactions.filter((t) => t.categoryId === cat.id).length : 0;
    const footer =
      '<button class="btn primary grow" data-save>保存</button>' +
      (!isNew && !cat.builtin && used === 0 ? '<button class="btn danger" data-del style="width:46px;padding:0">' + svg('trash', 18) + '</button>' : '');
    openSheet({
      title: isNew ? '新增分类' : '编辑分类',
      subtitle: isNew ? (type === 'expense' ? '支出分类' : '收入分类') : (cat.builtin ? '内置分类' : '自定义分类'),
      content:
        '<div class="field"><div class="field-label">名称</div>' +
          '<input class="input" data-name maxlength="8" placeholder="例如：咖啡" value="' + esc(draft.name) + '"></div>' +
        '<div class="field"><div class="field-label">图标</div><div class="icon-picker">' +
          CAT_ICONS.map((ic) => '<button data-icon="' + ic + '" class="' + (ic === draft.icon ? 'active' : '') + '">' + ic + '</button>').join('') +
        '</div></div>' +
        '<div class="field"><div class="field-label">颜色</div><div class="color-dots">' +
          CAT_COLORS.map((c) => '<button class="color-dot' + (c === draft.color ? ' active' : '') + '" data-color="' + c + '" style="background:' + c + '"></button>').join('') +
        '</div></div>' +
        (used ? '<div class="hint-box">该分类下已有 ' + used + ' 笔账单，修改名称与图标会同步显示。</div>' : ''),
      footer,
      onMount(root, close) {
        const nameEl = $('[data-name]', root);
        root.addEventListener('click', (e) => {
          const ic = e.target.closest('[data-icon]');
          if (ic) {
            draft.icon = ic.dataset.icon;
            $$('[data-icon]', root).forEach((b) => b.classList.toggle('active', b === ic));
            return;
          }
          const color = e.target.closest('[data-color]');
          if (color) {
            draft.color = color.dataset.color;
            $$('[data-color]', root).forEach((b) => b.classList.toggle('active', b === color));
            return;
          }
          if (e.target.closest('[data-save]')) {
            const name = nameEl.value.trim();
            if (!name) { toast('请输入分类名称'); return; }
            if (cat) {
              cat.name = name;
              cat.icon = draft.icon;
              cat.color = draft.color;
            } else {
              const orders = state.data.categories.filter((c) => c.type === type).map((c) => c.order || 0);
              state.data.categories.push({
                id: C.uid('c'), name, icon: draft.icon, color: draft.color,
                type, order: Math.max.apply(null, orders.concat([0])) + 1, builtin: false
              });
            }
            saveData();
            close();
            render();
            toast(isNew ? '分类已创建' : '分类已更新', 'success');
            if (onSaved) onSaved();
            return;
          }
          if (e.target.closest('[data-del]') && cat) {
            if (used) { toast('该分类下还有账单，不能删除'); return; }
            confirmDialog({ title: '删除分类「' + esc(cat.name) + '」？', message: '删除后不可恢复。', confirmText: '删除', danger: true })
              .then((ok) => {
                if (!ok) return;
                state.data.categories = state.data.categories.filter((c) => c.id !== cat.id);
                saveData();
                close();
                render();
                toast('分类已删除');
                if (onSaved) onSaved();
              });
          }
        });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 预算
   * ------------------------------------------------------------------ */

  function openBudget() {
    const book = C.activeBook(state.data);
    const month = state.month;
    const cats = C.categoriesOf(state.data, 'expense');
    const budget = book.budget || { total: 0, categories: {} };
    const status = C.budgetStatus(state.data, book.id, month);
    const spentByCat = {};
    C.categoryBreakdown(state.data, book.id, month, 'expense').forEach((x) => { spentByCat[x.id] = x.value; });
    const content =
      '<div class="field"><div class="field-label">每月总预算<span>0 表示不设置</span></div>' +
        '<input class="input num" inputmode="decimal" data-total placeholder="例如 5000" value="' + (budget.total ? budget.total : '') + '"></div>' +
      '<div class="row-between" style="margin:2px 2px 12px;font-size:11.5px;color:var(--text-3)">' +
        '<span>本月已支出 ¥' + C.money(status.spent) + '</span>' +
        '<span>' + (status.total ? '剩余 ¥' + C.money(status.remain) : '') + '</span>' +
      '</div>' +
      '<div class="field-label" style="margin-bottom:8px">分类预算（可选）</div>' +
      '<div class="list-plain">' + cats.map((c) => (
        '<div class="list-item">' +
          '<span class="ic" style="background:' + alpha(c.color, 0.14) + '">' + c.icon + '</span>' +
          '<span class="grow"><span class="t" style="display:block">' + esc(c.name) + '</span>' +
            '<span class="s" style="display:block">本月 ¥' + C.money(spentByCat[c.id] || 0, 0) + '</span></span>' +
          '<input class="input num" inputmode="decimal" data-cat="' + c.id + '" style="width:100px;height:36px;padding:0 10px;text-align:right" placeholder="0" value="' +
            (budget.categories[c.id] ? budget.categories[c.id] : '') + '">' +
        '</div>'
      )).join('') + '</div>' +
      '<div class="hint-box" style="margin-top:14px">预算只统计当前账本。分类预算不填写则不限制。</div>';
    openSheet({
      title: '预算设置', subtitle: '先定一个数，再慢慢靠近', content,
      footer: '<button class="btn primary block" data-save>保存预算</button>',
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          if (!e.target.closest('[data-save]')) return;
          const total = Number($('[data-total]', root).value);
          if (!isFinite(total) || total < 0) { toast('请输入正确的总预算'); return; }
          const categories = {};
          $$('[data-cat]', root).forEach((input) => {
            const v = Number(input.value);
            if (isFinite(v) && v > 0) categories[input.dataset.cat] = C.round2(v);
          });
          book.budget = { total: C.round2(total), categories };
          saveData();
          close();
          render();
          toast(total ? '预算已保存' : '已取消月预算', 'success');
        });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 周期记账
   * ------------------------------------------------------------------ */

  function nextRunText(rule) {
    const tmp = Object.assign({}, rule, { lastRun: C.todayISO(), enabled: true });
    const dates = C.dueDates(tmp, C.addDaysISO(C.todayISO(), 800));
    return dates.length ? C.dateLabel(dates[0]) : '已结束';
  }

  function openRecurring() {
    const data = state.data;
    const content =
      '<div class="list-plain">' + (data.recurring.length ? data.recurring.map((r) => {
        const cat = data.categories.find((c) => c.id === r.categoryId) || { icon: '🔁', name: '未分类' };
        return '<div class="list-item">' +
          '<span class="ic" style="background:' + alpha(cat.color || '#94a3b8', 0.14) + '">' + cat.icon + '</span>' +
          '<button class="grow" data-edit-rule="' + r.id + '" style="text-align:left;background:none;color:inherit">' +
            '<span class="t" style="display:block">' + (esc(r.note) || esc(cat.name)) + ' · ¥' + C.money(r.amount) + '</span>' +
            '<span class="s" style="display:block">' + C.freqLabel(r) + ' · 下次 ' + nextRunText(r) + '</span>' +
          '</button>' +
          '<label class="switch"><input type="checkbox" data-toggle="' + r.id + '"' + (r.enabled ? ' checked' : '') + '><span class="switch-track"></span></label>' +
        '</div>';
      }).join('') : '<div class="empty" style="padding:30px 12px"><div class="empty-emoji">🔁</div>' +
        '<div class="empty-title">还没有周期记账</div><div class="empty-text">房租、工资、会员费，设置一次就会自动入账。</div></div>') + '</div>' +
      '<button class="btn primary block" data-new-rule style="margin-top:14px">+ 新建周期记账</button>' +
      '<div class="hint-box" style="margin-top:12px">打开 App 时会自动补记错过的周期账单，同一天不会重复入账。</div>';
    openSheet({
      title: '周期记账', subtitle: '固定收支，自动记下来', content,
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          const edit = e.target.closest('[data-edit-rule]');
          if (edit) {
            const rule = data.recurring.find((r) => r.id === edit.dataset.editRule);
            close();
            openRecurringEditor(rule, () => openRecurring());
            return;
          }
          if (e.target.closest('[data-new-rule]')) {
            close();
            openRecurringEditor(null, () => openRecurring());
          }
        });
        root.addEventListener('change', (e) => {
          const toggle = e.target.closest('[data-toggle]');
          if (!toggle) return;
          const rule = data.recurring.find((r) => r.id === toggle.dataset.toggle);
          if (!rule) return;
          rule.enabled = toggle.checked;
          saveData();
          toast(rule.enabled ? '已启用' : '已暂停');
        });
      }
    });
  }

  function openRecurringEditor(rule, onDone) {
    const isNew = !rule;
    const accounts = state.data.accounts.filter((a) => a.bookkeeping !== false || (tx && (tx.accountId === a.id || tx.toAccountId === a.id)));
    if (!accounts.length) { toast('没有启用记账的账户，请先到资产页开启'); return; }
    const draft = {
      type: rule ? rule.type : 'expense',
      amount: rule ? String(rule.amount) : '',
      categoryId: rule ? rule.categoryId : (C.categoriesOf(state.data, 'expense')[0] || {}).id,
      accountId: rule ? rule.accountId : (accounts[0] || {}).id,
      note: rule ? rule.note : '',
      freq: rule ? rule.freq : 'monthly',
      startDate: rule ? rule.startDate : C.todayISO(),
      enabled: rule ? rule.enabled !== false : true
    };
    const footer =
      '<button class="btn primary grow" data-save>保存</button>' +
      (!isNew ? '<button class="btn danger" data-del style="width:46px;padding:0">' + svg('trash', 18) + '</button>' : '');
    function catsHTML() {
      return C.categoriesOf(state.data, draft.type).map((c) => (
        '<option value="' + c.id + '"' + (c.id === draft.categoryId ? ' selected' : '') + '>' + c.icon + ' ' + esc(c.name) + '</option>'
      )).join('');
    }
    openSheet({
      title: isNew ? '新建周期记账' : '编辑周期记账',
      subtitle: '设置一次，之后自动入账',
      content:
        '<div class="field"><div class="field-label">类型</div><div class="seg" data-rtype>' +
          '<button class="seg-btn' + (draft.type === 'expense' ? ' active' : '') + '" data-rt="expense">支出</button>' +
          '<button class="seg-btn' + (draft.type === 'income' ? ' active' : '') + '" data-rt="income">收入</button>' +
        '</div></div>' +
        '<div class="field"><div class="field-label">金额</div>' +
          '<input class="input num" inputmode="decimal" data-amount placeholder="0.00" value="' + esc(draft.amount) + '"></div>' +
        '<div class="field"><div class="field-label">分类</div><select class="select" data-cat>' + catsHTML() + '</select></div>' +
        '<div class="field"><div class="field-label">账户</div><select class="select" data-acc>' +
          accounts.map((a) => '<option value="' + a.id + '"' + (a.id === draft.accountId ? ' selected' : '') + '>' + a.icon + ' ' + esc(a.name) + '</option>').join('') +
        '</select></div>' +
        '<div class="field"><div class="field-label">备注</div>' +
          '<input class="input" data-note maxlength="24" placeholder="例如：房租、工资" value="' + esc(draft.note) + '"></div>' +
        '<div class="field"><div class="field-label">频率</div><select class="select" data-freq>' +
          [['daily', '每天'], ['weekly', '每周'], ['monthly', '每月'], ['yearly', '每年']].map((f) => (
            '<option value="' + f[0] + '"' + (draft.freq === f[0] ? ' selected' : '') + '>' + f[1] + '</option>'
          )).join('') +
        '</select></div>' +
        '<div class="field"><div class="field-label">首次日期</div>' +
          '<button class="account-pick" data-start><span class="ic">📅</span>' +
            '<span class="grow"><span class="t">从这一天开始</span><span class="v" data-start-text>' + C.fullDateLabel(draft.startDate) + '</span></span>' +
            '<span class="chev">›</span></button></div>' +
        '<label class="list-item" style="border:0;padding-left:0;padding-right:0">' +
          '<span class="grow"><span class="t" style="display:block">启用</span><span class="s" style="display:block">关闭后不再自动入账</span></span>' +
          '<span class="switch"><input type="checkbox" data-enabled' + (draft.enabled ? ' checked' : '') + '><span class="switch-track"></span></span>' +
        '</label>',
      footer,
      onMount(root, close) {
        const amountEl = $('[data-amount]', root);
        const catEl = $('[data-cat]', root);
        root.addEventListener('click', (e) => {
          const rt = e.target.closest('[data-rt]');
          if (rt) {
            draft.type = rt.dataset.rt;
            $$('[data-rt]', root).forEach((b) => b.classList.toggle('active', b === rt));
            draft.categoryId = (C.categoriesOf(state.data, draft.type)[0] || {}).id;
            catEl.innerHTML = catsHTML();
            return;
          }
          if (e.target.closest('[data-start]')) {
            openDatePicker(draft.startDate, (day) => {
              draft.startDate = day;
              $('[data-start-text]', root).textContent = C.fullDateLabel(day);
            });
            return;
          }
          if (e.target.closest('[data-del]') && rule) {
            confirmDialog({ title: '删除这条周期记账？', message: '已经自动生成的账单不会被删除。', confirmText: '删除', danger: true })
              .then((ok) => {
                if (!ok) return;
                state.data.recurring = state.data.recurring.filter((r) => r.id !== rule.id);
                saveData();
                close();
                render();
                toast('周期记账已删除');
                if (onDone) onDone();
              });
            return;
          }
          if (e.target.closest('[data-save]')) {
            const amount = Number(amountEl.value);
            if (!isFinite(amount) || amount <= 0) { toast('请输入正确金额'); return; }
            const base = {
              type: draft.type,
              amount: C.round2(amount),
              categoryId: catEl.value,
              accountId: $('[data-acc]', root).value,
              note: $('[data-note]', root).value.trim(),
              freq: $('[data-freq]', root).value,
              startDate: draft.startDate,
              enabled: $('[data-enabled]', root).checked
            };
            if (rule) Object.assign(rule, base);
            else state.data.recurring.push(Object.assign({ id: C.uid('r'), bookId: state.data.activeBookId, lastRun: null }, base));
            const n = C.applyRecurring(state.data, C.todayISO());
            saveData();
            close();
            render();
            toast('周期记账已保存' + (n ? '，自动补记 ' + n + ' 笔' : ''), 'success');
            if (onDone) onDone();
          }
        });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 账户
   * ------------------------------------------------------------------ */

  function openAccountEditor(account, onDone) {
    const isNew = !account;
    const draft = {
      name: account ? account.name : '',
      type: account ? account.type : 'cash',
      icon: account ? account.icon : '💵',
      initial: account ? String(account.initial) : '',
      include: account ? account.include !== false : true,
      bookkeeping: account ? account.bookkeeping !== false : true
    };
    const used = account ? state.data.transactions.filter((t) => t.accountId === account.id || t.toAccountId === account.id).length : 0;
    const inRules = account ? state.data.recurring.some((r) => r.accountId === account.id) : 0;
    const footer =
      '<button class="btn primary grow" data-save>保存</button>' +
      (!isNew && used === 0 && !inRules ? '<button class="btn danger" data-del style="width:46px;padding:0">' + svg('trash', 18) + '</button>' : '');
    openSheet({
      title: isNew ? '新增账户' : '编辑账户',
      subtitle: isNew ? '钱包、银行卡、信用卡都可以' : (used ? '该账户已有 ' + used + ' 笔账单' : (inRules ? '该账户正被周期记账使用' : '余额将随账单自动变化')),
      content:
        '<div class="field"><div class="field-label">账户名称</div>' +
          '<input class="input" data-name maxlength="12" placeholder="例如：招商银行" value="' + esc(draft.name) + '"></div>' +
        '<div class="field"><div class="field-label">账户类型</div><select class="select" data-type>' +
          Object.keys(C.ACCOUNT_TYPES).map((k) => (
            '<option value="' + k + '"' + (draft.type === k ? ' selected' : '') + '>' + C.ACCOUNT_TYPES[k].name + '</option>'
          )).join('') +
        '</select></div>' +
        '<div class="field"><div class="field-label">初始余额<span>记账前这个账户有多少钱</span></div>' +
          '<input class="input num" inputmode="decimal" data-initial placeholder="0.00" value="' + esc(draft.initial) + '"></div>' +
        '<div class="field"><div class="field-label">图标</div><div class="icon-picker">' +
          ACCOUNT_ICONS.map((ic) => '<button data-icon="' + ic + '" class="' + (ic === draft.icon ? 'active' : '') + '">' + ic + '</button>').join('') +
        '</div></div>' +
        '<label class="list-item" style="border:0;padding-left:0;padding-right:0">' +
          '<span class="grow"><span class="t" style="display:block">计入总资产</span>' +
            '<span class="s" style="display:block">关闭后只用于记账，不参与资产统计</span></span>' +
          '<span class="switch"><input type="checkbox" data-include' + (draft.include ? ' checked' : '') + '><span class="switch-track"></span></span>' +
        '</label>' +
        '<label class="list-item" style="border:0;padding-left:0;padding-right:0">' +
          '<span class="grow"><span class="t" style="display:block">启用记账</span>' +
            '<span class="s" style="display:block">关闭后不出现在记账账户选择里</span></span>' +
          '<span class="switch"><input type="checkbox" data-bookkeeping' + (draft.bookkeeping ? ' checked' : '') + '><span class="switch-track"></span></span>' +
        '</label>',
      footer,
      onMount(root, close) {
        const nameEl = $('[data-name]', root);
        root.addEventListener('click', (e) => {
          const ic = e.target.closest('[data-icon]');
          if (ic) {
            draft.icon = ic.dataset.icon;
            $$('[data-icon]', root).forEach((b) => b.classList.toggle('active', b === ic));
            return;
          }
          if (e.target.closest('[data-del]') && account) {
            confirmDialog({ title: '删除账户「' + esc(account.name) + '」？', message: '删除后不可恢复。', confirmText: '删除', danger: true })
              .then((ok) => {
                if (!ok) return;
                state.data.accounts = state.data.accounts.filter((a) => a.id !== account.id);
                saveData();
                close();
                render();
                toast('账户已删除');
                if (onDone) onDone();
              });
            return;
          }
          if (e.target.closest('[data-save]')) {
            const name = nameEl.value.trim();
            if (!name) { toast('请输入账户名称'); return; }
            const init = Number($('[data-initial]', root).value || 0);
            if (!isFinite(init)) { toast('初始余额填写有误'); return; }
            const type = $('[data-type]', root).value;
            const base = {
              name, type, icon: draft.icon,
              color: (C.ACCOUNT_TYPES[type] || { icon: '👛' }).liability ? '#f43f5e' : '#0ea5e9',
              initial: C.round2(init),
              include: $('[data-include]', root).checked,
              bookkeeping: $('[data-bookkeeping]', root).checked
            };
            if (account) Object.assign(account, base);
            else state.data.accounts.push(Object.assign({ id: C.uid('a') }, base));
            saveData();
            close();
            render();
            toast(isNew ? '账户已创建' : '账户已更新', 'success');
            if (onDone) onDone();
          }
        });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 数据
   * ------------------------------------------------------------------ */

  function openData() {
    const data = state.data;
    const bytes = new Blob([JSON.stringify(data)]).size;
    const stats = C.overallStats(data);
    const content =
      '<div class="stat-grid">' +
        '<div class="stat-cell"><div class="k">账单</div><div class="v">' + stats.count + '<small>笔</small></div></div>' +
        '<div class="stat-cell"><div class="k">账本</div><div class="v">' + stats.books + '<small>个</small></div></div>' +
        '<div class="stat-cell"><div class="k">占用</div><div class="v">' + (bytes / 1024).toFixed(1) + '<small>KB</small></div></div>' +
      '</div>' +
      '<div class="menu-group" style="margin-top:16px"><div class="menu-group-title">导出</div>' +
        '<div class="menu">' +
          '<button class="menu-row" data-export-xlsx><span class="menu-icon">📊</span><span class="menu-label">导出 Excel 账单</span><span class="menu-value">.xlsx<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-export-csv><span class="menu-icon">🧾</span><span class="menu-label">导出 CSV 账单</span><span class="menu-value">.csv<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-export-json><span class="menu-icon">📦</span><span class="menu-label">导出 JSON 完整备份</span><span class="menu-value">含附件<span class="chev">›</span></span></button>' +
        '</div>' +
      '</div>' +
      '<div class="menu-group"><div class="menu-group-title">导入</div>' +
        '<div class="menu">' +
          '<button class="menu-row" data-import-bills><span class="menu-icon">📥</span><span class="menu-label">导入 Excel / CSV 账单</span><span class="menu-value">合并<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-import-json><span class="menu-icon">🗂️</span><span class="menu-label">从 JSON 备份恢复</span><span class="menu-value">覆盖<span class="chev">›</span></span></button>' +
        '</div>' +
      '</div>' +
      '<div class="menu-group"><div class="menu-group-title">危险操作</div>' +
        '<div class="menu">' +
          '<button class="menu-row danger" data-clear><span class="menu-icon" style="background:var(--danger-soft)">🗑️</span><span class="menu-label">清空全部数据</span><span class="chev">›</span></button>' +
        '</div>' +
      '</div>' +
      '<div class="hint-box">' +
        'Excel / CSV 列与星空记账一致：日期、收支类型、金额、类别、二级分类、账户、账本、退款、优惠、备注、标签、报销账户、报销金额、报销明细、多币种、地址、创建用户、其他、附件1-5。' +
        '<br>账单导入是追加合并，会自动创建缺失的账本/分类/账户，并跳过重复账单；JSON 恢复会覆盖全部数据。' +
      '</div>';
    openSheet({
      title: '数据与备份', subtitle: '账本握在自己手里', content,
      onMount(root, close) {
        function applyBillRows(rows, sourceName) {
          if (!rows || rows.length < 2) { toast('没有可导入的账单', 'error'); return; }
          confirmDialog({
            title: '导入账单？',
            message: '将从「' + esc(sourceName) + '」追加 ' + (rows.length - 1) + ' 行账单到现有数据；缺少的账本/分类/账户会自动创建，重复账单会跳过。',
            confirmText: '开始导入'
          }).then((ok) => {
            if (!ok) return;
            const result = C.importBillRows(state.data, rows);
            if (result.error) { toast(result.error, 'error'); return; }
            if (!saveData()) return;
            closeAllOverlays();
            state.route = 'home';
            state.month = C.thisMonthKey();
            render();
            const extra = [];
            if (result.books) extra.push(result.books + ' 个账本');
            if (result.categories) extra.push(result.categories + ' 个分类');
            if (result.accounts) extra.push(result.accounts + ' 个账户');
            toast('导入 ' + result.imported + ' 笔' +
              (result.skipped ? '，跳过 ' + result.skipped + ' 笔' : '') +
              (extra.length ? '，新建 ' + extra.join('、') : ''), 'success');
          });
        }

        function pickBillFile() {
          const input = document.createElement('input');
          input.type = 'file';
          input.accept = '.xlsx,.csv,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          input.style.display = 'none';
          document.body.appendChild(input);
          input.addEventListener('change', () => {
            const file = input.files && input.files[0];
            input.remove();
            if (!file) return;
            const isExcel = /\.xlsx$/i.test(file.name) || (file.type || '').indexOf('spreadsheet') >= 0;
            if (isExcel) {
              if (!window.LedgerXlsx) { toast('Excel 组件未加载', 'error'); return; }
              const reader = new FileReader();
              reader.onload = async () => {
                try {
                  const parsed = await window.LedgerXlsx.parseWorkbook(reader.result);
                  applyBillRows([parsed.headers].concat(parsed.rows), file.name);
                } catch (err) {
                  toast('Excel 解析失败：' + err.message, 'error');
                }
              };
              reader.onerror = () => toast('读取文件失败', 'error');
              reader.readAsArrayBuffer(file);
            } else {
              const reader = new FileReader();
              reader.onload = () => {
                try {
                  applyBillRows(C.parseCSV(String(reader.result || '')), file.name);
                } catch (err) {
                  toast('CSV 解析失败：' + err.message, 'error');
                }
              };
              reader.onerror = () => toast('读取文件失败', 'error');
              reader.readAsText(file);
            }
          });
          input.click();
        }

        root.addEventListener('click', (e) => {
          if (e.target.closest('[data-export-xlsx]')) {
            const table = C.billRows(state.data);
            const bytesOut = window.LedgerXlsx.buildWorkbook(table.headers, table.rows);
            const name = '星空记账账单_' + C.todayISO().replace(/-/g, '') + '.xlsx';
            const mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            if (download(name, bytesOut, mime)) {
              toast(window.AndroidBridge ? '请选择保存位置' : 'Excel 已导出：' + name, 'success');
            }
            return;
          }
          if (e.target.closest('[data-export-csv]')) {
            const csv = C.toCSV(state.data);
            const name = '星空记账账单_' + C.todayISO().replace(/-/g, '') + '.csv';
            if (download(name, csv, 'text/csv;charset=utf-8')) toast(window.AndroidBridge ? '请选择保存位置' : 'CSV 已导出：' + name, 'success');
            return;
          }
          if (e.target.closest('[data-export-json]')) {
            const payload = C.exportPayload(state.data);
            const name = '星空记账备份_' + C.todayISO().replace(/-/g, '') + '.json';
            if (download(name, JSON.stringify(payload, null, 2), 'application/json;charset=utf-8')) {
              toast(window.AndroidBridge ? '请选择保存位置' : '备份已导出：' + name, 'success');
            }
            return;
          }
          if (e.target.closest('[data-import-bills]')) {
            pickBillFile();
            return;
          }
          if (e.target.closest('[data-import-json]')) {
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = '.json,application/json';
            input.style.display = 'none';
            document.body.appendChild(input);
            input.addEventListener('change', () => {
              const file = input.files && input.files[0];
              input.remove();
              if (!file) return;
              const reader = new FileReader();
              reader.onload = () => {
                let parsed = null;
                try { parsed = JSON.parse(String(reader.result)); } catch (err) { toast('文件不是有效的 JSON', 'error'); return; }
                const result = C.validateBackup(parsed);
                if (!result.ok) { toast(result.error || '备份文件无法识别', 'error'); return; }
                confirmDialog({
                  title: '恢复 JSON 备份？',
                  message: '恢复后将覆盖当前的 ' + state.data.transactions.length + ' 笔账单和全部设置。',
                  confirmText: '覆盖恢复', danger: true
                }).then((ok) => {
                  if (!ok) return;
                  state.data = result.data;
                  state.data.settings.onboarded = true;
                  saveData();
                  applyTheme();
                  closeAllOverlays();
                  state.route = 'home';
                  state.month = C.thisMonthKey();
                  render();
                  toast('恢复成功，共 ' + state.data.transactions.length + ' 笔账单', 'success');
                });
              };
              reader.readAsText(file);
            });
            input.click();
            return;
          }
          if (e.target.closest('[data-clear]')) {
            confirmDialog({
              title: '清空全部数据？',
              message: '所有账本、账单、账户和设置都会被删除，且无法恢复。建议先导出备份。',
              confirmText: '确认清空', danger: true
            }).then((ok) => {
              if (!ok) return;
              state.data = C.createDefaultData();
              state.data.settings.onboarded = true;
              saveData();
              applyTheme();
              closeAllOverlays();
              state.route = 'home';
              state.month = C.thisMonthKey();
              render();
              toast('已清空，从零开始', 'success');
            });
          }
        });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 主题 / 密码 / 关于
   * ------------------------------------------------------------------ */

  function registerServiceWorker() {
    if (!document.querySelector('link[rel="manifest"]')) return;
    if (!('serviceWorker' in navigator)) return;
    const host = location.hostname;
    const secure = location.protocol === 'https:' || host === 'localhost' || host === '127.0.0.1' || host === '[::1]';
    if (!secure) return;
    navigator.serviceWorker.register('./sw.js').then((reg) => {
      reg.addEventListener('updatefound', () => {
        const sw = reg.installing;
        if (!sw) return;
        sw.addEventListener('statechange', () => {
          if (sw.state === 'installed' && navigator.serviceWorker.controller) {
            toast('新版本已就绪，重新打开 App 生效');
          }
        });
      });
    }).catch(() => {});
  }

  function handleLaunchAction() {
    let action = null;
    try { action = new URLSearchParams(location.search).get('action'); } catch (err) { action = null; }
    if (!action) return;
    try { history.replaceState(null, '', location.pathname + location.hash); } catch (err) { /* ignore */ }
    if (action === 'add') window.setTimeout(() => openEntry(), 260);
    else if (action === 'stats') window.setTimeout(() => go('stats'), 260);
  }

  function compressThemeImage(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onerror = () => reject(new Error('读取图片失败'));
      reader.onload = () => {
        const img = new Image();
        img.onerror = () => reject(new Error('图片格式不支持'));
        img.onload = () => {
          try {
            const max = 1440;
            const scale = Math.min(1, max / Math.max(img.width, img.height));
            const w = Math.max(1, Math.round(img.width * scale));
            const h = Math.max(1, Math.round(img.height * scale));
            const canvas = document.createElement('canvas');
            canvas.width = w; canvas.height = h;
            const ctx = canvas.getContext('2d');
            ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, w, h);
            ctx.drawImage(img, 0, 0, w, h);
            resolve(canvas.toDataURL('image/jpeg', 0.82));
          } catch (err) { reject(err); }
        };
        img.src = reader.result;
      };
      reader.readAsDataURL(file);
    });
  }

  function openTheme() {
    const current = state.data.settings.theme;
    const customImage = state.data.settings.customThemeImage;
    openSheet({
      title: '外观主题', subtitle: '星空、草原、天空、自定义图片', content:
        '<div class="theme-grid">' + THEMES.map((o) => (
          '<button class="theme-card' + (current === o.id ? ' active' : '') + '" data-theme-opt="' + o.id + '">' +
            '<span class="theme-swatch sw-' + o.sw + '"' + (o.id === 'custom' && customImage ? ' style="background-image:url(' + customImage + ');background-size:cover;background-position:center"' : '') + '>' + (o.id === 'custom' && customImage ? '' : o.emoji) + '</span>' +
            '<span class="theme-card-name">' + o.name + '</span>' +
            '<span class="theme-card-desc">' + (o.id === 'custom' ? (customImage ? '已导入图片' : '导入一张图片') : o.desc) + '</span>' +
            (current === o.id ? '<span class="theme-check">' + svg('check', 14) + '</span>' : '') +
          '</button>'
        )).join('') + '</div>' +
        '<div class="theme-custom-actions">' +
          '<button class="btn ghost theme-upload" data-theme-upload>🖼️ ' + (customImage ? '更换图片' : '导入图片') + '</button>' +
          (customImage ? '<button class="btn ghost theme-clear" data-theme-clear>移除</button>' : '') +
        '</div>' +
        '<input type="file" accept="image/*" data-theme-file hidden>' +
        '<div class="hint-box" style="margin-top:12px">导入的图片会作为页面背景，并自动压缩后保存在本机，不会上传。</div>',
      onMount(root, close) {
        const fileInput = root.querySelector('[data-theme-file]');
        root.addEventListener('click', (e) => {
          const upload = e.target.closest('[data-theme-upload]');
          if (upload) { fileInput.click(); return; }
          const clear = e.target.closest('[data-theme-clear]');
          if (clear) {
            state.data.settings.customThemeImage = '';
            if (state.data.settings.theme === 'custom') state.data.settings.theme = 'light';
            saveData(); applyTheme(); close(); render(); toast('已移除自定义图片');
            return;
          }
          const btn = e.target.closest('[data-theme-opt]');
          if (!btn) return;
          if (btn.dataset.themeOpt === 'custom' && !customImage) { fileInput.click(); return; }
          state.data.settings.theme = btn.dataset.themeOpt;
          saveData(); applyTheme(); close(); render();
          toast('已切换为「' + themeById(btn.dataset.themeOpt).name + '」');
        });
        fileInput.addEventListener('change', async () => {
          const file = fileInput.files && fileInput.files[0];
          if (!file) return;
          try {
            const dataUrl = await compressThemeImage(file);
            state.data.settings.customThemeImage = dataUrl;
            state.data.settings.theme = 'custom';
            saveData(); applyTheme(); close(); render();
            toast('自定义图片已应用');
          } catch (err) {
            toast(err.message || '导入图片失败');
          }
        });
      }
    });
  }

  function hashPin(pin) {
    let h = 2166136261;
    const s = 'xingkong-salt:' + pin;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0).toString(16);
  }

  function openPin() {
    const hasPin = !!state.data.settings.pinHash;
    openSheet({
      title: hasPin ? '修改隐私锁' : '设置隐私锁',
      subtitle: '4 位数字，仅用于本机界面保护',
      content:
        '<div class="field"><div class="field-label">' + (hasPin ? '新密码' : '密码') + '</div>' +
          '<input class="input num" type="password" inputmode="numeric" maxlength="4" data-pin1 placeholder="4 位数字"></div>' +
        '<div class="field"><div class="field-label">确认密码</div>' +
          '<input class="input num" type="password" inputmode="numeric" maxlength="4" data-pin2 placeholder="再次输入"></div>' +
        '<button class="btn primary block" data-save-pin>保存密码</button>' +
        (hasPin ? '<button class="btn danger block" data-remove-pin style="margin-top:10px">关闭隐私锁</button>' : '') +
        '<div class="hint-box" style="margin-top:14px">密码只保存在本机，用于打开 App 时遮挡账单。忘记密码将无法进入，只能清除浏览器数据。</div>',
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          if (e.target.closest('[data-save-pin]')) {
            const p1 = $('[data-pin1]', root).value;
            const p2 = $('[data-pin2]', root).value;
            if (!/^\d{4}$/.test(p1)) { toast('请输入 4 位数字密码'); return; }
            if (p1 !== p2) { toast('两次输入的密码不一致'); return; }
            state.data.settings.pinHash = hashPin(p1);
            saveData();
            close();
            render();
            toast('隐私锁已开启', 'success');
            return;
          }
          if (e.target.closest('[data-remove-pin]')) {
            confirmDialog({ title: '关闭隐私锁？', message: '关闭后打开 App 不再需要输入密码。', confirmText: '关闭', danger: true })
              .then((ok) => {
                if (!ok) return;
                state.data.settings.pinHash = null;
                saveData();
                close();
                render();
                toast('隐私锁已关闭');
              });
          }
        });
      }
    });
  }

  function showLock() {
    let pin = '';
    lockEl.hidden = false;
    lockEl.innerHTML =
      '<div class="lock-logo">🌌</div>' +
      '<div class="lock-title">欢迎回来</div>' +
      '<div class="lock-sub">输入 4 位数字密码</div>' +
      '<div class="pin-dots">' + [0, 1, 2, 3].map(() => '<span class="pin-dot"></span>').join('') + '</div>' +
      '<div class="pin-error"></div>' +
      '<div class="pin-pad">' +
        [1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => '<button class="pin-key" data-pin="' + n + '">' + n + '</button>').join('') +
        '<span class="pin-key blank"></span>' +
        '<button class="pin-key" data-pin="0">0</button>' +
        '<button class="pin-key del" data-pin="del">⌫</button>' +
      '</div>';
    const dots = $$('.pin-dot', lockEl);
    const err = $('.pin-error', lockEl);
    function paint() {
      dots.forEach((d, i) => d.classList.toggle('on', i < pin.length));
    }
    function fail() {
      pin = '';
      paint();
      err.textContent = '密码不正确，请重试';
      lockEl.querySelector('.pin-dots').classList.add('shake');
      window.setTimeout(() => lockEl.querySelector('.pin-dots').classList.remove('shake'), 450);
    }
    lockEl.onclick = (e) => {
      const key = e.target.closest('[data-pin]');
      if (!key) return;
      const v = key.dataset.pin;
      if (v === 'del') {
        pin = pin.slice(0, -1);
        paint();
        err.textContent = '';
        return;
      }
      if (pin.length >= 4) return;
      pin += v;
      paint();
      if (pin.length === 4) {
        if (hashPin(pin) === state.data.settings.pinHash) {
          lockEl.hidden = true;
          lockEl.innerHTML = '';
          lockEl.onclick = null;
          toast('欢迎回来', 'success');
        } else {
          fail();
        }
      }
    };
    paint();
  }

  function openAbout() {
    openSheet({
      title: '关于星空记账',
      subtitle: 'v' + VERSION_TEXT + ' · 本地版',
      content:
        '<div style="text-align:center;padding:8px 0 20px"><div style="font-size:56px">🌌</div>' +
          '<div style="font-size:17px;font-weight:700;margin-top:8px">星空记账</div>' +
          '<div class="muted small" style="margin-top:4px">把每一笔，都记成生活的年轮</div></div>' +
        '<div class="menu"><div class="menu-row"><span class="menu-icon">📝</span><span class="menu-label">快速记账</span><span class="menu-value">数字键盘 + 算式</span></div>' +
          '<div class="menu-row"><span class="menu-icon">📊</span><span class="menu-label">图表统计</span><span class="menu-value">分类占比 · 趋势</span></div>' +
          '<div class="menu-row"><span class="menu-icon">🎯</span><span class="menu-label">预算管理</span><span class="menu-value">总额 + 分类</span></div>' +
          '<div class="menu-row"><span class="menu-icon">🔁</span><span class="menu-label">周期记账</span><span class="menu-value">自动补记</span></div>' +
          '<div class="menu-row"><span class="menu-icon">🔒</span><span class="menu-label">隐私锁</span><span class="menu-value">本机 4 位密码</span></div>' +
        '</div>' +
        '<div class="hint-box" style="margin-top:14px">这是一个单文件本地记账应用：无广告、无账号、无网络请求。数据保存在浏览器 localStorage 中，建议定期在「数据与备份」导出 JSON。</div>',
      footer: '<button class="btn primary block" data-close-footer>知道了</button>',
      onMount(root, close) {
        const btn = root.querySelector('[data-close-footer]');
        if (btn) btn.addEventListener('click', close);
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 全局动作
   * ------------------------------------------------------------------ */

  function closeAllOverlays() {
    overlayRoot.innerHTML = '';
    document.body.classList.remove('no-scroll');
  }

  function enterSelection(id) {
    if (!id) return;
    state.selectMode = true;
    state.selectedIds = [id];
    state.suppressClickUntil = Date.now() + 350;
    try { if (navigator.vibrate) navigator.vibrate(12); } catch (err) { /* ignore */ }
    render();
  }

  function toggleSelection(id) {
    if (!id) return;
    const index = state.selectedIds.indexOf(id);
    if (index >= 0) state.selectedIds.splice(index, 1);
    else state.selectedIds.push(id);
    if (!state.selectedIds.length) state.selectMode = false;
    render();
  }

  function clearSelection() {
    state.selectMode = false;
    state.selectedIds = [];
    render();
  }

  function selectAllVisible() {
    const ids = C.bookTransactions(state.data, state.data.activeBookId)
      .filter((t) => C.monthKeyOf(t.date) === state.month)
      .map((t) => t.id);
    const allSelected = ids.length > 0 && ids.every((id) => state.selectedIds.indexOf(id) >= 0);
    state.selectedIds = allSelected ? [] : ids;
    state.selectMode = state.selectedIds.length > 0;
    render();
  }

  function openSelectionExport() {
    if (!state.selectedIds.length) { toast('请先选择账单'); return; }
    const count = state.selectedIds.length;
    const ids = new Set(state.selectedIds);
    const copy = Object.assign({}, state.data, {
      transactions: state.data.transactions.filter((t) => ids.has(t.id))
    });
    const stamp = C.todayISO().replace(/-/g, '');
    openSheet({
      title: '导出选中账单', subtitle: '已选 ' + count + ' 笔', content:
        '<div class="menu">' +
          '<button class="menu-row" data-sel-xlsx><span class="menu-icon">📊</span><span class="menu-label">导出 Excel</span><span class="menu-value">.xlsx<span class="chev">›</span></span></button>' +
          '<button class="menu-row" data-sel-csv><span class="menu-icon">🧾</span><span class="menu-label">导出 CSV</span><span class="menu-value">.csv<span class="chev">›</span></span></button>' +
        '</div>' +
        '<div class="hint-box">使用与全部账单相同的 23 列字段，包含时间、分类、报销、多币种、标签等。</div>',
      onMount(root, close) {
        root.addEventListener('click', (e) => {
          if (e.target.closest('[data-sel-xlsx]')) {
            const table = C.billRows(copy);
            const bytes = window.LedgerXlsx.buildWorkbook(table.headers, table.rows);
            const name = '星空记账选中账单_' + stamp + '.xlsx';
            const mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            if (download(name, bytes, mime)) toast(window.AndroidBridge ? '请选择保存位置' : 'Excel 已导出', 'success');
            close();
            return;
          }
          if (e.target.closest('[data-sel-csv]')) {
            const csv = C.toCSV(copy);
            const name = '星空记账选中账单_' + stamp + '.csv';
            if (download(name, csv, 'text/csv;charset=utf-8')) toast(window.AndroidBridge ? '请选择保存位置' : 'CSV 已导出', 'success');
            close();
          }
        });
      }
    });
  }

  function deleteSelected() {
    if (!state.selectedIds.length) { toast('请先选择账单'); return; }
    const ids = new Set(state.selectedIds);
    const count = ids.size;
    confirmDialog({
      title: '删除选中的 ' + count + ' 笔账单？',
      message: '删除后无法恢复，账户余额会同步更新。',
      confirmText: '删除', danger: true
    }).then((ok) => {
      if (!ok) return;
      state.data.transactions = state.data.transactions.filter((t) => !ids.has(t.id));
      if (!saveData()) return;
      state.selectMode = false;
      state.selectedIds = [];
      render();
      toast('已删除 ' + count + ' 笔账单', 'success');
    });
  }

  /* 长按账单进入多选 */
  let pressTimer = null;
  let pressId = null;
  let pressPos = null;

  function cancelPress() {
    if (pressTimer) window.clearTimeout(pressTimer);
    pressTimer = null;
    pressId = null;
    pressPos = null;
  }

  function pressStart(e) {
    if (e.type === 'mousedown' && ('ontouchstart' in window) && navigator.maxTouchPoints > 0) return;
    if (state.route !== 'home' || state.selectMode || overlayRoot.children.length) return;
    const row = e.target.closest('.tx');
    if (!row || !viewEl.contains(row)) return;
    const point = e.touches ? e.touches[0] : e;
    pressId = row.dataset.id;
    pressPos = { x: point.clientX, y: point.clientY };
    cancelPress();
    pressId = row.dataset.id;
    pressPos = { x: point.clientX, y: point.clientY };
    pressTimer = window.setTimeout(() => {
      pressTimer = null;
      const id = pressId;
      pressId = null;
      if (id) enterSelection(id);
    }, 480);
  }

  function pressMove(e) {
    if (!pressPos) return;
    const point = e.touches ? e.touches[0] : e;
    if (Math.abs(point.clientX - pressPos.x) > 10 || Math.abs(point.clientY - pressPos.y) > 10) cancelPress();
  }

  document.addEventListener('touchstart', pressStart, { passive: true });
  document.addEventListener('touchmove', pressMove, { passive: true });
  document.addEventListener('touchend', cancelPress, { passive: true });
  document.addEventListener('mousedown', pressStart);
  document.addEventListener('mousemove', pressMove);
  document.addEventListener('mouseup', cancelPress);
  document.addEventListener('contextmenu', (e) => { if (e.target.closest('.tx')) e.preventDefault(); });

  /* 明细页下滑记一笔 */
  let pullStartY = null;
  let pullStartX = null;
  let pullStartedAt = 0;
  let pullDistance = 0;
  let pulling = false;
  const PULL_TRIGGER = 115;

  function pullHintEl() {
    let el = document.getElementById('pullHint');
    if (!el) {
      el = document.createElement('div');
      el.id = 'pullHint';
      el.className = 'pull-hint liquid';
      el.innerHTML = '<span class="arrow">↓</span><span>下拉记一笔</span>';
      document.body.appendChild(el);
    }
    return el;
  }

  function resetPull() {
    pullStartY = null;
    pullStartX = null;
    pullStartedAt = 0;
    pullDistance = 0;
    pulling = false;
    const el = document.getElementById('pullHint');
    if (el) { el.classList.remove('show', 'ready'); el.querySelector('.arrow').textContent = '↓'; el.querySelector('span:last-child').textContent = '下拉记一笔'; }
  }

  document.addEventListener('touchstart', (e) => {
    if (state.route !== 'home' || state.selectMode || overlayRoot.children.length || window.scrollY > 1) return;
    if (e.target.closest('.tabbar, .fab-add, .appbar, .select-bar, .sheet')) return;
    pullStartY = e.touches[0].clientY;
    pullStartX = e.touches[0].clientX;
    pullStartedAt = Date.now();
    pullDistance = 0;
    pulling = false;
  }, { passive: true });

  document.addEventListener('touchmove', (e) => {
    if (pullStartY == null) return;
    const dy = e.touches[0].clientY - pullStartY;
    const dx = e.touches[0].clientX - pullStartX;
    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 14) { resetPull(); return; }
    if (dy > 0 && window.scrollY <= 1) {
      if (dy < 18) return;
      pulling = true;
      pullDistance = Math.min(dy, 180);
      const hint = pullHintEl();
      hint.classList.add('show');
      hint.classList.toggle('ready', pullDistance > PULL_TRIGGER);
      hint.querySelector('.arrow').textContent = pullDistance > PULL_TRIGGER ? '↑' : '↓';
      hint.querySelector('span:last-child').textContent = pullDistance > PULL_TRIGGER ? '松开记一笔' : '继续下拉';
      if (dy > 8 && e.cancelable) e.preventDefault();
    } else if (dy < -4) {
      resetPull();
    }
  }, { passive: false });

  document.addEventListener('touchend', () => {
    if (pullStartY == null) return;
    const trigger = pulling && pullDistance > PULL_TRIGGER && (Date.now() - pullStartedAt) > 200;
    resetPull();
    if (trigger) {
      state.suppressClickUntil = Date.now() + 450;
      openEntry();
    }
  }, { passive: true });

  const ACTIONS = {
    go: (t) => go(t.dataset.route),
    'open-entry': () => openEntry(null, state.route === 'calendar' ? { date: state.calendarSelected } : undefined),
    'edit-tx': (t) => {
      if (Date.now() < (state.suppressClickUntil || 0)) return;
      if (state.selectMode) { toggleSelection(t.dataset.id); return; }
      const fromSearch = !!document.getElementById('searchPage');
      if (fromSearch) {
        closeSearchPage();
        openEntry(t.dataset.id);
      } else {
        const inSheet = t.closest('.sheet');
        if (inSheet) closeAllOverlays();
        openEntry(t.dataset.id);
      }
    },
    'prev-month': () => { state.month = C.addMonthsKey(state.month, -1); state.selectMode = false; state.selectedIds = []; render(); },
    'next-month': () => { state.month = C.addMonthsKey(state.month, 1); state.selectMode = false; state.selectedIds = []; render(); },
    'reset-month': () => { state.month = C.thisMonthKey(); state.selectMode = false; state.selectedIds = []; render(); },
    'stats-mode': (t) => {
      const mode = t.dataset.mode;
      if (['daily', 'month', 'year', 'custom'].indexOf(mode) < 0) return;
      state.statsMode = mode;
      render();
      window.scrollTo(0, 0);
    },
    'stats-type': (t) => {
      const type = t.dataset.type;
      state.statsType = type === 'income' || type === 'balance' || type === 'all' ? type : 'expense';
      renderView();
    },
    'stats-share-type': (t) => {
      state.statsShareType = t.dataset.type === 'income' ? 'income' : 'expense';
      renderView();
    },
    'stats-sankey': (t) => {
      state.statsSankey = t.dataset.value === 'all' ? 'all' : 'category';
      renderView();
    },
    'stats-month-step': (t) => stepStatsMonth(Number(t.dataset.step || 0)),
    'stats-set-month': (t) => {
      const month = t.dataset.month;
      if (!month) return;
      state.statsMonth = month;
      state.statsYear = Number(month.slice(0, 4));
      state.statsMode = 'month';
      render();
      window.scrollTo(0, 0);
    },
    'stats-reset-month': () => {
      state.statsMonth = C.thisMonthKey();
      state.statsYear = Number(C.thisMonthKey().slice(0, 4));
      state.statsMode = 'month';
      render();
      window.scrollTo(0, 0);
    },
    'stats-year-step': (t) => {
      state.statsYear += Number(t.dataset.step || 0);
      state.statsYearAll = false;
      renderView();
    },
    'stats-year-all': () => {
      state.statsYearAll = true;
      state.statsYear = Number(C.thisMonthKey().slice(0, 4));
      renderView();
    },
    'stats-set-year': (t) => {
      const y = Number(t.dataset.year);
      if (!Number.isFinite(y)) return;
      state.statsYear = y;
      state.statsYearAll = false;
      renderView();
    },
    'stats-chart-type': (t) => {
      state.statsChartType = t.dataset.value === 'line' ? 'line' : 'bar';
      renderView();
    },
    'stats-heat-type': (t) => {
      state.statsHeatType = t.dataset.type === 'income' ? 'income' : 'expense';
      renderView();
    },
    'stats-summary-toggle': () => {
      state.statsSummaryOpen = !state.statsSummaryOpen;
      renderView();
    },
    'open-year-heatmap': () => openYearHeatmap(),
    'stats-year-picker': () => openStatsMonthPicker(),
    'stats-custom-start': () => openStatsDate('start'),
    'stats-custom-end': () => openStatsDate('end'),
    'stats-preset': (t) => {
      const preset = t.dataset.preset;
      const today = C.todayISO();
      if (preset === '7') { state.statsCustomFrom = C.addDaysISO(today, -6); state.statsCustomTo = today; }
      else if (preset === '30') { state.statsCustomFrom = C.addDaysISO(today, -29); state.statsCustomTo = today; }
      else if (preset === 'month') { state.statsCustomFrom = C.thisMonthKey() + '-01'; state.statsCustomTo = C.monthEnd(C.thisMonthKey()); }
      else if (preset === 'year') { state.statsCustomFrom = C.thisMonthKey().slice(0, 4) + '-01-01'; state.statsCustomTo = C.thisMonthKey().slice(0, 4) + '-12-31'; }
      renderView();
    },
    'open-stats-menu': () => openStatsMenu(),
    'open-search': openSearch,
    'open-calendar': () => go('calendar'),
    'select-all': selectAllVisible,
    'select-export': openSelectionExport,
    'select-delete': deleteSelected,
    'select-cancel': clearSelection,
    'calendar-prev': () => calendarStep(-1),
    'calendar-next': () => calendarStep(1),
    'calendar-today': () => {
      state.calendarMonth = C.thisMonthKey();
      state.calendarSelected = C.todayISO();
      render();
      window.scrollTo(0, 0);
    },
    'calendar-month-picker': openCalendarMonthPicker,
    'calendar-select': (t) => {
      if (!t.dataset.day) return;
      state.calendarSelected = t.dataset.day;
      renderView();
    },
    'calendar-settings': openCalendarSettings,
    'calendar-add': () => openEntry(null, { date: state.calendarSelected }),
    'open-books': openBooks,
    'open-categories': () => openCategories('expense'),
    'open-budget': openBudget,
    'open-recurring': openRecurring,
    'open-data': openData,
    'open-theme': openTheme,
    'open-pin': openPin,
    'lock-now': () => { closeAllOverlays(); showLock(); },
    'open-about': openAbout,
    'open-transfer': () => openEntry(null, { type: 'transfer' }),
    'add-account': () => openAccountEditor(null),
    'open-account-bookkeeping': openBookkeepingAccounts,
    'edit-account': (t) => {
      const account = state.data.accounts.find((a) => a.id === t.dataset.id);
      if (account) openAccountEditor(account);
    },
    'edit-balance': (t) => {
      const account = state.data.accounts.find((a) => a.id === t.dataset.id);
      if (account) openBalanceEditor(account);
    }
  };

  document.addEventListener('click', (e) => {
    if (Date.now() < (state.suppressClickUntil || 0)) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    const target = e.target.closest('[data-act]');
    if (!target || !document.body.contains(target)) return;
    const fn = ACTIONS[target.dataset.act];
    if (!fn) return;
    e.preventDefault();
    fn(target, e);
  });

  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const top = overlayRoot.lastElementChild;
    if (!top) return;
    const closeBtn = top.querySelector('[data-close]');
    if (closeBtn) closeBtn.click();
  });

  let resizeTimer = null;
  window.addEventListener('resize', () => {
    if (state.route !== 'stats') return;
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(remountStatsPanes, 180);
  });

  const mq = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
  if (mq && mq.addEventListener) {
    mq.addEventListener('change', () => {
      if (state.data && state.data.settings.theme === 'auto') {
        applyTheme();
        if (state.route === 'stats') remountStatsPanes();
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * 启动
   * ------------------------------------------------------------------ */

  function init() {
    if (state.data) return;
    state.data = loadData();
    applyInsets();
    const created = C.applyRecurring(state.data, C.todayISO());
    if (created) saveData();
    applyTheme();
    render();

    if (state.data.settings.pinHash) showLock();
    registerServiceWorker();
    handleLaunchAction();
    if (state.data.settings.demo && !state.data.settings.onboarded) {
      state.data.settings.onboarded = true;
      saveData();
      window.setTimeout(() => toast('已准备示例账单，可在「我的 → 数据与备份」清空'), 900);
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();

  /* 长按账户删除 */
  let acctPressTimer = null;
  let acctPressId = null;
  let acctPressPos = null;

  function cancelAcctPress() {
    if (acctPressTimer) window.clearTimeout(acctPressTimer);
    acctPressTimer = null;
    acctPressId = null;
    acctPressPos = null;
  }

  function acctPressStart(e) {
    if (e.type === 'mousedown' && ('ontouchstart' in window) && navigator.maxTouchPoints > 0) return;
    if (state.route !== 'assets' || overlayRoot.children.length) return;
    const row = e.target.closest('.acct-row');
    if (!row || !viewEl.contains(row)) return;
    const point = e.touches ? e.touches[0] : e;
    cancelAcctPress();
    acctPressId = row.dataset.id;
    acctPressPos = { x: point.clientX, y: point.clientY };
    acctPressTimer = window.setTimeout(() => {
      acctPressTimer = null;
      const id = acctPressId;
      acctPressId = null;
      acctPressPos = null;
      if (!id) return;
      state.suppressClickUntil = Date.now() + 450;
      const account = state.data.accounts.find((a) => a.id === id);
      if (account) deleteAccountWithBills(account);
    }, 520);
  }

  function acctPressMove(e) {
    if (!acctPressPos) return;
    const point = e.touches ? e.touches[0] : e;
    if (Math.abs(point.clientX - acctPressPos.x) > 10 || Math.abs(point.clientY - acctPressPos.y) > 10) cancelAcctPress();
  }

  document.addEventListener('touchstart', acctPressStart, { passive: true });
  document.addEventListener('touchmove', acctPressMove, { passive: true });
  document.addEventListener('touchend', cancelAcctPress, { passive: true });
  document.addEventListener('mousedown', acctPressStart);
  document.addEventListener('mousemove', acctPressMove);
  document.addEventListener('mouseup', cancelAcctPress);


  /* 五个主界面左右滑动切换 */
  const PAGE_ORDER = ['home', 'calendar', 'stats', 'assets', 'profile'];
  let pageTouchX = null;
  let pageTouchY = null;
  let pageTouchAt = 0;
  let pageTouchTarget = null;
  let pageHorizontal = false;

  function pageTouchBlocked(target) {
    return !!(target && target.closest('.month-rail, .month-stepper, .calendar-grid-card, .tabbar, .fab-add, .select-bar, .appbar, .sheet, .modal, .pull-hint, input, textarea, select'));
  }

  let pageDrag = null;

  function pagePreviewHTML(route, statsMode) {
    let html = '';
    if (route === 'home') html = homeHTML();
    else if (route === 'calendar') html = calendarHTML();
    else if (route === 'stats') html = statsHTML(statsMode, '-drag');
    else if (route === 'assets') html = assetsHTML();
    else html = profileHTML();
    const ab = appbarHTML(route, statsMode);
    return '<div class="page-preview-pane">' +
      (ab ? '<div class="appbar">' + ab + '</div>' : '') +
      '<div class="view page-preview-view' + (route === 'assets' ? ' assets-preview' : '') + '">' + html + '</div>' +
    '</div>';
  }

  function pageDragTarget(dir) {
    const index = PAGE_ORDER.indexOf(state.route);
    if (index < 0) return null;
    if (state.route === 'stats') {
      const modes = ['daily', 'month', 'year', 'custom'];
      const mi = Math.max(0, modes.indexOf(state.statsMode));
      if (dir < 0 && mi === 0) return { route: 'calendar' };
      if (dir > 0 && mi === modes.length - 1) return { route: 'assets' };
      return null;
    }
    const next = index + dir;
    if (next < 0 || next >= PAGE_ORDER.length) return null;
    const route = PAGE_ORDER[next];
    return { route, statsMode: route === 'stats' ? (dir > 0 ? 'daily' : 'custom') : null };
  }

  function beginPageDrag(target, dir) {
    if (pageDrag || !target) return null;
    const height = Math.max(120, window.innerHeight);
    const overlay = document.createElement('div');
    overlay.className = 'page-drag';
    overlay.style.top = '0px';
    overlay.style.height = height + 'px';
    const clone = viewEl.cloneNode(true);
    clone.removeAttribute('id');
    clone.classList.add('page-preview-view');
    if (state.route === 'assets') clone.classList.add('assets-preview');
    clone.style.transform = 'translateY(' + (-window.scrollY) + 'px)';
    const appClone = appbarEl.hidden ? null : appbarEl.cloneNode(true);
    if (appClone) {
      appClone.removeAttribute('id');
      appClone.style.visibility = 'visible';
    }
    const curPane = '<div class="page-preview-pane">' +
      (appClone ? appClone.outerHTML : '') +
      clone.outerHTML +
    '</div>';
    const targetPane = pagePreviewHTML(target.route, target.statsMode);
    const panes = dir > 0 ? curPane + targetPane : targetPane + curPane;
    appbarEl.style.visibility = 'hidden';
    const base = dir > 0 ? 0 : -50;
    overlay.innerHTML = '<div class="page-preview-track" style="transform:translate3d(' + base + '%,0,0)">' + panes + '</div>';
    document.body.appendChild(overlay);
    if (target.route === 'stats') {
      try { mountStatsCharts(target.statsMode, '-drag'); } catch (err) { /* preview only */ }
    }
    const track = overlay.querySelector('.page-preview-track');
    const width = overlay.clientWidth || window.innerWidth || 320;
    pageDrag = {
      overlay, track, target, dir, width, moved: false,
      move(dx) {
        this.moved = true;
        const max = width * 0.92;
        const x = Math.max(-max, Math.min(max, dx));
        track.style.transform = 'translate3d(calc(' + base + '% + ' + x.toFixed(1) + 'px),0,0)';
      },
      finish(commit) {
        const o = this;
        if (!commit) {
          track.style.transition = 'transform .22s cubic-bezier(.22,.8,.28,1)';
          track.style.transform = 'translate3d(' + base + '%,0,0)';
          window.setTimeout(() => {
            if (o.overlay.parentNode) o.overlay.remove();
            appbarEl.style.visibility = '';
          }, 230);
          return;
        }
        track.style.transition = 'transform .26s cubic-bezier(.22,.8,.28,1)';
        track.style.transform = 'translate3d(' + (dir > 0 ? -50 : 0) + '%,0,0)';
        window.setTimeout(() => {
          if (o.overlay.parentNode) o.overlay.remove();
          appbarEl.style.visibility = '';
          state.selectMode = false;
          state.selectedIds = [];
          state.route = target.route;
          if (target.route === 'stats' && target.statsMode) state.statsMode = target.statsMode;
          render();
          window.scrollTo(0, 0);
        }, 270);
      }
    };
    return pageDrag;
  }

  function endPageDrag(commit) {
    if (!pageDrag) return;
    const d = pageDrag;
    pageDrag = null;
    state.suppressClickUntil = Date.now() + 450;
    d.finish(commit);
  }

  function pageStep(dir) {
    const index = PAGE_ORDER.indexOf(state.route);
    const next = index + dir;
    if (index < 0 || next < 0 || next >= PAGE_ORDER.length) return;
    state.suppressClickUntil = Date.now() + 350;
    go(PAGE_ORDER[next], dir);
  }

  document.addEventListener('touchstart', (e) => {
    pageTouchX = null;
    if (!PAGE_ORDER.includes(state.route) || state.selectMode || overlayRoot.children.length || pageDrag) return;
    if (pageTouchBlocked(e.target)) return;
    if (state.route === 'stats' && e.target.closest('button, .month-rail, .stats-table, .heat-year-grid, .stats-chart-controls, .stats-chart-type, .stats-tabs')) return;
    pageTouchX = e.touches[0].clientX;
    pageTouchY = e.touches[0].clientY;
    pageTouchAt = Date.now();
    pageTouchTarget = e.target;
    pageHorizontal = false;
  }, { passive: true });

  document.addEventListener('touchmove', (e) => {
    if (pageDrag) {
      const dx = e.touches[0].clientX - pageTouchX;
      pageDrag.move(dx);
      if (e.cancelable) e.preventDefault();
      return;
    }
    if (pageTouchX == null) return;
    const dx = e.touches[0].clientX - pageTouchX;
    const dy = e.touches[0].clientY - pageTouchY;
    if (Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy) * 1.15) {
      if (pageHorizontal) {
        if (e.cancelable) e.preventDefault();
        return;
      }
      const dir = dx < 0 ? 1 : -1;
      const target = pageDragTarget(dir);
      if (!target) return;
      pageHorizontal = true;
      if (e.cancelable) e.preventDefault();
      if (beginPageDrag(target, dir)) pageDrag.move(dx);
    }
  }, { passive: false });

  document.addEventListener('touchend', (e) => {
    if (pageTouchX == null && !pageDrag) return;
    const point = (e.changedTouches && e.changedTouches[0]) || (e.touches && e.touches[0]);
    if (!point) { pageTouchX = null; pageDrag = null; pageHorizontal = false; return; }
    const dx = point.clientX - pageTouchX;
    if (pageDrag) {
      const threshold = Math.min(80, pageDrag.width * 0.2);
      endPageDrag(Math.abs(dx) > threshold);
    }
    pageTouchX = null;
    pageTouchY = null;
    pageTouchAt = 0;
    pageTouchTarget = null;
    pageHorizontal = false;
  }, { passive: true });

  /* 日历 / 我的 页面向下回弹固定 */
  let fixedPageStartY = null;
  document.addEventListener('touchstart', (e) => {
    if ((state.route !== 'calendar' && state.route !== 'profile') || overlayRoot.children.length) return;
    if (window.scrollY > 1) return;
    if (pageTouchBlocked(e.target)) return;
    fixedPageStartY = e.touches[0].clientY;
  }, { passive: true });
  document.addEventListener('touchmove', (e) => {
    if (fixedPageStartY == null) return;
    const dy = e.touches[0].clientY - fixedPageStartY;
    if (dy > 6 && window.scrollY <= 1 && e.cancelable) e.preventDefault();
    if (dy < -2) fixedPageStartY = null;
  }, { passive: false });
  document.addEventListener('touchend', () => { fixedPageStartY = null; }, { passive: true });


  /* 长按分类管理 */
  let catPressTimer = null;
  let catPressId = null;
  let catPressPos = null;

  function cancelCatPress() {
    if (catPressTimer) window.clearTimeout(catPressTimer);
    catPressTimer = null;
    catPressId = null;
    catPressPos = null;
  }

  function catPressStart(e) {
    if (e.type === 'mousedown' && ('ontouchstart' in window) && navigator.maxTouchPoints > 0) return;
    const row = e.target.closest('[data-cat-edit]');
    if (!row || !overlayRoot.contains(row)) return;
    const point = e.touches ? e.touches[0] : e;
    cancelCatPress();
    catPressId = row.dataset.catEdit;
    catPressPos = { x: point.clientX, y: point.clientY };
    catPressTimer = window.setTimeout(() => {
      catPressTimer = null;
      const id = catPressId;
      catPressId = null;
      catPressPos = null;
      if (!id) return;
      state.suppressClickUntil = Date.now() + 450;
      const cat = state.data.categories.find((c) => c.id === id);
      if (cat) openCategoryActions(cat);
    }, 520);
  }

  function catPressMove(e) {
    if (!catPressPos) return;
    const point = e.touches ? e.touches[0] : e;
    if (Math.abs(point.clientX - catPressPos.x) > 10 || Math.abs(point.clientY - catPressPos.y) > 10) cancelCatPress();
  }

  document.addEventListener('touchstart', catPressStart, { passive: true });
  document.addEventListener('touchmove', catPressMove, { passive: true });
  document.addEventListener('touchend', cancelCatPress, { passive: true });
  document.addEventListener('mousedown', catPressStart);
  document.addEventListener('mousemove', catPressMove);
  document.addEventListener('mouseup', cancelCatPress);

})();
