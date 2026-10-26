import 'package:flutter/material.dart';

import '../store.dart';

class PinGate extends StatelessWidget {
  const PinGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return store.locked ? const LockScreen() : child;
      },
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final AppStore store = AppStore.instance;
  String _pin = '';
  String _error = '';

  void _tap(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        if (store.verifyPin(_pin)) {
          store.unlock(_pin);
        } else {
          setState(() {
            _pin = '';
            _error = '密码错误，请重试';
          });
        }
      });
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(colors: [Color(0xFF1A2355), Color(0xFF070A17), Color(0xFF211747)]),
              ),
              child: const Text('✦', style: TextStyle(color: Color(0xFFFFE08A), fontSize: 38)),
            ),
            const SizedBox(height: 16),
            const Text('星空记账', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('输入 4 位隐私密码', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? scheme.primary : Colors.transparent,
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.45), width: 1.5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 20,
              child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 11)),
            ),
            const SizedBox(height: 6),
            _keypad(),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _keypad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 16,
        childAspectRatio: 1.35,
        children: keys.map((key) {
          if (key.isEmpty) return const SizedBox.shrink();
          if (key == '⌫') {
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _backspace,
              child: const Center(child: Icon(Icons.backspace_outlined, size: 23)),
            );
          }
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _tap(key),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

Future<void> showPinSetupDialog(BuildContext context, AppStore store, {bool changing = false}) async {
  final first = TextEditingController();
  final second = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(changing ? '修改隐私密码' : '设置隐私密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: first,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: '4 位数字密码', counterText: ''),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: second,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: '再次输入', counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
      ],
    ),
  );
  if (result == true) {
    final a = first.text.trim();
    final b = second.text.trim();
    if (a.length == 4 && a == b && int.tryParse(a) != null) {
      store.setPin(a);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('隐私密码已保存')));
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入两次相同的 4 位数字')));
    }
  }
  first.dispose();
  second.dispose();
}

class PinSettingsScreen extends StatelessWidget {
  const PinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('隐私锁')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(store.pinHash.isEmpty ? '设置隐私密码' : '修改隐私密码'),
                      subtitle: const Text('4 位数字，仅用于本机界面保护'),
                      onTap: () => showPinSetupDialog(context, store, changing: store.pinHash.isNotEmpty),
                    ),
                    if (store.pinHash.isNotEmpty) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_clock_outlined),
                        title: const Text('立即锁定'),
                        onTap: () {
                          store.lockNow();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_open_outlined),
                        title: const Text('关闭隐私锁'),
                        textColor: Colors.red,
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('关闭隐私锁？'),
                              content: const Text('关闭后打开应用将不再需要密码。'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('关闭'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            store.removePin();
                            if (context.mounted) Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '密码只保存哈希值在本机，忘记密码无法找回。',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      },
    );
  }
}
