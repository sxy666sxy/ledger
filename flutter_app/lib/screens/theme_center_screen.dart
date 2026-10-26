import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../store.dart';
import '../theme.dart';

class ThemeCenterScreen extends StatefulWidget {
  const ThemeCenterScreen({super.key});

  @override
  State<ThemeCenterScreen> createState() => _ThemeCenterScreenState();
}

class _ThemeCenterScreenState extends State<ThemeCenterScreen> {
  final AppStore store = AppStore.instance;
  bool _busy = false;

  Future<void> _pickImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
        imageQuality: 85,
      );
      if (picked == null) return;
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/theme_background.jpg');
      if (await file.exists()) await file.delete();
      await picked.saveTo(file.path);
      if (store.customImagePath.isNotEmpty && store.customImagePath != file.path) {
        final old = File(store.customImagePath);
        if (await old.exists()) await old.delete();
      }
      store.setCustomImagePath(file.path);
      store.setThemeId('custom');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('自定义图片已应用')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入图片失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeImage() async {
    final path = store.customImagePath;
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    store.setCustomImagePath('');
    if (store.themeId == 'custom') store.setThemeId('light');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已移除自定义图片')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final hasCustom = store.customImagePath.isNotEmpty &&
            File(store.customImagePath).existsSync();
        return Scaffold(
          appBar: AppBar(title: const Text('外观主题')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text(
                '选择一个外观，或导入一张自己的图片。主题只保存在本机。',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in const [
                          ('orbit', '星空椭圆'),
                          ('classic', '经典方形'),
                          ('minimal', '极简浅色'),
                          ('glass', '透明玻璃'),
                        ])
                          ChoiceChip(
                            label: Text(entry.$2, style: const TextStyle(fontSize: 11)),
                            selected: store.cardStyle == entry.$1,
                            onSelected: (_) => store.setCardStyle(entry.$1),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('账单深浅', style: TextStyle(fontSize: 11)),
                        Expanded(
                          child: Slider(
                            value: store.billCardAlpha,
                            min: 0.4,
                            max: 1.0,
                            divisions: 12,
                            onChanged: store.setBillCardAlpha,
                          ),
                        ),
                        Text('${(store.billCardAlpha * 100).round()}%', style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.35,
                children: themeSpecs.map((spec) {
                  final selected = store.themeId == spec.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      if (spec.id == 'custom' && !hasCustom) {
                        await _pickImage();
                      } else {
                        store.setThemeId(spec.id);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? spec.seed : Colors.transparent,
                          width: 2,
                        ),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: spec.id == 'custom' && hasCustom
                                ? Image.file(
                                    File(store.customImagePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _preview(spec),
                                  )
                                : _preview(spec),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 7, 8, 8),
                            child: Row(
                              children: [
                                Text(spec.emoji, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    spec.name,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check_circle, size: 16, color: spec.seed),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(hasCustom ? '更换图片' : '导入图片'),
                    ),
                  ),
                  if (hasCustom) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _removeImage,
                      child: const Text('移除'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '自定义图片会自动压缩并保存在本机，不会上传。',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _preview(ThemeSpec spec) {
    final style = store.cardStyle;
    final background = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: spec.preview,
        ),
      ),
    );
    if (style == 'orbit') {
      return Container(
        decoration: background.decoration,
        child: Center(
          child: SizedBox(
            width: 120,
            height: 54,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.elliptical(999, 999)),
                      color: const Color(0xFF111735),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 9,
                  bottom: 9,
                  width: 68,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.elliptical(999, 999)),
                      gradient: const LinearGradient(colors: [Color(0xFF2C3C8F), Color(0xFF1A1240)]),
                    ),
                  ),
                ),
                const Positioned(right: 8, top: 9, child: Text('2026', style: TextStyle(color: Colors.white70, fontSize: 7))),
                const Positioned(right: 6, top: 22, child: Text('10月', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                const Positioned(left: 16, top: 16, child: Text('✦', style: TextStyle(color: Color(0xFFFFE08A), fontSize: 8))),
                const Positioned(right: 30, bottom: 7, child: Text('·  ✦', style: TextStyle(color: Colors.white54, fontSize: 6))),
              ],
            ),
          ),
        ),
      );
    }
    Color cardColor;
    Color textColor;
    if (style == 'classic') {
      cardColor = const Color(0xFF111735);
      textColor = Colors.white;
    } else if (style == 'minimal') {
      cardColor = Colors.white.withValues(alpha: 0.92);
      textColor = const Color(0xFF202642);
    } else {
      cardColor = Colors.white.withValues(alpha: 0.28);
      textColor = Colors.white;
    }
    return Container(
      decoration: background.decoration,
      child: Center(
        child: Container(
          width: 116,
          height: 62,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(style == 'minimal' ? 9 : (style == 'glass' ? 15 : 10)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本月支出', style: TextStyle(color: textColor.withValues(alpha: 0.55), fontSize: 5.5)),
              const SizedBox(height: 1),
              Text('¥ 1,280.00', style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('2026年10月', style: TextStyle(color: textColor.withValues(alpha: 0.55), fontSize: 5.5)),
            ],
          ),
        ),
      ),
    );
  }

}
