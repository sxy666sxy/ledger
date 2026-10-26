import 'package:flutter/material.dart';

class SwipeDeleteTile extends StatefulWidget {
  const SwipeDeleteTile({
    super.key,
    required this.child,
    required this.onDelete,
    this.borderRadius = 16,
  });

  final Widget child;
  final VoidCallback onDelete;
  final double borderRadius;

  @override
  State<SwipeDeleteTile> createState() => _SwipeDeleteTileState();
}

class _SwipeDeleteTileState extends State<SwipeDeleteTile> {
  static const double _openWidth = 82;
  double _offset = 0;
  bool _dragging = false;

  bool get _open => _offset < -1;

  void _close() => setState(() => _offset = 0);

  void _delete() {
    setState(() => _offset = 0);
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) {
          setState(() {
            _offset = (_offset + d.delta.dx).clamp(-_openWidth, 0.0);
          });
        },
        onHorizontalDragEnd: (d) {
          final velocity = d.primaryVelocity ?? 0;
          setState(() {
            _dragging = false;
            if (velocity < -250 || _offset < -_openWidth * 0.45) {
              _offset = -_openWidth;
            } else {
              _offset = 0;
            }
          });
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _openWidth,
                  child: Material(
                    color: const Color(0xFFE5484D),
                    child: InkWell(
                      onTap: _delete,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.white, size: 21),
                            SizedBox(height: 2),
                            Text('删除', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: _dragging ? Duration.zero : const Duration(milliseconds: 190),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_offset, 0, 0),
              child: Stack(
                children: [
                  widget.child,
                  if (_open)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _close,
                      ),
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
