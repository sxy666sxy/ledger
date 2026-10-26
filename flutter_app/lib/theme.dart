import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'store.dart';

const Color seedColor = Color(0xFF5B6CFF);
const Color bgColor = Color(0xFFF3F5FF);

class ThemeSpec {
  const ThemeSpec({
    required this.id,
    required this.name,
    required this.emoji,
    required this.seed,
    required this.background,
    required this.surface,
    this.inputFill,
    this.dark = false,
    this.custom = false,
    this.preview = const [Color(0xFF5B6CFF), Color(0xFF9BA8FF)],
  });

  final String id;
  final String name;
  final String emoji;
  final Color seed;
  final Color background;
  final Color surface;
  final Color? inputFill;
  final bool dark;
  final bool custom;
  final List<Color> preview;
}

const List<ThemeSpec> themeSpecs = [
  ThemeSpec(id: 'system', name: '跟随系统', emoji: '🌓', seed: seedColor, background: bgColor, surface: Colors.white, preview: [Color(0xFFF3F5FF), Color(0xFF5B6CFF)]),
  ThemeSpec(id: 'light', name: '星空浅色', emoji: '✦', seed: seedColor, background: Color(0xFFF3F5FF), surface: Colors.white, preview: [Color(0xFF1A2355), Color(0xFF5B6CFF)]),
  ThemeSpec(id: 'dark', name: '星空深色', emoji: '🌌', seed: Color(0xFF8B9CFF), background: Color(0xFF070A17), surface: Color(0xFF10152B), inputFill: Color(0xFF141B34), dark: true, preview: [Color(0xFF070A17), Color(0xFF4A5BDB)]),
  ThemeSpec(id: 'grass', name: '草原', emoji: '🌿', seed: Color(0xFF2E8B57), background: Color(0xFFF4FBF0), surface: Colors.white, preview: [Color(0xFFDDF2D0), Color(0xFF2E8B57)]),
  ThemeSpec(id: 'sky', name: '天空', emoji: '☁️', seed: Color(0xFF2F80ED), background: Color(0xFFEFF8FF), surface: Colors.white, preview: [Color(0xFFBFE3FF), Color(0xFF2F80ED)]),
  ThemeSpec(id: 'cloud', name: '白云', emoji: '☁️', seed: Color(0xFF6C8AB8), background: Color(0xFFF4F7FC), surface: Colors.white, preview: [Color(0xFFE8EEF8), Color(0xFF8AA4C8)]),
  ThemeSpec(id: 'castle', name: '粉色城堡', emoji: '🏰', seed: Color(0xFFD65A9A), background: Color(0xFFFFF4FA), surface: Colors.white, preview: [Color(0xFFFFD6EA), Color(0xFFD65A9A)]),
  ThemeSpec(id: 'wheat', name: '麦田', emoji: '🌾', seed: Color(0xFFC08A2E), background: Color(0xFFFFFAEF), surface: Colors.white, preview: [Color(0xFFFFE9B8), Color(0xFFC08A2E)]),
  ThemeSpec(id: 'snow', name: '白雪', emoji: '❄️', seed: Color(0xFF5B8EC9), background: Color(0xFFF4F9FF), surface: Colors.white, preview: [Color(0xFFE4F1FF), Color(0xFF8FB8DD)]),
  ThemeSpec(id: 'storm', name: '闪电', emoji: '⚡', seed: Color(0xFF7C8CFF), background: Color(0xFF141821), surface: Color(0xFF1C2230), inputFill: Color(0xFF252D3D), dark: true, preview: [Color(0xFF141821), Color(0xFF7C8CFF)]),
  ThemeSpec(id: 'wave', name: '波浪', emoji: '🌊', seed: Color(0xFF168A9E), background: Color(0xFFEEFBFC), surface: Colors.white, preview: [Color(0xFFC2F0F4), Color(0xFF168A9E)]),
  ThemeSpec(id: 'ocean', name: '海底', emoji: '🐚', seed: Color(0xFF35C7D0), background: Color(0xFF071A2C), surface: Color(0xFF0C2438), inputFill: Color(0xFF112D43), dark: true, preview: [Color(0xFF071A2C), Color(0xFF168A9E)]),
  ThemeSpec(id: 'custom', name: '自定义图片', emoji: '🖼️', seed: seedColor, background: Color(0x00EEF2F9), surface: Color(0xCCFFFFFF), inputFill: Color(0x99FFFFFF), custom: true, preview: [Color(0xFFB8C4FF), Color(0xFFFFD4E6)]),
];


/// 顶部汇总卡使用当前主题色盘生成渐变，不再固定混入紫色。
List<Color> themeHeroColors(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final spec = themeSpec(AppStore.instance.themeId);
  final accent = spec.custom
      ? Color.lerp(scheme.primary, spec.preview.last, 0.50)!
      : spec.preview.last;
  return [
    Color.lerp(accent, Colors.black, 0.56)!,
    Color.lerp(accent, Colors.black, 0.74)!,
    Color.lerp(accent, Colors.black, 0.38)!,
  ];
}

/// 汇总卡的圆角跟随“外观主题”里选择的卡片样式。
double themeHeroRadius(double base) {
  switch (AppStore.instance.cardStyle) {
    case 'orbit':
      return base + 10;
    case 'classic':
      return base - 6;
    case 'minimal':
      return base - 10;
    case 'glass':
      return base;
    default:
      return base;
  }
}

bool themeHeroIsGlass() => AppStore.instance.cardStyle == 'glass';

