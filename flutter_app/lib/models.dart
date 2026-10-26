import 'dart:convert';

enum TxnType { expense, income, transfer }

TxnType txnTypeFromString(String? value) {
  if (value == 'income') return TxnType.income;
  if (value == 'transfer') return TxnType.transfer;
  return TxnType.expense;
}

String txnTypeString(TxnType type) {
  if (type == TxnType.income) return 'income';
  if (type == TxnType.transfer) return 'transfer';
  return 'expense';
}

class Book {
  Book({
    required this.id,
    required this.name,
    this.icon = '📒',
    this.color = 0xFF0E9F6E,
    this.budget = 0,
    Map<String, double>? categoryBudgets,
  }) : categoryBudgets = categoryBudgets ?? {};

  String id;
  String name;
  String icon;
  int color;
  double budget;
  Map<String, double> categoryBudgets;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'budget': budget,
        'categoryBudgets': categoryBudgets,
      };

  factory Book.fromJson(Map<String, dynamic> map) => Book(
        id: map['id'] as String? ?? 'b_main',
        name: map['name'] as String? ?? '日常账本',
        icon: map['icon'] as String? ?? '📒',
        color: (map['color'] as num?)?.toInt() ?? 0xFF0E9F6E,
        budget: (map['budget'] as num?)?.toDouble() ?? 0,
        categoryBudgets: (map['categoryBudgets'] as Map?)
                ?.map((key, value) => MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0)) ??
            {},
      );
}

class Category {
  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon = '🏷️',
    this.color = 0xFF94A3B8,
    this.order = 0,
  });

  String id;
  String name;
  TxnType type;
  String icon;
  int color;
  int order;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': txnTypeString(type),
        'icon': icon,
        'color': color,
        'order': order,
      };

  factory Category.fromJson(Map<String, dynamic> map) => Category(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '未分类',
        type: txnTypeFromString(map['type'] as String?),
        icon: map['icon'] as String? ?? '🏷️',
        color: (map['color'] as num?)?.toInt() ?? 0xFF94A3B8,
        order: (map['order'] as num?)?.toInt() ?? 0,
      );
}

class Account {
  Account({
    required this.id,
    required this.name,
    this.type = 'other',
    this.icon = '💳',
    this.color = 0xFF5B6CFF,
    this.initial = 0,
    this.include = true,
    this.bookkeeping = true,
    this.order = 0,
  });

  String id;
  String name;
  String type;
  String icon;
  int color;
  double initial;
  bool include;
  bool bookkeeping;
  int order;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'initial': initial,
        'include': include,
        'bookkeeping': bookkeeping,
        'order': order,
      };

  factory Account.fromJson(Map<String, dynamic> map) => Account(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '账户',
        type: map['type'] as String? ?? 'other',
        icon: map['icon'] as String? ?? '💳',
        color: (map['color'] as num?)?.toInt() ?? 0xFF5B6CFF,
        initial: (map['initial'] as num?)?.toDouble() ?? 0,
        include: map['include'] != false,
        bookkeeping: map['bookkeeping'] != false,
        order: (map['order'] as num?)?.toInt() ?? 0,
      );
}

class Txn {
  Txn({
    required this.id,
    required this.date,
    required this.time,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.toAccountId = '',
    required this.bookId,
    this.subcategory = '',
    this.note = '',
    this.tags = const [],
    this.refund = 0,
    this.discount = 0,
    this.reimburseAmount = 0,
    this.reimburseAccountId = '',
    this.recurringId = '',
    this.reimburseDetail = '',
    this.currency = '',
    this.foreignAmount = 0,
    this.address = '',
    this.createdBy = '',
    this.other = '',
    this.attachments = const [],
    this.createdAt = 0,
  });

