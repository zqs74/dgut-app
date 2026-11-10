import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_course_sheet.dart';
import '../components/dgut_page_scaffold.dart';
import '../model/course.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';
import 'course_edit_page.dart';

/// 课表：周视图 + 周次条 + 课块详情。
///
/// **为什么不做"左右滑动切周"**：外壳（`DgutShell`）已经是横向 `PageView` 负责切五个
/// tab，页内再嵌一层横向 PageView 会抢手势 —— 滑课表就切不了 tab。所以用
/// "‹ 第 N 周 ›" 加周次选择浮层代替，滑手势留给 tab。
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

  int get _week {
    final int now = _repo.currentWeek;
    final int fallback = now == 0 ? 1 : now;
    final int? picked = _picked;
    if (picked == null) return fallback.clamp(1, _repo.calendar.weekCount);
    return picked.clamp(1, _repo.calendar.weekCount);
  }

  void _goWeek(int week) {
    setState(() => _picked = week.clamp(1, _repo.calendar.weekCount));
  }

  Future<void> _openEdit({Course? course, int? slotIndex}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CourseEditPage(
          course: course,
          slotIndex: slotIndex,
          initialWeek: _week,
        ),
      ),
    );
  }

  Future<void> _openDetail(PlacedSlot placed) async {
    final Course course = placed.course;
    final int index = course.slots.indexWhere(
      (s) => s.weekday == placed.slot.weekday && s.startSlot == placed.slot.startSlot,
    );
    final CourseSheetAction? action = await showCourseSheet(
      context,
      course: course,
      focusIndex: index < 0 ? 0 : index,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case CourseSheetEdit(:final int slotIndex):
        await _openEdit(course: course, slotIndex: slotIndex);
      case CourseSheetAdd():
        await _openEdit(course: course);
      case CourseSheetDelete():
        await _repo.removeCourse(course.id);
    }
  }

  Future<void> _pickWeek(int current) async {
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (ctx) {
        final DgutColors c = ctx.dg;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                DgutSpace.s2, 0, DgutSpace.s2, DgutSpace.s2),
            child: Container(
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(DgutRadius.r4),
                boxShadow:
                    DgutShadows.forBrightness(Theme.of(ctx).brightness),
              ),
              padding: const EdgeInsets.fromLTRB(
                  DgutSpace.pad, DgutSpace.s3, DgutSpace.pad, DgutSpace.s3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('选周', style: DgutType.title3.copyWith(color: c.ink)),
                  const SizedBox(height: DgutSpace.s3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var w = 1; w <= _repo.calendar.weekCount; w++)
                        _WeekCell(
                          week: w,
                          selected: w == current,
                          isNow: w == _repo.currentWeek,
                          onTap: () => Navigator.of(ctx).pop(w),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) _goWeek(picked);
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

        return DgutPageScaffold(
          eyebrow: _repo.calendar.rangeLabel(week),
          title: '课表',
          offset: widget.offset,
          footerHeight: 240,
          children: [
            if (_repo.isEmpty)
              _EmptyState(onAdd: () => _openEdit())
            else ...[
              _weekStrip(context, week, isNow),
              _TimetableGrid(
                active: active,
                dormant: dormant,
                highlightWeekday: isNow ? DateTime.now().weekday : 0,
                onTap: _openDetail,
              ),
              _statsLine(context, week),
              Padding(
                padding: const EdgeInsets.only(
                    top: DgutSpace.s3, bottom: DgutSpace.s1),
                child: Center(
                  child: DgutButton(
                    label: '添加课程',
                    variant: DgutButtonVariant.plain,
                    size: DgutButtonSize.sm,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    onTap: () => _openEdit(),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _weekStrip(BuildContext context, int week, bool isNow) {
    final DgutColors c = context.dg;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DgutSpace.pad - 6, DgutSpace.s2, DgutSpace.pad - 6, DgutSpace.s1),
      child: Row(
        children: [
          _WeekArrow(
            icon: Icons.chevron_left_rounded,
            onTap: week > 1 ? () => _goWeek(week - 1) : null,
          ),
          Expanded(
            child: DgutPressable(
              onTap: () => _pickWeek(week),
              pressedOpacity: 0.6,
              child: Column(
                children: [
                  Text('第 $week 周',
                      style: DgutType.headline.copyWith(color: c.ink)),
                  const SizedBox(height: 2),
                  Text(
                    isNow
                        ? '${_repo.calendar.rangeLabel(week)} · 本周'
                        : _repo.calendar.rangeLabel(week),
                    style: DgutType.caption1.copyWith(
                      color: isNow ? c.blueInk : c.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _WeekArrow(
            icon: Icons.chevron_right_rounded,
            onTap: week < _repo.calendar.weekCount
                ? () => _goWeek(week + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _statsLine(BuildContext context, int week) {
    final int courses = _repo.courseCountIn(week);
    final int slots = _repo.slotCountIn(week);
    final int clash = _repo.clashCountIn(week);
    return DgutStatLine(
      padding:
          const EdgeInsets.fromLTRB(DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, 0),
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

class _WeekArrow extends StatelessWidget {
  const _WeekArrow({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool enabled = onTap != null;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 0.5,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          size: 22,
          color: enabled ? c.ink2 : c.ink4,
        ),
      ),
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({
    required this.week,
    required this.selected,
    required this.isNow,
    required this.onTap,
  });

  final int week;
  final bool selected;
  final bool isNow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 1,
      pressedScale: 0.94,
      child: Container(
        width: 42,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.ink : c.fill,
          borderRadius: BorderRadius.circular(DgutRadius.r1),
        ),
        child: Text(
          isNow ? '$week · 本周' : '$week',
          style: DgutType.caption1.copyWith(
            color: selected ? c.bg : (isNow ? c.blueInk : c.ink2),
            fontWeight: selected || isNow ? FontWeight.w600 : FontWeight.w400,
          ),
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
          DgutSpace.pad, DgutSpace.s5, DgutSpace.pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('还没有课表', style: DgutType.title2.copyWith(color: c.ink)),
          const SizedBox(height: 10),
          DgutLegend(
            '手动加一门课只要填四项：课程名、星期、节次、上课周。'
            '之后可以再从教务直接读取，读到的会先进预览页给你核对。',
          ),
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

/// 12 节 × 7 天网格。像素参数照原型 `.tt` / `.cr`（gap 3、行高 24、节次列 22）。
class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({
    required this.active,
    required this.dormant,
    required this.highlightWeekday,
    required this.onTap,
  });

  final List<PlacedSlot> active;
  final List<PlacedSlot> dormant;

  /// 0 = 不高亮；本周时才高亮今天那一列
  final int highlightWeekday;

  final ValueChanged<PlacedSlot> onTap;

  static const double _rh = 24;
  static const double _gap = 3;
  static const double _lab = 22;
  static const int _rows = 12;
  static const int _cols = 7;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    const List<String> heads = ['一', '二', '三', '四', '五', '六', '日'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tw =
              (constraints.maxWidth - _lab - _gap * _cols) / _cols;
          final double gridH = _rows * (_rh + _gap) - _gap;

          // 同一"星期 + 起始节"上的多段视为撞课：按原型半高叠放
          final Map<String, List<PlacedSlot>> groups = <String, List<PlacedSlot>>{};
          for (final p in active) {
            groups.putIfAbsent(p.key, () => <PlacedSlot>[]).add(p);
          }

          final List<Widget> blocks = <Widget>[];

          for (final List<PlacedSlot> list in groups.values) {
            final int n = list.length;
            for (var i = 0; i < n; i++) {
              final PlacedSlot p = list[i];
              final double baseTop = (p.slot.startSlot - 1) * (_rh + _gap) + 1;
              final double blockH = n == 1
                  ? p.slot.slotCount * _rh + (p.slot.slotCount - 1) * _gap - 2
                  : _rh / n - 2;
              blocks.add(Positioned(
                left: _lab + _gap + (p.slot.weekday - 1) * (tw + _gap) + 1,
                top: n == 1 ? baseTop : baseTop + i * (_rh / n),
                width: tw - 2,
                height: blockH,
                child: _CourseBlock(
                  placed: p,
                  clash: n > 1,
                  narrow: tw < 46,
                  onTap: () => onTap(p),
                ),
              ));
            }
          }

          for (final PlacedSlot p in dormant) {
            final double top = (p.slot.startSlot - 1) * (_rh + _gap) + 1;
            final double height =
                p.slot.slotCount * _rh + (p.slot.slotCount - 1) * _gap - 2;
            blocks.add(Positioned(
              left: _lab + _gap + (p.slot.weekday - 1) * (tw + _gap) + 1,
              top: top,
              width: tw - 2,
              height: height,
              child: _CourseBlock(
                placed: p,
                clash: false,
                narrow: tw < 46,
                dormant: true,
                onTap: () => onTap(p),
              ),
            ));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: _lab),
                  for (var i = 0; i < _cols; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: i == 0 ? _gap : _gap / 2, right: _gap / 2),
                        child: Text(
                          heads[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: (i + 1) == highlightWeekday
                                ? c.blueInk
                                : c.ink3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: gridH,
                child: Stack(
                  children: [
                    for (var r = 0; r < _rows; r++) ...[
                      Positioned(
                        left: 0,
                        width: _lab,
                        top: r * (_rh + _gap),
                        height: _rh,
                        child: Text(
                          '${r + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            height: _rh / 9,
                            color: c.ink4,
                          ),
                        ),
                      ),
                      for (var day = 0; day < _cols; day++)
                        Positioned(
                          left: _lab + _gap + day * (tw + _gap),
                          top: r * (_rh + _gap),
                          width: tw,
                          height: _rh,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.fill,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                    ],
                    ...blocks,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.placed,
    required this.clash,
    required this.narrow,
    required this.onTap,
    this.dormant = false,
  });

  final PlacedSlot placed;
  final bool clash;
  final bool narrow;
  final VoidCallback onTap;

  /// 非本周：整块压到 34% 不透明 + 左边线改虚线
  final bool dormant;

  Color _lineColor(DgutColors c) => switch (placed.course.tone) {
        0 => c.blue,
        1 => c.green,
        2 => c.violet,
        _ => c.orange,
      };

  /// 只有"单周 / 双周"值得标，其余不占位置
  String get _weekMark {
    final List<int> weeks = placed.slot.weeks;
    if (weeks.length < 2) return '';
    if (weeks.every((w) => w.isOdd)) return '单';
    if (weeks.every((w) => w.isEven)) return '双';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final Color line = _lineColor(c);

    if (clash) {
      // 撞课格只有 10px 高：一行小字 + 色条，不放教室与周次
      return Opacity(
        opacity: dormant ? 0.34 : 1,
        child: DgutPressable(
          onTap: onTap,
          pressedOpacity: 0.7,
          child: Container(
            padding: const EdgeInsets.fromLTRB(5, 0, 2, 0),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: c.fill,
              borderRadius: BorderRadius.circular(4),
              border: Border(left: BorderSide(color: line, width: 2)),
            ),
            child: Text(
              placed.course.name,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 7.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: dormant ? 0.34 : 1,
      child: DgutPressable(
        onTap: onTap,
        pressedScale: 0.955,
        pressedOpacity: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: EdgeInsets.fromLTRB(narrow ? 6 : 8, 5, narrow ? 3 : 6, 5),
            decoration: BoxDecoration(
              color: c.fill,
              border: dormant
                  ? null
                  : Border(left: BorderSide(color: line, width: 3)),
            ),
            child: Stack(
              children: [
                if (dormant)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 3,
                    child: CustomPaint(painter: _DashedLine(line)),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      placed.course.name,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: narrow ? 9 : 9.5,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        height: 1.2,
                      ),
                    ),
                    if (placed.slot.room.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        placed.slot.room,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 8.5,
                          color: c.ink3,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_weekMark.isNotEmpty)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Text(
                      _weekMark,
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        color: c.ink3,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 左侧虚线：非本周课的标记（实线 = 这周上，虚线 = 这周不上）
class _DashedLine extends CustomPainter {
  _DashedLine(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.butt;
    const double dash = 3;
    const double gap = 2.5;
    var y = 0.0;
    while (y < size.height) {
      final double end = (y + dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(1.5, y), Offset(1.5, end), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLine oldDelegate) =>
      oldDelegate.color != color;
}