/// 顶部汇总卡在玻璃样式下改用深色/浅色表面字色，保证可读性。
Color themeHeroFg(BuildContext context) =>
    themeHeroIsGlass() ? Theme.of(context).colorScheme.onSurface : Colors.white;

Color themeHeroMuted(BuildContext context) => themeHeroIsGlass()
    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)
    : Colors.white.withValues(alpha: 0.54);

Color themeHeroIncome(BuildContext context) => themeHeroIsGlass()
    ? const Color(0xFF0E9F6E)
    : const Color(0xFF8FE3C8);

BoxDecoration themeHeroDecoration(BuildContext context, {double radius = 22}) {
  final colors = themeHeroColors(context);
  final style = AppStore.instance.cardStyle;
  final custom = AppStore.instance.themeId == 'custom';
  final effectiveRadius = themeHeroRadius(radius);
  if (style == 'glass') {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(effectiveRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: 0.10),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
  return BoxDecoration(
    borderRadius: BorderRadius.circular(effectiveRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors
          .map((c) => custom ? c.withValues(alpha: 0.78) : c)
          .toList(growable: false),
    ),
    border: custom
        ? Border.all(color: Colors.white.withValues(alpha: 0.28))
        : null,
    boxShadow: style == 'minimal'
        ? const []
        : [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.20),
              blurRadius: style == 'classic' ? 10 : 18,
              offset: Offset(0, style == 'classic' ? 4 : 8),
            ),
          ],
  );
}

/// 带主题装饰纹理的顶部汇总卡，统计 / 资产 / 我的共用。
class ThemeHeroCard extends StatelessWidget {
  const ThemeHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = AppStore.instance.cardStyle;
    final effectiveRadius = themeHeroRadius(radius);
    final content = Container(
      decoration: themeHeroDecoration(context, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: Stack(
          children: [
            if (style != 'glass')
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ThemeHeroArtPainter(style: style),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
    if (style != 'glass') return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      ),
    );
  }
}

class _ThemeHeroArtPainter extends CustomPainter {
  _ThemeHeroArtPainter({required this.style});

  final String style;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == 'minimal') return;
    final white = Colors.white.withValues(alpha: 0.10);
    if (style == 'orbit') {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = white;
      final center = Offset(size.width * 0.82, size.height * 0.28);
      for (var i = 0; i < 3; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: size.width * (0.42 + i * 0.18),
            height: size.height * (0.62 + i * 0.26),
          ),
          ring,
        );
      }
      final star = Paint()..color = Colors.white.withValues(alpha: 0.30);
      for (final p in const [
        Offset(0.68, 0.18),
        Offset(0.90, 0.48),
        Offset(0.74, 0.74),
      ]) {
        canvas.drawCircle(Offset(size.width * p.dx, size.height * p.dy), 1.2, star);
      }
    } else if (style == 'glass') {
      canvas.drawCircle(
        Offset(size.width * 0.84, size.height * 0.30),
        size.width * 0.30,
        Paint()..color = Colors.white.withValues(alpha: 0.06),
      );
      canvas.drawCircle(
        Offset(size.width * 0.95, size.height * 0.80),
        size.width * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.05),
      );
    } else if (style == 'classic') {
      final line = Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 1;
      for (var i = 0; i < 3; i++) {
        final x = size.width * (0.70 + i * 0.09);
        canvas.drawLine(Offset(x, 0), Offset(size.width, size.height * 0.32), line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeHeroArtPainter oldDelegate) =>
      oldDelegate.style != style;
}

ThemeSpec themeSpec(String id) {
  for (final t in themeSpecs) {
    if (t.id == id) return t;
  }
  return themeSpecs[0];
}

ThemeData buildAppTheme(String themeId, Brightness systemBrightness) {
  final spec = themeSpec(themeId);
  final Brightness brightness = spec.id == 'system'
      ? systemBrightness
      : (spec.dark ? Brightness.dark : Brightness.light);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: spec.seed,
      brightness: brightness,
    ),
  );
  final surface = spec.id == 'system'
      ? (brightness == Brightness.dark ? const Color(0xFF10152B) : Colors.white)
      : spec.surface;
  final background = spec.id == 'system'
      ? (brightness == Brightness.dark ? const Color(0xFF070A17) : bgColor)
      : spec.background;
  final scheme = base.colorScheme.copyWith(
    surface: surface,
    surfaceContainerLow: surface,
    surfaceContainer: spec.inputFill ?? surface,
    surfaceContainerHighest: spec.inputFill ?? surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: spec.custom ? Colors.transparent : background,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: spec.custom ? Colors.transparent : background,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: spec.inputFill ?? (brightness == Brightness.dark ? const Color(0xFF141B34) : const Color(0xFFF7F8FF)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: spec.seed.withValues(alpha: 0.5)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: spec.custom ? const Color(0xCCFFFFFF) : surface,
      indicatorColor: spec.seed.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? spec.seed : scheme.onSurface.withValues(alpha: 0.55),
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: spec.seed,
      foregroundColor: Colors.white,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.onSurface.withValues(alpha: 0.08),
      thickness: 1,
    ),
  );
}

class ThemeBackground extends StatelessWidget {
  const ThemeBackground({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    if (store.themeId != 'custom') return child ?? const SizedBox.shrink();
    final file = store.customImagePath.isEmpty ? null : File(store.customImagePath);
    if (file == null || !file.existsSync()) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB8C4FF), Color(0xFFFFD4E6), Color(0xFFF6F8FF)],
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const ColoredBox(color: Color(0xFFEEF2F9)),
        ),
        ColoredBox(color: Colors.white.withValues(alpha: 0.18)),
        child ?? const SizedBox.shrink(),
      ],
    );
  }
}
