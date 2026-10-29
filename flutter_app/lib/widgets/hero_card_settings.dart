import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../store.dart';
import '../theme.dart';

const List<int> _expenseColors = [
  0,
  0xFFD92D20,
  0xFFFF7A85,
  0xFFF97316,
  0xFFF3B63B,
  0xFF7C3AED,
  0xFF2563EB,
  0xFF0E9F6E,
  0xFF64748B,
];

Future<void> showHeroCardSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HeroCardSettingsSheet(),
  );
}

class _HeroCardSettingsSheet extends StatefulWidget {
  const _HeroCardSettingsSheet();

  @override
  State<_HeroCardSettingsSheet> createState() => _HeroCardSettingsSheetState();
}

class _HeroCardSettingsSheetState extends State<_HeroCardSettingsSheet> {
  final AppStore store = AppStore.instance;
  bool _busy = false;

  Future<void> _pickImage() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      final dir = await getApplicationDocumentsDirectory();
      final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.jpg';
      final target = File('${dir.path}/hero_card_${DateTime.now().millisecondsSinceEpoch}$ext');
      await File(path).copy(target.path);
      store.setHeroCardImagePath(target.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择背景失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imagePath = store.heroCardImagePath;
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    return XkSheet(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('顶部卡片设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('三处卡片同步', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 14),
              const Text('支出金额颜色', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 11,
                runSpacing: 10,
                children: _expenseColors.map((value) {
                  final selected = store.heroExpenseColor == value;
                  final color = value == 0 ? scheme.primary : Color(value);
                  return InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => store.setHeroExpenseColor(value),
                    child: Container(
                      width: 31,
                      height: 31,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: value == 0 ? scheme.surfaceContainerHighest : color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? scheme.onSurface : Colors.white.withValues(alpha: 0.7),
                          width: selected ? 2.2 : 1,
                        ),
                      ),
                      child: value == 0
                          ? Icon(Icons.auto_awesome, size: 14, color: scheme.onSurface)
                          : selected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text('第一个为跟随主题；选择后三处顶部汇总卡立即生效。', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('卡片自定义背景', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (hasImage)
                    TextButton(
                      onPressed: () => store.setHeroCardImagePath(''),
                      child: const Text('移除', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _busy ? null : _pickImage,
                child: Container(
                  height: 86,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: scheme.surfaceContainerHighest,
                    image: hasImage
                        ? DecorationImage(image: FileImage(File(imagePath)), fit: BoxFit.cover)
                        : null,
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
                  ),
                  child: hasImage
                      ? const SizedBox.shrink()
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_busy ? Icons.hourglass_top : Icons.add_photo_alternate_outlined, size: 24),
                              const SizedBox(height: 4),
                              Text(_busy ? '正在保存…' : '从相册选择图片', style: const TextStyle(fontSize: 10.5)),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 7),
              Text('背景会覆盖明细、资产、我的三处顶部卡片，并自动加深保证文字可读。', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
