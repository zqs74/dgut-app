import 'package:flutter/foundation.dart';

import '../data/default_term.dart';
import '../model/course.dart';
import '../model/course_override.dart';
import '../model/term_calendar.dart';
import 'store.dart';

/// 课表仓储：唯一的数据入口，页面只跟它打交道。
///
/// 三条约定（改之前想清楚）：
/// 1. **手动录入与教务抓取写的是同一套模型**，否则两个数据源无法合并（方案 §5.4）。
/// 2. **按来源整体替换**：重新抓教务时，只删 `source == jwx` 的旧记录，
///    `manual` / `paste` 一条不动。用户手改过的抓取结果会转成 `manual`。
/// 3. 任何写操作都要 `notifyListeners()`，页面用 `ListenableBuilder` 订阅。
class TimetableRepository extends ChangeNotifier {
  TimetableRepository._();

  static final TimetableRepository instance = TimetableRepository._();

  static const String keyCourses = 'timetable.v1';
  static const String keyTerm = 'term.v1';
  static const String keyOverrides = 'overrides.v1';

  TermCalendar _calendar = defaultTerm();
  final List<Course> _courses = <Course>[];
  final List<CourseOverride> _overrides = <CourseOverride>[];
  bool _loaded = false;

  TermCalendar get calendar => _calendar;
  List<Course> get courses => List<Course>.unmodifiable(_courses);
  List<CourseOverride> get overrides =>
      List<CourseOverride>.unmodifiable(_overrides);
  bool get loaded => _loaded;
  bool get isEmpty => _courses.isEmpty;

  /// 今天在第几周；学期之外是 0
  int get currentWeek => _calendar.weekOf(DateTime.now());

