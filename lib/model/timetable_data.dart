import '../data/default_term.dart';
import 'course.dart';
import 'course_override.dart';
import 'term_calendar.dart';

/// 一张课表：课程 + 学期锚点 + 覆盖层。
///
/// 多课表的隔离边界就是它 —— 切换课表换的是这个对象，科目、周次、当前周一起换，
/// 而不是只换一份课程列表。
class TimetableData {
  TimetableData({
    required this.id,
    required this.name,
    required this.calendar,
    required this.courses,
    required this.overrides,
  });

  final String id;
  String name;
  TermCalendar calendar;
  final List<Course> courses;
  final List<CourseOverride> overrides;

  static int _seq = 0;

  static String newId() {
    _seq = (_seq + 1) % 1000;
    return 't${DateTime.now().microsecondsSinceEpoch}$_seq';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'calendar': calendar.toJson(),
    'courses': courses.map((c) => c.toJson()).toList(),
    'overrides': overrides.map((o) => o.toJson()).toList(),
  };

  factory TimetableData.fromJson(Map<String, dynamic> json) {
    TermCalendar calendar;
    try {
      final Object? raw = json['calendar'];
      calendar = raw is Map<String, dynamic>
          ? TermCalendar.fromJson(raw)
          : defaultTerm();
    } catch (_) {
      calendar = defaultTerm();
    }
    return TimetableData(
      id: (json['id'] as String?) ?? newId(),
      name: (json['name'] as String?) ?? '我的课表',
      calendar: calendar,
      courses: <Course>[
        for (final Object? item in (json['courses'] as List?) ?? const [])
          if (item is Map<String, dynamic>) Course.fromJson(item),
      ],
      overrides: <CourseOverride>[
        for (final Object? item in (json['overrides'] as List?) ?? const [])
          if (item is Map<String, dynamic>) CourseOverride.fromJson(item),
      ],
    );
  }
}
