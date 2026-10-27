import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';
import 'entry_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final AppStore store = AppStore.instance;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Txn> _results() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final list = store.activeTransactions.where((t) {
      final cat = store.categoryById(t.categoryId);
      final account = store.accountById(t.accountId);
      final haystack = [
        t.note,
        cat?.name ?? '',
        t.subcategory,
        account?.name ?? '',
        t.date,
        t.time,
        formatMoney(t.amount, symbol: false),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final results = _results();
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜索备注、分类、账户、金额…',
                border: InputBorder.none,
              ),
            ),
            actions: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _controller.text.trim().isEmpty ? '输入关键词开始搜索' : '没有找到匹配的账单',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final t = results[i];
                    final cat = store.categoryById(t.categoryId);
                    final account = store.accountById(t.accountId);
                    final isExpense = t.type == TxnType.expense;
                    final isTransfer = t.type == TxnType.transfer;
                    return Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => showEntrySheet(context, existing: t),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Text(
                                isTransfer ? '🔁' : (cat?.icon ?? '🏷️'),
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isTransfer
                                          ? '转账'
                                          : '${cat?.name ?? '未分类'}${t.subcategory.isNotEmpty ? ' · ${t.subcategory}' : ''}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.date} ${t.time} · ${account?.name ?? ''}${t.note.isEmpty ? '' : ' · ${t.note}'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isTransfer
                                    ? formatMoney(t.amount)
                                    : '${isExpense ? '-' : '+'}${formatMoney(t.amount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isTransfer
                                      ? const Color(0xFF5B6CFF)
                                      : (isExpense ? const Color(0xFFE5484D) : const Color(0xFF0E9F6E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
