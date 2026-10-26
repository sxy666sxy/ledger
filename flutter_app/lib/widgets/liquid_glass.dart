import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidTopGlass extends StatelessWidget {
  const LiquidTopGlass({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [const Color(0xD90A1120), const Color(0x8F0A1120)]
                  : [Colors.white.withValues(alpha: 0.72), Colors.white.withValues(alpha: 0.36)],
            ),
            border: Border(
              bottom: BorderSide(
                color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class LiquidBottomGlass extends StatelessWidget {
  const LiquidBottomGlass({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [const Color(0xC70A1120), const Color(0xF20A1120)]
                  : [Colors.white.withValues(alpha: 0.62), Colors.white.withValues(alpha: 0.92)],
            ),
            border: Border(
              top: BorderSide(
                color: dark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}
