import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../utils.dart';

class SimpleMonthCard extends StatelessWidget {
  const SimpleMonthCard({
    super.key,
    required this.month,
    required this.totals,
    required this.bookName,
    required this.bookIcon,
    required this.count,
    required this.onChanged,
    required this.variant,
  });

  final DateTime month;
  final MoneyTotals totals;
  final String bookName;
  final String bookIcon;
  final int count;
  final ValueChanged<DateTime> onChanged;
  final String variant; // minimal | glass

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择月份',
    );
    if (picked != null) onChanged(monthStart(picked));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = variant == 'glass';
    final imagePath = AppStore.instance.heroCardImagePath;
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    final fg = hasImage ? themeHeroFg(context) : scheme.onSurface;
    final muted = hasImage ? themeHeroMuted(context) : scheme.onSurface.withValues(alpha: 0.55);
    final content = Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      decoration: BoxDecoration(
        color: hasImage ? Colors.transparent : (glass ? scheme.surface.withValues(alpha: 0.55) : scheme.surface),
        borderRadius: BorderRadius.circular(glass ? 22 : 16),
        border: Border.all(
          color: glass
              ? Colors.white.withValues(alpha: 0.45)
              : scheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: glass ? 0.10 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$bookIcon $bookName', style: TextStyle(fontSize: 11, color: muted)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _pickMonth(context),
                child: Row(
                  children: [
                    Text(monthTitle(month), style: TextStyle(fontSize: 11, color: hasImage ? Colors.white70 : scheme.onSurface.withValues(alpha: 0.6))),
                    const Icon(Icons.expand_more, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('本月支出', style: TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(totals.expense),
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: themeHeroExpense(context),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _cell('收入', formatMoney(totals.income), themeHeroIncome(context)),
              _cell('结余', formatMoney(totals.balance), totals.balance < 0 ? themeHeroExpense(context) : themeHeroIncome(context)),
              _cell('笔数', '$count', fg),
            ],
          ),
        ],
      ),
    );
    Widget card = content;
    if (hasImage) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x55000000), Color(0x99000000)],
                  ),
                ),
              ),
            ),
            content,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: glass
          ? ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: card,
              ),
            )
          : card,
    );
  }

  Widget _cell(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.55))),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}
