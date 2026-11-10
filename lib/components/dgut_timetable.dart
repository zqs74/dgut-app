import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/default_periods.dart';
import '../model/course.dart';
import '../model/term_calendar.dart';
import '../theme/dgut_tokens.dart';
import 'dgut_basics.dart';

/// 课表页的尺寸常量。全部落在 8 的倍数上（2px 是课块内缩，不是 gap）。
class DgutTimetableMetrics {
  static const double rowHeight = 48;
  static const double timeAxis = 44;
  static const double inset = 2;
  static const double dayHeader = 44;
}

/// 20 周周条：可滑、可点，当前周黑底，今天所在周带小圆点。
class DgutWeekStrip extends StatefulWidget {
  const DgutWeekStrip({
    super.key,
    required this.week,
    required this.currentWeek,
    required this.weekCount,
    required this.onPick,
  });

  final int week;
  final int currentWeek;
  final int weekCount;
  final ValueChanged<int> onPick;

  @override
  State<DgutWeekStrip> createState() => _DgutWeekStripState();
}

class _DgutWeekStripState extends State<DgutWeekStrip> {
  static const double _step = 44;

  late final ScrollController _sc = ScrollController(
    initialScrollOffset: math
        .max(0, (widget.week - 1) * _step - 120)
        .toDouble(),
  );

