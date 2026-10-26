
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';

class OrbitMonthCard extends StatefulWidget {
  const OrbitMonthCard({
    super.key,
    required this.month,
    required this.totals,
    required this.bookName,
    required this.bookIcon,
    required this.count,
    required this.onChanged,
  });

  final DateTime month;
  final MoneyTotals totals;
  final String bookName;
  final String bookIcon;
  final int count;
  final ValueChanged<DateTime> onChanged;

  @override
  State<OrbitMonthCard> createState() => _OrbitMonthCardState();
}

class _OrbitMonthCardState extends State<OrbitMonthCard> {
  double _drag = 0;
  String _target = '';

  void _update(String target, DragUpdateDetails details) {
    setState(() {
      _target = target;
      _drag += details.delta.dy;
    });
  }

  void _end(String target, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final delta = _drag;
    setState(() {
      _drag = 0;
      _target = '';
    });
    if (delta < -22 || velocity < -180) {
      _shift(target, 1);
    } else if (delta > 22 || velocity > 180) {
      _shift(target, -1);
    }
  }

  void _shift(String target, int delta) {
    HapticFeedback.lightImpact();
    final month = widget.month;
    if (target == 'year') {
      widget.onChanged(DateTime(month.year + delta, month.month, 1));
      return;
    }
    final total = month.year * 12 + (month.month - 1) + delta;
    widget.onChanged(DateTime(total ~/ 12, total % 12 + 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width * 0.63).clamp(214.0, 286.0).toDouble();
        final smallLeft = 7.0;
        final smallWidth = width * 0.57;
        final smallTop = height * 0.13;
        final smallHeight = height * 0.74;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _OrbitPainter(
                    dragTarget: _target,
                    dragOffset: _drag,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: 17,
                child: Text(
                  '${widget.bookIcon} ${widget.bookName}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
              Positioned(
                left: smallLeft,
                top: smallTop,
                width: smallWidth,
                height: smallHeight,
                child: _smallEllipse(context),
              ),
              Positioned(
                right: 12,
                top: height * 0.16,
                bottom: height * 0.14,
                width: width * 0.29,
                child: _dial(context),
              ),
              Positioned(
                right: 20,
                bottom: 18,
                child: Text(
                  '上下滑动切换',
                  style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.42)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _smallEllipse(BuildContext context) {
    const radius = BorderRadius.all(Radius.elliptical(999, 999));
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF283A88), Color(0xFF141B45), Color(0xFF241442)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF5B6CFF).withValues(alpha: 0.30), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              left: 15,
              top: 18,
              child: _planet(),
            ),
            Positioned(
              left: 58,
              right: 8,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('本月支出', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        formatMoney(widget.totals.expense),
                        key: ValueKey(widget.totals.expense),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _tiny('收入', formatMoney(widget.totals.income, symbol: false)),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _tiny('结余', formatMoney(widget.totals.balance, symbol: false)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 9,
              child: Text(
                '${widget.count} 笔',
                style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.35)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tiny(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 7.5, color: Colors.white.withValues(alpha: 0.40))),
        Text(value, style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _planet() {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.35,
            child: Container(
              width: 36,
              height: 11,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFFFD98A).withValues(alpha: 0.55), width: 1),
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.4, -0.4),
                radius: 1.1,
                colors: [Color(0xFFFFE7AA), Color(0xFFE0A84A), Color(0xFF7A4B1B)],
              ),
              boxShadow: [BoxShadow(color: Color(0x66FFD98A), blurRadius: 12, spreadRadius: 1)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dial(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dialText('year', '${widget.month.year}', '年', 23),
        const SizedBox(height: 1),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 18, height: 1, color: Colors.white.withValues(alpha: 0.16)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('✦', style: TextStyle(color: Color(0xFFFFE08A), fontSize: 7)),
            ),
            Container(width: 18, height: 1, color: Colors.white.withValues(alpha: 0.16)),
          ],
        ),
        const SizedBox(height: 1),
        _dialText('month', widget.month.month.toString().padLeft(2, '0'), '月', 30),
      ],
    );
  }

  Widget _dialText(String target, String value, String suffix, double size) {
    final active = _target == target;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => setState(() {
        _target = target;
        _drag = 0;
      }),
      onVerticalDragUpdate: (d) => _update(target, d),
      onVerticalDragEnd: (d) => _end(target, d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, active ? _drag * 0.22 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                value,
                key: ValueKey('$target$value'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Text(suffix, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.dragTarget, required this.dragOffset});
  final String dragTarget;
  final double dragOffset;

  static const _stars = [
    (0.13, 0.26, 2.1),
    (0.24, 0.10, 1.2),
    (0.44, 0.06, 1.7),
    (0.63, 0.10, 1.2),
    (0.78, 0.20, 2.2),
    (0.88, 0.34, 1.2),
    (0.90, 0.63, 1.7),
    (0.80, 0.82, 1.1),
    (0.62, 0.90, 1.5),
    (0.42, 0.92, 1.0),
    (0.22, 0.84, 1.5),
    (0.08, 0.66, 1.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF151B45), Color(0xFF080D25), Color(0xFF21133F)],
    ).createShader(rect);
    canvas.drawOval(rect, Paint()..shader = shader);
    canvas.drawOval(
      rect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    // inner halo / star dust
    canvas.drawOval(
      Rect.fromCenter(center: rect.center, width: size.width * 0.72, height: size.height * 0.55),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x225B6CFF), Color(0x00000000)],
        ).createShader(rect),
    );
    for (final s in _stars) {
      final dx = size.width * s.$1;
      final dy = size.height * s.$2;
      _star(canvas, Offset(dx, dy), s.$3);
    }
    // Four bigger sparkles near the rim.
    for (final p in [
      Offset(size.width * 0.36, size.height * 0.15),
      Offset(size.width * 0.83, size.height * 0.50),
      Offset(size.width * 0.58, size.height * 0.84),
    ]) {
      _sparkle(canvas, p, 3.6);
    }
    if (dragTarget.isNotEmpty) {
      final progress = (dragOffset / 100).clamp(-1.2, 1.2).toDouble();
      final start = dragTarget == 'year' ? -0.82 - progress * 0.08 : 0.16 + progress * 0.08;
      final sweep = 0.46 + progress.abs() * 0.16;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8CA0FF).withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawArc(rect.deflate(4), start, sweep, false, paint);
    }
  }

  void _star(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(center, radius, paint);
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = const Color(0xFFFFE8A8).withValues(alpha: 0.8);
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.25, c.dy - r * 0.25, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.25, c.dy + r * 0.25, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.25, c.dy + r * 0.25, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.25, c.dy - r * 0.25, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.dragTarget != dragTarget || old.dragOffset != dragOffset;
}
