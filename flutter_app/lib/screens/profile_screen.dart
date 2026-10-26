import 'package:flutter/material.dart';

import '../store.dart';
import '../utils.dart';
import 'budget_screen.dart';
import 'categories_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final all = store.activeTransactions;
        final days = all.map((t) => t.date).toSet().length;
        final themeLabel = switch (store.themeMode) {
          ThemeMode.dark => '深色',
          ThemeMode.light => '浅色',
          ThemeMode.system => '跟随系统',
        };
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2355), Color(0xFF0A0F2A), Color(0xFF211747)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B2356), Color(0xFF070A17), Color(0xFF211747)],
                        ),
                      ),
                      child: const Text('✦', style: TextStyle(color: Color(0xFFFFE08A), fontSize: 30)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('星空记账', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                          SizedBox(height: 3),
                          Text('本地记账 · 数据自持 · 离线可用', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('v$appVersion', style: const TextStyle(color: Colors.white70, fontSize: 9)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      _stat('${all.length}', '记账笔数'),
                      _stat('$days', '记账天数'),
                      _stat('${store.accounts.length}', '账户'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _SectionTitle('账本与偏好'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const _MenuIcon('🎨'),
                      title: const Text('外观主题'),
                      trailing: Text('$themeLabel ›', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      onTap: () => _pickTheme(context, store),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const _MenuIcon('🏷️'),
                      title: const Text('分类管理'),
                      subtitle: Text('${store.categories.length} 个分类'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const _MenuIcon('🎯'),
                      title: const Text('预算设置'),
                      subtitle: Text(store.activeBook.budget > 0
                          ? '每月 ${formatMoney(store.activeBook.budget)}'
                          : '未设置'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BudgetScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const _MenuIcon('📒'),
                      title: const Text('当前账本'),
                      subtitle: Text(store.activeBook.name),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SectionTitle('数据'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const _MenuIcon('🗂️'),
                      title: const Text('数据与备份'),
                      subtitle: const Text('数据保存在本机；Excel 导入导出将在下一阶段迁移'),
                      onTap: () => _showDataInfo(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const _MenuIcon('🧹'),
                      title: const Text('清空所有数据'),
                      textColor: Colors.red,
                      onTap: () => _clearData(context, store),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SectionTitle('关于'),
              Card(
                child: ListTile(
                  leading: const _MenuIcon('✦'),
                  title: const Text('星空记账 Flutter'),
                  subtitle: Text('核心版 v$appVersion · 纯 Flutter 原生'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: '星空记账',
                    applicationVersion: appVersion,
                    applicationLegalese: '本地记账，数据自持。',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, AppStore store) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('外观主题', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            for (final option in [
              (ThemeMode.system, '跟随系统', '自动切换浅色/深色'),
              (ThemeMode.light, '浅色', '星空浅色'),
              (ThemeMode.dark, '深色', '深夜银河'),
            ])
              ListTile(
                leading: Icon(
                  option.$1 == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : option.$1 == ThemeMode.light
                          ? Icons.light_mode_outlined
                          : Icons.brightness_auto_outlined,
                ),
                title: Text(option.$2),
                subtitle: Text(option.$3),
                trailing: store.themeMode == option.$1 ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, option.$1),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (selected != null) store.setTheme(selected);
  }

  void _showDataInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('数据与备份'),
        content: const Text(
          '当前 Flutter 核心版的数据保存在本机，不会上传。\n\n'
          '原 WebView 版的数据无法直接共享；Excel 导入导出会在下一阶段迁移。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  }

  Future<void> _clearData(BuildContext context, AppStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有数据？'),
        content: const Text('所有账本、账单、账户和分类都会被删除，无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) store.resetAll();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 7),
      child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon(this.emoji);
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF5B6CFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 16)),
    );
  }
}
