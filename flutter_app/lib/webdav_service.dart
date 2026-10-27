import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

class WebDavConfig {
  const WebDavConfig({
    this.server = '',
    this.username = '',
    this.password = '',
    this.folder = '星空记账',
  });

  final String server;
  final String username;
  final String password;
  final String folder;

  bool get configured => server.trim().isNotEmpty;

  WebDavConfig copyWith({String? server, String? username, String? password, String? folder}) {
    return WebDavConfig(
      server: server ?? this.server,
      username: username ?? this.username,
      password: password ?? this.password,
      folder: folder ?? this.folder,
    );
  }

  Map<String, dynamic> toJson() => {
        'server': server,
        'username': username,
        'password': password,
        'folder': folder,
      };

  static WebDavConfig fromJson(Map<String, dynamic> json) => WebDavConfig(
        server: (json['server'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        password: (json['password'] ?? '').toString(),
        folder: (json['folder'] ?? '星空记账').toString(),
      );
}

class WebDavItem {
  const WebDavItem({
    required this.name,
    required this.url,
    this.size,
    this.modified,
  });

  final String name;
  final String url;
  final int? size;
  final DateTime? modified;
}

class WebDavException implements Exception {
  const WebDavException(this.message);
  final String message;

  @override
  String toString() => message;
}

class WebDavService {
  static const String _prefsKey = 'xingkong.webdav.config';

  static Future<WebDavConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const WebDavConfig();
    try {
      return WebDavConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const WebDavConfig();
    }
  }

  static Future<void> saveConfig(WebDavConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
  }

  static Uri directoryUri(WebDavConfig config) {
    var base = config.server.trim();
    if (base.isEmpty) throw const WebDavException('请先填写 WebDAV 服务器地址');
    if (!base.endsWith('/')) base += '/';
    var uri = Uri.parse(base);
    for (final segment in config.folder.trim().split('/')) {
      if (segment.isEmpty) continue;
      uri = uri.resolve('${Uri.encodeComponent(segment)}/');
    }
    return uri;
  }

  static Map<String, String> _authHeaders(WebDavConfig config) {
    final headers = <String, String>{
      'User-Agent': 'XingkongLedger/1.0',
      'Accept': '*/*',
    };
    if (config.username.isNotEmpty || config.password.isNotEmpty) {
      final token = base64Encode(utf8.encode('${config.username}:${config.password}'));
      headers['Authorization'] = 'Basic $token';
    }
    return headers;
  }

  static Future<_DavResponse> _request(
    String method,
    Uri uri,
    WebDavConfig config, {
    Map<String, String>? headers,
    List<int>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.openUrl(method, uri);
      for (final entry in _authHeaders(config).entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (headers != null) {
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
      }
      if (body != null) request.add(body);
      final response = await request.close();
      final bytes = await response.fold<List<int>>(<int>[], (list, chunk) => list..addAll(chunk));
      return _DavResponse(response.statusCode, bytes);
    } on HandshakeException {
      throw const WebDavException('HTTPS 证书校验失败，请检查服务器地址');
    } on SocketException catch (e) {
      throw WebDavException('无法连接服务器：${e.message}');
    } on HttpException catch (e) {
      throw WebDavException('网络请求失败：${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  static String _statusMessage(int status) {
    if (status == 401) return '用户名或密码错误（401）';
    if (status == 403) return '服务器拒绝访问（403）';
    if (status == 404) return '远程目录不存在（404）';
    if (status == 405) return '服务器不支持该操作（405）';
    if (status == 409) return '远程父目录不存在（409）';
    return '服务器返回 HTTP $status';
  }

  static Future<String> test(WebDavConfig config) async {
    final uri = directoryUri(config);
    final response = await _request(
      'PROPFIND',
      uri,
      config,
      headers: {'Depth': '0', 'Content-Type': 'application/xml; charset=utf-8'},
      body: utf8.encode('<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>'),
    );
    if (response.status == 207 || response.status == 200) {
      return '连接成功，可以上传备份';
    }
    if (response.status == 404) {
      return '连接成功，但远程目录尚不存在；上传时会尝试自动创建';
    }
    throw WebDavException(_statusMessage(response.status));
  }

  static Future<void> upload(WebDavConfig config, String fileName, String content) async {
    final dir = directoryUri(config);
    // 目录已存在时 MKCOL 通常返回 405；不存在时返回 201。
    final mkcol = await _request('MKCOL', dir, config);
    if (mkcol.status != 201 && mkcol.status != 405 && mkcol.status != 200 && mkcol.status != 301) {
      if (mkcol.status == 401 || mkcol.status == 403) {
        throw WebDavException(_statusMessage(mkcol.status));
      }
    }
    final fileUri = dir.resolve(Uri.encodeComponent(fileName));
    final response = await _request(
      'PUT',
      fileUri,
      config,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: utf8.encode(content),
    );
    if (response.status < 200 || response.status >= 300) {
      throw WebDavException(_statusMessage(response.status));
    }
  }

  static Future<List<WebDavItem>> list(WebDavConfig config) async {
    final dir = directoryUri(config);
    final response = await _request(
      'PROPFIND',
      dir,
      config,
      headers: {'Depth': '1', 'Content-Type': 'application/xml; charset=utf-8'},
      body: utf8.encode('<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/><d:getcontentlength/><d:getlastmodified/><d:resourcetype/></d:prop></d:propfind>'),
    );
    if (response.status != 207 && response.status != 200) {
      throw WebDavException(_statusMessage(response.status));
    }
    final text = utf8.decode(response.bytes, allowMalformed: true);
    final document = XmlDocument.parse(text);
    final items = <WebDavItem>[];
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'response') continue;
      String? valueOf(String local) {
        for (final child in element.descendants.whereType<XmlElement>()) {
          if (child.name.local == local) return child.innerText.trim();
        }
        return null;
      }

      final href = valueOf('href');
      if (href == null || href.isEmpty) continue;
      final isCollection = element.descendants.whereType<XmlElement>().any(
            (e) => e.name.local == 'collection',
          );
      if (isCollection || href.endsWith('/')) continue;
      Uri itemUri;
      try {
        final parsed = Uri.parse(href);
        itemUri = parsed.hasScheme ? parsed : dir.resolve(href);
      } catch (_) {
        continue;
      }
      var name = itemUri.pathSegments.isEmpty ? '' : itemUri.pathSegments.last;
      try {
        name = Uri.decodeComponent(name);
      } catch (_) {}
      if (name.isEmpty) name = href.split('/').last;
      if (!name.toLowerCase().endsWith('.json')) continue;
      final size = int.tryParse(valueOf('getcontentlength') ?? '');
      final modifiedRaw = valueOf('getlastmodified');
      DateTime? modified;
      if (modifiedRaw != null) {
        try {
          modified = HttpDate.parse(modifiedRaw).toLocal();
        } catch (_) {}
      }
      items.add(WebDavItem(name: name, url: itemUri.toString(), size: size, modified: modified));
    }
    items.sort((a, b) {
      final am = a.modified?.millisecondsSinceEpoch ?? 0;
      final bm = b.modified?.millisecondsSinceEpoch ?? 0;
      return bm.compareTo(am);
    });
    return items;
  }

  static Future<String> download(WebDavConfig config, WebDavItem item) async {
    final response = await _request('GET', Uri.parse(item.url), config);
    if (response.status != 200) throw WebDavException(_statusMessage(response.status));
    return utf8.decode(response.bytes);
  }
}

class _DavResponse {
  const _DavResponse(this.status, this.bytes);
  final int status;
  final List<int> bytes;
}
