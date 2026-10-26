import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models.dart';
import 'screens/assets_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/entry_sheet.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/stats_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.load();
  runApp(const XkApp());
}

class XkApp extends StatelessWidget {
  const XkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
        title: '星空记账',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: store.themeMode,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showBookPicker() async {
    final store = AppStore.instance;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('切换账本', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            for (final book in store.books)
              ListTile(
                leading: Text(book.icon, style: const TextStyle(fontSize: 22)),
                title: Text(book.name),
                trailing: store.activeBookId == book.id ? const Icon(Icons.check) : null,
                onTap: () {
                  store.setActiveBook(book.id);
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新建账本'),
              onTap: () async {
                Navigator.pop(ctx);
                final controller = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('新建账本'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '账本名称'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: const Text('取消')),
                      FilledButton(
                        onPressed: () => Navigator.pop(d, controller.text.trim()),
                        child: const Text('创建'),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty) {
                  store.addBook(Book(id: '', name: name));
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    final store = AppStore.instance;
    if (_index == 0) {
      return AppBar(
        titleSpacing: 14,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showBookPicker,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(store.activeBook.icon),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    store.activeBook.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '日历',
            onPressed: () => _select(1),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      );
    }
    if (_index == 2) {
      return AppBar(
        title: const Text('统计'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: _buildAppBar(),
          body: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _index = i),
            physics: const BouncingScrollPhysics(),
            children: [
              HomeScreen(onOpenCalendar: () => _select(1)),
              const CalendarScreen(),
              const StatsScreen(),
              const AssetsScreen(),
              const ProfileScreen(),
            ],
          ),
          floatingActionButton: _index == 0
              ? FloatingActionButton(
                  onPressed: () => showEntrySheet(context),
                  child: const Icon(Icons.add, size: 28),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: '明细'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '日历'),
              NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: '统计'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: '资产'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
            ],
          ),
        );
      },
    );
  }
}
