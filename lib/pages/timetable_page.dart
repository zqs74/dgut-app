import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../components/dgut_timetable.dart';
import '../model/course.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';
import 'course_detail_page.dart';
import 'course_edit_page.dart';
import 'timetable_settings_page.dart';

/// 课表：周视图 + 周条 + 课块详情。
///
/// **为什么不做"左右滑动切周"**：外壳（`DgutShell`）已经是横向 `PageView` 负责切五个
/// tab，页内再嵌一层横向 PageView 会抢手势 —— 滑课表就切不了 tab。所以用周条、
/// 两个箭头和"回到本周"代替，滑手势留给 tab。
///
/// **页面层级**：本页是 L1；课块 → 详情（L2）→ 编辑（L3）；
/// 右上「⋯」→ 课表设置（L2）→ 已添课程（L3）→ 详情（L4）。每层只 pop 一层。
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key, required this.offset});

  final ValueNotifier<DgutScrollInfo> offset;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  /// null = 跟随"今天所在的周"；翻过周之后就不再跟随
  int? _picked;

  TimetableRepository get _repo => TimetableRepository.instance;

  int get _weekCount => _repo.calendar.weekCount;

  int get _week {
    final int now = _repo.currentWeek;
    final int fallback = now == 0 ? 1 : now;
    final int? picked = _picked;
    return (picked ?? fallback).clamp(1, _weekCount);
  }

  /// 要画几天：整学期有周六/周日课才扩列，空周末不付宽度代价
  List<int> get _days {
    var max = 5;
    for (final Course c in _repo.courses) {
      for (final CourseSlot s in c.slots) {
        if (s.weekday > max) max = s.weekday;
      }
    }
    return <int>[for (var d = 1; d <= max; d++) d];
  }

  void _goWeek(int week) {
    setState(() => _picked = week.clamp(1, _weekCount));
  }

  Future<void> _openEdit({
    Course? course,
    int? slotIndex,
    int? weekday,
    int? slot,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CourseEditPage(
          course: course,
          slotIndex: slotIndex,
          initialWeek: _week,
          initialWeekday: weekday,
          initialSlot: slot,
        ),
      ),
    );
  }

  Future<void> _openDetail(PlacedSlot placed) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailPage(
          courseId: placed.course.id,
          focusWeekday: placed.slot.weekday,
          focusStartSlot: placed.slot.startSlot,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TimetableSettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final int week = _week;
        final bool isNow = week == _repo.currentWeek;
        final List<PlacedSlot> active = _repo.layoutOf(week);
        final List<PlacedSlot> dormant = _repo
            .dormantOf(week)
            .where((p) => !active.any((a) => a.key == p.key))
            .toList();
        final double topInset = MediaQuery.viewPaddingOf(context).top;

        return Stack(
          children: [
            Positioned.fill(
              child: DgutPageScaffold(
                eyebrow:
                    '第 $week 周 · '
                    '${_md(_repo.calendar.mondayOf(week))}–'
                    '${_md(_repo.calendar.dateOf(week, 7))}',
                title: '课表',
                offset: widget.offset,
                footerHeight: 240,
                children: [
                  if (_repo.isEmpty)
                    _EmptyState(onAdd: () => _openEdit())
                  else ...[
                    DgutWeekStrip(
                      week: week,
                      currentWeek: _repo.currentWeek,
                      weekCount: _weekCount,
                      onPick: _goWeek,
                    ),
                    DgutTimetableGrid(
                      active: active,
                      dormant: dormant,
                      week: week,
                      calendar: _repo.calendar,
                      days: _days,
                      isCurrentWeek: isNow,
                      onTap: _openDetail,
                      onAddAt: (int weekday, int slot) =>
                          _openEdit(weekday: weekday, slot: slot),
                    ),
                    _statsLine(context, week),
                  ],
                ],
              ),
            ),
            // 页头操作：⋯ 课表设置 / ＋ 添加课程。固定在右上，随页面滚动不动
            Positioned(
              right: DgutSpace.pad,
              top: topInset + 22,
              child: Row(
                children: [
                  _HeaderAction(
                    icon: Icons.more_horiz_rounded,
                    onTap: _openSettings,
                    label: '课表设置',
                  ),
                  const SizedBox(width: 8),
                  _HeaderAction(
                    icon: Icons.add_rounded,
                    onTap: () => _openEdit(),
                    primary: true,
                    label: '添加课程',
                  ),
                ],
              ),
            ),
            if (!isNow)
              Positioned(
                left: 0,
                right: 0,
                bottom: 100,
                child: Center(
                  child: _GlassButton(
                    label: '回到本周',
                    onTap: () => _goWeek(_repo.currentWeek),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _md(DateTime d) => '${d.month}/${d.day}';

  Widget _statsLine(BuildContext context, int week) {
    final int courses = _repo.courseCountIn(week);
    final int slots = _repo.slotCountIn(week);
    final int clash = _repo.clashCountIn(week);
    return DgutStatLine(
      padding: const EdgeInsets.fromLTRB(
        DgutSpace.pad,
        DgutSpace.s2,
        DgutSpace.pad,
        0,
      ),
      spans: [
        dgutPlain('本周 '),
        dgutStrong(context, '$courses'),
        dgutPlain(' 门课 · 共 '),
        dgutStrong(context, '$slots'),
        dgutPlain(' 节'),
        if (clash > 0) ...[
          dgutPlain(' · '),
          dgutStrong(context, '$clash'),
          dgutPlain(' 处撞课'),
        ],
      ],
    );
  }
}

/// 与 Dock 同材质的浮起胶囊：同样的玻璃、发丝边和阴影。
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 1,
      pressedScale: 0.95,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DgutRadius.full),
          boxShadow: dark ? DgutShadows.floatDark : DgutShadows.float,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DgutRadius.full),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: c.glassDock.withValues(alpha: dark ? 0.55 : 0.52),
                borderRadius: BorderRadius.circular(DgutRadius.full),
                border: Border.all(color: c.glassEdge, width: 1),
              ),
              child: Text(
                label,
                style: DgutType.caption1.copyWith(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
    required this.label,
    this.primary = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Semantics(
      button: true,
      label: label,
      child: DgutPressable(
        onTap: onTap,
        pressedOpacity: 1,
        pressedScale: 0.92,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary ? c.blue : c.fill,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: primary ? Colors.white : c.ink2),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DgutSpace.pad,
        DgutSpace.s5,
        DgutSpace.pad,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('还没有课表', style: DgutType.title2.copyWith(color: c.ink)),
          const SizedBox(height: DgutSpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: DgutButton(
              label: '添加第一门课',
              variant: DgutButtonVariant.filled,
              icon: const Icon(Icons.add_rounded, size: 17),
              onTap: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}
