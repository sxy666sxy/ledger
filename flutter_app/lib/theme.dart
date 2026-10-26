import 'dart:io';

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
