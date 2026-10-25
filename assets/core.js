/*
 * 星空记账 · 核心逻辑
 * 纯函数数据层：日期/金额工具、账目计算、预算、周期记账、导入导出。
 * 同时支持 <script>（window.LedgerCore）与 Node（require）两种加载方式。
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.LedgerCore = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const VERSION = 2;
  const WEEK_CN = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  const TYPE_CN = { expense: '支出', income: '收入', transfer: '转账' };

  // 与「星空记账」账单导出列保持一致
  const BILL_HEADERS = [
    '日期', '收支类型', '金额', '类别', '二级分类', '账户', '账本',
    '退款', '优惠', '备注', '标签', '报销账户', '报销金额', '报销明细',
    '多币种', '地址', '创建用户', '其他',
    '附件1', '附件2', '附件3', '附件4', '附件5'
  ];
  const BILL_NUMERIC = ['金额', '退款', '优惠', '报销金额'];

  /* ------------------------------------------------------------------ *
   * 基础工具
   * ------------------------------------------------------------------ */

  let seq = 0;
  function uid(prefix) {
    seq = (seq + 1) % 1296;
    return (prefix || 'id') + '_' + Date.now().toString(36) + seq.toString(36) +
      Math.random().toString(36).slice(2, 6);
  }

  const pad2 = (n) => (n < 10 ? '0' : '') + n;

  function iso(date) {
    return date.getFullYear() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate());
  }
  function parseISO(str) {
    const p = String(str || '').split('-').map(Number);
    return new Date(p[0] || 1970, (p[1] || 1) - 1, p[2] || 1, 12, 0, 0, 0);
  }
  function todayISO() { return iso(new Date()); }
  function thisMonthKey() { return todayISO().slice(0, 7); }
  function monthKeyOf(day) { return String(day || '').slice(0, 7); }
  function daysInMonth(year, month1) { return new Date(year, month1, 0).getDate(); }
  function monthStart(key) { return key + '-01'; }
  function monthEnd(key) {
    const [y, m] = key.split('-').map(Number);
    return key + '-' + pad2(daysInMonth(y, m));
  }
  function addDaysISO(day, delta) {
    const d = parseISO(day);
    d.setDate(d.getDate() + delta);
    return iso(d);
  }
  function addMonthsKey(key, delta) {
    const [y, m] = key.split('-').map(Number);
    const d = new Date(y, m - 1 + delta, 1, 12);
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1);
  }
  function weekdayIndex(day) { return parseISO(day).getDay(); }
  function weekdayCN(day) { return WEEK_CN[weekdayIndex(day)]; }
  function monthLabel(key) {
    const [y, m] = key.split('-').map(Number);
    return y + '年' + m + '月';
  }
  function shortMonthLabel(key) {
    const [y, m] = key.split('-').map(Number);
    return m + '月';
  }
  function dateLabel(day) {
    const d = parseISO(day);
    return (d.getMonth() + 1) + '月' + d.getDate() + '日';
  }
  function fullDateLabel(day) {
    const d = parseISO(day);
    return d.getFullYear() + '年' + (d.getMonth() + 1) + '月' + d.getDate() + '日';
  }
  function relativeDay(day) {
    const t = todayISO();
    if (day === t) return '今天';
    if (day === addDaysISO(t, -1)) return '昨天';
    if (day === addDaysISO(t, -2)) return '前天';
    return '';
  }
  const SOLAR_TERM_NAMES = ['小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑', '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至'];
  const SOLAR_TERM_INFO = [0, 21208, 42467, 63836, 85337, 107014, 128867, 150921, 173149, 195551, 218072, 240693, 263343, 285989, 308563, 331033, 353350, 375494, 397447, 419210, 440795, 462224, 483532, 504758];
  const SOLAR_FESTIVALS = {
    '01-01': '元旦', '02-14': '情人节', '03-08': '妇女节', '03-12': '植树节',
    '04-01': '愚人节', '05-01': '劳动节', '05-04': '青年节', '06-01': '儿童节',
    '07-01': '建党节', '08-01': '建军节', '09-10': '教师节', '10-01': '国庆节',
    '10-31': '万圣节', '12-24': '平安夜', '12-25': '圣诞节'
  };
  const LUNAR_FESTIVALS = {
    '正月初一': '春节', '正月十五': '元宵节', '二月初二': '龙抬头',
    '五月初五': '端午节', '七月初七': '七夕节', '八月十五': '中秋节',
    '九月初九': '重阳节', '腊月初八': '腊八节', '腊月廿三': '小年'
  };

  function chineseLunarDay(n) {
    const digits = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (n <= 10) return '初' + digits[n];
    if (n < 20) return '十' + digits[n - 10];
    if (n === 20) return '二十';
    if (n < 30) return '廿' + digits[n - 20];
    return '三十';
  }

  function solarTermName(iso) {
    const d = parseISO(iso);
    const year = d.getFullYear();
    const month = d.getMonth() + 1;
    const day = d.getDate();
    for (let i = (month - 1) * 2; i <= (month - 1) * 2 + 1; i++) {
      const ms = 31556925974.7 * (year - 1900) + SOLAR_TERM_INFO[i] * 60000 + Date.UTC(1900, 0, 6, 2, 5);
      const term = new Date(ms);
      if (term.getUTCMonth() + 1 === month && term.getUTCDate() === day) return SOLAR_TERM_NAMES[i];
    }
    return '';
  }

  /** 日历单元格的农历 / 节日 / 节气文字。 */
  function calendarLabel(iso) {
    const d = parseISO(iso);
    const solarKey = pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
    const solarFestival = SOLAR_FESTIVALS[solarKey] || '';
    let lunar = null;
    try {
      const parts = new Intl.DateTimeFormat('zh-CN-u-ca-chinese', {
        month: 'long', day: 'numeric'
      }).formatToParts(d);
      const monthName = (parts.find((p) => p.type === 'month') || {}).value || '';
      const dayNum = Number((parts.find((p) => p.type === 'day') || {}).value || 0);
      if (monthName && dayNum) {
        lunar = {
          monthName,
          dayNum,
          dayName: chineseLunarDay(dayNum),
          key: monthName + (dayNum === 1 ? '初一' : chineseLunarDay(dayNum))
        };
      }
    } catch (err) { /* 浏览器不支持中国农历时降级 */ }

    const lunarKey = lunar ? lunar.monthName + lunar.dayName : '';
    const lunarFest = lunar ? (LUNAR_FESTIVALS[lunarKey] || '') : '';
    const term = solarTermName(iso);
    const festival = solarFestival || lunarFest;
    const text = festival || term || (lunar ? (lunar.dayNum === 1 ? lunar.monthName : lunar.dayName) : '');
    return {
      text,
      festival,
      term,
      lunar: lunar ? (lunar.dayNum === 1 ? lunar.monthName : lunar.dayName) : '',
      lunarMonth: lunar ? lunar.monthName : '',
      lunarDay: lunar ? lunar.dayNum : 0,
      holiday: !!festival
    };
  }

  function monthDays(key) {
    const [y, m] = key.split('-').map(Number);
    const n = daysInMonth(y, m);
    const out = [];
    for (let i = 1; i <= n; i++) out.push(key + '-' + pad2(i));
    return out;
  }
  function monthsBetween(startKey, endKey) {
    const [sy, sm] = startKey.split('-').map(Number);
    const [ey, em] = endKey.split('-').map(Number);
    return (ey - sy) * 12 + (em - sm);
  }

  // 金额一律以「分」参与加减，避免 0.1+0.2 浮点误差
  function toCents(n) { return Math.round((Number(n) || 0) * 100); }
  function fromCents(c) { return Math.round(c) / 100; }
  function round2(n) { return Math.round((Number(n) || 0) * 100) / 100; }
  function money(n, digits) {
    const d = digits == null ? 2 : digits;
    const v = Number(n) || 0;
    const fixed = Math.abs(v).toFixed(d);
    const parts = fixed.split('.');
    const int = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return (v < 0 ? '-' : '') + int + (d > 0 ? '.' + (parts[1] || '') : '');
  }
  function amountParts(n) {
    const abs = Math.abs(round2(n));
    const fixed = abs.toFixed(2);
    const [int, dec] = fixed.split('.');
    return {
      sign: (Number(n) || 0) < 0 ? '-' : '',
      int: int.replace(/\B(?=(\d{3})+(?!\d))/g, ','),
      dec: dec
    };
  }

  /** 解析 12+3.5-1 这类算式，失败返回 NaN */
  function parseAmountExpr(expr) {
    if (typeof expr === 'number') return isFinite(expr) ? round2(expr) : NaN;
    const s = String(expr == null ? '' : expr).replace(/[\s,，]/g, '');
    if (!s) return NaN;
    if (!/^[+-]?(\d+(\.\d*)?|\.\d+)([+-](\d+(\.\d*)?|\.\d+))*$/.test(s)) return NaN;
    const tokens = s.match(/[+-]?(\d+(?:\.\d*)?|\.\d+)/g) || [];
    let cents = 0;
    for (const tok of tokens) {
      if (tok === '+' || tok === '-') continue;
      const v = Number(tok);
      if (!isFinite(v)) return NaN;
      cents += Math.round(v * 100);
    }
    return fromCents(cents);
  }

  /* ------------------------------------------------------------------ *
   * 默认分类 / 账户
   * ------------------------------------------------------------------ */

  const EXPENSE_CATS = [
    ['food', '餐饮', '🍜', '#f97316'],
    ['transport', '交通', '🚌', '#3b82f6'],
    ['shopping', '购物', '🛍️', '#ec4899'],
    ['fun', '娱乐', '🎮', '#8b5cf6'],
    ['home', '居住', '🏠', '#0ea5e9'],
    ['medical', '医疗', '💊', '#ef4444'],
    ['study', '学习', '📚', '#6366f1'],
    ['phone', '通讯', '📱', '#14b8a6'],
    ['clothes', '服饰', '👕', '#d946ef'],
    ['daily', '日用', '🧻', '#84cc16'],
    ['travel', '旅行', '✈️', '#06b6d4'],
    ['sport', '运动', '🏀', '#f59e0b'],
    ['pet', '宠物', '🐶', '#f43f5e'],
    ['beauty', '美容', '💄', '#e879f9'],
    ['digital', '数码', '💻', '#64748b'],
    ['utility', '水电', '💡', '#eab308'],
    ['baby', '育儿', '🧸', '#fb923c'],
    ['social', '人情', '🎁', '#db2777'],
    ['other', '其它', '📦', '#94a3b8']
  ];
  const INCOME_CATS = [
    ['salary', '工资', '💼', '#10b981'],
    ['bonus', '奖金', '🏆', '#f59e0b'],
    ['invest', '理财', '📈', '#0ea5e9'],
    ['parttime', '兼职', '🧑‍💻', '#6366f1'],
    ['redpacket', '红包', '🧧', '#ef4444'],
    ['reimburse', '报销', '🧾', '#14b8a6'],
    ['refund', '退款', '↩️', '#8b5cf6'],
    ['other_income', '其它', '💰', '#94a3b8']
  ];

  const ACCOUNT_TYPES = {
    cash: { name: '现金', icon: '💵', liability: false },
    alipay: { name: '支付宝', icon: '💠', liability: false },
    wechat: { name: '微信', icon: '🟢', liability: false },
    bank: { name: '银行卡', icon: '🏦', liability: false },
    invest: { name: '投资', icon: '📈', liability: false },
    credit: { name: '信用卡', icon: '💳', liability: true },
    other: { name: '其它', icon: '👛', liability: false }
  };

  function makeCategories() {
    const out = [];
    EXPENSE_CATS.forEach((c, i) => out.push({
      id: 'c_' + c[0], name: c[1], icon: c[2], color: c[3], type: 'expense', order: i, builtin: true
    }));
    INCOME_CATS.forEach((c, i) => out.push({
      id: 'c_' + c[0], name: c[1], icon: c[2], color: c[3], type: 'income', order: i, builtin: true
    }));
    return out;
  }

  const DEFAULT_ACCOUNTS = [
    { id: 'a_cash', name: '现金', type: 'cash', icon: '💵', color: '#22c55e', initial: 800, include: true },
    { id: 'a_alipay', name: '支付宝', type: 'alipay', icon: '💠', color: '#0ea5e9', initial: 6800, include: true },
    { id: 'a_wechat', name: '微信', type: 'wechat', icon: '🟢', color: '#10b981', initial: 3200, include: true },
    { id: 'a_bank', name: '银行卡', type: 'bank', icon: '🏦', color: '#6366f1', initial: 10000, include: true },
    { id: 'a_credit', name: '信用卡', type: 'credit', icon: '💳', color: '#f43f5e', initial: 0, include: true }
  ];

  /* ------------------------------------------------------------------ *
   * 数据初始化 / 演示账单
   * ------------------------------------------------------------------ */

  function createDefaultData(options) {
    const opts = options || {};
    const bookId = 'b_main';
    const data = {
      version: VERSION,
      createdAt: new Date().toISOString(),
      settings: {
        theme: 'auto',
        pinHash: null,
        lockEnabled: false,
        currency: '¥',
        demo: !!opts.demo,
        onboarded: false,
        calendarHeat: true,
        calendarLunar: true
      },
      books: [{
        id: bookId,
        name: '日常账本',
        icon: '📒',
        color: '#0e9f6e',
        budget: { total: 0, categories: {} },
        createdAt: new Date().toISOString()
      }],
      activeBookId: bookId,
      categories: makeCategories(),
      accounts: DEFAULT_ACCOUNTS.map((a) => Object.assign({}, a)),
      transactions: [],
      tags: [],
      recurring: []
    };
    if (opts.demo) seedDemoData(data);
    return data;
  }

  function seedDemoData(data) {
    const bookId = data.books[0].id;
    const now = new Date();
    const templates = [
      ['expense', 'c_food', ['午饭', '咖啡', '外卖', '和朋友吃饭', '早餐'], [15, 58], 'a_alipay'],
      ['expense', 'c_transport', ['地铁', '打车', '公交'], [3, 42], 'a_wechat'],
      ['expense', 'c_shopping', ['生活用品', '超市采购', '网购'], [35, 260], 'a_alipay'],
      ['expense', 'c_daily', ['纸巾牙膏', '洗衣液', '水果'], [12, 75], 'a_alipay'],
      ['expense', 'c_fun', ['电影票', '游戏充值', '演出'], [25, 180], 'a_wechat'],
      ['expense', 'c_study', ['买书', '网课'], [30, 199], 'a_alipay'],
      ['expense', 'c_phone', ['话费充值'], [50, 100], 'a_wechat'],
      ['expense', 'c_clothes', ['T恤', '鞋子'], [99, 399], 'a_alipay'],
      ['expense', 'c_sport', ['羽毛球', '健身月卡'], [30, 199], 'a_wechat'],
      ['expense', 'c_medical', ['药品'], [18, 120], 'a_cash'],
      ['expense', 'c_pet', ['猫粮'], [68, 188], 'a_alipay'],
      ['income', 'c_invest', ['基金分红'], [20, 160], 'a_bank']
    ];
    const rand = (a, b) => a + Math.random() * (b - a);
    const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
    const subMap = {
      c_food: ['早餐', '午餐', '晚餐', '咖啡', '外卖'],
      c_transport: ['地铁', '公交', '打车'],
      c_shopping: ['超市', '网购'],
      c_daily: ['日用', '水果'],
      c_fun: ['电影', '游戏', '演出'],
      c_study: ['书籍', '网课'],
      c_clothes: ['上衣', '鞋子'],
      c_sport: ['羽毛球', '健身'],
      c_pet: ['猫粮'],
      c_medical: ['药品']
    };

    let created = 0;
    for (let back = 2; back >= 0; back--) {
      const y = now.getFullYear();
      const m = now.getMonth() - back;
      const first = new Date(y, m, 1, 12);
      const yy = first.getFullYear();
      const mm = first.getMonth();
      const dim = daysInMonth(yy, mm + 1);
      const today = now.getDate();
      const maxDay = back === 0 ? today : dim;
      const key = yy + '-' + pad2(mm + 1);

      // 固定的大额支出 / 收入
      const fixed = [
        { day: 5, type: 'expense', cat: 'c_home', note: '房租', amount: 1800, account: 'a_bank', tags: ['固定支出'] },
        { day: 6, type: 'expense', cat: 'c_utility', note: '水电费', amount: 128, account: 'a_alipay', tags: [] },
        { day: 8, type: 'expense', cat: 'c_home', note: '宽带续费', amount: 90, account: 'a_wechat', tags: [] },
        { day: 10, type: 'income', cat: 'c_salary', note: '工资', amount: 12000, account: 'a_bank', tags: ['工资'] },
        { day: 18, type: 'income', cat: 'c_invest', note: '理财收益', amount: 86, account: 'a_bank', tags: [] }
      ];
      fixed.forEach((f, idx) => {
        if (f.day > maxDay) return;
        data.transactions.push({
          id: uid('t'), bookId,
          type: f.type, amount: f.amount, categoryId: f.cat,
          accountId: f.account, toAccountId: null,
          date: key + '-' + pad2(f.day), time: pad2(7 + idx) + ':' + pick(['12', '35', '48']),
          note: f.note, tags: f.tags,
          subcategory: subMap[f.cat] ? pick(subMap[f.cat]) : '',
          refund: 0, discount: 0,
          reimburseAccount: '', reimburseAmount: 0, reimburseNote: '',
          currency: '', foreignAmount: 0,
          location: '', creator: '我', extra: '',
          attachments: [],
          createdAt: new Date(yy, mm, f.day, 9).toISOString(), updatedAt: null
        });
        created++;
      });

      for (let d = 1; d <= maxDay; d++) {
        if (d === 5 || d === 10 || d === 18) continue;
        const rolls = Math.random() < 0.25 ? 2 : (Math.random() < 0.75 ? 1 : 0);
        for (let r = 0; r < rolls; r++) {
          const tpl = pick(templates);
          const amount = Math.round(rand(tpl[3][0], tpl[3][1]) * 100) / 100;
          if (back === 0 && Math.random() < 0.25) continue;
          data.transactions.push({
            id: uid('t'), bookId,
            type: tpl[0], amount,
            categoryId: tpl[1], accountId: tpl[4], toAccountId: null,
            date: key + '-' + pad2(d),
            time: pad2(6 + Math.floor(Math.random() * 15)) + ':' + pad2(Math.floor(Math.random() * 60)),
            note: pick(tpl[2]), tags: Math.random() < 0.18 ? ['日常'] : [],
            subcategory: subMap[tpl[1]] ? pick(subMap[tpl[1]]) : '',
            refund: 0, discount: 0,
            reimburseAccount: '', reimburseAmount: 0, reimburseNote: '',
            currency: '', foreignAmount: 0,
            location: Math.random() < 0.08 ? '公司' : '',
            creator: '我', extra: '',
            attachments: [],
            createdAt: new Date(yy, mm, d, 10).toISOString(), updatedAt: null
          });
          created++;
        }
      }
    }
    data.transactions.sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
    data.tags = ['固定支出', '日常', '工资'];
    data.settings.demo = true;
    adjustDemoBalances(data);
    return created;
  }

  /** 让演示数据的账户余额保持自然（不至于一打开就是负数） */
  function adjustDemoBalances(data) {
    const flow = {};
    data.accounts.forEach((a) => {
      flow[a.id] = 0; });
    data.transactions.forEach((t) => {
      if (t.type === 'income' && flow[t.accountId] != null) flow[t.accountId] += t.amount;
      if (t.type === 'expense' && flow[t.accountId] != null) flow[t.accountId] -= t.amount;
      if (t.type === 'transfer') {
        if (flow[t.accountId] != null) flow[t.accountId] -= t.amount;
        if (t.toAccountId && flow[t.toAccountId] != null) flow[t.toAccountId] += t.amount;
      }
    });
    const targets = { cash: 800, alipay: 3200, wechat: 2200, bank: 22000, credit: 0, invest: 5000, other: 500 };
    data.accounts.forEach((a) => {
      const target = targets[a.type] == null ? 500 : targets[a.type];
      const needed = round2(target - (flow[a.id] || 0));
      if (needed > a.initial) a.initial = Math.ceil(needed / 100) * 100;
    });
  }

  /* ------------------------------------------------------------------ *
   * 迁移 / 校验
   * ------------------------------------------------------------------ */

  function migrateData(input) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
    const data = input;
    data.version = VERSION;
    if (!Array.isArray(data.books) || data.books.length === 0) {
      data.books = [{
        id: 'b_main', name: '日常账本', icon: '📒', color: '#0e9f6e',
        budget: { total: 0, categories: {} }, createdAt: new Date().toISOString()
      }];
    }
    data.books.forEach((b) => {
      b.id = b.id || uid('b');
      b.name = b.name || '未命名账本';
      b.icon = b.icon || '📒';
      b.color = b.color || '#0e9f6e';
      if (!b.budget || typeof b.budget !== 'object') b.budget = { total: 0, categories: {} };
      if (!b.budget.categories || typeof b.budget.categories !== 'object') b.budget.categories = {};
      b.budget.total = Number(b.budget.total) || 0;
    });
    if (!data.books.some((b) => b.id === data.activeBookId)) data.activeBookId = data.books[0].id;

    if (!Array.isArray(data.categories) || !data.categories.length) data.categories = makeCategories();
    data.categories = data.categories.filter((c) => c && c.id && c.name).map((c, i) => ({
      id: c.id, name: c.name, icon: c.icon || '🏷️', color: c.color || '#94a3b8',
      type: c.type === 'income' ? 'income' : 'expense',
      order: Number.isFinite(c.order) ? c.order : i,
      builtin: !!c.builtin
    }));

    if (!Array.isArray(data.accounts) || !data.accounts.length) {
      data.accounts = DEFAULT_ACCOUNTS.map((a) => Object.assign({}, a));
    }
    data.accounts = data.accounts.filter((a) => a && a.id && a.name).map((a, i) => ({
      id: a.id, name: a.name, type: ACCOUNT_TYPES[a.type] ? a.type : 'other',
      icon: a.icon || (ACCOUNT_TYPES[a.type] || ACCOUNT_TYPES.other).icon,
      color: a.color || '#94a3b8',
      initial: round2(Number(a.initial) || 0),
      include: a.include !== false,
      bookkeeping: a.bookkeeping !== false,
      order: Number.isFinite(a.order) ? a.order : i
    }));

    data.transactions = (Array.isArray(data.transactions) ? data.transactions : []).filter((t) => t && t.date).map((t) => {
      const type = t.type === 'income' || t.type === 'transfer' ? t.type : 'expense';
      return {
        id: t.id || uid('t'),
        bookId: t.bookId || data.activeBookId,
        type,
        amount: round2(Math.abs(Number(t.amount) || 0)),
        categoryId: type === 'transfer' ? null : (t.categoryId || null),
        accountId: t.accountId || null,
        toAccountId: type === 'transfer' ? (t.toAccountId || null) : null,
        date: String(t.date).slice(0, 10),
        time: /^\d{2}:\d{2}/.test(String(t.time)) ? String(t.time).slice(0, 5) : '12:00',
        subcategory: typeof t.subcategory === 'string' ? t.subcategory.slice(0, 20) : '',
        refund: Math.max(0, round2(Number(t.refund) || 0)),
        discount: Math.max(0, round2(Number(t.discount) || 0)),
        reimburseAccount: typeof t.reimburseAccount === 'string' ? t.reimburseAccount.slice(0, 40) : '',
        reimburseAmount: Math.max(0, round2(Number(t.reimburseAmount) || 0)),
        reimburseNote: typeof t.reimburseNote === 'string' ? t.reimburseNote.slice(0, 200) : '',
        currency: typeof t.currency === 'string' ? t.currency.slice(0, 12) : '',
        foreignAmount: Math.max(0, round2(Number(t.foreignAmount) || 0)),
        location: typeof t.location === 'string' ? t.location.slice(0, 120) : '',
        creator: typeof t.creator === 'string' ? t.creator.slice(0, 20) : '',
        extra: typeof t.extra === 'string' ? t.extra.slice(0, 200) : '',
        attachments: Array.isArray(t.attachments) ? t.attachments
          .filter((a) => a && typeof a.name === 'string')
          .slice(0, 5)
          .map((a) => ({
            name: a.name.slice(0, 120),
            dataUrl: typeof a.dataUrl === 'string' ? a.dataUrl : null,
            type: typeof a.type === 'string' ? a.type.slice(0, 40) : ''
          })) : [],
        note: typeof t.note === 'string' ? t.note : '',
        tags: Array.isArray(t.tags) ? t.tags.filter((x) => typeof x === 'string') : [],
        recurringId: t.recurringId || null,
        createdAt: t.createdAt || new Date().toISOString(),
        updatedAt: t.updatedAt || null
      };
    });

    if (!Array.isArray(data.recurring)) data.recurring = [];
    data.recurring = data.recurring.filter((r) => r && r.id).map((r) => ({
      id: r.id,
      bookId: r.bookId || data.activeBookId,
      type: r.type === 'income' ? 'income' : 'expense',
      amount: round2(Number(r.amount) || 0),
      categoryId: r.categoryId || null,
      accountId: r.accountId || null,
      note: r.note || '',
      freq: ['daily', 'weekly', 'monthly', 'yearly'].indexOf(r.freq) >= 0 ? r.freq : 'monthly',
      startDate: r.startDate || todayISO(),
      lastRun: r.lastRun || null,
      enabled: r.enabled !== false
    }));

    if (!data.settings || typeof data.settings !== 'object') data.settings = {};
    const s = data.settings;
    s.theme = ['auto', 'light', 'dark'].indexOf(s.theme) >= 0 ? s.theme : 'auto';
    s.currency = s.currency || '¥';
    s.pinHash = s.pinHash || null;
    s.lockEnabled = !!s.pinHash;
    s.demo = !!s.demo;
    s.onboarded = !!s.onboarded;
    s.calendarHeat = s.calendarHeat !== false;
    s.calendarLunar = s.calendarLunar !== false;

    if (!Array.isArray(data.tags)) data.tags = [];
    data.tags = Array.from(new Set(data.tags.filter((t) => typeof t === 'string')));
    return data;
  }

  function validateBackup(obj) {
    if (!obj || typeof obj !== 'object') return { ok: false, error: '文件内容不是有效的数据' };
    const data = obj.data && typeof obj.data === 'object' ? obj.data : obj;
    if (!Array.isArray(data.books) || !Array.isArray(data.transactions)) {
      return { ok: false, error: '缺少账本或账单数据，无法导入' };
    }
    const migrated = migrateData(JSON.parse(JSON.stringify(data)));
    if (!migrated) return { ok: false, error: '数据格式无法识别' };
    return { ok: true, data: migrated };
  }

  /* ------------------------------------------------------------------ *
   * 查询 / 统计
   * ------------------------------------------------------------------ */

  function categoryMap(data) {
    const map = {};
    data.categories.forEach((c) => { map[c.id] = c; });
    return map;
  }
  function accountMap(data) {
    const map = {};
    data.accounts.forEach((a) => {
      map[a.id] = a; });
    return map;
  }
  function activeBook(data) {
    return data.books.find((b) => b.id === data.activeBookId) || data.books[0];
  }
  function categoriesOf(data, type) {
    return data.categories
      .filter((c) => c.type === type)
      .sort((a, b) => (a.order || 0) - (b.order || 0));
  }

  function sortTransactions(list) {
    return list.slice().sort((a, b) => {
      const ta = a.date + ' ' + a.time;
      const tb = b.date + ' ' + b.time;
      if (ta !== tb) return tb.localeCompare(ta);
      return String(b.createdAt || '').localeCompare(String(a.createdAt || ''));
    });
  }

  function bookTransactions(data, bookId) {
    const id = bookId || data.activeBookId;
    return sortTransactions(data.transactions.filter((t) => t.bookId === id));
  }

  function filterTransactions(data, opts) {
    const o = opts || {};
    const cm = categoryMap(data);
    const am = accountMap(data);
    const q = String(o.q || '').trim().toLowerCase();
    let list = data.transactions.filter((t) => {
      if (o.bookId && t.bookId !== o.bookId) return false;
      if (o.type && t.type !== o.type) return false;
      if (o.categoryId && t.categoryId !== o.categoryId) return false;
      if (o.accountId && t.accountId !== o.accountId && t.toAccountId !== o.accountId) return false;
      if (o.month && monthKeyOf(t.date) !== o.month) return false;
      if (o.from && t.date < o.from) return false;
      if (o.to && t.date > o.to) return false;
      if (o.tag && !(t.tags || []).includes(o.tag)) return false;
      if (q) {
        const cat = cm[t.categoryId];
        const acc = am[t.accountId];
        const to = am[t.toAccountId];
        const hay = [
          t.note, t.tags && t.tags.join(' '), cat && cat.name, acc && acc.name,
          to && to.name, money(t.amount, 2), String(t.amount), TYPE_CN[t.type],
          dateLabel(t.date), t.date, t.subcategory, t.reimburseAccount, t.reimburseNote,
          t.currency, t.location, t.creator, t.extra, t.reimburseAmount
        ].join(' ').toLowerCase();
        if (hay.indexOf(q) < 0) return false;
      }
      return true;
    });
    return sortTransactions(list);
  }

  function monthTotals(data, bookId, monthKey) {
    let expense = 0, income = 0, count = 0, transfer = 0;
    for (const t of data.transactions) {
      if (t.bookId !== bookId || monthKeyOf(t.date) !== monthKey) continue;
      if (!t.amount) continue;
      count++;
      if (t.type === 'expense') expense += toCents(t.amount);
      else if (t.type === 'income') income += toCents(t.amount);
      else transfer += toCents(t.amount);
    }
    return {
      expense: fromCents(expense),
      income: fromCents(income),
      balance: fromCents(income - expense),
      transfer: fromCents(transfer),
      count
    };
  }

  function dayTotals(data, bookId, monthKey) {
    const map = {};
    for (const t of data.transactions) {
      if (t.bookId !== bookId || monthKeyOf(t.date) !== monthKey) continue;
      const d = Number(t.date.slice(8, 10));
      if (!map[d]) map[d] = { expense: 0, income: 0, count: 0 };
      map[d].count++;
      if (t.type === 'expense') map[d].expense += toCents(t.amount);
      if (t.type === 'income') map[d].income += toCents(t.amount);
    }
    Object.keys(map).forEach((k) => {
      map[k].expense = fromCents(map[k].expense);
      map[k].income = fromCents(map[k].income);
    });
    return map;
  }

  function categoryBreakdown(data, bookId, monthKey, type) {
    const cm = categoryMap(data);
    const totals = {};
    let sum = 0;
    for (const t of data.transactions) {
      if (t.bookId !== bookId || monthKeyOf(t.date) !== monthKey) continue;
      if (t.type !== type) continue;
      const key = t.categoryId || 'unknown';
      const cents = toCents(t.amount);
      sum += cents;
      if (!totals[key]) totals[key] = { cents: 0, count: 0 };
      totals[key].cents += cents;
      totals[key].count++;
    }
    const list = Object.keys(totals).map((key) => {
      const c = cm[key] || { id: key, name: '未分类', icon: '🏷️', color: '#94a3b8' };
      return {
        id: key,
        name: c.name,
        icon: c.icon,
        color: c.color,
        value: fromCents(totals[key].cents),
        count: totals[key].count,
        pct: sum ? totals[key].cents / sum : 0
      };
    });
    list.sort((a, b) => b.value - a.value);
    return list;
  }

  function accountBalances(data, bookId) {
    const map = {};
    data.accounts.forEach((a) => {
      map[a.id] = toCents(a.initial); });
    for (const t of data.transactions) {
      if (bookId && t.bookId !== bookId) continue;
      if (t.type === 'income' && map[t.accountId] != null) map[t.accountId] += toCents(t.amount);
      if (t.type === 'expense' && map[t.accountId] != null) map[t.accountId] -= toCents(t.amount);
      if (t.type === 'transfer') {
        if (map[t.accountId] != null) map[t.accountId] -= toCents(t.amount);
        if (t.toAccountId && map[t.toAccountId] != null) map[t.toAccountId] += toCents(t.amount);
      }
    }
    Object.keys(map).forEach((k) => { map[k] = fromCents(map[k]); });
    return map;
  }

  function totalAssets(data) {
    const balances = accountBalances(data);
    let assets = 0, debts = 0;
    data.accounts.forEach((a) => {
      if (!a.include) return;
      const amt = toCents(balances[a.id] || 0);
      if (ACCOUNT_TYPES[a.type] && ACCOUNT_TYPES[a.type].liability) {
        if (amt < 0) debts += amt;
        else assets += amt;
      } else {
        assets += amt;
      }
    });
    return {
      assets: fromCents(assets),
      debts: fromCents(debts),
      net: fromCents(assets + debts)
    };
  }

  function accountMonthFlow(data, accountId, monthKey) {
    let inflow = 0, outflow = 0;
    for (const t of data.transactions) {
      if (monthKeyOf(t.date) !== monthKey) continue;
      if (t.type === 'income' && t.accountId === accountId) inflow += toCents(t.amount);
      if (t.type === 'expense' && t.accountId === accountId) outflow += toCents(t.amount);
      if (t.type === 'transfer') {
        if (t.accountId === accountId) outflow += toCents(t.amount);
        if (t.toAccountId === accountId) inflow += toCents(t.amount);
      }
    }
    return { inflow: fromCents(inflow), outflow: fromCents(outflow) };
  }

  function inDateRange(date, from, to) {
    return (!from || date >= from) && (!to || date <= to);
  }

  function rangeTotals(data, bookId, from, to) {
    let expense = 0, income = 0, transfer = 0, count = 0;
    data.transactions.forEach((t) => {
      if (bookId && t.bookId !== bookId) return;
      if (!inDateRange(t.date, from, to)) return;
      count++;
      if (t.type === 'expense') expense += toCents(t.amount);
      else if (t.type === 'income') income += toCents(t.amount);
      else transfer += toCents(t.amount);
    });
    return {
      expense: fromCents(expense),
      income: fromCents(income),
      balance: fromCents(income - expense),
      transfer: fromCents(transfer),
      count
    };
  }

  function categoryBreakdownRange(data, bookId, from, to, type) {
    const cm = categoryMap(data);
    const totals = {};
    let sum = 0;
    data.transactions.forEach((t) => {
      if (bookId && t.bookId !== bookId) return;
      if (t.type !== type || !inDateRange(t.date, from, to)) return;
      const key = t.categoryId || 'unknown';
      const cents = toCents(t.amount);
      sum += cents;
      if (!totals[key]) totals[key] = { cents: 0, count: 0 };
      totals[key].cents += cents;
      totals[key].count++;
    });
    const list = Object.keys(totals).map((key) => {
      const c = cm[key] || { id: key, name: '未分类', icon: '🏷️', color: '#94a3b8' };
      return {
        id: key, name: c.name, icon: c.icon, color: c.color,
        value: fromCents(totals[key].cents), count: totals[key].count,
        pct: sum ? totals[key].cents / sum : 0
      };
    });
    list.sort((a, b) => b.value - a.value);
    return list;
  }

  function dailyRows(data, bookId, from, to) {
    const map = {};
    data.transactions.forEach((t) => {
      if (bookId && t.bookId !== bookId) return;
      if (!inDateRange(t.date, from, to)) return;
      if (!map[t.date]) map[t.date] = { date: t.date, expense: 0, income: 0, count: 0 };
      map[t.date].count++;
      if (t.type === 'expense') map[t.date].expense += toCents(t.amount);
      if (t.type === 'income') map[t.date].income += toCents(t.amount);
    });
    return Object.keys(map).sort().reverse().map((date) => {
      const x = map[date];
      return {
        date,
        expense: fromCents(x.expense),
        income: fromCents(x.income),
        balance: fromCents(x.income - x.expense),
        count: x.count
      };
    });
  }

  /** 某月每天结束时的净资产（只统计计入总资产的账户）。 */
  function assetSeries(data, monthKey) {
    const [year, month] = monthKey.split('-').map(Number);
    const dim = daysInMonth(year, month);
    const balances = {};
    data.accounts.forEach((a) => {
      if (a.include) balances[a.id] = toCents(a.initial); });
    const start = monthKey + '-01';

    function apply(t) {
      if (t.type === 'income' && balances[t.accountId] != null) balances[t.accountId] += toCents(t.amount);
      if (t.type === 'expense' && balances[t.accountId] != null) balances[t.accountId] -= toCents(t.amount);
      if (t.type === 'transfer') {
        if (balances[t.accountId] != null) balances[t.accountId] -= toCents(t.amount);
        if (t.toAccountId && balances[t.toAccountId] != null) balances[t.toAccountId] += toCents(t.amount);
      }
    }
    function sum() {
      return Object.keys(balances).reduce((acc, key) => acc + balances[key], 0);
    }

    data.transactions.forEach((t) => { if (t.date < start) apply(t); });
    const series = [];
    for (let d = 1; d <= dim; d++) {
      const date = monthKey + '-' + pad2(d);
      data.transactions.forEach((t) => { if (t.date === date) apply(t); });
      series.push({ day: d, value: fromCents(sum()) });
    }
    return series;
  }

  function yearRows(data, bookId, startYear, endYear) {
    const rows = [];
    for (let y = startYear; y <= endYear; y++) {
      const t = rangeTotals(data, bookId, y + '-01-01', y + '-12-31');
      rows.push({ year: y, income: t.income, expense: t.expense, balance: t.balance, count: t.count });
    }
    return rows;
  }

  function extendedRangeStats(data, bookId, from, to) {
    const out = {
      transfer: 0, repay: 0, receive: 0, payable: 0, receivable: 0, fee: 0,
      reimburse: 0, reimburseReceived: 0, reimbursePending: 0,
      refund: 0, refundIncome: 0, refundExpense: 0,
      discountExpense: 0, discountIncome: 0, months: 0
    };
    const months = {};
    let hasReimbursePending = false;
    data.transactions.forEach((t) => {
      if (t.bookId !== bookId || t.date < from || t.date > to) return;
      months[t.date.slice(0, 7)] = true;
      const amount = Number(t.amount) || 0;
      if (t.type === 'transfer') out.transfer += amount;
      if (t.type === 'income') out.receive += 0; // 当前数据模型没有独立收款字段
      out.refund += Number(t.refund) || 0;
      if (t.type === 'income') out.refundIncome += Number(t.refund) || 0;
      if (t.type === 'expense') out.refundExpense += Number(t.refund) || 0;
      if (t.type === 'expense') out.discountExpense += Number(t.discount) || 0;
      if (t.type === 'income') out.discountIncome += Number(t.discount) || 0;
      const reimburse = Number(t.reimburseAmount) || 0;
      if (reimburse > 0) {
        out.reimburse += reimburse;
        out.reimbursePending += reimburse;
        hasReimbursePending = true;
      }
    });
    out.reimburseReceived = 0;
    out.months = Object.keys(months).length;
    if (!hasReimbursePending) out.reimbursePending = 0;
    Object.keys(out).forEach((k) => { if (k !== 'months') out[k] = round2(out[k]); });
    return out;
  }

  /** 任意日期区间内每日净资产（含所有账户）。 */
  function assetSeriesRange(data, from, to) {
    const balances = {};
    data.accounts.forEach((a) => { if (a.include) balances[a.id] = toCents(a.initial); });
    function apply(t) {
      if (t.type === 'income' && balances[t.accountId] != null) balances[t.accountId] += toCents(t.amount);
      if (t.type === 'expense' && balances[t.accountId] != null) balances[t.accountId] -= toCents(t.amount);
      if (t.type === 'transfer') {
        if (balances[t.accountId] != null) balances[t.accountId] -= toCents(t.amount);
        if (t.toAccountId && balances[t.toAccountId] != null) balances[t.toAccountId] += toCents(t.amount);
      }
    }
    function sum() { return Object.keys(balances).reduce((acc, key) => acc + balances[key], 0); }
    data.transactions.forEach((t) => { if (t.date < from) apply(t); });
    const series = [];
    let date = from;
    let guard = 0;
    while (date <= to && guard++ < 5000) {
      data.transactions.forEach((t) => { if (t.date === date) apply(t); });
      series.push({ date, value: fromCents(sum()) });
      const d = parseISO(date);
      d.setDate(d.getDate() + 1);
      date = iso(d);
    }
    return series;
  }

  function monthDailySeries(data, bookId, monthKey, type) {
    const [year, month] = monthKey.split('-').map(Number);
    const dim = daysInMonth(year, month);
    const values = [];
    for (let d = 1; d <= dim; d++) {
      const day = monthKey + '-' + pad2(d);
      let expense = 0, income = 0;
      data.transactions.forEach((t) => {
        if (t.bookId !== bookId || t.date !== day) return;
        if (t.type === 'expense') expense += toCents(t.amount);
        if (t.type === 'income') income += toCents(t.amount);
      });
      values.push(type === 'expense' ? fromCents(expense) : type === 'income' ? fromCents(income) : fromCents(income - expense));
    }
    return values;
  }

  function yearMonths(data, bookId, year) {
    const out = [];
    for (let m = 1; m <= 12; m++) {
      const key = year + '-' + pad2(m);
      const t = monthTotals(data, bookId, key);
      out.push({ month: m, key, expense: t.expense, income: t.income, balance: t.balance, count: t.count });
    }
    return out;
  }

  function trendMonths(data, bookId, endMonthKey, n) {
    const out = [];
    for (let i = n - 1; i >= 0; i--) {
      const key = addMonthsKey(endMonthKey, -i);
      const t = monthTotals(data, bookId, key);
      out.push({ key, label: shortMonthLabel(key), expense: t.expense, income: t.income });
    }
    return out;
  }

  function budgetStatus(data, bookId, monthKey) {
    const book = data.books.find((b) => b.id === bookId) || activeBook(data);
    const budget = (book && book.budget) || { total: 0, categories: {} };
    const totals = monthTotals(data, bookId, monthKey);
    const total = Math.round(Number(budget.total) * 100) || 0;
    const spent = toCents(totals.expense);
    const categories = [];
    Object.keys(budget.categories || {}).forEach((catId) => {
      const amount = Math.round(Number(budget.categories[catId]) * 100) || 0;
      if (!amount) return;
      const cat = data.categories.find((c) => c.id === catId) || { id: catId, name: '未知分类', icon: '🏷️' };
      const used = data.transactions.reduce((s, t) => (
        t.bookId === bookId && t.type === 'expense' && t.categoryId === catId && monthKeyOf(t.date) === monthKey
          ? s + toCents(t.amount) : s
      ), 0);
      categories.push({
        id: catId, name: cat.name, icon: cat.icon,
        budget: fromCents(amount), spent: fromCents(used),
        percent: amount ? used / amount : 0,
        remain: fromCents(amount - used)
      });
    });
    return {
      total: fromCents(total),
      spent: totals.expense,
      remain: fromCents(total - spent),
      percent: total ? spent / total : 0,
      categories,
      hasBudget: total > 0 || categories.length > 0
    };
  }

  /* ------------------------------------------------------------------ *
   * 周期记账
   * ------------------------------------------------------------------ */

  const FREQ_CN = { daily: '每天', weekly: '每周', monthly: '每月', yearly: '每年' };

  function freqLabel(rule) {
    if (!rule) return '';
    if (rule.freq === 'daily') return '每天';
    if (rule.freq === 'weekly') return '每周' + WEEK_CN[weekdayIndex(rule.startDate)].replace('周', '');
    if (rule.freq === 'monthly') return '每月' + parseISO(rule.startDate).getDate() + '日';
    if (rule.freq === 'yearly') {
      const d = parseISO(rule.startDate);
      return '每年' + (d.getMonth() + 1) + '月' + d.getDate() + '日';
    }
    return '';
  }

  function dueDates(rule, today) {
    if (!rule || rule.enabled === false) return [];
    const end = today || todayISO();
    const startDay = rule.lastRun ? addDaysISO(rule.lastRun, 1) : rule.startDate;
    if (!startDay || startDay > end) return [];
    const out = [];
    const startD = parseISO(startDay);
    const endD = parseISO(end);
    if (rule.freq === 'daily' || rule.freq === 'weekly') {
      const targetWeekday = weekdayIndex(rule.startDate);
      const cursor = new Date(startD);
      let guard = 0;
      while (cursor <= endD && guard++ < 500) {
        if (rule.freq === 'daily' || cursor.getDay() === targetWeekday) out.push(iso(cursor));
        cursor.setDate(cursor.getDate() + 1);
        if (out.length >= 100) break;
      }
    } else if (rule.freq === 'monthly') {
      const day = parseISO(rule.startDate).getDate();
      let y = startD.getFullYear(), m = startD.getMonth();
      let guard = 0;
      while (guard++ < 240) {
        const dim = new Date(y, m + 1, 0).getDate();
        const occ = new Date(y, m, Math.min(day, dim), 12);
        if (occ > endD) break;
        if (iso(occ) >= startDay) out.push(iso(occ));
        m++;
        if (m > 11) { m = 0; y++; }
      }
    } else if (rule.freq === 'yearly') {
      const d = parseISO(rule.startDate);
      const m = d.getMonth(), day = d.getDate();
      let y = startD.getFullYear();
      let guard = 0;
      while (guard++ < 60) {
        const dim = new Date(y, m + 1, 0).getDate();
        const occ = new Date(y, m, Math.min(day, dim), 12);
        if (occ > endD) break;
        if (iso(occ) >= startDay) out.push(iso(occ));
        y++;
      }
    }
    return out.slice(0, 100);
  }

  function applyRecurring(data, today) {
    const end = today || todayISO();
    let created = 0;
    (data.recurring || []).forEach((rule) => {
      if (!rule.enabled) return;
      const dates = dueDates(rule, end);
      if (!dates.length) return;
      dates.forEach((day) => {
        data.transactions.push({
          id: uid('t'), bookId: rule.bookId, type: rule.type,
          amount: round2(rule.amount), categoryId: rule.categoryId,
          accountId: rule.accountId, toAccountId: null,
          date: day, time: '09:00', note: rule.note || '',
          tags: [], recurringId: rule.id,
          createdAt: new Date().toISOString(), updatedAt: null
        });
        created++;
      });
      rule.lastRun = dates[dates.length - 1];
    });
    if (created) {
      data.transactions.sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
    }
    return created;
  }

  /* ------------------------------------------------------------------ *
   * 导入 / 导出
   * ------------------------------------------------------------------ */

  function csvCell(v) {
    const s = v == null ? '' : String(v);
    return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }

  function plainMoney(n) {
    return (Math.round((Number(n) || 0) * 100) / 100).toFixed(2);
  }

  function parseImportNumber(value) {
    if (typeof value === 'number') return isFinite(value) ? value : 0;
    const text = String(value == null ? '' : value).replace(/[¥￥$€£\s,，]/g, '');
    if (!text) return 0;
    const n = Number(text);
    return isFinite(n) ? n : 0;
  }

  function normalizeBillDate(value) {
    if (typeof value === 'number' && value > 0) {
      const whole = Math.floor(value);
      const frac = value - whole;
      const ms = Math.round((whole - 25569) * 86400 * 1000 + Math.round(frac * 86400) * 1000);
      const d = new Date(ms);
      if (!isNaN(d.getTime())) {
        return {
          date: d.getUTCFullYear() + '-' + pad2(d.getUTCMonth() + 1) + '-' + pad2(d.getUTCDate()),
          time: pad2(d.getUTCHours()) + ':' + pad2(d.getUTCMinutes())
        };
      }
    }
    let text = String(value == null ? '' : value).trim();
    if (!text) return null;
    text = text.replace(/[年月]/g, '-').replace(/日/g, '').replace(/[./]/g, '-');
    const m = /^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2}))?/.exec(text);
    if (!m) return null;
    const month = Number(m[2]);
    const day = Number(m[3]);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return {
      date: m[1] + '-' + pad2(month) + '-' + pad2(day),
      time: m[4] != null ? pad2(Number(m[4])) + ':' + pad2(Number(m[5] || 0)) : ''
    };
  }

  function splitTags(value) {
    return String(value == null ? '' : value)
      .split(/[,，、;；\s]+/)
      .map((x) => x.trim())
      .filter(Boolean)
      .slice(0, 12);
  }

  function currencyInfo(value) {
    const text = String(value == null ? '' : value).trim();
    if (!text) return { currency: '', foreignAmount: 0 };
    const m = /^([A-Za-z]{2,6})\s*([\d.,]+)?$/.exec(text);
    if (m) return { currency: m[1].toUpperCase(), foreignAmount: Math.abs(parseImportNumber(m[2] || 0)) };
    return { currency: text.slice(0, 12), foreignAmount: 0 };
  }

  /** 导出用的整表：表头 + 每行值（金额类为数字，其余为字符串）。 */
  function billRows(data, bookId) {
    const books = {};
    data.books.forEach((b) => { books[b.id] = b; });
    const cats = categoryMap(data);
    const accs = accountMap(data);
    const list = sortTransactions(data.transactions.filter((t) => !bookId || t.bookId === bookId)).reverse();
    const rows = list.map((t) => {
      const cat = cats[t.categoryId];
      const from = accs[t.accountId];
      const to = accs[t.toAccountId];
      const currency = t.currency
        ? (t.foreignAmount ? t.currency + ' ' + plainMoney(t.foreignAmount) : t.currency)
        : '';
      const attachments = (t.attachments || []).slice(0, 5);
      const row = [
        t.date,
        TYPE_CN[t.type] || t.type,
        round2(t.amount),
        t.type === 'transfer' ? '' : (cat ? cat.name : '未分类'),
        t.type === 'transfer' ? '' : (t.subcategory || ''),
        t.type === 'transfer'
          ? ((from ? from.name : '') + ' → ' + (to ? to.name : ''))
          : (from ? from.name : ''),
        books[t.bookId] ? books[t.bookId].name : '',
        t.refund ? round2(t.refund) : '',
        t.discount ? round2(t.discount) : '',
        t.note || '',
        (t.tags || []).join('、'),
        t.reimburseAccount || '',
        t.reimburseAmount ? round2(t.reimburseAmount) : '',
        t.reimburseNote || '',
        currency,
        t.location || '',
        t.creator || '',
        t.extra || ''
      ];
      for (let i = 0; i < 5; i++) row.push(attachments[i] ? attachments[i].name : '');
      return row;
    });
    return { headers: BILL_HEADERS.slice(), rows };
  }

  function toCSV(data, bookId) {
    const table = billRows(data, bookId);
    const lines = [table.headers.map(csvCell).join(',')];
    table.rows.forEach((row) => {
      lines.push(row.map((value, i) => {
        if (BILL_NUMERIC.indexOf(table.headers[i]) >= 0) {
          return csvCell(value === '' ? '' : plainMoney(value));
        }
        return csvCell(value);
      }).join(','));
    });
    return '\ufeff' + lines.join('\r\n');
  }

  function parseCSV(text) {
    const src = String(text == null ? '' : text).replace(/^\ufeff/, '');
    const rows = [];
    let row = [];
    let cell = '';
    let quoted = false;
    for (let i = 0; i < src.length; i++) {
      const ch = src[i];
      if (quoted) {
        if (ch === '"') {
          if (src[i + 1] === '"') { cell += '"'; i++; }
          else quoted = false;
        } else cell += ch;
      } else if (ch === '"') {
        quoted = true;
      } else if (ch === ',') {
        row.push(cell); cell = '';
      } else if (ch === '\n' || ch === '\r') {
        if (ch === '\r' && src[i + 1] === '\n') i++;
        row.push(cell); cell = '';
        if (row.some((c) => String(c).trim() !== '')) rows.push(row);
        row = [];
      } else {
        cell += ch;
      }
    }
    if (cell !== '' || row.length) {
      row.push(cell);
      if (row.some((c) => String(c).trim() !== '')) rows.push(row);
    }
    return rows;
  }

  /**
   * 把 Excel / CSV 行合并进现有数据。
   * rows[0] 为表头；支持新表头，以及旧版「日期/时间/类型/分类...」表头。
   */
  function importBillRows(data, rows, options) {
    const opts = options || {};
    const result = { imported: 0, skipped: 0, books: 0, categories: 0, accounts: 0, error: '' };
    if (!Array.isArray(rows) || rows.length < 2) {
      result.error = '没有可导入的数据行';
      return result;
    }
    const headers = rows[0].map((h) => String(h == null ? '' : h).trim());
    const index = {};
    headers.forEach((h, i) => { if (h && index[h] == null) index[h] = i; });
    const col = function () {
      for (let i = 0; i < arguments.length; i++) {
        if (index[arguments[i]] != null) return index[arguments[i]];
      }
      return -1;
    };
    const dateCol = col('日期');
    const amountCol = col('金额');
    const typeCol = col('收支类型', '类型');
    const timeCol = col('时间');
    if (dateCol < 0 || amountCol < 0) {
      result.error = '缺少「日期」或「金额」列';
      return result;
    }
    const get = (row, name) => (index[name] != null ? row[index[name]] : '');
    const bookByName = {};
    data.books.forEach((b) => { bookByName[b.name] = b.id; });
    const catByKey = {};
    data.categories.forEach((c) => { catByKey[c.type + '|' + c.name] = c.id; });
    const accByName = {};
    data.accounts.forEach((a) => {
      accByName[a.name] = a.id; });

    function ensureBook(name) {
      const text = String(name == null ? '' : name).trim();
      if (!text) return data.activeBookId;
      if (bookByName[text]) return bookByName[text];
      const book = {
        id: uid('b'), name: text, icon: '📒', color: '#0e9f6e',
        budget: { total: 0, categories: {} }, createdAt: new Date().toISOString()
      };
      data.books.push(book);
      bookByName[text] = book.id;
      result.books++;
      return book.id;
    }

    function ensureCategory(name, type) {
      const text = String(name == null ? '' : name).trim();
      if (!text) return null;
      const key = type + '|' + text;
      if (catByKey[key]) return catByKey[key];
      const orders = data.categories.filter((c) => c.type === type).map((c) => c.order || 0);
      const cat = {
        id: uid('c'), name: text, icon: '🏷️', color: '#94a3b8', type: type,
        order: Math.max.apply(null, orders.concat([0])) + 1, builtin: false
      };
      data.categories.push(cat);
      catByKey[key] = cat.id;
      result.categories++;
      return cat.id;
    }

    function ensureAccount(name) {
      const text = String(name == null ? '' : name).trim();
      if (!text) return data.accounts[0] ? data.accounts[0].id : null;
      if (accByName[text]) return accByName[text];
      const acc = {
        id: uid('a'), name: text, type: 'other', icon: '👛', color: '#94a3b8',
        initial: 0, include: true
      };
      data.accounts.push(acc);
      accByName[text] = acc.id;
      result.accounts++;
      return acc.id;
    }

    const existing = new Set();
    function dedupeKey(t) {
      return [t.date, t.type, round2(t.amount), t.categoryId || '', t.accountId || '', t.toAccountId || '', t.note || ''].join('|');
    }
    data.transactions.forEach((t) => existing.add(dedupeKey(t)));

    for (let r = 1; r < rows.length; r++) {
      const row = rows[r];
      if (!row || !row.some((c) => String(c == null ? '' : c).trim() !== '')) continue;
      const dateInfo = normalizeBillDate(row[dateCol]);
      const amount = Math.abs(parseImportNumber(row[amountCol]));
      if (!dateInfo || !(amount > 0)) { result.skipped++; continue; }

      const typeText = typeCol >= 0 ? String(row[typeCol] || '') : '';
      let type = 'expense';
      if (typeText.indexOf('收入') >= 0) type = 'income';
      else if (typeText.indexOf('转账') >= 0 || typeText.indexOf('轉賬') >= 0) type = 'transfer';

      const bookId = ensureBook(get(row, '账本'));
      const categoryName = get(row, '类别') || get(row, '分类');
      const subcategory = String(get(row, '二级分类') || '').slice(0, 20);
      const tagCandidates = (data.tags || []).concat(
        (data.categories || []).map((c) => c.name),
        BUILTIN_TAGS
      );
      const tags = Array.from(new Set(splitTags(get(row, '标签'))
        .map((tag) => canonicalTag(tag, tagCandidates))
        .filter(Boolean)));
      let categoryId = null;
      let accountId = null;
      let toAccountId = null;

      if (type === 'transfer') {
        const rawAccount = String(get(row, '账户') || '').trim();
        const parts = rawAccount.split(/\s*(?:→|->|=>)\s*/).filter(Boolean);
        if (parts.length >= 2) {
          accountId = ensureAccount(parts[0]);
          toAccountId = ensureAccount(parts[1]);
        } else {
          accountId = ensureAccount(parts[0] || '');
          toAccountId = ensureAccount(get(row, '转入账户'));
        }
        if (!accountId || !toAccountId || accountId === toAccountId) { result.skipped++; continue; }
      } else {
        categoryId = ensureCategory(categoryName, type);
        accountId = ensureAccount(get(row, '账户'));
      }

      const cur = currencyInfo(get(row, '多币种'));
      const attachments = [];
      for (let a = 1; a <= 5; a++) {
        const name = String(get(row, '附件' + a) || '').trim();
        if (name) attachments.push({ name: name.slice(0, 120), dataUrl: null, type: '' });
      }
      const tx = {
        id: uid('t'), bookId, type,
        amount: round2(amount),
        categoryId, accountId, toAccountId,
        date: dateInfo.date,
        time: dateInfo.time || (timeCol >= 0 ? String(row[timeCol] || '').slice(0, 5) : '') || '12:00',
        note: String(get(row, '备注') || ''),
        tags,
        subcategory: type === 'transfer' ? '' : subcategory,
        refund: Math.max(0, round2(parseImportNumber(get(row, '退款')))),
        discount: Math.max(0, round2(parseImportNumber(get(row, '优惠')))),
        reimburseAccount: String(get(row, '报销账户') || ''),
        reimburseAmount: Math.max(0, round2(parseImportNumber(get(row, '报销金额')))),
        reimburseNote: String(get(row, '报销明细') || ''),
        currency: cur.currency,
        foreignAmount: cur.foreignAmount,
        location: String(get(row, '地址') || ''),
        creator: String(get(row, '创建用户') || ''),
        extra: String(get(row, '其他') || ''),
        attachments,
        recurringId: null,
        createdAt: new Date().toISOString(),
        updatedAt: null
      };
      const key = dedupeKey(tx);
      if (opts.dedupe !== false && existing.has(key)) { result.skipped++; continue; }
      existing.add(key);
      data.transactions.push(tx);
      tags.forEach((tag) => { if (data.tags.indexOf(tag) < 0) data.tags.push(tag); });
      result.imported++;
    }

    if (result.imported) data.transactions.sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
    return result;
  }

  function exportPayload(data) {
    return {
      app: '星空记账 · 本地版',
      version: VERSION,
      exportedAt: new Date().toISOString(),
      data: JSON.parse(JSON.stringify(data))
    };
  }

  /* ------------------------------------------------------------------ *
   * 其它统计
   * ------------------------------------------------------------------ */

  function overallStats(data) {
    const days = new Set();
    data.transactions.forEach((t) => days.add(t.date));
    const sorted = Array.from(days).sort();
    let streak = 0;
    let cursor = todayISO();
    if (!days.has(cursor)) cursor = addDaysISO(cursor, -1);
    while (days.has(cursor)) {
      streak++;
      cursor = addDaysISO(cursor, -1);
    }
    return {
      count: data.transactions.length,
      days: days.size,
      streak,
      books: data.books.length,
      categories: data.categories.length,
      firstDate: sorted[0] || null,
      lastDate: sorted[sorted.length - 1] || null
    };
  }

  function recentTags(data, limit) {
    const counts = {};
    data.transactions.forEach((t) => (t.tags || []).forEach((tag) => {
      counts[tag] = (counts[tag] || 0) + 1;
    }));
    return Object.keys(counts).sort((a, b) => counts[b] - counts[a]).slice(0, limit || 12);
  }

  const BUILTIN_TAGS = ['餐饮', '交通', '购物', '居住', '娱乐', '医疗', '学习', '通讯', '人情', '旅行', '宠物', '运动', '工资', '理财', '兼职', '红包', '报销', '固定支出', '日常'];

  function tagKey(value) {
    return String(value || '').replace(/\s+/g, '').replace(/[，,、#·.\-_/\\()（）]/g, '').toLowerCase();
  }

  function tagDice(a, b) {
    if (a === b) return 1;
    if (a.length < 2 || b.length < 2) return 0;
    const grams = (s) => {
      const arr = [];
      for (let i = 0; i < s.length - 1; i++) arr.push(s.slice(i, i + 2));
      return arr;
    };
    const ga = grams(a), gb = grams(b);
    const map = {};
    ga.forEach((g) => { map[g] = (map[g] || 0) + 1; });
    let hit = 0;
    gb.forEach((g) => { if (map[g]) { hit++; map[g]--; } });
    return (2 * hit) / (ga.length + gb.length);
  }

  /** 将导入标签归到最相近的内置/已有标签；匹配不可靠时保留原标签。 */
  function canonicalTag(raw, candidates) {
    const original = normalizeTag(raw);
    const a = tagKey(original);
    if (!a) return '';
    const list = [];
    const seen = {};
    (candidates || []).forEach((value) => {
      const originalValue = String(value || '').trim();
      const b = tagKey(originalValue);
      if (!b || seen[b]) return;
      seen[b] = true;
      list.push({ original: originalValue, key: b });
    });
    let best = null;
    let bestScore = 0;
    list.forEach((item) => {
      const b = item.key;
      let score = 0;
      if (a === b) score = 1;
      else if (b.length >= 2 && a.indexOf(b) >= 0) {
        score = 0.86 + 0.12 * Math.min(b.length / a.length, 1);
      } else if (a.length >= 2 && b.indexOf(a) >= 0) {
        score = 0.82 + 0.1 * Math.min(a.length / b.length, 1);
      } else {
        const dice = tagDice(a, b);
        if (dice >= 0.66) score = dice * 0.9;
      }
      if (score > bestScore) { bestScore = score; best = item.original; }
    });
    if (best && bestScore >= 0.72) return normalizeTag(best);
    return original;
  }

  function normalizeTag(tag) {
    return String(tag || '').trim().replace(/[#,，、]/g, '').slice(0, 12);
  }

  return {
    VERSION,
    WEEK_CN,
    TYPE_CN,
    BILL_HEADERS,
    BILL_NUMERIC,
    FREQ_CN,
    ACCOUNT_TYPES,
    uid,
    iso,
    parseISO,
    todayISO,
    thisMonthKey,
    monthKeyOf,
    daysInMonth,
    monthStart,
    monthEnd,
    addDaysISO,
    addMonthsKey,
    weekdayIndex,
    weekdayCN,
    monthLabel,
    shortMonthLabel,
    dateLabel,
    fullDateLabel,
    relativeDay,
    monthDays,
    monthsBetween,
    calendarLabel,
    chineseLunarDay,
    toCents,
    fromCents,
    round2,
    money,
    amountParts,
    parseAmountExpr,
    makeCategories,
    createDefaultData,
    seedDemoData,
    migrateData,
    validateBackup,
    categoryMap,
    accountMap,
    activeBook,
    categoriesOf,
    sortTransactions,
    bookTransactions,
    filterTransactions,
    monthTotals,
    rangeTotals,
    categoryBreakdownRange,
    dailyRows,
    assetSeries,
    assetSeriesRange,
    yearRows,
    extendedRangeStats,
    monthDailySeries,
    yearMonths,
    dayTotals,
    categoryBreakdown,
    accountBalances,
    totalAssets,
    accountMonthFlow,
    trendMonths,
    budgetStatus,
    freqLabel,
    dueDates,
    applyRecurring,
    csvCell,
    toCSV,
    billRows,
    parseCSV,
    importBillRows,
    normalizeBillDate,
    parseImportNumber,
    exportPayload,
    overallStats,
    recentTags,
    normalizeTag,
    canonicalTag,
    BUILTIN_TAGS
  };
});
