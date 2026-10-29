import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils.dart';

const String _githubUrl = 'https://github.com/sxy666sxy/ledger';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _copyGithub(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _githubUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GitHub 地址已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = themeHeroIsGlass();
    final fg = themeHeroFg(context);
    final muted = themeHeroMuted(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          ThemeHeroCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: glass
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: glass ? 0.55 : 0.28),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '星空记账',
                  style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text('版本 v$appVersion', style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  '纯 Flutter 原生 · 本地记账 · 数据自持',
                  style: TextStyle(color: muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                _AboutRow(
                  icon: Icons.history_rounded,
                  title: '更新日志',
                  subtitle: 'v$appVersion 更新内容与历史版本',
                  onTap: () => Navigator.of(context).push(
                    fastPageRoute<void>(const ChangelogScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 58),
                _AboutRow(
                  icon: Icons.menu_book_rounded,
                  title: '使用手册',
                  subtitle: '记账、统计、资产与数据备份',
                  onTap: () => Navigator.of(context).push(
                    fastPageRoute<void>(const ManualScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 58),
                _AboutRow(
                  icon: Icons.code_rounded,
                  title: 'GitHub 网址',
                  subtitle: _githubUrl,
                  trailing: Icons.copy_rounded,
                  onTap: () => _copyGithub(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '默认只在本机；WebDAV 由你主动上传',
              style: TextStyle(fontSize: 10, color: scheme.onSurface.withValues(alpha: 0.45)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = Icons.chevron_right_rounded,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: scheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(trailing, size: 19, color: scheme.onSurface.withValues(alpha: 0.35)),
      onTap: onTap,
    );
  }
}

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  static const List<_Release> _releases = [
    _Release('v0.21.0', '2026-10-29', [
      '热力图详细页支持点击某一天，查看当天账单。',
      '明细、资产、我的顶部汇总卡支持点击设置支出颜色和自定义背景。',
      '日历顶部改为显示当月支出、收入、结余，金额按收支配色。',
      '资产账户支持进入账户账单页：统计、记账、转账、导出、编辑和转账记录。',
    ]),
    _Release('v0.20.0', '2026-10-28', [
      '记账页把日期、账户选择移到备注框下方，并新增报销和附件按钮。',
      '日期选择改为主题化月历，支持今天、昨天、前天快捷选择。',
      '添加账单可不选账户；账户可在编辑页直接校正当前余额。',
      '新增/编辑账户弹窗收窄输入框，优化主题样式。',
    ]),
    _Release('v0.19.0', '2026-10-28', [
      '新增自动备份：默认开启，启动和退出时备份，保留最近 5 次。',
      '自动备份路径可修改，支持从最近备份一键恢复。',
      '新增 WebDAV 备份，可上传到坚果云 / Nextcloud 等自己的服务器并恢复。',
    ]),
    _Release('v0.18.0', '2026-10-28', [
      '新增“我的-关于”独立页面，应用图标与主题样式联动。',
      '关于页展示版本、更新日志、使用手册和 GitHub 地址。',
    ]),
    _Release('v0.17.0', '2026-10-28', [
      '统计图表可点击进入对应日/月/年账单。',
      '热力图去掉底部按钮，点击月份直接定位详情。',
      '汇总卡片金额统一：支出红、收入绿、结余正绿负红。',
      '备注直接使用手机键盘，收起内置键盘。',
    ]),
    _Release('v0.16.0', '2026-10-28', [
      '页面切换改为快速淡入，减少重影。',
      '统计图表增加坐标轴和完整金额标签。',
    ]),
    _Release('v0.15.0', '2026-10-27', [
      '备注输入与手机键盘优化。',
      '账户、分类弹窗统一主题样式。',
      '分类支持转入其他分类。',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更新日志')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        itemCount: _releases.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final release = _releases[index];
          final latest = index == 0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        release.version,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      if (latest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '当前',
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(release.date, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  for (final item in release.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('· ', style: TextStyle(fontWeight: FontWeight.w800)),
                          Expanded(child: Text(item, style: const TextStyle(fontSize: 12, height: 1.4))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Release {
  const _Release(this.version, this.date, this.items);

  final String version;
  final String date;
  final List<String> items;
}

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  static const List<_ManualSection> _sections = [
    _ManualSection(Icons.add_circle_outline_rounded, '快速记账', [
      '点击右下角 + 新建账单；长按 + 可快速输入一句话或语音识别。',
      '账单页顶部可选择支出、收入或转账，分类支持自定义图标和颜色。',
      '备注框直接点击即可用手机键盘输入，内置数字键盘会自动收起。',
      '日期和账户选择在备注框下方；账户可以留空，不关联账户余额。',
      '日期支持主题月历与今天/昨天/前天快捷选择；报销和附件按钮在日期右侧。',
    ]),
    _ManualSection(Icons.insights_rounded, '统计', [
      '周、月、年、自定义统计可切换；再次进入会保留上次的子页面。',
      '日历顶部会显示当月支出、收入、结余，支出红色、收入绿色，结余按正负着色。',
      '点击趋势图中的某一天、某个月或某一年，可查看对应账单明细。',
      '点击年度热力图中的月份，会进入该月附近的热力详情；在详细热力图中点某一天，可查看当天账单。',
      '明细、资产、我的顶部汇总卡可点击，设置支出金额颜色和自定义背景。',
    ]),
    _ManualSection(Icons.account_balance_wallet_outlined, '资产', [
      '在资产页新增账户并填写初始余额；账户支持编辑、删除和排序查看。',
      '编辑账户时直接改“当前余额”，会自动校正初始余额，不改变已有账单。',
      '点击“资产走势”查看净资产变化；点击账户进入账户账单页。',
      '账户账单页支持统计、记一笔、转账、导出流水、编辑账户和转账记录。',
    ]),
    _ManualSection(Icons.backup_outlined, '数据与备份', [
      '所有数据默认保存在本机；只有主动使用 WebDAV 时才会联网上传。',
      '在“我的-数据与备份”中可导出/导入 JSON 备份和 23 列 Excel。',
      '自动备份默认开启，启动和退出应用时各备份一次，保留最近 5 次。',
      '点“自动备份”区域的存放路径可修改目录；点“最近自动备份”可恢复或删除。',
      'WebDAV 备份：填写服务器地址、用户名、密码和远程目录，测试连接后可上传或恢复。',
      'Excel 重复导入会自动去重，旧版负数支出金额会自动兼容。',
    ]),
    _ManualSection(Icons.palette_outlined, '主题与安全', [
      '在“我的-主题中心”切换主题、卡片样式，或导入自定义背景图。',
      '可设置隐私密码、分类预算和周期记账规则。',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用手册')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = _sections[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(section.icon, size: 19, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 7),
                      Text(section.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  for (final line in section.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('· ', style: TextStyle(fontWeight: FontWeight.w800)),
                          Expanded(child: Text(line, style: const TextStyle(fontSize: 12, height: 1.45))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ManualSection {
  const _ManualSection(this.icon, this.title, this.lines);

  final IconData icon;
  final String title;
  final List<String> lines;
}
