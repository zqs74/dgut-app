import 'dart:async';

import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../components/dgut_timeline.dart';
import '../data/today.dart';
import '../pages/course_detail_page.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 首页「今天」。
///
/// v0.11.0 起这里不再有写死的值：眉标（星期 / 第几周 / 时刻）、时间线、
/// 今天几节、本周概况全部来自 [TimetableRepository] 与 [buildToday]。
/// 之前那版把「周一 · 第 11 周 · 10:05」和「4 门课 · 18 节」直接写在 build 里，
/// 过了第 11 周就一直在说谎，而且看不出错在哪。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.offset, required this.onOpenTab});

  final ValueNotifier<DgutScrollInfo> offset;

  /// 切到别的 tab：0 首页 / 1 课表 / 2 服务 / 3 消息 / 4 我的
  final ValueChanged<int> onOpenTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 首页显示的是「此刻」，要随钟走：分钟数、三态、今天还剩几节。
  /// 30 秒重建一次就够 —— 分钟级显示用不到秒，太频繁只是白重建整页。
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final TimetableRepository repo = TimetableRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (BuildContext context, Widget? _) {
        final DateTime now = DateTime.now();
        final TodaySnapshot snap = buildToday(
          courses: repo.courses,
          calendar: repo.calendar,
          now: now,
        );

        return DgutPageScaffold(
          eyebrow: snap.eyebrow(now),
          title: snap.title,
          offset: widget.offset,
          footerHeight: 520,
          children: [
            DgutStatLine(
              padding: const EdgeInsets.fromLTRB(
                DgutSpace.pad,
                DgutSpace.s2,
                DgutSpace.pad,
                2,
              ),
              spans: _statSpans(context, snap),
            ),
            const SizedBox(height: DgutSpace.s1),
            if (snap.isEmptyDay)
              _EmptyDay(snap: snap, onTap: () => widget.onOpenTab(1))
            else
              DgutTimeline(
                items: <DgutTimelineItemData>[
                  for (final TodayClass item in snap.items)
                    DgutTimelineItemData(
                      time: item.startLabel,
                      title: item.course.name,
                      subtitle: item.subtitle,
                      state: switch (item.state) {
                        TodayState.past => DgutTimelineState.past,
                        TodayState.now => DgutTimelineState.now,
                        TodayState.todo => DgutTimelineState.todo,
                      },
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CourseDetailPage(courseId: item.course.id),
                        ),
                      ),
                    ),
                ],
              ),
            // 待办：只露最急一条。**这一段仍是占位**，等待办模块（F3 后半）接真数据
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DgutGroupHead(title: '待办', action: '全部 2 条', onAction: () {}),
                  DgutRow(
                    title: '晚归申请未提交',
                    subtitle: '今晚 22:00 截止',
                    tone: DgutRowTone.urgent,
                    showDivider: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            // 本周概况：一行统计，不重复课程清单
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DgutSpace.pad,
                DgutSpace.s1,
                DgutSpace.pad,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DgutGroupHead(
                    title: '本周',
                    action: '查看课表 ›',
                    onAction: () => widget.onOpenTab(1),
                  ),
                  DgutLegend(snap.weekSummary),
                ],
              ),
            ),
            // 控件区：与内容用留白隔开（HIG: differentiate controls from content）
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DgutSpace.pad,
                DgutSpace.s3,
                DgutSpace.pad,
                0,
              ),
              child: Row(
                children: [
                  // 莞工码 / 开热水是微信小程序，去处要等 F4 的微信引导页；
                  // 这两格暂时没有真去处，点下去仍无反应
                  _QuickItem(
                    icon: Icons.qr_code_2_rounded,
                    label: '莞工码',
                    color: c.greenInk,
                  ),
                  const SizedBox(width: 2),
                  _QuickItem(
                    icon: Icons.water_drop_outlined,
                    label: '开热水',
                    color: c.blueInk,
                  ),
                  const SizedBox(width: 2),
                  _QuickItem(
                    icon: Icons.calendar_month_outlined,
                    label: '课表',
                    color: c.orangeInk,
                    onTap: () => widget.onOpenTab(1),
                  ),
                  const SizedBox(width: 2),
                  _QuickItem(
                    icon: Icons.pie_chart_outline_rounded,
                    label: '学分',
                    color: c.violetInk,
                    onTap: () => widget.onOpenTab(4),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 统计行
  ///
  /// 今天：`今天 4 节课 · 已过 2 · 还有 2`（「还有」含正在上的那节，
  /// 否则三个数加起来对不上当天节数）。
  /// 明天：`明天 3 节课 · 08:30–12:00` —— 明天的课还没上，
  /// 「已过 / 还有」没有意义，改成给起止时间。
  ///
  /// 这天没课时这里只说「今天 / 明天没有课」，**下一节交给下面那一行**：
  /// 两处都写一遍，同一句话会在同一屏出现两次。
  List<InlineSpan> _statSpans(BuildContext context, TodaySnapshot snap) {
    if (!snap.hasCourses) {
      return <InlineSpan>[dgutPlain('课表还没建')];
    }
    if (snap.isEmptyDay) {
      return <InlineSpan>[dgutPlain('${snap.title}没有课')];
    }
    if (snap.showingTomorrow) {
      return <InlineSpan>[
        dgutPlain('明天 '),
        dgutStrong(context, '${snap.items.length}'),
        dgutPlain(' 节课 · ${snap.daySpan}'),
      ];
    }
    return <InlineSpan>[
      dgutPlain('今天 '),
      dgutStrong(context, '${snap.items.length}'),
      dgutPlain(' 节课 · 已过 '),
      dgutStrong(context, '${snap.pastCount}'),
      dgutPlain(' · 还有 '),
      dgutStrong(context, '${snap.items.length - snap.pastCount}'),
    ];
  }
}

/// 视图日没课时的占位行。三种情况、三种出路，不能共用一句"暂无数据"：
/// 课表还没建 → 去建；今天没有课 → 等明天；明天也没有课 → 看下一节是哪天。
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.snap, required this.onTap});

  final TodaySnapshot snap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? next = snap.nextSummary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
      child: DgutRow(
        title: snap.hasCourses ? '${snap.title}没有课' : '课表还没建',
        subtitle: !snap.hasCourses
            ? '导入教务课表，或手动添加一门'
            : (next == null ? '这个学期都没有排课' : '下一节 $next'),
        showDivider: false,
        onTap: onTap,
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// 为空表示这一格还没有真去处：此时**不给按压反馈**，
  /// 免得按下去有反应、松手什么都不发生 —— 那比不能点更让人困惑
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 9),
          Text(
            label,
            style: DgutType.caption1.copyWith(
              color: c.ink2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap == null
          ? body
          : DgutPressable(
              onTap: onTap,
              pressedScale: 0.94,
              pressedOpacity: 1,
              pressedFill: c.fill,
              radius: BorderRadius.circular(DgutRadius.r2),
              child: body,
            ),
    );
  }
}
