import '../model/course.dart';

/// 一次解析的结果：课程 + 认不出的原文（不静默丢）
class JwxParseResult {
  const JwxParseResult({
    required this.courses,
    required this.blockCount,
    required this.issues,
  });

  final List<Course> courses;

  /// 识别到的课块数（同一门课多段会算多个块）
  final int blockCount;

  /// 认不出来的原文行，导入页据此提示"有几条没认出来"
  final List<String> issues;
}

/// 强智 6「学期理论课表」解析器。
///
/// 输入是课表页的 HTML（整页也行，只有表格片段也行）。真实结构：
/// 一行 8 个单元格 = 节次 + 周一…周日，每格里可能挤着好几门课，
/// 每门课三行：课名 / `老师:…;时间:…;地点:…` / 可能再来一段 `时间:…`。
///
/// 这里只做"把 HTML 变成 Course"，不碰网络、不碰存储，方便拿固定样本做单测。
class JwxParser {
  static final RegExp _rowRe = RegExp(
    r'<tr\b[^>]*>(.*?)</tr>',
    dotAll: true,
    caseSensitive: false,
  );
  static final RegExp _cellRe = RegExp(
    r'<t[dh]\b[^>]*>(.*?)</t[dh]>',
    dotAll: true,
    caseSensitive: false,
  );
  static final RegExp _tagRe = RegExp(r'<[^>]+>');
  static final RegExp _breakRe = RegExp(
    r'<br\s*/?>|</p>|</div>',
    caseSensitive: false,
  );
  static final RegExp _timeRe = RegExp(
    r'(\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)周\[(\d+)(?:-(\d+))?节\]',
  );

  static const List<String> _weekdayNames = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  static JwxParseResult parse(String html) {
    final List<String> issues = <String>[];
    final Map<String, Course> merged = <String, Course>{};
    var blocks = 0;

    for (final RegExpMatch row in _rowRe.allMatches(html)) {
      final List<String> cells = <String>[
        for (final RegExpMatch c in _cellRe.allMatches(row.group(1) ?? ''))
          _cellText(c.group(1) ?? ''),
      ];
      if (cells.length < 2) continue;
      if (!cells.any((String t) => t.contains('时间:') || t.contains('时间：'))) {
        continue;
      }

      for (var i = 1; i < cells.length && i <= 7; i++) {
        final List<_Block> parsed = _parseCell(cells[i], issues);
        for (final _Block b in parsed) {
          blocks++;
          final String key = '${b.name}|${b.teacher}';
          final Course? existing = merged[key];
          final List<CourseSlot> slots = <CourseSlot>[
            for (final _Span s in b.spans)
              CourseSlot(
                weekday: i,
                startSlot: s.startSlot,
                slotCount: s.slotCount,
                weeks: s.weeks,
                room: b.room,
              ),
          ];
          if (existing == null) {
            merged[key] = Course(
              id: _idOf(b.name, b.teacher),
              name: b.name,
              teacher: b.teacher,
              tone: _toneOf(b.name),
              source: CourseSource.jwx,
              slots: slots,
            );
          } else {
            existing.slots.addAll(slots);
          }
        }
      }
    }

    final List<Course> courses = merged.values.toList()
      ..sort((Course a, Course b) {
        final CourseSlot? sa = a.slots.isEmpty ? null : a.slots.first;
        final CourseSlot? sb = b.slots.isEmpty ? null : b.slots.first;
        final int byDay = (sa?.weekday ?? 9).compareTo(sb?.weekday ?? 9);
        return byDay != 0
            ? byDay
            : (sa?.startSlot ?? 99).compareTo(sb?.startSlot ?? 99);
      });

    // 页面里同一格可能在隐藏表里重复一遍：完全相同的段只留一条
    for (final Course c in courses) {
      final Set<String> seen = <String>{};
      c.slots.removeWhere((CourseSlot s) {
        final String key =
            '${s.weekday}:${s.startSlot}:${s.slotCount}:${s.weeks.join(',')}:${s.room}';
        return !seen.add(key);
      });
    }
    for (final Course c in courses) {
      c.slots.sort((CourseSlot a, CourseSlot b) {
        final int byDay = a.weekday.compareTo(b.weekday);
        return byDay != 0 ? byDay : a.startSlot.compareTo(b.startSlot);
      });
    }

    return JwxParseResult(courses: courses, blockCount: blocks, issues: issues);
  }

  /// 课表格子里夹着的元信息行（不是课程）：`考核方式: 考查` 之类
  static const List<String> _metaKeys = <String>[
    '考核方式',
    '课程性质',
    '学分',
    '总学时',
    '学时',
    '课程类型',
    '开课学院',
    '授课教师',
    '考试方式',
    '成绩',
    '周学时',
    '起止周',
    '选课人数',
    '上课班级',
    '教学班',
    '课程代码',
    '课程名称',
    '选课课号',
    '校区',
    '考试类型',
    '备注',
  ];

  static bool _isMeta(String line) {
    for (final String key in _metaKeys) {
      if (line.startsWith(key)) return true;
    }
    return false;
  }

  /// 去掉职称尾巴，让同一门课在不同格子里能按"课名 + 老师"合起来
  static String _cleanTeacher(String raw) {
    var s = raw.trim().replaceAll('　', ' ');
    for (final String title in <String>[
      '助理研究员',
      '副研究员',
      '副教授',
      '讲师',
      '助教',
      '教授',
      '研究员',
    ]) {
      if (s.endsWith(title) && s.length > title.length) {
        s = s.substring(0, s.length - title.length);
        break;
      }
    }
    return s.trim();
  }

