import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  TxnType _type = TxnType.expense;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final list = store.categoriesFor(_type);
        return Scaffold(
          appBar: AppBar(title: const Text('分类管理')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SegmentedButton<TxnType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: TxnType.expense, label: Text('支出分类')),
                    ButtonSegment(value: TxnType.income, label: Text('收入分类')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (set) => setState(() => _type = set.first),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, i) {
                    final c = list[i];
                    final used = store.transactions.where((t) => t.categoryId == c.id).length;
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color(c.color).withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(c.icon, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(used > 0 ? '已有 $used 笔账单' : '暂无账单'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (used > 0)
                              IconButton(
                                tooltip: '转入其他分类账单',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _moveCategory(context, store, c),
                                icon: const Icon(Icons.swap_horiz, size: 18),
                              ),
                            const Icon(Icons.edit_outlined, size: 18),
                          ],
                        ),
                        onTap: () => _edit(context, store, c),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, store, null),
            icon: const Icon(Icons.add),
            label: const Text('新增分类'),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, AppStore store, Category? category) async {
    final name = TextEditingController(text: category?.name ?? '');
    final icon = TextEditingController(text: category?.icon ?? '🏷️');
    var color = category?.color ?? 0xFF94A3B8;
    final palette = [
      0xFFF59E0B,
      0xFFEC4899,
      0xFF3B82F6,
      0xFF8B5CF6,
      0xFF14B8A6,
      0xFFEF4444,
      0xFF06B6D4,
      0xFF6366F1,
      0xFF0E9F6E,
      0xFF94A3B8,
    ];
    final used = category == null
        ? 0
        : store.transactions.where((t) => t.categoryId == category.id).length;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => XkDialog(
          title: category == null ? '新增分类' : '编辑分类',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: icon,
                textAlign: TextAlign.center,
                maxLength: 4,
                decoration: const InputDecoration(labelText: '图标（Emoji）', counterText: ''),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: name,
                autofocus: category == null,
                decoration: const InputDecoration(labelText: '分类名称'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: palette.map((c) {
                  return InkWell(
                    onTap: () => setDialogState(() => color = c),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: color == c ? Border.all(color: Colors.black54, width: 2.5) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (category != null) ...[
                const SizedBox(height: 14),
                if (used > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final moved = await _moveCategory(context, store, category);
                        if (moved && ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('转入其他分类账单'),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _delete(ctx, store, category),
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    label: const Text('删除分类', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (result != true) return;
    final label = name.text.trim();
    if (label.isEmpty) return;
    final order = category?.order ??
        store.categories.where((c) => c.type == _type).fold<int>(0, (a, c) => c.order > a ? c.order : a) + 1;
    if (category == null) {
      store.addCategory(Category(
        id: '',
        name: label,
        type: _type,
        icon: icon.text.trim().isEmpty ? '🏷️' : icon.text.trim(),
        color: color,
        order: order,
      ));
    } else {
      category.name = label;
      category.icon = icon.text.trim().isEmpty ? '🏷️' : icon.text.trim();
      category.color = color;
      store.updateCategory(category);
    }
  }

  Future<bool> _moveCategory(BuildContext pageContext, AppStore store, Category category) async {
    final count = store.transactions.where((t) => t.categoryId == category.id).length;
    if (count == 0) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('该分类下暂无账单')),
      );
      return false;
    }
    final targets = store
        .categoriesFor(category.type)
        .where((c) => c.id != category.id)
        .toList(growable: false);
    if (targets.isEmpty) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('没有其他分类可转入')),
      );
      return false;
    }
    final targetId = await showDialog<String>(
      context: pageContext,
      builder: (ctx) => XkDialog(
        title: '转入其他分类账单',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '将「${category.name}」下的 $count 笔账单转入：',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(height: 8),
            for (final target in targets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Text(target.icon, style: const TextStyle(fontSize: 20)),
                title: Text(target.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${store.transactions.where((t) => t.categoryId == target.id).length} 笔账单',
                  style: const TextStyle(fontSize: 10.5),
                ),
                onTap: () => Navigator.pop(ctx, target.id),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
    if (targetId == null || !pageContext.mounted) return false;
    final target = store.categoryById(targetId);
    final moved = store.moveCategoryTransactions(category.id, targetId);
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(content: Text('已将 $moved 笔账单转入「${target?.name ?? '其他分类'}」')),
    );
    return moved > 0;
  }

  Future<void> _delete(BuildContext context, AppStore store, Category category) async {
    final used = store.transactions.where((t) => t.categoryId == category.id).length;
    if (used > 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已有 $used 笔账单使用该分类，可先转入其他分类')),
        );
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => XkDialog(
        title: '删除分类？',
        content: Text('确定删除「${category.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      store.deleteCategory(category.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
