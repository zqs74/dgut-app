/// 教务成绩模型与解析。
///
/// 设计要点：**不写死列名**。教务的成绩表各学期列不完全一样
/// （「成绩」/「总成绩」、「学分」/「课程学分」、「考核方式」/「考试性质」），
/// 写死字段的结果是某学期突然全空。这里保留原始行、按候选列名取值，
/// 改版后最多某格变空，一眼看得出来。
library;

import '../services/html_table.dart';

class DgutScore {
  const DgutScore({required this.cells});

  /// 原始「表头名 → 值」
  final Map<String, String> cells;

  /// 按候选列名取值，先精确后模糊
  String pick(List<String> candidates) {
    for (final String key in candidates) {
      for (final MapEntry<String, String> e in cells.entries) {
        if (e.key.contains(key) && e.value.isNotEmpty) return e.value;
      }
    }
    return '';
  }

  String get course => pick(<String>['课程名称', '课程名', '课程']);
  String get score => pick(<String>['总成绩', '最终成绩', '成绩']);
  String get credit => pick(<String>['学分']);
  String get point => pick(<String>['绩点', '学分绩']);
  String get nature => pick(<String>['课程性质', '课程属性', '性质']);
  String get examType => pick(<String>['考试性质', '考核方式', '考试方式']);
  String get term => pick(<String>['开课学期', '学期']);

  /// 分数是否为数字（「优秀」「合格」这类不是）
  bool get isNumeric => double.tryParse(score) != null;

  /// 换算成百分制分数；非数字返回 null
  double? get numericScore => double.tryParse(score);

  /// 行内所有值拼起来，用于搜索
  String get searchText => cells.values.join(' ');
}

class ScoreParser {
  ScoreParser._();

  /// 从整页 HTML 解析成绩列表
  static List<DgutScore> parse(String html) {
    final List<Map<String, String>> rows = HtmlTable.parseAll(html);
    final List<DgutScore> out = <DgutScore>[];
    for (final Map<String, String> row in rows) {
      if (!HtmlTable.isDataRow(row)) continue;
      final DgutScore s = DgutScore(cells: row);
      // 没有课程名的行是表头残留或备注行
      if (s.course.isEmpty) continue;
      out.add(s);
    }
    return out;
  }

  /// 简单统计：门数、加权平均分（只算数字成绩且有学分的）
  static ScoreSummary summarize(List<DgutScore> scores) {
    int count = scores.length;
    double weightSum = 0;
    double scoreWeight = 0;
    for (final DgutScore s in scores) {
      final double? sc = s.numericScore;
      final double? cr = double.tryParse(s.credit);
      if (sc == null) continue;
      final double w = (cr == null || cr <= 0) ? 1.0 : cr;
      weightSum += w;
      scoreWeight += sc * w;
    }
    return ScoreSummary(
      count: count,
      average: weightSum > 0 ? scoreWeight / weightSum : null,
    );
  }
}

class ScoreSummary {
  const ScoreSummary({required this.count, this.average});

  final int count;

  /// 学分加权平均分；没有可用成绩时为 null
  final double? average;
}
