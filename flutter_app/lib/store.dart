import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'utils.dart';

class MoneyTotals {
  const MoneyTotals({this.expense = 0, this.income = 0});
  final double expense;
  final double income;
  double get balance => income - expense;
}

class CategoryTotal {
  const CategoryTotal({required this.category, required this.value, required this.count});
  final Category category;
  final double value;
  final int count;
}

class AppStore extends ChangeNotifier {
  AppStore._();

  static final AppStore instance = AppStore._();
  static const String _storageKey = 'xingkong.flutter.v1';

  late SharedPreferences _prefs;
  bool loaded = false;
  List<Book> books = [];
  String activeBookId = 'b_main';
  List<Category> categories = [];
  List<Account> accounts = [];
  List<Txn> transactions = [];
  String themeId = 'system';
  String customImagePath = '';
  String cardStyle = 'orbit';
  double billCardAlpha = 1.0;
  bool showLunar = true;
  List<RecurringRule> recurringRules = [];
  String pinHash = '';
  bool locked = false;

  Book get activeBook {
    for (final book in books) {
      if (book.id == activeBookId) return book;
    }
    if (books.isNotEmpty) return books.first;
    final fallback = Book(id: 'b_main', name: '日常账本');
    books = [fallback];
    activeBookId = fallback.id;
    return fallback;
  }

