import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data_io.dart';
import '../store.dart';
import '../utils.dart';

class DataBackupScreen extends StatefulWidget {
  const DataBackupScreen({super.key});

  @override
  State<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends State<DataBackupScreen> {
  final AppStore store = AppStore.instance;
  bool _busy = false;

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
      builder: (ctx) => AlertDialog(
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
          Text(
            'JSON 备份适合完整迁移；Excel 适合查看和整理账单。数据不会上传。',
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
