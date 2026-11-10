/// 登录后的身份信息。
///
/// 来源是学工系统（`stu.dgut.edu.cn`）的「基本信息」页 —— 那是全校唯一
/// 一处把这些字段排在一张表里的地方。App 不向任何自己的服务器上传它，
/// 也不读任何凭据：只在登录后从**用户自己已经登录的页面**上读一次，
/// 存本机，退出登录时清掉。
library;

class DgutIdentity {
  const DgutIdentity({
    required this.name,
    this.studentId = '',
    this.campus = '',
    this.college = '',
    this.major = '',
    this.grade = '',
    this.className = '',
    required this.fetchedAt,
  });

  /// 姓名（唯一必填字段：抓到它就说明登录成功且页面认得出来）
  final String name;

  /// 学号
  final String studentId;

  /// 校区
  final String campus;

  /// 学院
  final String college;

  /// 专业
  final String major;

  /// 年级，如 `2024`
  final String grade;

  /// 班级（自然班）
  final String className;

  /// 抓到这份信息的时间，用来在页面上标"数据截至"
  final DateTime fetchedAt;

  /// 头像里那个字
  String get initial => name.isEmpty ? '?' : name.characters.first;

  /// `2024463030442 · 数据科学与大数据技术`；缺字段时自动少写一段
  String get subtitle {
    final List<String> parts = <String>[
      if (studentId.isNotEmpty) studentId,
      if (major.isNotEmpty) major,
    ];
    return parts.isEmpty ? '莞工统一身份认证' : parts.join(' · ');
  }

  /// `计算机科学与技术学院 · 2024级 · 大数据2班`
  String get detail {
    final List<String> parts = <String>[
      if (college.isNotEmpty) college,
      if (grade.isNotEmpty) '$grade级',
      if (className.isNotEmpty) className,
    ];
    return parts.join(' · ');
  }

  DgutIdentity copyWith({
    String? name,
    String? studentId,
    String? campus,
    String? college,
    String? major,
    String? grade,
    String? className,
    DateTime? fetchedAt,
  }) => DgutIdentity(
    name: name ?? this.name,
    studentId: studentId ?? this.studentId,
    campus: campus ?? this.campus,
    college: college ?? this.college,
    major: major ?? this.major,
    grade: grade ?? this.grade,
    className: className ?? this.className,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'studentId': studentId,
    'campus': campus,
    'college': college,
    'major': major,
    'grade': grade,
    'className': className,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory DgutIdentity.fromJson(Map<String, dynamic> json) => DgutIdentity(
    name: (json['name'] as String?) ?? '',
    studentId: (json['studentId'] as String?) ?? '',
    campus: (json['campus'] as String?) ?? '',
    college: (json['college'] as String?) ?? '',
    major: (json['major'] as String?) ?? '',
    grade: (json['grade'] as String?) ?? '',
    className: (json['className'] as String?) ?? '',
    fetchedAt:
        DateTime.tryParse((json['fetchedAt'] as String?) ?? '') ??
        DateTime.now(),
  );
}

/// `.characters` 的最小替代：只取第一个字形，不引 characters 包。
extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
