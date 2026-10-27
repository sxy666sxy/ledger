import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models.dart';
import '../quick_parse.dart';
import '../store.dart';
import '../utils.dart';

Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const QuickAddSheet(),
  );
}

/// Small long-press entry panel. The modal sheet itself is pushed up by the
/// keyboard inset, so the whole panel stays above the system keyboard.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final AppStore store = AppStore.instance;
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  QuickParseResult? _parsed;

  @override
  void initState() {
    super.initState();
    _parse();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _speechReady = ready);
    } catch (_) {
      if (mounted) setState(() => _speechReady = false);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    _parsed = parseQuickEntry(
      _controller.text,
      categories: store.categories,
      accounts: store.bookkeepingAccounts.isEmpty ? store.accounts : store.bookkeepingAccounts,
    );
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前设备没有可用的语音识别服务')),
          );
        }
        return;
      }
    }
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'zh_CN',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        _controller.value = TextEditingValue(
          text: words,
          selection: TextSelection.collapsed(offset: words.length),
        );
        setState(() {
          _parse();
          if (result.finalResult) _listening = false;
        });
      },
    );
  }

  void _save() {
    final parsed = _parsed;
    if (parsed == null || !parsed.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请说出或输入金额，例如“早餐12元”')),
      );
      return;
    }
    if (parsed.type != TxnType.transfer && parsed.categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有识别到分类，请编辑后保存')),
      );
      return;
    }
    if (parsed.accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加账户')),
      );
      return;
    }
    final now = TimeOfDay.now();
    final txn = Txn(
      id: store.newTxnId(),
      date: parsed.date,
      time: '${two(now.hour)}:${two(now.minute)}',
      type: parsed.type,
      amount: parsed.amount,
      categoryId: parsed.categoryId,
      accountId: parsed.accountId,
      toAccountId: parsed.toAccountId,
      bookId: store.activeBookId,
      note: parsed.note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final messenger = ScaffoldMessenger.of(context);
    store.addTxn(txn);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('已记录')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final parsed = _parsed;
    final category = parsed == null ? null : store.categoryById(parsed.categoryId);
    final account = parsed == null ? null : store.accountById(parsed.accountId);
    final typeLabel = parsed == null
        ? '待识别'
        : parsed.type == TxnType.income
            ? '收入'
            : parsed.type == TxnType.transfer
                ? '转账'
                : '支出';
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.18),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('快捷记账', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                if (_listening)
                  Text('正在聆听…', style: TextStyle(fontSize: 11, color: scheme.primary))
                else
                  Text('说出或输入一句话', style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.45))),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(_parse),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: '例如：早餐12元 支付宝',
                filled: true,
                fillColor: scheme.primary.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _PreviewChip(
                        icon: parsed?.type == TxnType.transfer ? '🔁' : (category?.icon ?? '🏷️'),
                        label: parsed?.type == TxnType.transfer
                            ? '转账'
                            : (category?.name ?? '待分类'),
                      ),
                      _PreviewChip(icon: '💰', label: parsed == null || parsed.amount <= 0 ? '待识别' : formatMoney(parsed.amount)),
                      _PreviewChip(icon: account?.icon ?? '💳', label: account?.name ?? '待账户'),
                      _PreviewChip(icon: '📅', label: parsed?.date == dateKey(DateTime.now()) ? '今天' : (parsed?.date ?? '今天')),
                      _PreviewChip(icon: '📤', label: typeLabel),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: _listening ? '停止语音' : '语音记账',
                  onPressed: _toggleVoice,
                  icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: parsed != null && parsed.valid ? _save : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(46, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Icon(Icons.check, size: 21),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '自动识别分类和金额；也可以点麦克风说一句话。',
              style: TextStyle(fontSize: 10, color: scheme.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$icon $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }
}