  List<Category> categoriesFor(TxnType type) {
    final list = categories.where((c) => c.type == type).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  List<Account> get bookkeepingAccounts =>
      accounts.where((a) => a.bookkeeping).toList();

  Category? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Account? accountById(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<Txn> get activeTransactions =>
      transactions.where((t) => t.bookId == activeBookId).toList()
        ..sort(_sortTxn);

  int _sortTxn(Txn a, Txn b) {
    final d = b.date.compareTo(a.date);
    if (d != 0) return d;
    final t = b.time.compareTo(a.time);
    if (t != 0) return t;
    return b.createdAt.compareTo(a.createdAt);
  }

  List<Txn> txnsForMonth(DateTime month) {
    final prefix = monthKey(month);
    final list = transactions
        .where((t) => t.bookId == activeBookId && t.date.startsWith(prefix))
        .toList()
      ..sort(_sortTxn);
    return list;
  }

  List<Txn> txnsForDate(String date) {
    final list = transactions
        .where((t) => t.bookId == activeBookId && t.date == date)
        .toList()
      ..sort(_sortTxn);
    return list;
  }

  MoneyTotals totalsForMonth(DateTime month) {
    double expense = 0;
    double income = 0;
    for (final t in txnsForMonth(month)) {
      if (t.type == TxnType.expense) {
        expense += t.amount;
      } else if (t.type == TxnType.income) {
        income += t.amount;
      }
    }
    return MoneyTotals(expense: expense, income: income);
  }

  double accountBalance(Account account) {
    double value = account.initial;
    for (final t in transactions) {
      if (t.type == TxnType.transfer) {
        if (t.accountId == account.id) value -= t.amount;
        if (t.toAccountId == account.id) value += t.amount;
        continue;
      }
      if (t.accountId != account.id) continue;
      if (t.type == TxnType.expense) {
        value -= t.amount;
      } else {
        value += t.amount;
      }
    }
    return value;
  }

  double accountBalanceAt(Account account, DateTime end) {
    final endKey = dateKey(end);
    double value = account.initial;
    for (final t in transactions) {
      if (t.date.compareTo(endKey) > 0) continue;
      if (t.type == TxnType.transfer) {
        if (t.accountId == account.id) value -= t.amount;
        if (t.toAccountId == account.id) value += t.amount;
        continue;
      }
      if (t.accountId != account.id) continue;
      if (t.type == TxnType.expense) {
        value -= t.amount;
      } else {
        value += t.amount;
      }
    }
    return value;
  }

  double get netAssets {
    double value = 0;
    for (final a in accounts) {
      if (a.include) value += accountBalance(a);
    }
    return value;
  }

  Map<String, double> dailyExpense(DateTime month) {
    final result = <String, double>{};
    for (final t in txnsForMonth(month)) {
      if (t.type != TxnType.expense) continue;
      result[t.date] = (result[t.date] ?? 0) + t.amount;
    }
    return result;
  }

  Map<String, double> dailyIncome(DateTime month) {
    final result = <String, double>{};
    for (final t in txnsForMonth(month)) {
      if (t.type != TxnType.income) continue;
      result[t.date] = (result[t.date] ?? 0) + t.amount;
    }
    return result;
  }

  List<Txn> txnsBetween(DateTime start, DateTime end) {
    final from = dateKey(start);
    final to = dateKey(end);
    final list = transactions
        .where((t) =>
            t.bookId == activeBookId &&
            t.date.compareTo(from) >= 0 &&
            t.date.compareTo(to) <= 0)
        .toList()
      ..sort(_sortTxn);
    return list;
  }

  MoneyTotals totalsForRangeDay(DateTime day) => totalsBetween(day, day);

  MoneyTotals totalsBetween(DateTime start, DateTime end) {
    double expense = 0;
    double income = 0;
    for (final t in txnsBetween(start, end)) {
      if (t.type == TxnType.expense) {
        expense += t.amount;
      } else if (t.type == TxnType.income) {
        income += t.amount;
      }
    }
    return MoneyTotals(expense: expense, income: income);
  }

  List<CategoryTotal> categoryTotalsBetween(DateTime start, DateTime end, TxnType type) {
    final map = <String, CategoryTotal>{};
    for (final t in txnsBetween(start, end)) {
      if (t.type != type) continue;
      final category = categoryById(t.categoryId) ??
          Category(id: t.categoryId, name: '未分类', type: type);
      final old = map[category.id];
      map[category.id] = CategoryTotal(
        category: category,
        value: (old?.value ?? 0) + t.amount,
        count: (old?.count ?? 0) + 1,
      );
    }
    final list = map.values.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<Txn> txnsForYear(int year) {
    final prefix = '$year-';
    final list = transactions
        .where((t) => t.bookId == activeBookId && t.date.startsWith(prefix))
        .toList()
      ..sort(_sortTxn);
    return list;
  }

  MoneyTotals totalsForYear(int year) {
    double expense = 0;
    double income = 0;
    for (final t in txnsForYear(year)) {
      if (t.type == TxnType.expense) {
        expense += t.amount;
      } else if (t.type == TxnType.income) {
        income += t.amount;
      }
    }
    return MoneyTotals(expense: expense, income: income);
  }

  MoneyTotals get allYearsTotals {
    double expense = 0;
    double income = 0;
    for (final t in transactions.where((t) => t.bookId == activeBookId)) {
      if (t.type == TxnType.expense) {
        expense += t.amount;
      } else if (t.type == TxnType.income) {
        income += t.amount;
      }
    }
    return MoneyTotals(expense: expense, income: income);
  }

  List<MoneyTotals> monthlyTotalsForYear(int year) {
    final rows = List<MoneyTotals>.generate(12, (_) => const MoneyTotals());
    final expense = List<double>.filled(12, 0);
    final income = List<double>.filled(12, 0);
    for (final t in txnsForYear(year)) {
      final month = int.tryParse(t.date.substring(5, 7));
      if (month == null || month < 1 || month > 12) continue;
      if (t.type == TxnType.expense) {
        expense[month - 1] += t.amount;
      } else if (t.type == TxnType.income) {
        income[month - 1] += t.amount;
      }
    }
    for (var i = 0; i < 12; i++) {
      rows[i] = MoneyTotals(expense: expense[i], income: income[i]);
    }
    return rows;
  }

  List<CategoryTotal> categoryTotalsForYear(int year, TxnType type) {
    final map = <String, CategoryTotal>{};
    for (final t in txnsForYear(year)) {
      if (t.type != type) continue;
      final category = categoryById(t.categoryId) ??
          Category(id: t.categoryId, name: '未分类', type: type);
      final old = map[category.id];
      map[category.id] = CategoryTotal(
        category: category,
        value: (old?.value ?? 0) + t.amount,
        count: (old?.count ?? 0) + 1,
      );
    }
    final list = map.values.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<CategoryTotal> categoryTotalsAllYears(TxnType type) {
    final map = <String, CategoryTotal>{};
    for (final t in transactions.where((t) => t.bookId == activeBookId)) {
      if (t.type != type) continue;
      final category = categoryById(t.categoryId) ??
          Category(id: t.categoryId, name: '未分类', type: type);
      final old = map[category.id];
      map[category.id] = CategoryTotal(
        category: category,
        value: (old?.value ?? 0) + t.amount,
        count: (old?.count ?? 0) + 1,
      );
    }
    final list = map.values.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  double netAssetsAt(DateTime end) {
    final endKey = dateKey(end);
    double total = 0;
    for (final a in accounts) {
      if (a.include) total += a.initial;
    }
    for (final t in transactions) {
      if (t.bookId != activeBookId || t.date.compareTo(endKey) > 0) continue;
      final account = accountById(t.accountId);
      if (t.type == TxnType.transfer) {
        final to = accountById(t.toAccountId);
        if (account != null && account.include) total -= t.amount;
        if (to != null && to.include) total += t.amount;
        continue;
      }
      if (account == null || !account.include) continue;
      if (t.type == TxnType.expense) {
        total -= t.amount;
      } else {
        total += t.amount;
      }
    }
    return total;
  }

  List<double> monthlyNetAssets(int year) {
    return List<double>.generate(12, (i) {
      final end = DateTime(year, i + 1, daysInMonth(DateTime(year, i + 1, 1)));
      return netAssetsAt(end);
    });
  }

  List<int> monthlyCountsForYear(int year) {
    final counts = List<int>.filled(12, 0);
    for (final t in txnsForYear(year)) {
      final m = int.tryParse(t.date.substring(5, 7));
      if (m != null && m >= 1 && m <= 12) counts[m - 1]++;
    }
    return counts;
  }

  List<int> get yearsWithData {
    final years = transactions
        .where((t) => t.bookId == activeBookId)
        .map((t) => int.tryParse(t.date.substring(0, 4)))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    if (years.isEmpty) years.add(DateTime.now().year);
    return years;
  }

  List<CategoryTotal> categoryTotals(DateTime month, TxnType type) {
    final map = <String, CategoryTotal>{};
    for (final t in txnsForMonth(month)) {
      if (t.type != type) continue;
      final category = categoryById(t.categoryId) ??
          Category(id: t.categoryId, name: '未分类', type: type);
      final old = map[category.id];
      map[category.id] = CategoryTotal(
        category: category,
        value: (old?.value ?? 0) + t.amount,
        count: (old?.count ?? 0) + 1,
      );
    }
    final list = map.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _seed();
    } else {
      try {
        _readJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _seed();
      }
    }
    if (books.isEmpty) _seed();
    loaded = true;
    final created = applyRecurringRules();
    locked = pinHash.isNotEmpty;
    if (created) await save();
    notifyListeners();
  }

  void _seed() {
    books = [Book(id: 'b_main', name: '日常账本')];
    activeBookId = 'b_main';
    categories = [
      Category(id: 'c_food', name: '餐饮', type: TxnType.expense, icon: '🍜', color: 0xFFF59E0B, order: 0),
      Category(id: 'c_shop', name: '购物', type: TxnType.expense, icon: '🛍️', color: 0xFFEC4899, order: 1),
      Category(id: 'c_transport', name: '交通', type: TxnType.expense, icon: '🚌', color: 0xFF3B82F6, order: 2),
      Category(id: 'c_home', name: '居住', type: TxnType.expense, icon: '🏠', color: 0xFF8B5CF6, order: 3),
      Category(id: 'c_fun', name: '娱乐', type: TxnType.expense, icon: '🎮', color: 0xFF14B8A6, order: 4),
      Category(id: 'c_health', name: '医疗', type: TxnType.expense, icon: '💊', color: 0xFFEF4444, order: 5),
      Category(id: 'c_study', name: '学习', type: TxnType.expense, icon: '📚', color: 0xFF06B6D4, order: 6),
      Category(id: 'c_phone', name: '通讯', type: TxnType.expense, icon: '📱', color: 0xFF6366F1, order: 7),
      Category(id: 'c_pet', name: '宠物', type: TxnType.expense, icon: '🐶', color: 0xFFB45309, order: 8),
      Category(id: 'c_other', name: '其他', type: TxnType.expense, icon: '🏷️', color: 0xFF94A3B8, order: 9),
      Category(id: 'i_salary', name: '工资', type: TxnType.income, icon: '💼', color: 0xFF0E9F6E, order: 0),
      Category(id: 'i_invest', name: '理财', type: TxnType.income, icon: '📈', color: 0xFF3B82F6, order: 1),
      Category(id: 'i_part', name: '兼职', type: TxnType.income, icon: '💻', color: 0xFF8B5CF6, order: 2),
      Category(id: 'i_gift', name: '红包', type: TxnType.income, icon: '🧧', color: 0xFFEF4444, order: 3),
      Category(id: 'i_other', name: '其他收入', type: TxnType.income, icon: '💰', color: 0xFF94A3B8, order: 4),
    ];
    accounts = [
      Account(id: 'a_cash', name: '现金', type: 'cash', icon: '💵', color: 0xFF10B981, order: 0),
      Account(id: 'a_alipay', name: '支付宝', type: 'alipay', icon: '🔵', color: 0xFF3B82F6, order: 1),
      Account(id: 'a_wechat', name: '微信', type: 'wechat', icon: '💚', color: 0xFF22C55E, order: 2),
      Account(id: 'a_bank', name: '银行卡', type: 'bank', icon: '💳', color: 0xFF8B5CF6, order: 3),
    ];
    transactions = [];
    recurringRules = [];
    themeId = 'system';
    customImagePath = '';
    cardStyle = 'orbit';
    billCardAlpha = 1.0;
    showLunar = true;
    pinHash = '';
    locked = false;
  }

  void _readJson(Map<String, dynamic> map) {
    books = (map['books'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Book.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (books.isEmpty) books = [Book(id: 'b_main', name: '日常账本')];
    activeBookId = map['activeBookId'] as String? ?? books.first.id;
    categories = (map['categories'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (categories.isEmpty) {
      _seed();
      return;
    }
    accounts = (map['accounts'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (accounts.isEmpty) {
      accounts = [Account(id: 'a_cash', name: '现金', type: 'cash', icon: '💵')];
    }
    transactions = (map['transactions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Txn.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    themeId = map['themeId'] as String? ??
        (map['themeMode'] == 'dark'
            ? 'dark'
            : map['themeMode'] == 'light'
                ? 'light'
                : 'system');
    customImagePath = map['customImagePath'] as String? ?? '';
    cardStyle = map['cardStyle'] as String? ?? 'orbit';
    billCardAlpha = (((map['billCardAlpha'] as num?)?.toDouble() ?? 1.0).clamp(0.4, 1.0)).toDouble();
    showLunar = map['showLunar'] != false;
    recurringRules = (map['recurringRules'] as List? ?? [])
        .whereType<Map>()
        .map((e) => RecurringRule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    pinHash = map['pinHash'] as String? ?? '';
    locked = pinHash.isNotEmpty;
  }

  Map<String, dynamic> _toJson() => {
        'version': 1,
        'books': books.map((e) => e.toJson()).toList(),
        'activeBookId': activeBookId,
        'categories': categories.map((e) => e.toJson()).toList(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'themeId': themeId,
        'customImagePath': customImagePath,
        'cardStyle': cardStyle,
        'billCardAlpha': billCardAlpha,
        'showLunar': showLunar,
        'recurringRules': recurringRules.map((e) => e.toJson()).toList(),
        'pinHash': pinHash,
      };

  Future<void> save() async {
    if (!loaded) return;
    await _prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  String _id(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';

  void addTxn(Txn txn) {
    transactions.add(txn);
    notifyListeners();
    save();
  }

  void updateTxn(Txn txn) {
    final index = transactions.indexWhere((t) => t.id == txn.id);
    if (index >= 0) {
      transactions[index] = txn;
    } else {
      transactions.add(txn);
    }
    notifyListeners();
    save();
  }

  void deleteTxn(String id) {
    transactions.removeWhere((t) => t.id == id);
    notifyListeners();
    save();
  }

  void addCategory(Category category) {
    if (category.id.isEmpty) category.id = _id('c');
    categories.add(category);
    notifyListeners();
    save();
  }

  void updateCategory(Category category) {
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index >= 0) categories[index] = category;
    notifyListeners();
    save();
  }

  void deleteCategory(String id) {
    categories.removeWhere((c) => c.id == id);
    notifyListeners();
    save();
  }

  void addAccount(Account account) {
    if (account.id.isEmpty) account.id = _id('a');
    accounts.add(account);
    notifyListeners();
    save();
  }

  void updateAccount(Account account) {
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index >= 0) accounts[index] = account;
    notifyListeners();
    save();
  }

  void deleteAccount(String id) {
    accounts.removeWhere((a) => a.id == id);
    transactions.removeWhere((t) => t.accountId == id);
    notifyListeners();
    save();
  }

  void addBook(Book book) {
    if (book.id.isEmpty) book.id = _id('b');
    books.add(book);
    activeBookId = book.id;
    notifyListeners();
    save();
  }

  void updateBook(Book book) {
    final index = books.indexWhere((b) => b.id == book.id);
    if (index >= 0) books[index] = book;
    notifyListeners();
    save();
  }

  void setActiveBook(String id) {
    activeBookId = id;
    notifyListeners();
    save();
  }

  void setThemeId(String id) {
    themeId = id;
    notifyListeners();
    save();
  }

  void setCustomImagePath(String path) {
    customImagePath = path;
    notifyListeners();
    save();
  }

  void setCardStyle(String style) {
    cardStyle = style;
    notifyListeners();
    save();
  }

  void setBillCardAlpha(double value) {
    billCardAlpha = value.clamp(0.4, 1.0).toDouble();
    notifyListeners();
    save();
  }

  void setShowLunar(bool value) {
    showLunar = value;
    notifyListeners();
    save();
  }

  void addRecurring(RecurringRule rule) {
    if (rule.id.isEmpty) rule.id = _id('r');
    recurringRules.add(rule);
    applyRecurringRules();
    notifyListeners();
    save();
  }

  void updateRecurring(RecurringRule rule) {
    final i = recurringRules.indexWhere((r) => r.id == rule.id);
    if (i >= 0) recurringRules[i] = rule;
    notifyListeners();
    save();
  }

  void deleteRecurring(String id) {
    recurringRules.removeWhere((r) => r.id == id);
    notifyListeners();
    save();
  }

  bool applyRecurringRules() {
    final today = dateKey(DateTime.now());
    var created = false;
    for (final rule in recurringRules) {
      if (!rule.enabled) continue;
      var next = rule.lastGenerated.isNotEmpty
          ? _advanceDate(rule.lastGenerated, rule.frequency)
          : rule.startDate;
      var guard = 0;
      while (next.compareTo(today) <= 0 && guard < 400) {
        guard++;
        final exists = transactions.any(
          (t) => t.recurringId == rule.id && t.date == next,
        );
        if (!exists) {
          final bookId = books.any((b) => b.id == rule.bookId)
              ? rule.bookId
              : activeBookId;
          transactions.add(Txn(
            id: newTxnId(),
            date: next,
            time: '08:00',
            type: rule.type,
            amount: rule.amount,
            categoryId: rule.categoryId,
            accountId: rule.accountId,
            bookId: bookId,
            note: rule.note.isEmpty ? rule.name : rule.note,
            recurringId: rule.id,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ));
          created = true;
        }
        rule.lastGenerated = next;
        next = _advanceDate(next, rule.frequency);
      }
    }
    return created;
  }

  String _advanceDate(String iso, String frequency) {
    final d = DateTime.tryParse(iso) ?? DateTime.now();
    if (frequency == 'daily') {
      final n = d.add(const Duration(days: 1));
      return dateKey(n);
    }
    if (frequency == 'weekly') {
      final n = d.add(const Duration(days: 7));
      return dateKey(n);
    }
    final year = d.month == 12 ? d.year + 1 : d.year;
    final month = d.month == 12 ? 1 : d.month + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = d.day > maxDay ? maxDay : d.day;
    return dateKey(DateTime(year, month, day));
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode('xingkong-flutter:$pin')).toString();
  }

  void setPin(String pin) {
    pinHash = _hashPin(pin);
    locked = false;
    notifyListeners();
    save();
  }

  bool verifyPin(String pin) => pinHash.isNotEmpty && _hashPin(pin) == pinHash;

  void unlock(String pin) {
    if (verifyPin(pin)) {
      locked = false;
      notifyListeners();
    }
  }

  void lockNow() {
    if (pinHash.isEmpty) return;
    locked = true;
    notifyListeners();
  }

  void removePin() {
    pinHash = '';
    locked = false;
    notifyListeners();
    save();
  }

  Map<String, dynamic> exportMap() => _toJson();

  String exportJsonString() => const JsonEncoder.withIndent('  ').convert(_toJson());

  void importJsonMap(Map<String, dynamic> map) {
    _readJson(map);
    if (books.isEmpty) _seed();
    loaded = true;
    locked = false;
    applyRecurringRules();
    notifyListeners();
    save();
  }

  int importTransactions(List<Txn> list) {
    final seen = transactions.map(_importKey).toSet();
    final added = <Txn>[];
    for (final t in list) {
      final key = _importKey(t);
      if (seen.contains(key)) continue;
      seen.add(key);
      added.add(t);
    }
    transactions.addAll(added);
    notifyListeners();
    save();
    return added.length;
  }

  String _importKey(Txn t) {
    return '${t.date}|${t.type.name}|${t.amount.toStringAsFixed(2)}|'
        '${t.categoryId}|${t.accountId}|${t.toAccountId}|${t.note}';
  }

  void importJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) importJsonMap(decoded);
  }

  void resetAll() {
    _seed();
    notifyListeners();
    save();
  }

  String newTxnId() => _id('t');

  void touch() => notifyListeners();
}
