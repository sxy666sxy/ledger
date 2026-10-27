import 'dart:io';

import 'package:flutter/material.dart';

import '../backup_service.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';

class AutoBackupListScreen extends StatefulWidget {
  const AutoBackupListScreen({super.key});

  @override
  State<AutoBackupListScreen> createState() => _AutoBackupListScreenState();
}

class _AutoBackupListScreenState extends State<AutoBackupListScreen> {
  final AppStore store = AppStore.instance;
  List<File> _files = const [];
  String _path = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final path = await AutoBackupService.currentPath();
    final files = await AutoBackupService.listFiles();
    if (!mounted) return;
    setState(() {
      _path = path;
      _files = files;
      _loading = false;
    });
  }

  Future<void> _restore(File file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => XkDialog(
        title: const Text('恢复自动备份'),
        content: Text('导入 ${file.path.split('/').last}？\n会覆盖当前全部账本、账单、账户、分类、周期规则和设置。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('覆盖导入')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final content = await file.readAsString();
      store.importJsonString(content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('自动备份已恢复')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

  Future<void> _delete(File file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => XkDialog(
        title: const Text('删除备份'),
        content: Text('删除 ${file.path.split('/').last}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await file.delete();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  Future<String> _time(File file) async {
    try {
      return dateTimeText((await file.stat()).modified);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('最近自动备份')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('自动备份保留最近 5 次', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            _path,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.52),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_files.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('暂无自动备份')),
                      ),
                    )
                  else
                    for (final file in _files)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: FutureBuilder<String>(
                          future: _time(file),
                          builder: (context, snapshot) => ListTile(
                            leading: const Icon(Icons.history_rounded),
                            title: Text(file.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(snapshot.data ?? ''),
                            trailing: IconButton(
                              tooltip: '删除',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(file),
                            ),
                            onTap: () => _restore(file),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
