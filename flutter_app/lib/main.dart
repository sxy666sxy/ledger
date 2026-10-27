import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models.dart';
import 'screens/assets_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/entry_sheet.dart';
import 'screens/home_screen.dart';
import 'screens/pin_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quick_add_sheet.dart';
import 'screens/search_screen.dart';
import 'screens/stats_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/liquid_glass.dart';

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
        theme: buildAppTheme(store.themeId, Brightness.light),
        darkTheme: buildAppTheme(store.themeId, Brightness.dark),
        themeMode: themeSpec(store.themeId).id == 'system'
            ? ThemeMode.system
            : themeSpec(store.themeId).dark
                ? ThemeMode.dark
                : ThemeMode.light,
        builder: (context, child) => ThemeBackground(child: child),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PinGate(child: RootShell()),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ValueNotifier<double> _pagePos = ValueNotifier(0);
  late final AnimationController _forceTopBarController;
  int? _forceTopBar;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScroll);
    _forceTopBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && _forceTopBar != null) {
          setState(() => _forceTopBar = null);
        }
      });
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page != null && page != _pagePos.value) _pagePos.value = page;
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _pagePos.dispose();
    _forceTopBarController.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_index == index) return;
    if (index == 0 || index == 2) {
      setState(() => _forceTopBar = index);
      _forceTopBarController.forward(from: 0);
    } else {
      _forceTopBar = null;
      _forceTopBarController.value = 0;
    }
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutQuint,
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

  Widget _buildTopBar(
    BuildContext context,
    double topPadding,
    double topHeight,
    bool detail,
    double factor,
  ) {
    final store = AppStore.instance;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: topHeight,
      child: Stack(
        children: [
          const Positioned.fill(child: LiquidTopGlass()),
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            height: kToolbarHeight,
            child: detail
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _showBookPicker,
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.34),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
                        const Spacer(),
                        IconButton(
                          tooltip: '搜索',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                          ),
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '统计',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final topPadding = MediaQuery.of(context).padding.top;
        final topHeight = topPadding + kToolbarHeight;
        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _index = i),
                physics: const BouncingScrollPhysics(),
                children: [
                  HomeScreen(active: _index == 0),
                  const CalendarScreen(),
                  StatsScreen(active: _index == 2),
                  const AssetsScreen(),
                  const ProfileScreen(),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _forceTopBarController,
                  builder: (context, _) => ValueListenableBuilder<double>(
                    valueListenable: _pagePos,
                    builder: (context, page, child) {
                      final forced = _forceTopBar;
                      final detail = forced != null ? forced == 0 : page < 1;
                      final stats = forced != null ? forced == 2 : (page >= 1 && page < 3);
                      if (!detail && !stats) return const SizedBox.shrink();
                      final factor = forced != null
                          ? _forceTopBarController.value
                          : detail
                              ? (1 - page).clamp(0.0, 1.0)
                              : (page < 2 ? page - 1 : 3 - page).clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: Offset(0, -topHeight * (1 - factor)),
                        child: _buildTopBar(context, topPadding, topHeight, detail, factor),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: _index == 0
              ? GestureDetector(
                  onLongPress: () => showQuickAddSheet(context),
                  child: FloatingActionButton(
                    onPressed: () => showEntrySheet(context),
                    child: const Icon(Icons.add, size: 28),
                  ),
                )
              : null,
          bottomNavigationBar: LiquidBottomGlass(
            child: NavigationBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
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
          ),
        );
      },
    );
  }
}
