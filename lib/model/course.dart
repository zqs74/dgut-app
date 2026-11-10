/// 课表数据模型。
///
/// 两个设计要点（改动前先读 `文档-功能实现路线-2026-11-10-v1.md` §1.1）：
///
/// 1. **一门课挂多段。** 实测教务课表里，「自然语言处理」在周三第 1–2 节与第 3–4 节
///    各出现一次；「形势与政策5」同一格里还有 13–16 周[1-2节] 与 13–16 周[2节] 两段。
///    地点与周次是跟着"段"走的，不跟着课程走，所以 weekday / room / weeks 都在
///    [CourseSlot] 上，[Course] 只留身份信息。
/// 2. **周次用 `List<int>`，不用位图。** 位图只是用来表达"任意周集合"这个语义；
///    dart2js 的位运算只有 32 位宽，64 位 `int` 在 Web 预览上第 33 周以后全错。
///    一学期 20 周、每课几段，列表的性能代价为零，JSON 还能直接看和改。
library;

enum CourseSource {
  manual('手动录入'),
  paste('粘贴导入'),
  jwx('教务读取');

  const CourseSource(this.label);
  final String label;

  static CourseSource fromName(String? name) => CourseSource.values.firstWhere(
        (e) => e.name == name,
        orElse: () => CourseSource.manual,
      );
}

/// 一段上课时间：星期 + 起始节 + 节数 + 周集合 + 地点。
class CourseSlot {
  const CourseSlot({
    required this.weekday,
    required this.startSlot,
    required this.slotCount,
    required this.weeks,
    this.room = '',
  });

  /// 1 = 周一 … 7 = 周日
  final int weekday;

  /// 1 起
  final int startSlot;

  /// 跨几节，实测见过 1 / 2 / 3
  final int slotCount;

  /// 任意周集合（已排序去重）
  final List<int> weeks;

  /// 地点，教务里可能为空（原文是 `地点:()`）
  final String room;

  int get endSlot => startSlot + slotCount - 1;

  bool activeIn(int week) => weeks.contains(week);

  /// "1-16周" / "1-12,14周" / "3周"
  String get weeksLabel => formatWeeks(weeks);

  /// "第1-2节" / "第2节"
  String get slotsLabel =>
      slotCount <= 1 ? '第$startSlot节' : '第$startSlot-$endSlot节';

  CourseSlot copyWith({
    int? weekday,
    int? startSlot,
    int? slotCount,
    List<int>? weeks,
    String? room,
  }) =>
      CourseSlot(
        weekday: weekday ?? this.weekday,
        startSlot: startSlot ?? this.startSlot,
        slotCount: slotCount ?? this.slotCount,
        weeks: weeks ?? this.weeks,
        room: room ?? this.room,
      );

  Map<String, Object?> toJson() => {
        'weekday': weekday,
        'startSlot': startSlot,
        'slotCount': slotCount,
        'weeks': weeks,
        'room': room,
      };

  factory CourseSlot.fromJson(Map<String, dynamic> json) => CourseSlot(
        weekday: (json['weekday'] as num?)?.toInt() ?? 1,
        startSlot: (json['startSlot'] as num?)?.toInt() ?? 1,
        slotCount: (json['slotCount'] as num?)?.toInt() ?? 1,
        weeks: ((json['weeks'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList()
          ..sort(),
        room: (json['room'] as String?) ?? '',
      );
}

/// 一门课（可能有多段）。
class Course {
  Course({
    required this.id,
    required this.name,
    this.teacher = '',
    this.tone = 0,
    this.source = CourseSource.manual,
    required this.slots,
    this.note = '',
  });

  final String id;
  final String name;
  final String teacher;

  /// 0 蓝 / 1 绿 / 2 紫 / 3 橙，决定课块左边线颜色
  final int tone;

  final CourseSource source;
  final List<CourseSlot> slots;

  /// 备注，只有手动录入会填
  final String note;

  static int _seq = 0;

  /// 不引 uuid 包：时间戳 + 进程内序号足够，且跨端一致
  static String newId() {
    _seq = (_seq + 1) % 1000;
    return 'c${DateTime.now().microsecondsSinceEpoch}$_seq';
  }

  /// 一周上几节（同一门课多段会累加）
  int get weeklySlots => slots.fold(0, (sum, s) => sum + s.slotCount);

  bool activeIn(int week) => slots.any((s) => s.activeIn(week));

  String get teacherLabel => teacher.isEmpty ? '—' : teacher;

  /// 所有段的地点的去重集合，详情页用
  List<String> get rooms {
    final out = <String>[];
    for (final s in slots) {
      if (s.room.isNotEmpty && !out.contains(s.room)) out.add(s.room);
    }
    return out;
  }

  Course copyWith({
    String? name,
    String? teacher,
    int? tone,
    CourseSource? source,
    List<CourseSlot>? slots,
    String? note,
  }) =>
      Course(
        id: id,
        name: name ?? this.name,
        teacher: teacher ?? this.teacher,
        tone: tone ?? this.tone,
        source: source ?? this.source,
        slots: slots ?? this.slots,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'tone': tone,
        'source': source.name,
        'slots': slots.map((s) => s.toJson()).toList(),
        'note': note,
      };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: (json['id'] as String?) ?? newId(),
        name: (json['name'] as String?) ?? '',
        teacher: (json['teacher'] as String?) ?? '',
        tone: (json['tone'] as num?)?.toInt() ?? 0,
        source: CourseSource.fromName(json['source'] as String?),
        slots: ((json['slots'] as List?) ?? const [])
            .map((e) => CourseSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: (json['note'] as String?) ?? '',
      );
}

/// 把周集合压成 "1-16周" / "1-12,14周" / "3周"
String formatWeeks(List<int> weeks) {
  if (weeks.isEmpty) return '—';
  final sorted = [...weeks]..sort();
  final parts = <String>[];
  var start = sorted.first;
  var prev = sorted.first;
  for (final w in sorted.skip(1)) {
    if (w == prev + 1) {
      prev = w;
      continue;
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    start = w;
    prev = w;
  }
  parts.add(start == prev ? '$start' : '$start-$prev');
  return '${parts.join(',')}周';
}

/// 网格里一个待画的格子：某门课的某一段
class PlacedSlot {
  const PlacedSlot({required this.course, required this.slot});

  final Course course;
  final CourseSlot slot;

  String get key => '${slot.weekday}:${slot.startSlot}';
}