  @override
  void didUpdateWidget(covariant DgutWeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 从"回到本周"或周条外翻页进来时，把当前周滚到视野中间
    if (oldWidget.week != widget.week && _sc.hasClients) {
      final double target = (widget.week - 1) * _step - 120;
      _sc.animateTo(
        target.clamp(0, _sc.position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad - 6),
        itemCount: widget.weekCount,
        itemBuilder: (context, i) {
          final int w = i + 1;
          final bool selected = w == widget.week;
          final bool today = w == widget.currentWeek;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: DgutPressable(
              onTap: () => widget.onPick(w),
              pressedOpacity: 1,
              pressedScale: 0.94,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? c.ink : c.fill,
                        borderRadius: BorderRadius.circular(DgutRadius.full),
                      ),
                      child: Text(
                        '$w',
                        style: DgutType.caption1.copyWith(
                          color: selected ? c.bg : c.ink2,
                          height: 1.1,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: today ? c.brand : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 周网格：12 节 × 5–7 天。
///
/// 与旧实现的区别（旧版是 24px 行、每格灰底）：
/// 行高 48、去掉格子底、表头带日期、今天列淡底、一条"现在"线、
/// 同格多课上下各占一半、课块用 9% 强调色底 + 2px 色条。
class DgutTimetableGrid extends StatelessWidget {
  const DgutTimetableGrid({
    super.key,
    required this.active,
    required this.dormant,
    required this.week,
    required this.calendar,
    required this.days,
    required this.isCurrentWeek,
    required this.onTap,
    required this.onAddAt,
  });

  final List<PlacedSlot> active;
  final List<PlacedSlot> dormant;
  final int week;
  final TermCalendar calendar;

  /// 要画的星期（1..7，连续）：5 列 = [1,2,3,4,5]
  final List<int> days;

  final bool isCurrentWeek;
  final ValueChanged<PlacedSlot> onTap;

  /// 长按空白格：带出星期与节次，直接进添加页
  final void Function(int weekday, int slot) onAddAt;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    const double axis = DgutTimetableMetrics.timeAxis;
    const double rh = DgutTimetableMetrics.rowHeight;
    final int rows = dgutPeriodCount;
    final double gridHeight = rows * rh;
    final int today = isCurrentWeek ? DateTime.now().weekday : 0;

    return Padding(
      padding: const EdgeInsets.only(top: DgutSpace.s1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double colW =
              (constraints.maxWidth - DgutSpace.pad * 2 - axis) / days.length;

          final Map<String, List<PlacedSlot>> groups =
              <String, List<PlacedSlot>>{};
          for (final PlacedSlot p in active) {
            groups.putIfAbsent(p.key, () => <PlacedSlot>[]).add(p);
          }

          final List<Widget> overlay = <Widget>[];

          // 今天列淡底
          final int todayIndex = days.indexOf(today);
          if (todayIndex >= 0) {
            overlay.add(
              Positioned(
                left: DgutSpace.pad + axis + todayIndex * colW,
                top: 0,
                width: colW,
                height: gridHeight,
                child: ColoredBox(color: c.fill),
              ),
            );
          }

          // 列线
          for (var i = 1; i < days.length; i++) {
            overlay.add(
              Positioned(
                left: DgutSpace.pad + axis + i * colW,
                top: 0,
                width: 1,
                height: gridHeight,
                child: ColoredBox(color: c.line),
              ),
            );
          }

          // 课块
          groups.forEach((String key, List<PlacedSlot> list) {
            final PlacedSlot first = list.first;
            final int dayIndex = days.indexOf(first.slot.weekday);
            if (dayIndex < 0) return;
            final double top = (first.slot.startSlot - 1) * rh + 1;
            final double height = first.slot.slotCount * rh - 2;
            final double left = DgutSpace.pad + axis + dayIndex * colW + 1;
            final double width = colW - 2;

            if (list.length == 1) {
              overlay.add(
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: DgutCourseBlock(
                    placed: first,
                    width: width,
                    height: height,
                    onTap: () => onTap(first),
                  ),
                ),
              );
              return;
            }

            const double gap = 2;
            final double each =
                (height - gap * (list.length - 1)) / list.length;
            overlay.add(
              Positioned(
                left: left,
                top: top,
                width: width,
                height: height,
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: gap),
                      SizedBox(
                        height: each,
                        child: DgutCourseBlock(
                          placed: list[i],
                          width: width,
                          height: each,
                          grouped: true,
                          onTap: () => onTap(list[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          });

          // 非本周：只填空格，不压本周的课
          for (final PlacedSlot p in dormant) {
            if (groups.containsKey(p.key)) continue;
            final int dayIndex = days.indexOf(p.slot.weekday);
            if (dayIndex < 0) continue;
            overlay.add(
              Positioned(
                left: DgutSpace.pad + axis + dayIndex * colW + 1,
                top: (p.slot.startSlot - 1) * rh + 1,
                width: colW - 2,
                height: p.slot.slotCount * rh - 2,
                child: DgutCourseBlock(
                  placed: p,
                  width: colW - 2,
                  height: p.slot.slotCount * rh - 2,
                  dormant: true,
                  onTap: () => onTap(p),
                ),
              ),
            );
          }

          // 现在线
          final (double r, double t)? nowPos = dgutNowPosition();
          if (isCurrentWeek && todayIndex >= 0 && nowPos != null) {
            final double y = (nowPos.$1 + nowPos.$2) * rh;
            overlay.add(
              Positioned(
                left: DgutSpace.pad + axis + todayIndex * colW + 2,
                top: y - 0.75,
                width: colW - 4,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: c.red,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
            overlay.add(
              Positioned(
                left: DgutSpace.pad + axis + todayIndex * colW,
                top: y - 4.5,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.red.withValues(alpha: 0.18),
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DayHeader(
                days: days,
                axis: axis,
                colW: colW,
                week: week,
                calendar: calendar,
                today: today,
              ),
              SizedBox(
                height: gridHeight + 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (LongPressStartDetails d) {
                    final double dx = d.localPosition.dx - DgutSpace.pad - axis;
                    if (dx < 0) return;
                    final int dayIndex = (dx / colW).floor().clamp(
                      0,
                      days.length - 1,
                    );
                    final int slot =
                        (d.localPosition.dy / rh).floor().clamp(0, rows - 1) +
                        1;
                    onAddAt(days[dayIndex], slot);
                  },
                  child: Stack(
                    children: [
                      // 行：发丝线 + 节次/时间
                      Column(
                        children: [
                          for (var r = 0; r < rows; r++)
                            Container(
                              height: rh,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: c.line, width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: DgutSpace.pad),
                                  SizedBox(
                                    width: axis,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${r + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.1,
                                            fontWeight: FontWeight.w600,
                                            color: c.ink3,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          kDgutPeriods[r].start,
                                          style: TextStyle(
                                            fontSize: 10,
                                            height: 1,
                                            color: c.ink4,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  const SizedBox(width: DgutSpace.pad),
                                ],
                              ),
                            ),
                          Container(height: 1, color: c.line),
                        ],
                      ),
                      ...overlay,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.days,
    required this.axis,
    required this.colW,
    required this.week,
    required this.calendar,
    required this.today,
  });

  final List<int> days;
  final double axis;
  final double colW;
  final int week;
  final TermCalendar calendar;
  final int today;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    const List<String> names = ['一', '二', '三', '四', '五', '六', '日'];
    return SizedBox(
      height: DgutTimetableMetrics.dayHeader,
      child: Row(
        children: [
          const SizedBox(width: DgutSpace.pad),
          SizedBox(width: axis),
          for (final int d in days)
            SizedBox(
              width: colW,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    names[d - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: 0.2,
                      color: d == today ? c.brandInk : c.ink2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _md(calendar.dateOf(week, d)),
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1,
                      color: d == today ? c.brandInk : c.ink4,
                      fontWeight: d == today
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: DgutSpace.pad),
        ],
      ),
    );
  }

  static String _md(DateTime d) => '${d.month}/${d.day}';
}

/// 一块课。
///
/// 结构：2px 左边线 + 9%（暗色 18%）强调色底 + 课名两行 + 备注一行 + 地点一行。
/// 高 < 94 时不显示备注，保证两节块的文字不挤。
class DgutCourseBlock extends StatelessWidget {
  const DgutCourseBlock({
    super.key,
    required this.placed,
    required this.width,
    required this.height,
    required this.onTap,
    this.grouped = false,
    this.dormant = false,
  });

  final PlacedSlot placed;
  final double width;
  final double height;
  final VoidCallback onTap;
  final bool grouped;
  final bool dormant;

  Color _bar(DgutColors c) => switch (placed.course.tone) {
    0 => c.blue,
    1 => c.green,
    2 => c.violet,
    _ => c.orange,
  };

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color bar = _bar(c);
    final Color tint = bar.withValues(alpha: dark ? 0.20 : 0.10);
    final bool showNote =
        !grouped && !dormant && placed.course.note.isNotEmpty && height >= 94;
    final bool showRoom = !grouped && placed.slot.room.isNotEmpty;
    final double nameSize = grouped ? 10.5 : 11;
    final String room = width < 52
        ? placed.slot.room.replaceAll('-', '')
        : placed.slot.room;

    return GestureDetector(
      onTap: onTap,
      // 吞掉长按：长按课块不该触发"长按空白格新建"
      onLongPress: onTap,
      child: Opacity(
        opacity: dormant ? 0.42 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DgutRadius.r1),
          child: Container(
            padding: const EdgeInsets.fromLTRB(5, 5, 3, 5),
            decoration: BoxDecoration(
              color: tint,
              border: Border(
                left: BorderSide(color: bar, width: dormant ? 1.5 : 2),
              ),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placed.course.name,
                      maxLines: grouped ? 1 : 2,
                      overflow: grouped
                          ? TextOverflow.ellipsis
                          : TextOverflow.clip,
                      style: TextStyle(
                        fontSize: nameSize,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: c.ink,
                      ),
                    ),
                    if (showNote) ...[
                      const SizedBox(height: 2),
                      Text(
                        placed.course.note,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: c.ink2,
                        ),
                      ),
                    ],
                    if (showRoom) ...[
                      const SizedBox(height: 2),
                      Text(
                        room,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: c.ink3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
                if (dormant)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Text(
                      '非本周',
                      style: TextStyle(fontSize: 9, color: c.ink3, height: 1.2),
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
