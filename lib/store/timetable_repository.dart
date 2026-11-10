import 'package:flutter/foundation.dart';

import '../data/default_periods.dart';
import '../model/timetable_appearance.dart';
import '../data/default_term.dart';
import '../model/course.dart';
import '../model/course_override.dart';
import '../model/term_calendar.dart';
import '../model/timetable_data.dart';
import 'store.dart';

/// 课表仓储：唯一的数据入口，页面只跟它打交道。
///
/// 四条约定（改之前想清楚）：
/// 1. **手动录入与教务抓取写的是同一套模型**，否则两个数据源无法合并（方案 §5.4）。
/// 2. **按来源整体替换**：重新抓教务时，只删 `source == jwx` 的旧记录，
///    `manual` / `paste` 一条不动。用户手改过的抓取结果会转成 `manual`。
/// 3. **多课表 = 多份 `TimetableData`**：课程、学期锚点、覆盖层一起隔离；
///    切课表换的是整份数据，不是只换课程列表。
/// 4. 任何写操作都要 `notifyListeners()`，页面用 `ListenableBuilder` 订阅。
class TimetableRepository extends ChangeNotifier {
  TimetableRepository._();

  static final TimetableRepository instance = TimetableRepository._();

  /// v1 键只读，用于把老数据迁进 v2；迁完不删，回退还有得救
  static const String keyCourses = 'timetable.v1';
  static const String keyTerm = 'term.v1';
  static const String keyOverrides = 'overrides.v1';

  static const String keyTables = 'tables.v2';
  static const String keyPeriods = 'periods.v1';
  static const String keyPeriodsV2 = 'periods.v2';
  static const String keyAppearance = 'appearance.v1';

  final List<TimetableData> _tables = <TimetableData>[];
  String _activeId = '';
  List<DgutPeriod> _periods = kDgutPeriods;

  /// 固定上课时长：开了之后每节的结束时间由开始时间 + 时长推出来，只改开始时间
  TimetableAppearance _appearance = const TimetableAppearance();
  bool _fixedDuration = true;
  int _durationMinutes = 45;
  bool _loaded = false;

  List<TimetableData> get tables => List<TimetableData>.unmodifiable(_tables);
  String get activeId => _activeId;
  TimetableData get active => _tables.firstWhere(
    (TimetableData t) => t.id == _activeId,
    orElse: () => _tables.first,
  );
  String get activeName => active.name;
  List<DgutPeriod> get periods => _periods;
  bool get fixedDuration => _fixedDuration;
  TimetableAppearance get appearance => _appearance;
  int get durationMinutes => _durationMinutes;

  List<Course> get courses => List<Course>.unmodifiable(active.courses);
  TermCalendar get calendar => active.calendar;
  List<CourseOverride> get overrides =>
      List<CourseOverride>.unmodifiable(active.overrides);

  bool get loaded => _loaded;
  bool get isEmpty => active.courses.isEmpty;

  /// 今天在第几周；学期之外是 0
  int get currentWeek => calendar.weekOf(DateTime.now());

