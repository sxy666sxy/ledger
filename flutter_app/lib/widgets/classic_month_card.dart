import 'package:flutter/material.dart';

import '../store.dart';
import '../utils.dart';

class ClassicMonthCard extends StatelessWidget {
  const ClassicMonthCard({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _pickMonth(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2355), Color(0xFF0A0F2A), Color(0xFF211747)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A2355).withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$bookIcon $bookName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const Spacer(),
                  Text(monthTitle(month), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, color: Colors.white38, size: 16),
                ],
              ),
              const SizedBox(height: 14),
              const Text('本月支出', style: TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMoney(totals.expense),
                  style: const TextStyle(color: Color(0xFFFFD98A), fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _sumCell('收入', formatMoney(totals.income))),
                  Expanded(child: _sumCell('结余', formatMoney(totals.balance))),
                  Expanded(child: _sumCell('笔数', '$count')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sumCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