  Future<void> load() async {
    await Store.instance.init();

    final Map<String, dynamic>? term = Store.instance.readJsonObject(keyTerm);
    if (term != null) {
      try {
        _calendar = TermCalendar.fromJson(term);
      } catch (_) {
        // 旧数据坏了就退回默认学期，不让 App 因为一份日历起不来
        _calendar = defaultTerm();
      }
    }

    _courses.clear();
    for (final item in Store.instance.readJsonList(keyCourses) ?? const []) {
      if (item is Map<String, dynamic>) _courses.add(Course.fromJson(item));
    }

    _overrides.clear();
    for (final item in Store.instance.readJsonList(keyOverrides) ?? const []) {
      if (item is Map<String, dynamic>) {
        _overrides.add(CourseOverride.fromJson(item));
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Course? byId(String id) {
    for (final c in _courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _persistCourses() =>
      Store.instance.writeJson(keyCourses, _courses.map((c) => c.toJson()).toList());

  Future<void> _persistOverrides() => Store.instance
      .writeJson(keyOverrides, _overrides.map((o) => o.toJson()).toList());

  /// 新增或整门覆盖（按 id）
  Future<void> upsert(Course course) async {
    final int index = _courses.indexWhere((c) => c.id == course.id);
    if (index >= 0) {
      _courses[index] = course;
    } else {
      _courses.add(course);
    }
    await _persistCourses();
    notifyListeners();
  }

  Future<void> removeCourse(String id) async {
    _courses.removeWhere((c) => c.id == id);
    _overrides.removeWhere((o) => o.courseId == id);
    await _persistCourses();
    await _persistOverrides();
    notifyListeners();
  }

  /// 抓取结果落库：只替换同来源的旧记录，其他来源一条不动
  Future<void> replaceBySource(
    CourseSource source,
    List<Course> incoming,
  ) async {
    _courses.removeWhere((c) => c.source == source);
    _courses.addAll(incoming);
    await _persistCourses();
    notifyListeners();
  }

  Future<void> setCalendar(TermCalendar calendar) async {
    _calendar = calendar;
    await Store.instance.writeJson(keyTerm, calendar.toJson());
    notifyListeners();
  }

  Future<void> setOverride(CourseOverride override) async {
    final int index = _overrides.indexWhere(
      (o) =>
          o.courseId == override.courseId &&
          o.week == override.week &&
          o.slot == override.slot,
    );
    if (index >= 0) {
      _overrides[index] = override;
    } else {
      _overrides.add(override);
    }
    await _persistOverrides();
    notifyListeners();
  }

  Future<void> clearOverride(String courseId, int week, int slot) async {
    _overrides.removeWhere(
      (o) => o.courseId == courseId && o.week == week && o.slot == slot,
    );
    await _persistOverrides();
    notifyListeners();
  }

  /// 某一周要在网格里画的格子
  List<PlacedSlot> layoutOf(int week) {
    final out = <PlacedSlot>[];
    for (final c in _courses) {
      for (final s in c.slots) {
        if (s.activeIn(week)) {
          out.add(PlacedSlot(course: c, slot: s));
        }
      }
    }
    out.sort((a, b) {
      final int byDay = a.slot.weekday.compareTo(b.slot.weekday);
      return byDay != 0 ? byDay : a.slot.startSlot.compareTo(b.slot.startSlot);
    });
    return out;
  }

  /// 该周不上、但整学期存在的段：网格里淡显，用来回答"这门课这周为什么没有"
  List<PlacedSlot> dormantOf(int week) {
    final out = <PlacedSlot>[];
    for (final c in _courses) {
      for (final s in c.slots) {
        if (!s.activeIn(week)) out.add(PlacedSlot(course: c, slot: s));
      }
    }
    return out;
  }

  int courseCountIn(int week) =>
      _courses.where((c) => c.activeIn(week)).length;
  int slotCountIn(int week) =>
      layoutOf(week).fold(0, (sum, p) => sum + p.slot.slotCount);

  /// 撞课处数：同一"星期 + 起始节"上不止一段
  int clashCountIn(int week) {
    final Map<String, int> groups = <String, int>{};
    for (final p in layoutOf(week)) {
      groups.update(p.key, (v) => v + 1, ifAbsent: () => 1);
    }
    return groups.values.where((v) => v > 1).length;
  }

  /// 验收用的**示例**数据（`?seed=1` 触发），只在课表为空时写入。
  ///
  /// 故意是编的，不是真课表：真课表只能靠抓教务或手动录，不能被一份写死的假数据顶替，
  /// 否则以后翻周、撞课、统计全是错的而且看不出来。五门课刚好覆盖五种画法：
  /// 常规两节、撞课两门、只上单周、跨三节、以及"非本周"淡显。
  Future<void> seedDemo() async {
    if (!isEmpty) return;
    CourseSlot slot(int weekday, int start, int count, int from, int to,
            {int step = 1, String room = ''}) =>
        CourseSlot(
          weekday: weekday,
          startSlot: start,
          slotCount: count,
          weeks: [for (var w = from; w <= to; w += step) w],
          room: room,
        );

    _courses.addAll([
      Course(
        id: 'demo1',
        name: '机器学习',
        teacher: '示例教师',
        tone: 1,
        slots: [slot(1, 1, 2, 1, 12, room: '7B-311')],
      ),
      Course(
        id: 'demo2',
        name: '大数据采集与集成技术',
        teacher: '示例教师',
        tone: 0,
        slots: [slot(1, 3, 2, 1, 16, room: '7B-412')],
      ),
      // 与 demo1 撞在同一格（周一第 1–2 节）
      Course(
        id: 'demo3',
        name: '形势与政策5',
        teacher: '示例教师',
        tone: 3,
        slots: [slot(1, 1, 2, 1, 16, room: '7B-211')],
      ),
      // 只上单周：右上角会出现「单」
      Course(
        id: 'demo4',
        name: '单周研讨',
        teacher: '示例教师',
        tone: 2,
        slots: [slot(3, 5, 2, 1, 15, step: 2, room: '6F-202')],
      ),
      // 跨三节，且第 15 周才开始：当前周（11）里应淡显 + 左侧虚线
      Course(
        id: 'demo5',
        name: '后期专题',
        teacher: '示例教师',
        tone: 0,
        slots: [slot(5, 9, 3, 15, 16, room: '6E-207')],
      ),
    ]);
    await _persistCourses();
    notifyListeners();
  }

  /// `?seed=reset`：清掉全部课表与覆盖层（演示数据与自己的数据一起清）
  Future<void> clearCourses() async {
    _courses.clear();
    _overrides.clear();
    await _persistCourses();
    await _persistOverrides();
    notifyListeners();
  }
}
