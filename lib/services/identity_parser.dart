/// 从页面文本里认出身份字段。
///
/// 学工系统的「基本信息」页是一张两列表格，`innerText` 里每个单元格用
/// 制表符或换行分隔，形如：
///
/// ```
/// 姓名    张淇森
/// 学号    2024463030442
/// 学院    计算机科学与技术学院
/// ```
///
/// 所以不解析 DOM 结构，而是**按行找中文标签、取它后面第一个词** ——
/// 页面改版换了 class 名也不影响，只要标签还在就还能认。
library;

import '../model/identity.dart';

/// 认不出姓名就返回 null（姓名是唯一必填字段）
DgutIdentity? parseIdentity(String text, {DateTime? now}) {
  if (text.trim().isEmpty) return null;
  final String name = _pick(text, const <String>['姓名', '学生姓名']);
  if (name.isEmpty) return null;
  return DgutIdentity(
    name: name,
    studentId: _pick(text, const <String>['学号', '学生学号']),
    campus: _pick(text, const <String>['校区']),
    college: _pick(text, const <String>['学院', '所在学院', '院系']),
    major: _pick(text, const <String>['专业', '专业名称']),
    grade: _pick(text, const <String>['年级']),
    className: _pick(text, const <String>['班级', '自然班', '行政班']),
    fetchedAt: now ?? DateTime.now(),
  );
}

/// 这些词出现在标签后面时说明那是**另一个标签**，不是值。
///
/// 典型：页面上有「姓名拼音」这一行，按 `姓名` 去匹配会拿到「拼音」。
const Set<String> _labelWords = <String>{
  '学号', '姓名', '性别', '学院', '专业', '年级', '班级', '校区', '民族',
  '政治面貌', '出生日期', '身份证号', '培养层次', '学制', '入学日期',
  '考生号', '拼音', '姓名拼音', '曾用名', '联系电话', '宿舍',
};

String _pick(String text, List<String> labels) {
  final List<String> lines = text.split(RegExp(r'[\r\n]+'));
  for (final String label in labels) {
    for (var i = 0; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty) continue;
      final int at = line.indexOf(label);
      if (at < 0) continue;

      String rest = line.substring(at + label.length);
      rest = rest.replaceFirst(RegExp(r'^[\s:：]+'), '');
      final bool hasValueOnSameLine = rest.trim().isNotEmpty;

      if (hasValueOnSameLine) {
        // 同一行就有东西：是值就取，是另一个标签（如「姓名拼音」的「拼音」）
        // 就放弃这一行 —— 不能往下找，否则会拿到「姓名拼音」的值当姓名
        final String token = _firstToken(rest);
        if (_acceptable(token)) return token;
        continue;
      }

      // 标签独占一行（块级布局）：看紧邻的下一行
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        final String next = lines[j].trim();
        if (next.isEmpty) continue;
        final String token = _firstToken(next);
        if (_acceptable(token)) return token;
        break; // 下一行也不是值，就别猜了
      }
    }
  }
  return '';
}

String _firstToken(String s) {
  for (final String part in s.trim().split(RegExp(r'[\s\u3000]+'))) {
    if (part.isNotEmpty) return part;
  }
  return '';
}

bool _acceptable(String v) =>
    v.isNotEmpty && !_labelWords.contains(v) && v.length <= 40;
