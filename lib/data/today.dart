/// 首页「今天 / 明天」的数据装配。
///
/// 全部是纯函数：输入课程、学期日历、当前时刻，输出一份 [TodaySnapshot]。
/// 放在 data 层而不是页面 build 里的理由只有一条 —— 时间判断必须能单测。
/// 「09:00 时哪一节正在上」「13:00 午休时上一节算已过、下一节算待上」
/// 「第 2 周时单周课该不该出现」「今天全上完了要不要切明天」这类东西
/// 写在 build 里只能改系统时间去验，写成纯函数一条 case 就够。
///
/// 周次一律走 [TermCalendar.teachingWeekOn] / [teachingWeekdayOn]，
/// 不直接读 `weekOf(date).weekday` —— 调休的周六要按周一的课表上，
/// 直接读真实星期几会把调休那天的课算错。
library;

import '../data/default_periods.dart';
import '../model/course.dart';
import '../model/term_calendar.dart';

enum TodayState { past, now, todo }

/// 某一天的一节课（= 课表里的一段，不是一门课）
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
    required this.showingTomorrow,
    required this.week,
    required this.weekLabel,
    required this.viewWeekday,
    required this.viewDate,
    required this.items,
    required this.next,
    required this.nextDayLabel,
    required this.courseCount,
    required this.slotCount,
    required this.clashLabels,
  });

  /// 当前课表里有没有课（区分"还没建课表"与"这天恰好没课"）
  final bool hasCourses;

  /// 视图落在明天：今天已经没有待上/正在上的课
  final bool showingTomorrow;

  /// 视图日落在第几周；学期之外是 0
  final int week;

  /// `第 11 周` / `未开学` / `假期`
  final String weekLabel;

  /// 视图日是周几（1=周一）。这是真实星期几，不是调休改写后的"按周几上课"
  final int viewWeekday;

  /// 视图日的日期
  final DateTime viewDate;

  /// 视图日要上的课（今天视图带三态；明天视图一律待上）
  final List<TodayClass> items;

  /// 视图日没有课时才用得上：往后找到的第一节
  final TodayClass? next;
  final String nextDayLabel;

  /// 视图日所在周的门数 / 节数
  final int courseCount;
  final int slotCount;

  /// 撞课位置，形如 `周一 1–2`
  final List<String> clashLabels;

  bool get isEmptyDay => items.isEmpty;

  int get pastCount =>
      items.where((TodayClass e) => e.state == TodayState.past).length;

  int get todoCount =>
      items.where((TodayClass e) => e.state == TodayState.todo).length;

  /// 大标题
  String get title => showingTomorrow ? '明天' : '今天';

  /// `周二 · 第 11 周 · 22:41` / `周三 · 11 月 11 日 · 第 11 周`
  ///
  /// 今天视图给时刻（能看出这屏数据有多新）；明天视图给日期
  /// —— 明天的"此刻"没有意义，日期才有。
  String eyebrow(DateTime now) {
    final String head = '周${weekdayLabel(viewWeekday)}';
    if (!showingTomorrow) return '$head · $weekLabel · ${_hhmm(now)}';
    return '$head · ${viewDate.month} 月 ${viewDate.day} 日 · $weekLabel';
  }

  /// 视图日那几节课的起止：`08:30–12:00`
  String get daySpan {
    if (items.isEmpty) return '';
    return '${items.first.startLabel}–${dgutFormatMinutes(items.last.endMinutes)}';
  }

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
/// **视图日怎么定**：今天还有待上或正在上的课 → 今天；否则 → 明天。
/// 「今天全上完了还显示今天」没有信息量，用户这时候真正要的是
/// 「明天几节课、几点开始」。明天也没课时不继续往后跳日子（标题会乱跳），
/// 而是留在明天写「明天没有课」再把下一节给出来。
///
/// [now] 不取 `DateTime.now()` 是为了让调用方决定时刻 —— 页面每 30 秒
/// 重算一次，测试则直接塞一个固定时刻进来。
TodaySnapshot buildToday({
  required List<Course> courses,
  required TermCalendar calendar,
  required DateTime now,
}) {
  final DateTime today = TermCalendar.dateOnly(now);
  final int nowMinutes = now.hour * 60 + now.minute;

  // 先按今天算一遍：只要还有没上完的（正在上也算），视图就留在今天
  final List<TodayClass> todayItems = _classesOn(
    courses: courses,
    calendar: calendar,
    date: today,
    stateOf: (int a, int b) => nowMinutes >= b
        ? TodayState.past
        : (nowMinutes >= a ? TodayState.now : TodayState.todo),
  );
  final bool showingTomorrow = !todayItems.any(
    (TodayClass e) => e.state != TodayState.past,
  );

  final DateTime viewDate = showingTomorrow
      ? today.add(const Duration(days: 1))
      : today;

  final List<TodayClass> items = showingTomorrow
      ? _classesOn(
          courses: courses,
          calendar: calendar,
          date: viewDate,
          // 明天的课一律是"待上"：还没到的日子不存在已过或正在上
          stateOf: (int _, int _) => TodayState.todo,
        )
      : todayItems;

  final int week = calendar.weekOf(viewDate);
  final String weekLabel = week > 0
      ? '第 $week 周'
      : (viewDate.isBefore(TermCalendar.dateOnly(calendar.week1Monday))
            ? '未开学'
            : '假期');

  // 下一节：只有视图日一节课都没有时才需要往后找。
  // 天数一律相对**今天**算，"后天"才是用户视角的后天。
  TodayClass? next;
  String nextDayLabel = '';
  if (items.isEmpty) {
    for (int d = 1; d <= 8 && next == null; d++) {
      final DateTime day = today.add(Duration(days: d));
      final List<TodayClass> found = _classesOn(
        courses: courses,
        calendar: calendar,
        date: day,
        stateOf: (int _, int _) => TodayState.todo,
      );
      if (found.isNotEmpty) {
        next = found.first;
        nextDayLabel = _dayLabel(d, weekdayLabel(day.weekday));
      }
    }
  }

  // 统计跟着视图日走：内容和统计必须同源，否则跨周那晚会自相矛盾
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
    showingTomorrow: showingTomorrow,
    week: week,
    weekLabel: weekLabel,
    viewWeekday: viewDate.weekday,
    viewDate: viewDate,
    items: items,
    next: next,
    nextDayLabel: nextDayLabel,
    courseCount: courseIds.length,
    slotCount: slotCount,
    clashLabels: clashLabels,
  );
}

