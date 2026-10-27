import 'package:flutter_test/flutter_test.dart';
import 'package:xingkong_ledger/webdav_service.dart';

void main() {
  test('builds encoded WebDAV directory URLs', () {
    const config = WebDavConfig(server: 'https://dav.example.com/dav', folder: '星空记账/备份');
    final uri = WebDavService.directoryUri(config);
    expect(uri.toString(), 'https://dav.example.com/dav/%E6%98%9F%E7%A9%BA%E8%AE%B0%E8%B4%A6/%E5%A4%87%E4%BB%BD/');
  });

  test('WebDAV config round-trips through JSON', () {
    const config = WebDavConfig(
      server: 'https://dav.example.com/dav/',
      username: 'demo',
      password: 'secret',
      folder: '星空记账',
    );
    final copy = WebDavConfig.fromJson(config.toJson());
    expect(copy.server, config.server);
    expect(copy.username, config.username);
    expect(copy.password, config.password);
    expect(copy.folder, config.folder);
  });
}
