/// 首页「今天」的数据装配。
///
/// 全部是纯函数：输入课程、学期日历、当前时刻，输出一份 [TodaySnapshot]。
/// 放在 data 层而不是页面 build 里的理由只有一条 —— 时间判断必须能单测。
/// 「09:00 时哪一节正在上」「13:00 午休时上一节算已过、下一节算待上」
/// 「第 2 周时单周课该不该出现」这类东西写在 build 里只能改系统时间去验，
/// 写成纯函数一条 case 就够。
///
/// 周次一律走 [TermCalendar.teachingWeekOn] / [teachingWeekdayOn]，
/// 不直接读 `weekOf(date).weekday` —— 调休的周六要按周一的课表上，
/// 直接读真实星期几会把调休那天的课算错。
library;

import '../data/default_periods.dart';
import '../model/course.dart';
import '../model/term_calendar.dart';

enum TodayState { past, now, todo }

/// 今天的一节课（= 课表里的一段，不是一门课）
class TodayClass {
  const TodayClass({
    required this.course,
    required this.slot,
    required this.startMinutes,
    required this.endMinutes,
    required this.state,
  });

  final Course course;
  final CourseSlot slot;

  /// 从 00:00 起的分钟数，比字符串好比较
  final int startMinutes;
  final int endMinutes;
  final TodayState state;

  String get startLabel => dgutFormatMinutes(startMinutes);

  String get spanLabel =>
      '${dgutFormatMinutes(startMinutes)}–${dgutFormatMinutes(endMinutes)}';

  /// 时间线副标题：`7B-311 · 已结束 · 阮奕邦`
  ///
  /// **状态排在教师前面。** 教务里的教师名带职称（"张剑副研究员"），
  /// 排在状态前会把"已结束 / 时间跨度"挤出单行，三态就白做了 ——
  /// 而地点与状态是这一行里最要紧的信息，教师可以截断。
  String get subtitle {
    final List<String> parts = <String>[];
    if (slot.room.isNotEmpty) parts.add(slot.room);
    parts.add(state == TodayState.past ? '已结束' : spanLabel);
    if (course.teacher.isNotEmpty) parts.add(course.teacher);
    return parts.join(' · ');
  }
}

/// 首页一次渲染要用到的全部"真数据"
class TodaySnapshot {
  const TodaySnapshot({
    required this.hasCourses,
    required this.week,
    required this.weekLabel,
    required this.weekday,
    required this.items,
    required this.next,
    required this.nextDayLabel,
    required this.courseCount,
    required this.slotCount,
    required this.clashLabels,
  });

  /// 当前课表里有没有课（区分"还没建课表"与"今天恰好没课"）
  final bool hasCourses;

  /// 真实第几周；学期之外是 0
  final int week;

  /// `第 11 周` / `未开学` / `假期`
  final String weekLabel;

  /// 今天实际星期几（1=周一），用于 eyebrow
  final int weekday;

  final List<TodayClass> items;

  /// 最近要上的一节（含今天剩余与未来 6 天），今天全上完了就是明天
  final TodayClass? next;
  final String nextDayLabel;

  /// 本周（假期时取第 1 周）的门数 / 节数
  final int courseCount;
  final int slotCount;

  /// 撞课位置，形如 `周一 1–2`
  final List<String> clashLabels;

  bool get isEmptyToday => items.isEmpty;

  int get pastCount =>
      items.where((TodayClass e) => e.state == TodayState.past).length;

  int get todoCount =>
      items.where((TodayClass e) => e.state == TodayState.todo).length;

  /// `周二 · 第 11 周 · 14:35`
  String eyebrow(DateTime now) =>
      '周${weekdayLabel(weekday)} · $weekLabel · ${_hhmm(now)}';

  String get clashText {
    if (clashLabels.isEmpty) return '无撞课';
    if (clashLabels.length == 1) return '1 处撞课（${clashLabels.first}）';
    return '${clashLabels.length} 处撞课（${clashLabels.join('、')}）';
  }

  /// 本周概况那一行
  String get weekSummary {
    if (!hasCourses) return '课表为空，去课表页添加课程';
    if (week == 0) return '假期中 · 全学期 $courseCount 门课';
    return '$courseCount 门课 · $slotCount 节 · $clashText';
  }

  /// `明天 08:30 大数据采集与集成技术 · 7B-412`；没有后续课就是 null
  String? get nextSummary {
    final TodayClass? n = next;
    if (n == null) return null;
    final String head = '$nextDayLabel ${n.startLabel} ${n.course.name}';
    return n.slot.room.isEmpty ? head : '$head · ${n.slot.room}';
  }
}

const List<String> _weekdayNames = <String>['一', '二', '三', '四', '五', '六', '日'];

