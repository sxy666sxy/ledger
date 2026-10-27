import 'models.dart';
import 'utils.dart';

/// A parsed quick-entry sentence, e.g. "早餐十二块 支付宝".
class QuickParseResult {
  const QuickParseResult({
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.toAccountId,
    required this.date,
    required this.note,
  });

  final double amount;
  final TxnType type;
  final String categoryId;
  final String accountId;
  final String toAccountId;
  final String date;
  final String note;

  bool get valid => amount > 0;
}

/// Turns a natural-language sentence into bookkeeping fields.
///
/// This intentionally stays rule-based and offline: the app must keep working
/// without any cloud service. It understands Arabic amounts ("12元"), common
/// Chinese amounts ("十二块"), income/transfer words, account names and the
/// most common expense categories.
QuickParseResult parseQuickEntry(
  String raw, {
  required List<Category> categories,
  required List<Account> accounts,
  DateTime? now,
}) {
  final text = raw.trim();
  final at = now ?? DateTime.now();
  final matchedAccounts = _matchedAccounts(text, accounts);
  final transfer = _looksLikeTransfer(text) && matchedAccounts.length >= 2;
  final type = transfer
      ? TxnType.transfer
      : (_looksLikeIncome(text) ? TxnType.income : TxnType.expense);
  final amount = _extractAmount(text) ?? 0;
  final category = transfer ? null : _pickCategory(text, type, categories);
  final account = matchedAccounts.isNotEmpty
      ? matchedAccounts.first
      : (accounts.isNotEmpty ? accounts.first : null);
  final toAccount = transfer
      ? (matchedAccounts.length > 1
          ? matchedAccounts[1]
          : (accounts.length > 1 ? accounts[1] : null))
      : null;
  return QuickParseResult(
    amount: amount,
    type: type,
    categoryId: category?.id ?? '',
    accountId: account?.id ?? '',
    toAccountId: toAccount?.id ?? '',
    date: _dateFor(text, at),
    note: text,
  );
}

String _dateFor(String text, DateTime now) {
  if (text.contains('前天')) {
    return dateKey(now.subtract(const Duration(days: 2)));
  }
  if (text.contains('昨天')) {
    return dateKey(now.subtract(const Duration(days: 1)));
  }
  if (text.contains('明天')) {
    return dateKey(now.add(const Duration(days: 1)));
  }
  final explicit = RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?')
      .firstMatch(text);
  if (explicit != null) {
    final month = int.tryParse(explicit.group(1)!);
    final day = int.tryParse(explicit.group(2)!);
    if (month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return dateKey(DateTime(now.year, month, day));
    }
  }
  return dateKey(now);
}

bool _looksLikeTransfer(String text) =>
    RegExp(r'转账|转到|转给|转至|转入|转出|还信用卡').hasMatch(text);

bool _looksLikeIncome(String text) =>
    RegExp(r'收入|工资|薪水|薪资|奖金|提成|红包|收到|收款|进账|利息|分红|理财|退款|报销|返现|赚了|外快|兼职|副业')
        .hasMatch(text);

List<Account> _matchedAccounts(String text, List<Account> accounts) {
  final hits = <({int index, Account account})>[];
  for (final a in accounts) {
    final name = a.name.trim();
    if (name.isEmpty) continue;
    final index = text.indexOf(name);
    if (index >= 0) hits.add((index: index, account: a));
  }
  hits.sort((a, b) => a.index.compareTo(b.index));
  return [for (final h in hits) h.account];
}

Category? _pickCategory(String text, TxnType type, List<Category> categories) {
  final list = categories.where((c) => c.type == type).toList()
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  if (list.isEmpty) return null;

  // Direct category-name mention wins.
  for (final c in list) {
    if (c.name.isNotEmpty && text.contains(c.name)) return c;
  }
  // Then common synonyms.
  for (final hint in _categoryHints.entries) {
    if (!hint.value.any(text.contains)) continue;
    for (final c in list) {
      if (c.name.contains(hint.key)) return c;
    }
  }
  for (final c in list) {
    if (c.name.contains('其他')) return c;
  }
  return list.first;
}

