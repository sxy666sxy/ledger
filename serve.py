#!/usr/bin/env python3
"""星空记账 · 本地静态服务器

为 PWA 准备正确的 MIME 与缓存头，并在启动时打印可安装地址。

用法：
    python3 serve.py            # 0.0.0.0:8765
    python3 serve.py 8080       # 指定端口
"""
import argparse
import http.server
import mimetypes
import os
import socket
from functools import partial

ROOT = os.path.dirname(os.path.abspath(__file__))

mimetypes.add_type('application/manifest+json', '.webmanifest')
mimetypes.add_type('text/javascript', '.js')
mimetypes.add_type('image/svg+xml', '.svg')


class AppHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.webmanifest': 'application/manifest+json',
        '.js': 'text/javascript',
        '.mjs': 'text/javascript',
        '.svg': 'image/svg+xml',
        '.json': 'application/json',
    }

    def end_headers(self):
        path = self.path.split('?', 1)[0]
        if path in ('/', '/index.html', '/sw.js', '/manifest.webmanifest'):
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        else:
            self.send_header('Cache-Control', 'public, max-age=300')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        if path == '/sw.js':
            self.send_header('Service-Worker-Allowed', '/')
        super().end_headers()

    def log_message(self, fmt, *args):
        print('  %s - %s' % (self.address_string(), fmt % args))


def lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.3)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return None


def main():
    parser = argparse.ArgumentParser(description='星空记账本地服务器')
    parser.add_argument('port', nargs='?', type=int, default=8765)
    parser.add_argument('--bind', default='0.0.0.0')
    args = parser.parse_args()

    handler = partial(AppHandler, directory=ROOT)
    with http.server.ThreadingHTTPServer((args.bind, args.port), handler) as httpd:
        print()
        print('  星空记账 · 本地服务已启动')
        print('  手机本机安装：http://127.0.0.1:%d/' % args.port)
        ip = lan_ip()
        if ip:
            print('  局域网预览：  http://%s:%d/' % (ip, args.port))
        print('  （PWA 安装只支持 localhost 或 HTTPS；局域网 HTTP 地址仅用于预览）')
        print('  按 Ctrl+C 停止')
        print()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print('\n已停止')


if __name__ == '__main__':
    main()