  String id;
  String date;
  String time;
  TxnType type;
  double amount;
  String categoryId;
  String subcategory;
  String accountId;
  String toAccountId;
  String bookId;
  String note;
  List<String> tags;
  double refund;
  double discount;
  double reimburseAmount;
  String reimburseAccountId;
  String recurringId;
  String reimburseDetail;
  String currency;
  double foreignAmount;
  String address;
  String createdBy;
  String other;
  List<String> attachments;
  int createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'time': time,
        'type': txnTypeString(type),
        'amount': amount,
        'categoryId': categoryId,
        'subcategory': subcategory,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'bookId': bookId,
        'note': note,
        'tags': tags,
        'refund': refund,
        'discount': discount,
        'reimburseAmount': reimburseAmount,
        'reimburseAccountId': reimburseAccountId,
        'recurringId': recurringId,
        'reimburseDetail': reimburseDetail,
        'currency': currency,
        'foreignAmount': foreignAmount,
        'address': address,
        'createdBy': createdBy,
        'other': other,
        'attachments': attachments,
        'createdAt': createdAt,
      };

  factory Txn.fromJson(Map<String, dynamic> map) => Txn(
        id: map['id'] as String? ?? '',
        date: map['date'] as String? ?? '1970-01-01',
        time: map['time'] as String? ?? '12:00',
        type: txnTypeFromString(map['type'] as String?),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        categoryId: map['categoryId'] as String? ?? '',
        subcategory: map['subcategory'] as String? ?? '',
        accountId: map['accountId'] as String? ?? '',
        toAccountId: map['toAccountId'] as String? ?? '',
        bookId: map['bookId'] as String? ?? '',
        note: map['note'] as String? ?? '',
        tags: (map['tags'] as List?)?.whereType<String>().toList() ?? const [],
        refund: (map['refund'] as num?)?.toDouble() ?? 0,
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        reimburseAmount: (map['reimburseAmount'] as num?)?.toDouble() ?? 0,
        reimburseAccountId: map['reimburseAccountId'] as String? ?? '',
        recurringId: map['recurringId'] as String? ?? '',
        reimburseDetail: map['reimburseDetail'] as String? ?? '',
        currency: map['currency'] as String? ?? '',
        foreignAmount: (map['foreignAmount'] as num?)?.toDouble() ?? 0,
        address: map['address'] as String? ?? '',
        createdBy: map['createdBy'] as String? ?? '',
        other: map['other'] as String? ?? '',
        attachments: (map['attachments'] as List?)?.whereType<String>().toList() ?? const [],
        createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      );
}

class RecurringRule {
  RecurringRule({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.bookId,
    required this.frequency,
    required this.startDate,
    this.note = '',
    this.lastGenerated = '',
    this.enabled = true,
  });

  String id;
  String name;
  TxnType type;
  double amount;
  String categoryId;
  String accountId;
  String bookId;
  String frequency;
  String startDate;
  String note;
  String lastGenerated;
  bool enabled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': txnTypeString(type),
        'amount': amount,
        'categoryId': categoryId,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'bookId': bookId,
        'frequency': frequency,
        'startDate': startDate,
        'note': note,
        'lastGenerated': lastGenerated,
        'enabled': enabled,
      };

  factory RecurringRule.fromJson(Map<String, dynamic> map) => RecurringRule(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '周期记账',
        type: txnTypeFromString(map['type'] as String?),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        categoryId: map['categoryId'] as String? ?? '',
        accountId: map['accountId'] as String? ?? '',
        toAccountId: map['toAccountId'] as String? ?? '',
        bookId: map['bookId'] as String? ?? '',
        frequency: map['frequency'] as String? ?? 'monthly',
        startDate: map['startDate'] as String? ?? '2026-01-01',
        note: map['note'] as String? ?? '',
        lastGenerated: map['lastGenerated'] as String? ?? '',
        enabled: map['enabled'] != false,
      );
}

Map<String, dynamic> decodeJsonMap(String value) {
  final decoded = jsonDecode(value);
  if (decoded is Map<String, dynamic>) return decoded;
  return <String, dynamic>{};
}
