import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// 自动备份设置与本地备份文件管理。
class AutoBackupService {
  static const String _enabledKey = 'xingkong.autoBackup.enabled';
  static const String _pathKey = 'xingkong.autoBackup.path';
  static const String _lastKey = 'xingkong.autoBackup.last';
  static const int keepCount = 5;

  static bool _running = false;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<bool> isEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_enabledKey, value);
  }

  static Future<String?> customPath() async {
    final prefs = await _prefs();
    final value = prefs.getString(_pathKey);
    return value == null || value.trim().isEmpty ? null : value.trim();
  }

  static Future<void> setCustomPath(String? path) async {
    final prefs = await _prefs();
    if (path == null || path.trim().isEmpty) {
      await prefs.remove(_pathKey);
    } else {
      await prefs.setString(_pathKey, path.trim());
    }
  }

  static Future<String> defaultPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/星空记账/自动备份';
  }

  static Future<String> currentPath() async => await customPath() ?? await defaultPath();

  static Future<DateTime?> lastBackupAt() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_lastKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<Directory> ensureDirectory() async {
    final dir = Directory(await currentPath());
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _stamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }

  static Future<List<File>> listFiles() async {
    try {
      final dir = Directory(await currentPath());
      if (!await dir.exists()) return const [];
      final files = await dir
          .list()
          .where((e) => e is File && e.path.split('/').last.startsWith('星空记账') && e.path.endsWith('.json'))
          .cast<File>()
          .toList();
      final withTime = <MapEntry<File, DateTime>>[];
      for (final file in files) {
        try {
          withTime.add(MapEntry(file, (await file.stat()).modified));
        } catch (_) {}
      }
      withTime.sort((a, b) => b.value.compareTo(a.value));
      return withTime.map((e) => e.key).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _prune(Directory dir) async {
    try {
      final entries = <MapEntry<File, DateTime>>[];
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.path.split('/').last;
        if (!name.startsWith('星空记账') || !name.endsWith('.json')) continue;
        try {
          entries.add(MapEntry(entity, (await entity.stat()).modified));
        } catch (_) {}
      }
      entries.sort((a, b) => b.value.compareTo(a.value));
      for (final stale in entries.skip(keepCount)) {
        try {
          await stale.key.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// 立即执行一次自动备份；关闭时直接返回 null。
  static Future<File?> run({String reason = '', bool force = false}) async {
    if (_running) return null;
    if (!force && !await isEnabled()) return null;
    _running = true;
    try {
      final store = AppStore.instance;
      if (!store.loaded) return null;
      final dir = await ensureDirectory();
      final now = DateTime.now();
      final file = File('${dir.path}/星空记账${_stamp(now)}.json');
      await file.writeAsString(store.exportJsonString(), flush: true);
      final prefs = await _prefs();
      await prefs.setString(_lastKey, now.toIso8601String());
      await _prune(dir);
      return file;
    } catch (_) {
      return null;
    } finally {
      _running = false;
    }
  }
}
