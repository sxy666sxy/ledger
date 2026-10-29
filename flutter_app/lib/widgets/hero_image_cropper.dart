import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

/// Opens a simple cover-crop editor for the home summary cards.
///
/// The preview has the same 16:9 shape as the summary card. The image is
/// initially laid out with BoxFit.cover, then the user can drag/pinch to pick
/// the visible part. The visible preview is rasterised at 3x for a crisp card
/// background, so the result is exactly what the user selected.
Future<String?> pickHeroCardImage(BuildContext context, String sourcePath) {
  return Navigator.of(context).push<String>(
    fastPageRoute<String>(_HeroImageCropPage(sourcePath: sourcePath)),
  );
}

class _HeroImageCropPage extends StatefulWidget {
  const _HeroImageCropPage({required this.sourcePath});

  final String sourcePath;

  @override
  State<_HeroImageCropPage> createState() => _HeroImageCropPageState();
}

class _HeroImageCropPageState extends State<_HeroImageCropPage> {
  final GlobalKey _previewKey = GlobalKey();
  final TransformationController _transform = TransformationController();
  ui.Image? _image;
  Size? _imageSize;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _image = frame.image;
        _imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _error = '图片读取失败，请重新选择');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _image == null) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final object = _previewKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) {
        throw StateError('preview not ready');
      }
      final shot = await object.toImage(pixelRatio: 3);
      final data = await shot.toByteData(format: ui.ImageByteFormat.png);
      shot.dispose();
      if (data == null) throw StateError('encode failed');
      final dir = await getApplicationDocumentsDirectory();
      final target = File(
        '${dir.path}/hero_card_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.of(context).pop(target.path);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('裁剪保存失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('裁剪卡片背景', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving || _image == null ? null : _save,
            child: Text(
              _saving ? '保存中…' : '完成',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _error != null
                    ? Text(_error!, style: const TextStyle(color: Colors.white70))
                    : _image == null
                        ? const CircularProgressIndicator(color: Colors.white70)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final previewWidth = math.min(constraints.maxWidth - 32, 560.0);
                              final previewHeight = previewWidth * 9 / 16;
                              final imageSize = _imageSize!;
                              final coverScale = math.max(
                                previewWidth / imageSize.width,
                                previewHeight / imageSize.height,
                              );
                              final imageWidth = imageSize.width * coverScale;
                              final imageHeight = imageSize.height * coverScale;
                              return SizedBox(
                                width: previewWidth,
                                height: previewHeight,
                                child: RepaintBoundary(
                                  key: _previewKey,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        InteractiveViewer(
                                          transformationController: _transform,
                                          constrained: false,
                                          alignment: Alignment.center,
                                          minScale: 1,
                                          maxScale: 5,
                                          boundaryMargin: EdgeInsets.zero,
                                          child: SizedBox(
                                            width: imageWidth,
                                            height: imageHeight,
                                            child: RawImage(
                                              image: _image,
                                              fit: BoxFit.fill,
                                              filterQuality: FilterQuality.high,
                                            ),
                                          ),
                                        ),
                                        IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.85),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '拖动图片选择显示区域，双指缩放调整大小',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _transform.value = Matrix4.identity(),
                    icon: const Icon(Icons.restart_alt, size: 18, color: Colors.white70),
                    label: const Text('重置位置', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
