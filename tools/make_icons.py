#!/usr/bin/env python3
"""生成星空记账的 PWA / Android 图标（纯标准库，无第三方依赖）。"""
import math
import os
import random
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PWA = os.path.join(ROOT, 'assets', 'icons')
ANDROID = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(size, maskable=False):
    hi = max(256, size * 3)
    px = bytearray(hi * hi * 4)
    top = (27, 35, 86)
    bottom = (6, 9, 24)
    glow_a = (92, 108, 255)
    glow_b = (137, 87, 255)
    for y in range(hi):
        row = y * hi * 4
        for x in range(hi):
            t = clamp((x * 0.55 + y * 0.45) / hi)
            r, g, b = mix(top, bottom, t)
            dx = (x - hi * 0.84) / (hi * 0.55)
            dy = (y - hi * 0.10) / (hi * 0.55)
            glow = clamp(1 - (dx * dx + dy * dy)) * 0.22
            r = int(r + (glow_a[0] - r) * glow)
            g = int(g + (glow_a[1] - g) * glow)
            b = int(b + (glow_a[2] - b) * glow)
            dx = (x - hi * 0.10) / (hi * 0.5)
            dy = (y - hi * 0.94) / (hi * 0.5)
            glow = clamp(1 - (dx * dx + dy * dy)) * 0.16
            r = int(r + (glow_b[0] - r) * glow)
            g = int(g + (glow_b[1] - g) * glow)
            b = int(b + (glow_b[2] - b) * glow)
            i = row + x * 4
            px[i], px[i + 1], px[i + 2], px[i + 3] = r, g, b, 255

    rnd = random.Random(20261026)
    for _ in range(90):
        cx = rnd.uniform(0.04, 0.96) * hi
        cy = rnd.uniform(0.03, 0.97) * hi
        rad = rnd.choice([0.7, 0.8, 1.0, 1.2, 1.6]) * hi / 512
        gold = rnd.random() < 0.18
        col = (255, 226, 150) if gold else (255, 255, 255)
        alpha = rnd.uniform(0.35, 0.95)
        rr = max(1, int(math.ceil(rad)))
        for yy in range(int(cy) - rr, int(cy) + rr + 1):
            for xx in range(int(cx) - rr, int(cx) + rr + 1):
                if 0 <= xx < hi and 0 <= yy < hi:
                    d = math.hypot(xx + 0.5 - cx, yy + 0.5 - cy)
                    if d <= rad:
                        i = (yy * hi + xx) * 4
                        a = alpha * clamp(rad - d + 0.8)
                        px[i] = int(px[i] * (1 - a) + col[0] * a)
                        px[i + 1] = int(px[i + 1] * (1 - a) + col[1] * a)
                        px[i + 2] = int(px[i + 2] * (1 - a) + col[2] * a)

    # 中央四角星 + 轨道
    cx, cy = hi * 0.5, hi * 0.50
    R = hi * (0.20 if maskable else 0.255)
    ring_r = hi * (0.33 if maskable else 0.385)
    ring_w = max(1, hi * 0.007)
    for y in range(int(cy - ring_r - ring_w), int(cy + ring_r + ring_w) + 1):
        for x in range(int(cx - ring_r - ring_w), int(cx + ring_r + ring_w) + 1):
            if 0 <= x < hi and 0 <= y < hi:
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if abs(d - ring_r) <= ring_w:
                    i = (y * hi + x) * 4
                    a = 0.42
                    px[i] = int(px[i] * (1 - a) + 185 * a)
                    px[i + 1] = int(px[i + 1] * (1 - a) + 205 * a)
                    px[i + 2] = int(px[i + 2] * (1 - a) + 255 * a)

    def star(R, inner, color, alpha=1.0):
        pts = []
        for k in range(16):
            ang = -math.pi / 2 + k * math.pi / 8
            r = R if k % 4 == 0 else inner
            pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
        x0 = min(p[0] for p in pts); x1 = max(p[0] for p in pts)
        y0 = min(p[1] for p in pts); y1 = max(p[1] for p in pts)
        for y in range(max(0, int(y0)), min(hi, int(y1) + 1)):
            for x in range(max(0, int(x0)), min(hi, int(x1) + 1)):
                inside = False
                j = len(pts) - 1
                for i in range(len(pts)):
                    xi, yi = pts[i]; xj, yj = pts[j]
                    if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi:
                        inside = not inside
                    j = i
                if inside:
                    p = (y * hi + x) * 4
                    px[p] = int(px[p] * (1 - alpha) + color[0] * alpha)
                    px[p + 1] = int(px[p + 1] * (1 - alpha) + color[1] * alpha)
                    px[p + 2] = int(px[p + 2] * (1 - alpha) + color[2] * alpha)

    star(R * 1.18, R * 0.20, (255, 210, 105), 0.22)
    star(R, R * 0.17, (255, 224, 140), 1.0)
    star(R * 0.54, R * 0.10, (255, 255, 255), 0.92)

    # 超采样缩放到目标
    out = bytearray(size * size * 4)
    ratio = hi / size
    for oy in range(size):
        y0 = oy * ratio; y1 = (oy + 1) * ratio
        for ox in range(size):
            x0 = ox * ratio; x1 = (ox + 1) * ratio
            r = g = b = 0.0; total = 0.0
            for yy in range(int(y0), min(hi, int(math.ceil(y1)))):
                wy = min(yy + 1, y1) - max(yy, y0)
                if wy <= 0: continue
                for xx in range(int(x0), min(hi, int(math.ceil(x1)))):
                    wx = min(xx + 1, x1) - max(xx, x0)
                    if wx <= 0: continue
                    w = wx * wy
                    i = (yy * hi + xx) * 4
                    r += px[i] * w; g += px[i + 1] * w; b += px[i + 2] * w; total += w
            total = total or 1
            i = (oy * size + ox) * 4
            out[i] = int(r / total); out[i + 1] = int(g / total); out[i + 2] = int(b / total); out[i + 3] = 255
    return out


def write_png(path, w, h, rgba):
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b''.join(b'\x00' + bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) +
           chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(png)


def main():
    jobs = [
        (os.path.join(PWA, 'icon-512.png'), 512, False),
        (os.path.join(PWA, 'icon-192.png'), 192, False),
        (os.path.join(PWA, 'icon-maskable-512.png'), 512, True),
        (os.path.join(PWA, 'apple-touch-icon.png'), 180, False),
    ]
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        jobs.append((os.path.join(ANDROID, 'mipmap-' + density, 'ic_launcher.png'), size, False))
    for path, size, maskable in jobs:
        write_png(path, size, size, render(size, maskable))
        print('wrote', path, size)


if __name__ == '__main__':
    main()
