/// 把 HTML 表格解析成「表头名 → 单元格文本」的行列表。
///
/// **为什么按表头名取值，不按下标**：教务的成绩表列序会变（某学期多一列
/// 「绩点」、某学期没有「考试性质」）。按下标取的话，改版后不会报错，
/// 而是把"学分"读成"成绩"这种静默错位；按表头名取，最多是那一列变空，
/// 一眼能看出来。
///
/// 不引 HTML 解析库：只用正则抓 `<tr>` / `<td>` / `<th>`，教务这几张表结构
/// 简单，够用且零依赖。
library;

class HtmlTable {
  HtmlTable._();

  static final RegExp _tableRe = RegExp(
    r'<table\b[^>]*>(.*?)</table>',
    dotAll: true,
    caseSensitive: false,
  );
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
  static final RegExp _brRe = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final RegExp _spaceRe = RegExp(r'[\s\u00a0]+');

  /// 单元格纯文本：去标签、解实体、折空白
  static String cellText(String raw) {
    String t = raw.replaceAll(_brRe, ' ');
    t = t.replaceAll(_tagRe, ' ');
    t = t
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    return t.replaceAll(_spaceRe, ' ').trim();
  }

  /// 解析整页 HTML 里的第一张（或指定 id 的）表格。
  ///
  /// 表头取「第一行里单元格数 ≥ 3 的那一行」—— 教务表格前面常有
  /// 一行 `colspan` 跨满的标题（"2026-2027 学年第一学期成绩"），
  /// 直接拿第一行当表头会全部错位。
  static List<Map<String, String>> parse(String html, {String? tableId}) {
    final String scope = _pickTable(html, tableId);
    if (scope.isEmpty) return const <Map<String, String>>[];
    return _parseTableScope(scope);
  }

  /// 解析整页里**所有**表格的数据行。
  ///
  /// 教务是 iframe 套娃，把各 frame 的 HTML 拼起来之后页面上不止一张表
  /// （左侧菜单表、筛选条件表、数据表都在），只取第一张必然抓错。
  static List<Map<String, String>> parseAll(String html) {
    final List<Map<String, String>> out = <Map<String, String>>[];
    for (final RegExpMatch m in _tableRe.allMatches(html)) {
      out.addAll(_parseTableScope(m.group(0)!));
    }
    return out;
  }

  static List<Map<String, String>> _parseTableScope(String scope) {
    final List<List<String>> rows = <List<String>>[];
    for (final RegExpMatch r in _rowRe.allMatches(scope)) {
      final List<String> cells = <String>[
        for (final RegExpMatch c in _cellRe.allMatches(r.group(1) ?? ''))
          cellText(c.group(1) ?? ''),
      ];
      if (cells.isNotEmpty) rows.add(cells);
    }
    if (rows.length < 2) return const <Map<String, String>>[];

    int headerIndex = 0;
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].length >= 3) {
        headerIndex = i;
        break;
      }
    }
    final List<String> header = rows[headerIndex];

    final List<Map<String, String>> out = <Map<String, String>>[];
    for (int i = headerIndex + 1; i < rows.length; i++) {
      final List<String> row = rows[i];
      if (row.length < 2) continue;
      final Map<String, String> map = <String, String>{};
      for (int j = 0; j < header.length && j < row.length; j++) {
        final String key = header[j].isEmpty ? 'col$j' : header[j];
        map[key] = row[j];
      }
      out.add(map);
    }
    return out;
  }

  static String _pickTable(String html, String? tableId) {
    if (tableId != null && tableId.isNotEmpty) {
      final RegExp re = RegExp(
        '<table[^>]*id=["\']?${RegExp.escape(tableId)}["\']?[^>]*>.*?</table>',
        dotAll: true,
        caseSensitive: false,
      );
      final RegExpMatch? m = re.firstMatch(html);
      if (m != null) return m.group(0)!;
    }
    final RegExpMatch? first = _tableRe.firstMatch(html);
    return first?.group(0) ?? '';
  }

  /// 该行是否像一条数据（至少两个非空单元格）
  static bool isDataRow(Map<String, String> row) {
    int filled = 0;
    for (final String v in row.values) {
      if (v.isNotEmpty) filled++;
    }
    return filled >= 2;
  }
}