  Future<void> load() async {
    await Store.instance.init();

    _tables.clear();
    final Map<String, dynamic>? v2 = Store.instance.readJsonObject(keyTables);
    if (v2 != null) {
      for (final Object? item in (v2['tables'] as List?) ?? const []) {
        if (item is Map<String, dynamic>) {
          _tables.add(TimetableData.fromJson(item));
        }
      }
      _activeId = (v2['activeId'] as String?) ?? '';
    }

    if (_tables.isEmpty) {
      await _migrateFromV1();
    }
    if (!_tables.any((TimetableData t) => t.id == _activeId)) {
      _activeId = _tables.first.id;
    }

    final Map<String, dynamic>? pv2 = Store.instance.readJsonObject(
      keyPeriodsV2,
    );
    if (pv2 != null) {
      final List<DgutPeriod> parsed = <DgutPeriod>[];
      for (final Object? item in (pv2['list'] as List?) ?? const []) {
        if (item is List && item.length == 2) {
          parsed.add(DgutPeriod('${item[0]}', '${item[1]}'));
        }
      }
      if (parsed.isNotEmpty) _periods = parsed;
      _fixedDuration = (pv2['fixed'] as bool?) ?? true;
      _durationMinutes = (pv2['duration'] as num?)?.toInt() ?? 45;
    } else {
      // 旧版只存了 12 行时间：读进来当作用户自己排过的表
      final List<dynamic>? legacy = Store.instance.readJsonList(keyPeriods);
      if (legacy != null) {
        final List<DgutPeriod> parsed = <DgutPeriod>[];
        for (final Object? item in legacy) {
          if (item is List && item.length == 2) {
            parsed.add(DgutPeriod('${item[0]}', '${item[1]}'));
          }
        }
        if (parsed.isNotEmpty) _periods = parsed;
      }
    }
    DgutClock.set(_periods);
    _appearance = TimetableAppearance.fromJson(
      Store.instance.readJsonObject(keyAppearance),
    );

    _loaded = true;
    notifyListeners();
  }

  /// v1 的单表数据 → v2 的一张「我的课表」。v1 键原样保留，不动。
  Future<void> _migrateFromV1() async {
    TermCalendar calendar = defaultTerm();
    final Map<String, dynamic>? term = Store.instance.readJsonObject(keyTerm);
    if (term != null) {
      try {
        calendar = TermCalendar.fromJson(term);
      } catch (_) {
        calendar = defaultTerm();
      }
    }

    final List<Course> courses = <Course>[];
    for (final Object? item
        in Store.instance.readJsonList(keyCourses) ?? const []) {
      if (item is Map<String, dynamic>) courses.add(Course.fromJson(item));
    }

    final List<CourseOverride> overrides = <CourseOverride>[];
    for (final Object? item
        in Store.instance.readJsonList(keyOverrides) ?? const []) {
      if (item is Map<String, dynamic>) {
        overrides.add(CourseOverride.fromJson(item));
      }
    }

    final TimetableData table = TimetableData(
      id: TimetableData.newId(),
      name: '我的课表',
      calendar: calendar,
      courses: courses,
      overrides: overrides,
    );
    _tables.add(table);
    _activeId = table.id;
    await _persist();
  }

  Future<void> _persist() =>
      Store.instance.writeJson(keyTables, <String, Object?>{
        'activeId': _activeId,
        'tables': _tables.map((TimetableData t) => t.toJson()).toList(),
      });

  // ---- 多课表 ----

  Future<TimetableData> createTable(String name) async {
    final String trimmed = name.trim();
    final TimetableData table = TimetableData(
      id: TimetableData.newId(),
      name: trimmed.isEmpty ? '未命名课表' : trimmed,
      calendar: defaultTerm(),
      courses: <Course>[],
      overrides: <CourseOverride>[],
    );
    _tables.add(table);
    _activeId = table.id;
    await _persist();
    notifyListeners();
    return table;
  }

  Future<void> renameTable(String id, String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;
    for (final TimetableData t in _tables) {
      if (t.id == id) {
        t.name = trimmed;
        break;
      }
    }
    await _persist();
    notifyListeners();
  }

  /// 删除课表。删的是最后一张时不清空列表，而是把这张重置成空白——
  /// 课表不能没有，用户想要的效果（清干净）也保住了。
  Future<void> deleteTable(String id) async {
    if (_tables.length <= 1) {
      final TimetableData only = _tables.firstWhere(
        (TimetableData t) => t.id == id,
        orElse: () => _tables.first,
      );
      only.courses.clear();
      only.overrides.clear();
      only.calendar = defaultTerm();
      only.name = '我的课表';
      await _persist();
      notifyListeners();
      return;
    }
    _tables.removeWhere((TimetableData t) => t.id == id);
    if (_activeId == id) _activeId = _tables.first.id;
    await _persist();
    notifyListeners();
  }

  Future<void> switchTable(String id) async {
    if (!_tables.any((TimetableData t) => t.id == id) || id == _activeId) {
      return;
    }
    _activeId = id;
    await _persist();
    notifyListeners();
  }

