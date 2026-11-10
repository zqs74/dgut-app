/// 学期日历：把"第几周"和"哪天"互相换算，并承载调休例外。
///
/// 只有**一个锚点**：第 1 周的周一。所有换算都从它加 7 天步进，
/// 不要引入"开学日期 + 周数表"这种第二真相源 —— 两个锚点迟早对不上。
library;

/// 一天的例外：停课，或按另一周的课表上课（调休）。
class DayException {
  const DayException({
    required this.date,
    this.holiday = false,
    this.followsWeek,
    this.followsWeekday,
    this.note = '',
  });

  final DateTime date;

  /// true = 当天停课
  final bool holiday;

  /// 调课：当天按第 X 周的课表上
  final int? followsWeek;

  /// 调课：取第 X 周的周 Y（1=周一）
  final int? followsWeekday;

  final String note;

  Map<String, Object?> toJson() => {
        'date': date.toIso8601String(),
        'holiday': holiday,
        'followsWeek': followsWeek,
        'followsWeekday': followsWeekday,
        'note': note,
      };

  factory DayException.fromJson(Map<String, dynamic> json) => DayException(
        date: DateTime.parse(json['date'] as String),
        holiday: (json['holiday'] as bool?) ?? false,
        followsWeek: (json['followsWeek'] as num?)?.toInt(),
        followsWeekday: (json['followsWeekday'] as num?)?.toInt(),
        note: (json['note'] as String?) ?? '',
      );
}

class TermCalendar {
  TermCalendar({
    required this.week1Monday,
    this.weekCount = 20,
    this.exceptions = const [],
  });

  /// 第 1 周的周一（只取年月日，时间部分无意义）
  final DateTime week1Monday;

  final int weekCount;
  final List<DayException> exceptions;

  static DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  /// 落在第几周：1..weekCount；学期之外返回 0
  int weekOf(DateTime date) {
    final diff = dateOnly(date).difference(dateOnly(week1Monday)).inDays;
    if (diff < 0) return 0;
    final week = diff ~/ 7 + 1;
    return week > weekCount ? 0 : week;
  }

  DateTime mondayOf(int week) =>
      dateOnly(week1Monday).add(Duration(days: 7 * (week - 1)));

  DateTime dateOf(int week, int weekday) =>
      mondayOf(week).add(Duration(days: weekday - 1));

  /// "11 月 9 日 – 11 月 15 日"
  String rangeLabel(int week) {
    final mon = mondayOf(week);
    final sun = mon.add(const Duration(days: 6));
    return '${mon.month} 月 ${mon.day} 日 – ${sun.month} 月 ${sun.day} 日';
  }

  DayException? exceptionOn(DateTime date) {
    final target = dateOnly(date);
    for (final e in exceptions) {
      if (dateOnly(e.date) == target) return e;
    }
    return null;
  }

  /// 某天实际按哪一周的课表上：调休日返回被调到的周，停课返回 0
  int teachingWeekOn(DateTime date) {
    final ex = exceptionOn(date);
    if (ex != null) {
      if (ex.followsWeek != null) return ex.followsWeek!;
      if (ex.holiday) return 0;
    }
    return weekOf(date);
  }

  /// 某天实际按周几的课表上（调休的周六会返回 1..5 之一）
  int teachingWeekdayOn(DateTime date) {
    final ex = exceptionOn(date);
    if (ex != null && ex.followsWeekday != null) return ex.followsWeekday!;
    return date.weekday;
  }

  TermCalendar copyWith({
    DateTime? week1Monday,
    int? weekCount,
    List<DayException>? exceptions,
  }) =>
      TermCalendar(
        week1Monday: week1Monday ?? this.week1Monday,
        weekCount: weekCount ?? this.weekCount,
        exceptions: exceptions ?? this.exceptions,
      );

  Map<String, Object?> toJson() => {
        'week1Monday': dateOnly(week1Monday).toIso8601String(),
        'weekCount': weekCount,
        'exceptions': exceptions.map((e) => e.toJson()).toList(),
      };

  factory TermCalendar.fromJson(Map<String, dynamic> json) => TermCalendar(
        week1Monday: DateTime.parse(json['week1Monday'] as String),
        weekCount: (json['weekCount'] as num?)?.toInt() ?? 20,
        exceptions: ((json['exceptions'] as List?) ?? const [])
            .map((e) => DayException.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
