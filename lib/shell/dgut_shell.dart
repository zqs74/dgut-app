import 'dart:async';

import 'package:flutter/material.dart';

import '../components/dgut_dock.dart';
import '../components/dgut_edge_blur.dart';
import '../components/dgut_reselect.dart';
import '../components/dgut_theme_sheet.dart';
import '../components/dgut_topbar.dart';
import '../pages/changelog_page.dart';
import '../pages/home_page.dart';
import '../pages/me_page.dart';
import '../pages/messages_page.dart';
import '../pages/services_page.dart';
import '../pages/timetable_page.dart';
import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

/// 五页外壳：PageView 横向切页 + 顶栏 + 上下边缘 + Dock。
///
/// 渐进式运动：PageView 负责 1:1 跟手平移；页内再按"离当前页的距离"
/// 叠一层缩放、上浮与淡出，相邻页在滑动过程中不是硬整体位移，
/// 而是边走边缩小变淡（ColorOS 那种"渐进"的简化版）。
class DgutShell extends StatefulWidget {
  const DgutShell({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.initialIndex = 0,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final int initialIndex;

  @override
  State<DgutShell> createState() => _DgutShellState();
}

class _DgutShellState extends State<DgutShell> {
  late int _index = widget.initialIndex.clamp(0, 4);
  late final PageController _pc = PageController(initialPage: _index);
  final ValueNotifier<double> _pagePos = ValueNotifier<double>(0);
  final DgutReselect _reselect = DgutReselect();

  final List<ValueNotifier<DgutScrollInfo>> _scroll =
      List<ValueNotifier<DgutScrollInfo>>.generate(
        5,
        (_) => ValueNotifier<DgutScrollInfo>(DgutScrollInfo.zero),
      );

  static const List<String> _titles = ['首页', '课表', '服务', '消息', '我的'];

  static const List<DgutDockItem> _dockItems = [
    DgutDockItem(label: '首页', icon: Icons.wb_sunny_outlined),
    DgutDockItem(label: '课表', icon: Icons.calendar_month_outlined),
    DgutDockItem(label: '服务', icon: Icons.grid_view_rounded),
    DgutDockItem(label: '消息', icon: Icons.notifications_none_rounded),
    DgutDockItem(label: '我的', icon: Icons.person_outline_rounded),
  ];

  Timer? _demoTimer;

  @override
  void initState() {
    super.initState();
    _pagePos.value = _index.toDouble();
    _pc.addListener(_syncPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pc.hasClients) _syncPage();
      _handleBoot();
    });
    if (Uri.base.queryParameters['demo'] == '1') {
      _demoTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (!mounted) return;
        _goTo((_index + 1) % 5);
      });
    }
  }

  void _syncPage() {
    if (!_pc.hasClients) return;
    final double? p = _pc.page;
    if (p != null) _pagePos.value = p;
  }

  /// ?boot=changelog 直接打开版本历史；?boot=theme 直接弹外观选择（验收用）
  void _handleBoot() {
    final String boot = Uri.base.queryParameters['boot'] ?? '';
    if (boot == 'changelog') {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ChangelogPage()));
    } else if (boot == 'theme') {
      showDgutThemeSheet(context, widget.themeMode).then((m) {
        if (m != null) widget.onThemeModeChanged(m);
      });
    }
  }

  void _goTo(int i) {
    if (!_pc.hasClients) return;
    _pc.animateToPage(
      i,
      duration: DgutMotion.enter,
      curve: DgutMotion.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _pc.removeListener(_syncPage);
    _pc.dispose();
    _pagePos.dispose();
    _reselect.dispose();
    for (final n in _scroll) {
      n.dispose();
    }
    super.dispose();
  }

  ValueNotifier<DgutScrollInfo> get _active => _scroll[_index];

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    final List<Widget> pages = [
      HomePage(offset: _scroll[0]),
      TimetablePage(offset: _scroll[1]),
      ServicesPage(offset: _scroll[2]),
      MessagesPage(offset: _scroll[3]),
      MePage(
        offset: _scroll[4],
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onOpenChangelog: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ChangelogPage())),
      ),
    ];

    return Scaffold(
      backgroundColor: c.bgDeep,
      body: Center(
        child: ConstrainedBox(
          // 手机优先：桌面 / 平板窗口里把内容收到手机宽度并居中
          constraints: const BoxConstraints(maxWidth: 460),
          child: SizedBox.expand(
            child: DgutReselectScope(
              notifier: _reselect,
              child: Stack(
                children: [
                  // 背景固定不动 —— 它是"渐进运动"里最慢的一层
                  const Positioned.fill(child: _AmbientBg()),

                  // 页面：PageView 横向切页
                  PageView.builder(
                    controller: _pc,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _ProgressivePage(
                      page: _pagePos,
                      index: i,
                      child: pages[i],
                    ),
                  ),

                  // 底部边缘（在 Dock 之下）
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: _active,
                      builder: (context, _) {
                        final DgutScrollInfo s = _active.value;
                        final double depth = DgutMotion.edgeDepth(s.rest);
                        return DgutEdgeBlur(
                          atTop: false,
                          sigma: DgutMotion.edgeSigma(depth),
                          strength: s.max <= 10
                              ? 0
                              : DgutMotion.edgeStrength(depth),
                        );
                      },
                    ),
                  ),

                  // 顶部边缘：滚过 2px 开始起，18px 内渐强到满（原型的 140ms 过渡）
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: AnimatedBuilder(
                      animation: _active,
                      builder: (context, _) {
                        final DgutScrollInfo s = _active.value;
                        return DgutEdgeBlur(
                          atTop: true,
                          sigma: DgutMotion.edgeSigmaMax,
                          strength: (s.pixels / 18).clamp(0.0, 1.0),
                        );
                      },
                    ),
                  ),

                  // 顶栏
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: AnimatedBuilder(
                      animation: _active,
                      builder: (context, _) => DgutTopBar(
                        title: _titles[_index],
                        offset: _active.value.pixels,
                      ),
                    ),
                  ),

                  // Dock：胶囊自己定宽，居中
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Center(
                      child: DgutDock(
                        items: _dockItems,
                        page: _pagePos,
                        onSelect: _goTo,
                        onReselect: (_) => _reselect.fire(_scroll[_index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 渐进式运动：离当前页越远，缩放越小、越淡、越往上浮
class _ProgressivePage extends StatelessWidget {
  const _ProgressivePage({
    required this.page,
    required this.index,
    required this.child,
  });

  final ValueNotifier<double> page;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: page,
      builder: (context, child) {
        final double d = (index - page.value).clamp(-1.0, 1.0);
        final double a = d.abs();
        return Transform.translate(
          offset: Offset(0, -18 * a),
          child: Transform.scale(
            scale: 1 - 0.04 * a,
            child: Opacity(
              opacity: (1 - 0.35 * a).clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 页面顶部双色柔光（.dg-ambient::before）
class _AmbientBg extends StatelessWidget {
  const _AmbientBg();

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.56, -1.0),
                radius: 0.62,
                colors: [c.ambient1, c.ambient1.withValues(alpha: 0)],
                stops: const [0.0, 0.70],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.72, -0.88),
                radius: 0.56,
                colors: [c.ambient2, c.ambient2.withValues(alpha: 0)],
                stops: const [0.0, 0.72],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