/// 1 → `一`
String weekdayLabel(int weekday) =>
    weekday >= 1 && weekday <= 7 ? _weekdayNames[weekday - 1] : '?';

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 把课表算成首页要显示的东西。
///
/// [now] 不取 `DateTime.now()` 是为了让调用方决定时刻 —— 页面每 30 秒
/// 重算一次，测试则直接塞一个固定时刻进来。
TodaySnapshot buildToday({
  required List<Course> courses,
  required TermCalendar calendar,
  required DateTime now,
}) {
  final int week = calendar.weekOf(now);
  final String weekLabel = week > 0
      ? '第 $week 周'
      : (now.isBefore(TermCalendar.dateOnly(calendar.week1Monday))
            ? '未开学'
            : '假期');

  // 今天按哪一周、周几的课表上：调休日会被改写成"按第 X 周周 Y"
  final int teachWeek = calendar.teachingWeekOn(now);
  final int teachWeekday = calendar.teachingWeekdayOn(now);
  final int nowMinutes = now.hour * 60 + now.minute;

  final List<TodayClass> items = <TodayClass>[];
  if (teachWeek > 0) {
    for (final Course c in courses) {
      for (final CourseSlot s in c.slots) {
        if (s.weekday != teachWeekday) continue;
        if (!s.activeIn(teachWeek)) continue;
        final DgutPeriod? first = dgutPeriodAt(s.startSlot);
        final DgutPeriod? last = dgutPeriodAt(s.startSlot + s.slotCount - 1);
        // 节次越界（作息表被改短了）就当这一节不存在，不让首页因为脏数据崩
        if (first == null || last == null) continue;
        final int a = dgutMinutesOf(first.start);
        final int b = dgutMinutesOf(last.end);
        items.add(
          TodayClass(
            course: c,
            slot: s,
            startMinutes: a,
            endMinutes: b,
            state: nowMinutes >= b
                ? TodayState.past
                : (nowMinutes >= a ? TodayState.now : TodayState.todo),
          ),
        );
      }
    }
    items.sort((TodayClass a, TodayClass b) {
      final int byTime = a.startMinutes.compareTo(b.startMinutes);
      return byTime != 0 ? byTime : a.course.name.compareTo(b.course.name);
    });
  }

  // 下一节：今天剩余的 → 往后 7 天（覆盖到下周同一天，
  // 否则「一周只有周二有课」的课表在周二晚上会算不出下一节）
  TodayClass? next;
  String nextDayLabel = '';
  for (int d = 0; d <= 7 && next == null; d++) {
    final DateTime day = TermCalendar.dateOnly(now).add(Duration(days: d));
    if (d == 0) {
      for (final TodayClass item in items) {
        if (item.state == TodayState.todo) {
          next = item;
          nextDayLabel = '今天';
          break;
        }
      }
      continue;
    }
    final int w = calendar.teachingWeekOn(day);
    if (w == 0) continue;
    final int wd = calendar.teachingWeekdayOn(day);
    final List<TodayClass> found = _classesOn(
      courses: courses,
      week: w,
      weekday: wd,
    );
    if (found.isNotEmpty) {
      next = found.first;
      nextDayLabel = _dayLabel(d, weekdayLabel(wd));
    }
  }

  // 本周统计：工期外用第 1 周，至少让"全学期几门课"是真实的
  final int statWeek = week > 0 ? week : 1;
  final Set<String> courseIds = <String>{};
  final Map<String, int> clashGroups = <String, int>{};
  final Map<String, String> clashLabelOfGroup = <String, String>{};
  int slotCount = 0;
  for (final Course c in courses) {
    for (final CourseSlot s in c.slots) {
      if (!s.activeIn(statWeek)) continue;
      courseIds.add(c.id);
      slotCount += s.slotCount;
      final String key = '${s.weekday}:${s.startSlot}';
      clashGroups.update(key, (int v) => v + 1, ifAbsent: () => 1);
      clashLabelOfGroup[key] ??=
          '周${weekdayLabel(s.weekday)} '
          '${s.startSlot}${s.slotCount <= 1 ? '' : '–${s.endSlot}'}';
    }
  }
  final List<String> clashLabels = <String>[
    for (final MapEntry<String, int> e in clashGroups.entries)
      if (e.value > 1) clashLabelOfGroup[e.key]!,
  ]..sort();

  return TodaySnapshot(
    hasCourses: courses.isNotEmpty,
    week: week,
    weekLabel: weekLabel,
    weekday: now.weekday,
    items: items,
    next: next,
    nextDayLabel: nextDayLabel,
    courseCount: courseIds.length,
    slotCount: slotCount,
    clashLabels: clashLabels,
  );
}

/// 指定"某周某天"的全部课，按开始时间排好
List<TodayClass> _classesOn({
  required List<Course> courses,
  required int week,
  required int weekday,
}) {
  final List<TodayClass> out = <TodayClass>[];
  for (final Course c in courses) {
    for (final CourseSlot s in c.slots) {
      if (s.weekday != weekday || !s.activeIn(week)) continue;
      final DgutPeriod? first = dgutPeriodAt(s.startSlot);
      final DgutPeriod? last = dgutPeriodAt(s.startSlot + s.slotCount - 1);
      if (first == null || last == null) continue;
      out.add(
        TodayClass(
          course: c,
          slot: s,
          startMinutes: dgutMinutesOf(first.start),
          endMinutes: dgutMinutesOf(last.end),
          state: TodayState.todo,
        ),
      );
    }
  }
  out.sort((TodayClass a, TodayClass b) {
    final int byTime = a.startMinutes.compareTo(b.startMinutes);
    return byTime != 0 ? byTime : a.course.name.compareTo(b.course.name);
  });
  return out;
}

/// 1 → `明天`，2 → `后天`，更远 → `周四`
String _dayLabel(int offset, String weekday) => switch (offset) {
  1 => '明天',
  2 => '后天',
  _ => '周$weekday',
};
