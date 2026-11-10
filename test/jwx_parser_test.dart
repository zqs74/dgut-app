import 'package:dgut_app/model/course.dart';
import 'package:dgut_app/services/jwx_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用 2026-11-10 抓到的真实课块原文拼一张课表页，覆盖六种写法。
const List<(int, String)> _blocks = <(int, String)>[
  (1, '机器学习<br>老师:阮奕邦讲师;时间:1-12周[1-2节];地点:7号楼(7B-311)'),
  (3, '机器学习<br>老师:阮奕邦讲师;时间:1-12周[3-4节];地点:7号楼(7B-311)'),
  (2, '大数据技术<br>老师:刘志刚助理研究员;时间:1-12周[1-2节];地点:7号楼(7B-408)'),
  (2, '大数据技术<br>老师:刘志刚助理研究员;时间:1-12周[3-4节];地点:7号楼(7B-408)'),
  (3, '华为认证HCIA-BD<br>老师:万宇晴讲师;时间:1-14周[1-2节];地点:()'),
  (3, '华为认证HCIA-BD<br>老师:万宇晴讲师;时间:1-14周[3-4节];地点:()'),
  (
    4,
    '自然语言处理<br>老师:张剑副研究员;时间:1-12周[1-2节];地点:7号楼(7B-411)'
        '<br>形势与政策5<br>老师:谢浩然助教;时间:13-16周[1-2节];地点:7号楼(7B-211)'
  ),
  (5, '形势与政策5<br>老师:谢浩然助教;时间:13-16周[2节];地点:()'),
  (2, '大数据采集与集成技术<br>老师:肖禹亭;时间:1-16周[3-4节];地点:7号楼(7B-412)'),
  (5, 'Python数据分析与应用<br>老师:万宇晴讲师;时间:1-16周[5-7节];地点:6号楼F座(6F-202)'),
  (
    6,
    '（面授公选）影像中的涉外民事权益法律保护<br>老师:王敬华副教授;'
        '时间:2-11周[9-11节];地点:6号楼E座(6E-207)'
        '<br>时间:12周[9-10节];地点:6号楼E座(6E-207)'
  ),
];

String _page() {
  final StringBuffer rows = StringBuffer();
  for (final (int weekday, String cell) in _blocks) {
    final List<String> cells = List<String>.filled(8, '');
    cells[0] = '1';
    cells[weekday] = cell;
    rows.write('<tr>${cells.map((String c) => '<td>$c</td>').join()}</tr>');
  }
  return '<html><body><table id="timetable"><tbody>$rows</tbody></table></body></html>';
}

void main() {
  test('真实课块：8 门课 / 12 个时间段', () {
    final JwxParseResult r = JwxParser.parse(_page());
    expect(r.courses.length, 8);
    expect(r.blockCount, 12);
    final List<String> names =
        r.courses.map((Course c) => c.name).toList();
    expect(names, contains('机器学习'));
    expect(names, contains('华为认证HCIA-BD'));
    expect(names, contains('（面授公选）影像中的涉外民事权益法律保护'));
  });

  test('单节、单周、跨三节都按原样落成 slotCount', () {
    final JwxParseResult r = JwxParser.parse(_page());
    Course? find(String name) =>
        r.courses.where((Course c) => c.name == name).firstOrNull;

    final Course huawei = find('华为认证HCIA-BD')!;
    expect(huawei.slots.length, 2);
    expect(huawei.slots.first.room, '');
    expect(huawei.slots.first.weeks.first, 1);
    expect(huawei.slots.first.weeks.last, 14);

    final Course policy = find('形势与政策5')!;
    expect(policy.slots.length, 2);
    expect(policy.slots.map((CourseSlot s) => s.slotCount), contains(1));

    final Course python = find('Python数据分析与应用')!;
    expect(python.slots.single.slotCount, 3);

    final Course law = find('（面授公选）影像中的涉外民事权益法律保护')!;
    expect(law.slots.length, 2);
    expect(law.slots.last.weeks, <int>[12]);
    expect(law.slots.last.slotCount, 2);
  });

  test('一格两门课会拆成两门，不并成一门', () {
    final JwxParseResult r = JwxParser.parse(_page());
    final Course nlp =
        r.courses.firstWhere((Course c) => c.name == '自然语言处理');
    final Course policy =
        r.courses.firstWhere((Course c) => c.name == '形势与政策5');
    expect(nlp.teacher, '张剑');
    expect(policy.teacher, '谢浩然');
    expect(nlp.slots.single.weekday, 4);
    expect(policy.slots.map((CourseSlot s) => s.weekday), contains(4));
  });

  test('考核方式这类元信息不会被当成课程，职称尾巴会被去掉', () {
    const String html = '<table><tbody><tr><td>1</td>'
        '<td>机器学习<br>总人数: 68<br>考核方式: 考查<br>总学时: 24.0<br>'
        '老师:阮奕邦讲师;时间:1-12周[1-2节];地点:7号楼(7B-311)</td>'
        '<td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>'
        '</tbody></table>';
    final JwxParseResult r = JwxParser.parse(html);
    expect(r.courses.length, 1);
    expect(r.courses.single.name, '机器学习');
    expect(r.courses.single.teacher, '阮奕邦');
    expect(r.courses.single.slots.single.startSlot, 1);
    expect(r.issues, isEmpty);
  });
  test('同一格在页面里出现两遍，段落不会重复', () {
    const String cell =
        '<td>机器学习<br>老师:阮奕邦讲师;时间:1-12周[1-2节];地点:7号楼(7B-311)</td>';
    const String empty = '<td></td>';
    final String row =
        '<tr><td>1</td>$cell$empty$empty$empty$empty$empty$empty$empty</tr>';
    final JwxParseResult r =
        JwxParser.parse('<table><tbody>$row$row</tbody></table>');
    expect(r.courses.length, 1);
    expect(r.courses.single.slots.length, 1);
  });
  test('来源标成 jwx，id 稳定可覆盖', () {
    final JwxParseResult a = JwxParser.parse(_page());
    final JwxParseResult b = JwxParser.parse(_page());
    expect(a.courses.first.source, CourseSource.jwx);
    expect(a.courses.first.id, b.courses.first.id);
  });
}