/// 某一天的全部课，按开始时间排好。
///
/// [stateOf] 决定每一节的三态：今天视图拿真实时刻比，
/// 明天视图一律返回待上。
List<TodayClass> _classesOn({
  required List<Course> courses,
  required TermCalendar calendar,
  required DateTime date,
  required TodayState Function(int startMinutes, int endMinutes) stateOf,
}) {
  final int week = calendar.teachingWeekOn(date);
  // 停课日与学期外都不上课
  if (week == 0) return <TodayClass>[];
  final int weekday = calendar.teachingWeekdayOn(date);

  final List<TodayClass> out = <TodayClass>[];
  for (final Course c in courses) {
    for (final CourseSlot s in c.slots) {
      if (s.weekday != weekday || !s.activeIn(week)) continue;
      final DgutPeriod? first = dgutPeriodAt(s.startSlot);
      final DgutPeriod? last = dgutPeriodAt(s.startSlot + s.slotCount - 1);
      // 节次越界（作息表被改短了）就当这一节不存在，不让首页因为脏数据崩
      if (first == null || last == null) continue;
      final int a = dgutMinutesOf(first.start);
      final int b = dgutMinutesOf(last.end);
      out.add(
        TodayClass(
          course: c,
          slot: s,
          startMinutes: a,
          endMinutes: b,
          state: stateOf(a, b),
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
