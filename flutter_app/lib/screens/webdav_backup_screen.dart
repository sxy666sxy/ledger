import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../webdav_service.dart';

class WebDavBackupScreen extends StatefulWidget {
  const WebDavBackupScreen({super.key});

  @override
  State<WebDavBackupScreen> createState() => _WebDavBackupScreenState();
}

class _WebDavBackupScreenState extends State<WebDavBackupScreen> {
  final AppStore store = AppStore.instance;
  final TextEditingController _server = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _folder = TextEditingController(text: '星空记账');
  bool _obscure = true;
  bool _busy = false;
  bool _loading = true;
  String? _status;
  List<WebDavItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await WebDavService.loadConfig();
    if (!mounted) return;
    setState(() {
      _server.text = config.server;
      _username.text = config.username;
      _password.text = config.password;
      _folder.text = config.folder;
      _loading = false;
    });
  }

  WebDavConfig get _config => WebDavConfig(
        server: _server.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        folder: _folder.text.trim().isEmpty ? '星空记账' : _folder.text.trim(),
      );

  Future<bool> _save() async {
    final config = _config;
    if (!config.configured) {
      _toast('请先填写服务器地址');
      return false;
    }
    final uri = Uri.tryParse(config.server);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _toast('服务器地址需要以 http:// 或 https:// 开头');
      return false;
    }
    await WebDavService.saveConfig(config);
    return true;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _status = '失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    if (!await _save()) return;
    await _run(() async {
      final message = await WebDavService.test(_config);
      if (mounted) setState(() => _status = message);
    });
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> _upload() async {
    if (!await _save()) return;
    await _run(() async {
      final name = '星空记账${_timestamp()}.json';
      await WebDavService.upload(_config, name, store.exportJsonString());
      if (!mounted) return;
      setState(() => _status = '已上传：$name');
      final items = await WebDavService.list(_config);
      if (mounted) setState(() => _items = items);
    });
  }

  Future<void> _refresh() async {
    if (!await _save()) return;
    await _run(() async {
      final items = await WebDavService.list(_config);
      if (!mounted) return;
      setState(() {
        _items = items;
        _status = items.isEmpty ? '云端暂无 JSON 备份' : '已发现 ${items.length} 个云端备份';
      });
    });
  }

  Future<void> _restore(WebDavItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => XkDialog(
        title: const Text('从 WebDAV 恢复'),
        content: Text('导入 ${item.name}？\n会覆盖当前全部账本、账单、账户、分类、周期规则和设置。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('覆盖导入')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final content = await WebDavService.download(_config, item);
      store.importJsonString(content);
      if (mounted) setState(() => _status = '已从 ${item.name} 恢复');
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _sizeText(int? size) {
    if (size == null) return '';
    if (size < 1024) return '$size B';
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV 备份')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('连接自己的 WebDAV', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          '支持坚果云、Nextcloud 等 WebDAV 服务。凭据仅保存在本机。',
                          style: TextStyle(fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.55)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _server,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: '服务器地址',
                            hintText: 'https://dav.example.com/dav/',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _username,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: '密码 / 应用密码',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _folder,
                          decoration: const InputDecoration(
                            labelText: '远程目录',
                            hintText: '星空记账',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _test,
                                icon: const Icon(Icons.wifi_tethering, size: 18),
                                label: const Text('测试连接'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _upload,
                                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                                label: const Text('上传当前备份'),
                              ),
                            ),
                          ],
                        ),
                        if (_busy) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(minHeight: 2),
                        ],
                        if (_status != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _status!,
                            style: TextStyle(
                              fontSize: 11,
                              color: _status!.startsWith('失败')
                                  ? scheme.error
                                  : scheme.onSurface.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cloud_outlined),
                        title: const Text('云端备份'),
                        subtitle: Text(_items.isEmpty ? '点击右侧刷新获取列表' : '${_items.length} 个可恢复的 JSON 备份'),
                        trailing: IconButton(
                          tooltip: '刷新',
                          onPressed: _busy ? null : _refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                      if (_items.isNotEmpty) const Divider(height: 1),
                      for (final item in _items)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.description_outlined, size: 20),
                          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text([
                            if (_sizeText(item.size).isNotEmpty) _sizeText(item.size),
                            if (item.modified != null) dateTimeText(item.modified!),
                          ].join(' · ')),
                          trailing: const Icon(Icons.download_rounded, size: 19),
                          onTap: _busy ? null : () => _restore(item),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '上传和恢复需要联网。备份文件会发送到你填写的 WebDAV 服务器，星空记账不会经过第三方中转。',
                  style: TextStyle(fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.48)),
                ),
              ],
            ),
    );
  }
}