  /// 一格 → 若干门课。名字行开新块；老师/时间/地点可能挤在同一行，按 ; 拆开逐段认。
  static List<_Block> _parseCell(String text, List<String> issues) {
    final List<_Block> out = <_Block>[];
    _Block? current;

    for (final String raw in text.split('\n')) {
      final String line = raw.trim();
      if (line.isEmpty) continue;

      if (_isField(line)) {
        if (current == null) {
          issues.add(line);
          continue;
        }
        _applyFields(current, line);
        continue;
      }

      // 老师/时间/地点之外的带冒号行（总人数 / 考核方式 / 总学时…）当元信息跳过
      if (_isMeta(line) || line.contains(':') || line.contains('：')) continue;

      // 名字行：也可能是 "课程名 老师:..." 挤在同一行
      int cut = line.indexOf('老师:');
      if (cut < 0) cut = line.indexOf('老师：');
      if (cut > 0) {
        current = _Block(line.substring(0, cut).trim());
        out.add(current);
        _applyFields(current, line.substring(cut));
        continue;
      }

      current = _Block(line);
      out.add(current);
    }

    // 没有时间段的块（多半是表头或说明）丢掉，并记账
    final List<_Block> valid = <_Block>[];
    for (final _Block b in out) {
      if (b.name.isEmpty) continue;
      if (b.spans.isEmpty) {
        if (b.teacher.isNotEmpty || b.room.isNotEmpty) {
          issues.add('${b.name}（缺时间）');
        }
        continue;
      }
      valid.add(b);
    }
    return valid;
  }

  static bool _isField(String line) =>
      line.startsWith('老师') || line.startsWith('时间') || line.startsWith('地点');

  /// 一行里可能有 老师 / 时间 / 地点 三段，也可能同一门课有两段 时间
  static void _applyFields(_Block block, String line) {
    for (final String seg in line.split(RegExp(r'[;；]'))) {
      final String s = seg.trim();
      if (s.isEmpty) continue;
      if (s.startsWith('老师')) {
        block.teacher = _cleanTeacher(_afterColon(s));
      } else if (s.startsWith('时间')) {
        block.spans.addAll(_spansOf(s));
      } else if (s.startsWith('地点')) {
        block.room = _roomOf(_afterColon(s));
      }
    }
  }

  static String _afterColon(String line) {
    final int i = line.indexOf(':');
    final int j = line.indexOf('：');
    final int at = i >= 0 ? i : j;
    return at < 0 ? line : line.substring(at + 1);
  }

  /// `地点:7号楼(7B-311)` → `7B-311`；`地点:()` → 空串；没有括号就原样
  static String _roomOf(String raw) {
    final String cleaned = raw.split(';').first.trim();
    final RegExpMatch? m = RegExp(r'[（(]([^）)]*)[）)]').firstMatch(cleaned);
    if (m != null) return (m.group(1) ?? '').trim();
    return cleaned;
  }

  static List<_Span> _spansOf(String line) {
    final List<_Span> out = <_Span>[];
    for (final RegExpMatch m in _timeRe.allMatches(line)) {
      final List<int> weeks = _weeksOf(m.group(1) ?? '');
      final int start = int.tryParse(m.group(2) ?? '') ?? 0;
      final int end = int.tryParse(m.group(3) ?? '') ?? start;
      if (start <= 0) continue;
      out.add(
        _Span(
          weeks: weeks,
          startSlot: start,
          slotCount: (end - start + 1).clamp(1, 12),
        ),
      );
    }
    return out;
  }

  static List<int> _weeksOf(String raw) {
    final List<int> weeks = <int>[];
    for (final String part in raw.split(',')) {
      final String p = part.trim();
      if (p.isEmpty) continue;
      final int dash = p.indexOf('-');
      if (dash > 0) {
        final int a = int.tryParse(p.substring(0, dash)) ?? 0;
        final int b = int.tryParse(p.substring(dash + 1)) ?? 0;
        if (a > 0 && b >= a) {
          for (var w = a; w <= b; w++) {
            weeks.add(w);
          }
        }
      } else {
        final int w = int.tryParse(p) ?? 0;
        if (w > 0) weeks.add(w);
      }
    }
    weeks.sort();
    return weeks;
  }

  /// 页面里 `<br>` 是换行，其它标签直接抹掉，实体做最小解码
  static String _cellText(String html) => html
      .replaceAll(_breakRe, '\n')
      .replaceAll(_tagRe, '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('\r', '');

  static String _idOf(String name, String teacher) {
    var hash = 0;
    for (final int c in '$name|$teacher'.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return 'jwx${hash.toRadixString(16)}';
  }

  static int _toneOf(String name) {
    var hash = 0;
    for (final int c in name.codeUnits) {
      hash = (hash * 17 + c) & 0x7fffffff;
    }
    return hash % 4;
  }

  static String weekdayLabel(int weekday) =>
      weekday >= 1 && weekday <= 7 ? _weekdayNames[weekday - 1] : '?';
}

class _Span {
  const _Span({
    required this.weeks,
    required this.startSlot,
    required this.slotCount,
  });

  final List<int> weeks;
  final int startSlot;
  final int slotCount;
}

class _Block {
  _Block(this.name);

  final String name;
  String teacher = '';
  String room = '';
  final List<_Span> spans = <_Span>[];
}