const Map<String, List<String>> _categoryHints = {
  '餐饮': [
    '早餐', '午餐', '晚餐', '夜宵', '外卖', '吃饭', '餐饮', '咖啡', '奶茶', '饮料',
    '零食', '水果', '餐厅', '饭店', '火锅', '烧烤', '面包', '蛋糕', '快餐', '食堂',
    '可乐', '啤酒', '喝酒', '买菜', '菜市场',
  ],
  '交通': [
    '打车', '出租', '滴滴', '地铁', '公交', '加油', '停车', '高铁', '火车', '飞机',
    '机票', '车费', '过路费', '共享单车', '骑车', '船票',
  ],
  '购物': [
    '淘宝', '京东', '拼多多', '购物', '超市', '商场', '衣服', '鞋', '化妆品',
    '日用品', '买单', '网购', '快递',
  ],
  '居住': [
    '房租', '水费', '电费', '燃气', '物业', '家居', '家具', '维修', '装修', '房贷',
    '租金',
  ],
  '娱乐': [
    '电影', '游戏', 'ktv', 'KTV', '娱乐', '会员', '视频', '演出', '旅游', '门票',
    '健身', '唱歌',
  ],
  '医疗': [
    '医院', '看病', '挂号', '药', '体检', '医疗', '诊所', '牙医', '疫苗', '门诊',
  ],
  '学习': [
    '书', '课程', '学费', '培训', '学习', '教育', '考试', '文具', '教材', '报名',
  ],
  '通讯': ['话费', '流量', '宽带', '手机费', '充话费', '电话费'],
  '宠物': ['猫粮', '狗粮', '宠物', '猫', '狗', '铲屎', '疫苗'],
  '人情': ['礼物', '送礼', '请客', '人情', '份子钱', '红包', '孝敬'],
  '工作': ['工作', '办公', '加班', '差旅', '打印', '名片'],
  '借出': ['借出', '借给', '借钱'],
  '工资': ['工资', '薪水', '薪资', '发薪', '月薪'],
  '奖金': ['奖金', '提成', '年终奖', '绩效'],
  '理财': ['利息', '分红', '理财', '收益', '基金', '股票'],
  '兼职': ['兼职', '外快', '副业', '稿费'],
  '退款': ['退款', '退货', '返现'],
  '报销': ['报销'],
};

double? _extractAmount(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'\d{4}\s*[-/.年]\s*\d{1,2}\s*[-/.月]\s*\d{1,2}\s*[日号]?'), ' ')
      .replaceAll(RegExp(r'\d{1,2}\s*月\s*\d{1,2}\s*[日号]?'), ' ')
      .replaceAll(RegExp(r'\d{1,2}\s*[:：]\s*\d{2}'), ' ');

  final marked = <({int index, double value})>[];
  final patterns = <RegExp>[
    RegExp(r'[¥￥]\s*(\d+(?:\.\d{1,2})?)'),
    RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:元|块|圆|rmb|RMB|人民币)'),
  ];
  for (final p in patterns) {
    for (final m in p.allMatches(cleaned)) {
      final value = double.tryParse(m.group(1)!);
      if (value != null) marked.add((index: m.start, value: value));
    }
  }
  final chinese = RegExp(r'([零〇一二两三四五六七八九十百千万点]+)\s*(?:元|块|圆)')
      .allMatches(cleaned);
  for (final m in chinese) {
    final value = _parseChineseNumber(m.group(1)!);
    if (value != null) marked.add((index: m.start, value: value));
  }
  if (marked.isNotEmpty) {
    marked.sort((a, b) => a.index.compareTo(b.index));
    return marked.last.value;
  }

  final bare = RegExp(r'\d+(?:\.\d{1,2})?').allMatches(cleaned).toList();
  if (bare.isEmpty) return null;
  return double.tryParse(bare.last.group(0)!);
}

double? _parseChineseNumber(String source) {
  final text = source.trim();
  if (text.isEmpty) return null;
  final point = text.indexOf('点');
  final integerPart = point >= 0 ? text.substring(0, point) : text;
  const digits = <String, int>{
    '零': 0, '〇': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
  };
  const units = <String, int>{'十': 10, '百': 100, '千': 1000};
  var total = 0;
  var section = 0;
  var number = 0;
  for (final ch in integerPart.split('')) {
    if (digits.containsKey(ch)) {
      number = digits[ch]!;
    } else if (units.containsKey(ch)) {
      section += (number == 0 ? 1 : number) * units[ch]!;
      number = 0;
    } else if (ch == '万') {
      section += number;
      total += section * 10000;
      section = 0;
      number = 0;
    } else if (ch == '亿') {
      section += number;
      total = (total + section) * 100000000;
      section = 0;
      number = 0;
    } else {
      return null;
    }
  }
  var value = (total + section + number).toDouble();
  if (point >= 0) {
    final decimals = text.substring(point + 1);
    var scale = 0.1;
    for (final ch in decimals.split('')) {
      final d = digits[ch];
      if (d == null) return null;
      value += d * scale;
      scale /= 10;
    }
  }
  return value;
}