  // ---- 作息 ----

  Future<void> _persistPeriods() =>
      Store.instance.writeJson(keyPeriodsV2, <String, Object?>{
        'fixed': _fixedDuration,
        'duration': _durationMinutes,
        'list': <List<String>>[
          for (final DgutPeriod p in _periods) <String>[p.start, p.end],
        ],
      });

  Future<void> setPeriods(List<DgutPeriod> next) async {
    _periods = List<DgutPeriod>.of(next);
    DgutClock.set(_periods);
    await _persistPeriods();
    notifyListeners();
  }

  /// 开了固定时长之后，每节的结束时间统一由开始时间 + 时长推出来
  Future<void> setFixedDuration(bool value) async {
    _fixedDuration = value;
    if (value) _applyDuration();
    DgutClock.set(_periods);
    await _persistPeriods();
    notifyListeners();
  }

  Future<void> setDuration(int minutes) async {
    _durationMinutes = minutes.clamp(20, 180);
    if (_fixedDuration) _applyDuration();
    DgutClock.set(_periods);
    await _persistPeriods();
    notifyListeners();
  }

  /// 节数增减：加的时候接着最后一节的结束时间排，减的时候从末尾删
  Future<void> setPeriodCount(int count) async {
    final int target = count.clamp(1, 16);
    if (target == _periods.length) return;
    final List<DgutPeriod> next = List<DgutPeriod>.of(_periods);
    while (next.length > target) {
      next.removeLast();
    }
    while (next.length < target) {
      final String start = next.isEmpty
          ? '08:30'
          : dgutShift(next.last.end, 10);
      next.add(DgutPeriod(start, dgutShift(start, _durationMinutes)));
    }
    _periods = next;
    DgutClock.set(_periods);
    await _persistPeriods();
    notifyListeners();
  }

  void _applyDuration() {
    _periods = <DgutPeriod>[
      for (final DgutPeriod p in _periods)
        DgutPeriod(p.start, dgutShift(p.start, _durationMinutes)),
    ];
  }

  Future<void> setAppearance(TimetableAppearance next) async {
    _appearance = next;
    await Store.instance.writeJson(keyAppearance, next.toJson());
    notifyListeners();
  }

  Future<void> resetPeriods() async {
    _periods = kDgutPeriods;
    _fixedDuration = true;
    _durationMinutes = 45;
    DgutClock.set(_periods);
    await _persistPeriods();
    notifyListeners();
  }

  // ---- 课程 ----

