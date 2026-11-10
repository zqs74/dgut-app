/// 单节覆盖层：某周某节的临时变更。优先级高于周次集合（方案 §5.4 第三层）。
///
/// F1 只把模型与仓储读写落好，界面上还没有"临时调课"的入口 —— 那一层等主页聚合
/// （F3）能显示"今天按调休上第 X 周的课"时再加，否则加了也没人看得见。
library;

enum OverrideKind {
  room('换教室'),
  teacher('换教师'),
  cancel('停课');

  const OverrideKind(this.label);
  final String label;

  static OverrideKind fromName(String? name) => OverrideKind.values.firstWhere(
        (e) => e.name == name,
        orElse: () => OverrideKind.cancel,
      );
}

class CourseOverride {
  const CourseOverride({
    required this.courseId,
    required this.week,
    required this.slot,
    required this.kind,
    this.value = '',
  });

  final String courseId;

  /// 第几周
  final int week;

  /// 第几节
  final int slot;

  final OverrideKind kind;

  /// 换教室时的新教室、换教师时的新教师；停课时为空
  final String value;

  Map<String, Object?> toJson() => {
        'courseId': courseId,
        'week': week,
        'slot': slot,
        'kind': kind.name,
        'value': value,
      };

  factory CourseOverride.fromJson(Map<String, dynamic> json) => CourseOverride(
        courseId: (json['courseId'] as String?) ?? '',
        week: (json['week'] as num?)?.toInt() ?? 1,
        slot: (json['slot'] as num?)?.toInt() ?? 1,
        kind: OverrideKind.fromName(json['kind'] as String?),
        value: (json['value'] as String?) ?? '',
      );
}
