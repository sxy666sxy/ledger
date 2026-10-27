import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../backup_service.dart';
import '../data_io.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'auto_backup_screen.dart';
import 'webdav_backup_screen.dart';

class DataBackupScreen extends StatefulWidget {
  const DataBackupScreen({super.key});

  @override
  State<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends State<DataBackupScreen> {
  final AppStore store = AppStore.instance;
  bool _busy = false;
  bool _autoEnabled = true;
  String _autoPath = '';
  DateTime? _lastAuto;
  int _autoCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAuto();
  }

  Future<void> _loadAuto() async {
    final enabled = await AutoBackupService.isEnabled();
    final path = await AutoBackupService.currentPath();
    final last = await AutoBackupService.lastBackupAt();
    final files = await AutoBackupService.listFiles();
    if (!mounted) return;
    setState(() {
      _autoEnabled = enabled;
      _autoPath = path;
      _lastAuto = last;
      _autoCount = files.length;
    });
  }

  Future<void> _toggleAuto(bool value) async {
    await AutoBackupService.setEnabled(value);
    if (value) await AutoBackupService.run(reason: '开启自动备份');
    await _loadAuto();
  }

  Future<void> _backupNow() async {
    final file = await AutoBackupService.run(reason: '手动', force: true);
    await _loadAuto();
    if (!mounted) return;
    _toast(file == null ? '备份失败，请检查存放路径是否可写' : '已备份到 ${file.path}');
  }

  Future<void> _changeAutoPath() async {
    final controller = TextEditingController(text: _autoPath);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => XkDialog(
        title: const Text('自动备份存放路径'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '输入可写的绝对路径',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final dir = await FilePicker.platform.getDirectoryPath(
                    dialogTitle: '选择自动备份目录',
                  );
                  if (dir != null && dir.trim().isNotEmpty) {
                    controller.text = dir;
                  }
                },
                icon: const Icon(Icons.folder_open_rounded, size: 17),
                label: const Text('选择目录'),
              ),
            ),
            Text(
              '默认保存在应用文档目录；更改后请确保该目录可写。',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('恢复默认'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await AutoBackupService.setCustomPath(result);
    await _loadAuto();
    if (mounted) _toast(result.isEmpty ? '已恢复默认备份路径' : '备份路径已更新');
  }

  Future<File> _tempFile(String name) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$name');
  }

  Future<void> _exportJson() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _tempFile('星空记账-备份-${dateKey(DateTime.now())}.json');
      await file.writeAsString(store.exportJsonString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: '星空记账 JSON 备份',
        text: '星空记账 JSON 备份',
      );
    } catch (e) {
      if (mounted) _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<int>?> _pickBytes(List<String> ext) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ext,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    if (f.bytes != null) return f.bytes;
    if (f.path != null) return File(f.path!).readAsBytes();
    return null;
  }

  Future<void> _importJson() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _pickBytes(['json']);
      if (bytes == null) return;
      final text = utf8.decode(bytes);
      final ok = await _confirm('导入 JSON 备份？', '会覆盖当前全部账本、账单、账户、分类、周期规则和设置。');
      if (ok != true) return;
      store.importJsonString(text);
      if (mounted) _toast('JSON 备份已导入');
    } catch (e) {
      if (mounted) _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await buildExcelBytes(store);
      final file = await _tempFile('星空记账-账单-${dateKey(DateTime.now())}.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: '星空记账 Excel 账单',
        text: '星空记账 Excel 账单',
      );
    } catch (e) {
      if (mounted) _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importExcel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _pickBytes(['xlsx']);
      if (bytes == null) return;
      final ok = await _confirm('导入 Excel 账单？', '账单会追加到当前账本；不存在的分类和账户会自动创建。');
      if (ok != true) return;
      final result = importExcelBytes(store, bytes);
      if (mounted) _toast('已导入 ${result.imported} 笔，跳过 ${result.skipped} 笔');
    } catch (e) {
      if (mounted) _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => XkDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续')),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据与备份')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.data_object),
                  title: const Text('导出 JSON 备份'),
                  subtitle: const Text('包含账本、账单、账户、分类、周期规则、主题和 PIN'),
                  trailing: const Icon(Icons.upload_file),
                  onTap: _busy ? null : _exportJson,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_page_outlined),
                  title: const Text('导入 JSON 备份'),
                  subtitle: const Text('覆盖当前全部数据'),
                  trailing: const Icon(Icons.download),
                  onTap: _busy ? null : _importJson,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew_rounded),
                  title: const Text('自动备份'),
                  subtitle: const Text('打开和退出应用时自动备份，保留最近 5 次'),
                  value: _autoEnabled,
                  onChanged: _toggleAuto,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: const Text('最近自动备份'),
                  subtitle: Text(
                    _lastAuto == null
                        ? '还没有自动备份 · 已保留 $_autoCount 份'
                        : '上次 ${dateTimeText(_lastAuto!)} · 已保留 $_autoCount 份',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(
                      fastPageRoute<void>(const AutoBackupListScreen()),
                    );
                    await _loadAuto();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('立即备份'),
                  subtitle: const Text('手动生成一份自动备份'),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: _backupNow,
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: _changeAutoPath,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('存放路径', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                _autoPath,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, height: 1.35, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_location_alt_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('导出 Excel 账单'),
                  subtitle: const Text('23 列标准账单格式，可在 Excel / WPS 打开'),
                  trailing: const Icon(Icons.upload_file),
                  onTap: _busy ? null : _exportExcel,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('导入 Excel 账单'),
                  subtitle: const Text('追加导入；自动创建缺失分类和账户'),
                  trailing: const Icon(Icons.download),
                  onTap: _busy ? null : _importExcel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('WebDAV 备份'),
              subtitle: const Text('上传到自己的坚果云 / Nextcloud，并从云端恢复'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                fastPageRoute<void>(const WebDavBackupScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'JSON 备份适合完整迁移；Excel 适合查看和整理账单。WebDAV 仅在你主动上传时联网。',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