  Course? byId(String id) {
    for (final Course c in active.courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 新增或整门覆盖（按 id）
  Future<void> upsert(Course course) async {
    final int index = active.courses.indexWhere(
      (Course c) => c.id == course.id,
    );
    if (index >= 0) {
      active.courses[index] = course;
    } else {
      active.courses.add(course);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeCourse(String id) async {
    active.courses.removeWhere((Course c) => c.id == id);
    active.overrides.removeWhere((CourseOverride o) => o.courseId == id);
    await _persist();
    notifyListeners();
  }

  /// 抓取结果落库：只替换同来源的旧记录，其他来源一条不动
  Future<void> replaceBySource(
    CourseSource source,
    List<Course> incoming,
  ) async {
    active.courses.removeWhere((Course c) => c.source == source);
    active.courses.addAll(incoming);
    await _persist();
    notifyListeners();
  }

  Future<void> setCalendar(TermCalendar calendar) async {
    active.calendar = calendar;
    await _persist();
    notifyListeners();
  }

  Future<void> setOverride(CourseOverride override) async {
    final int index = active.overrides.indexWhere(
      (CourseOverride o) =>
          o.courseId == override.courseId &&
          o.week == override.week &&
          o.slot == override.slot,
    );
    if (index >= 0) {
      active.overrides[index] = override;
    } else {
      active.overrides.add(override);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clearOverride(String courseId, int week, int slot) async {
    active.overrides.removeWhere(
      (CourseOverride o) =>
          o.courseId == courseId && o.week == week && o.slot == slot,
    );
    await _persist();
    notifyListeners();
  }

  /// 某一周要在网格里画的格子
  List<PlacedSlot> layoutOf(int week) {
    final List<PlacedSlot> out = <PlacedSlot>[];
    for (final Course c in active.courses) {
      for (final CourseSlot s in c.slots) {
        if (s.activeIn(week)) out.add(PlacedSlot(course: c, slot: s));
      }
    }
    out.sort((PlacedSlot a, PlacedSlot b) {
      final int byDay = a.slot.weekday.compareTo(b.slot.weekday);
      return byDay != 0 ? byDay : a.slot.startSlot.compareTo(b.slot.startSlot);
    });
    return out;
  }

  /// 该周不上、但整学期存在的段：网格里淡显，用来回答"这门课这周为什么没有"
  List<PlacedSlot> dormantOf(int week) {
    final List<PlacedSlot> out = <PlacedSlot>[];
    for (final Course c in active.courses) {
      for (final CourseSlot s in c.slots) {
        if (!s.activeIn(week)) out.add(PlacedSlot(course: c, slot: s));
      }
    }
    return out;
  }

  int courseCountIn(int week) =>
      active.courses.where((Course c) => c.activeIn(week)).length;

  int slotCountIn(int week) =>
      layoutOf(week).fold(0, (int sum, PlacedSlot p) => sum + p.slot.slotCount);

  /// 撞课处数：同一"星期 + 起始节"上不止一段
  int clashCountIn(int week) {
    final Map<String, int> groups = <String, int>{};
    for (final PlacedSlot p in layoutOf(week)) {
      groups.update(p.key, (int v) => v + 1, ifAbsent: () => 1);
    }
    return groups.values.where((int v) => v > 1).length;
  }

  /// 验收用的**示例**数据（`?seed=1` 触发），只在课表为空时写入。
  ///
  /// 故意是编的，不是真课表：真课表只能靠抓教务或手动录，不能被一份写死的假数据顶替，
  /// 否则以后翻周、撞课、统计全是错的而且看不出来。五门课刚好覆盖五种画法：
  /// 常规两节、撞课两门、只上单周、跨三节、以及"非本周"淡显。
  Future<void> seedDemo() async {
    if (!isEmpty) return;
    CourseSlot slot(
      int weekday,
      int start,
      int count,
      int from,
      int to, {
      int step = 1,
      String room = '',
    }) => CourseSlot(
      weekday: weekday,
      startSlot: start,
      slotCount: count,
      weeks: <int>[for (var w = from; w <= to; w += step) w],
      room: room,
    );

    active.courses.addAll(<Course>[
      Course(
        id: 'demo1',
        name: '机器学习',
        teacher: '示例教师',
        tone: 1,
        slots: <CourseSlot>[slot(1, 1, 2, 1, 12, room: '7B-311')],
      ),
      Course(
        id: 'demo2',
        name: '大数据采集与集成技术',
        teacher: '示例教师',
        tone: 0,
        slots: <CourseSlot>[slot(1, 3, 2, 1, 16, room: '7B-412')],
      ),
      Course(
        id: 'demo3',
        name: '形势与政策5',
        teacher: '示例教师',
        tone: 3,
        slots: <CourseSlot>[slot(1, 1, 2, 1, 16, room: '7B-211')],
      ),
      Course(
        id: 'demo4',
        name: '单周研讨',
        teacher: '示例教师',
        tone: 2,
        slots: <CourseSlot>[slot(3, 5, 2, 1, 15, step: 2, room: '6F-202')],
      ),
      Course(
        id: 'demo5',
        name: '后期专题',
        teacher: '示例教师',
        tone: 0,
        slots: <CourseSlot>[slot(5, 9, 3, 15, 16, room: '6E-207')],
      ),
    ]);
    await _persist();
    notifyListeners();
  }

  /// `?seed=reset`：清掉当前课表的全部课程与覆盖层
  Future<void> clearCourses() async {
    active.courses.clear();
    active.overrides.clear();
    await _persist();
    notifyListeners();
  }
}
