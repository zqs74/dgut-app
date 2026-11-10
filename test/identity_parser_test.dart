import 'package:flutter_test/flutter_test.dart';

import 'package:dgut_app/services/identity_parser.dart';

void main() {
  group('学工基本信息解析', () {
    test('标准两列表格：标签与值用换行分隔', () {
      const String text = '''
基本信息
姓名
张淇森
学号
2024463030442
性别
男
校区
松山湖校区
学院
计算机科学与技术学院
专业
数据科学与大数据技术
年级
2024
班级
大数据2班
''';
      final id = parseIdentity(text, now: DateTime(2026, 11, 10))!;
      expect(id.name, '张淇森');
      expect(id.studentId, '2024463030442');
      expect(id.campus, '松山湖校区');
      expect(id.college, '计算机科学与技术学院');
      expect(id.major, '数据科学与大数据技术');
      expect(id.grade, '2024');
      expect(id.className, '大数据2班');
    });

    test('一行里塞多个字段（innerText 用制表符对齐）', () {
      const String text =
          '姓名\t张淇森\t学号\t2024463030442\t学院\t计算机科学与技术学院';
      final id = parseIdentity(text)!;
      expect(id.name, '张淇森');
      expect(id.studentId, '2024463030442');
      expect(id.college, '计算机科学与技术学院');
    });

    test('标签后面跟全角冒号也认', () {
      const String text = '姓名：张淇森\n学号：2024463030442';
      final id = parseIdentity(text)!;
      expect(id.name, '张淇森');
      expect(id.studentId, '2024463030442');
    });

    test('「姓名拼音」不该被当成姓名', () {
      const String text = '姓名拼音\tZHANG QISEN\n姓名\t张淇森';
      final id = parseIdentity(text)!;
      expect(id.name, '张淇森');
    });

    test('缺字段时留空，不抛异常', () {
      const String text = '姓名\t张淇森';
      final id = parseIdentity(text)!;
      expect(id.name, '张淇森');
      expect(id.studentId, '');
      expect(id.college, '');
      // 少了字段也要能拼出可展示的副标题
      expect(id.subtitle, '莞工统一身份认证');
    });

    test('没认出姓名就当失败（页面还没加载对）', () {
      expect(parseIdentity('统一身份认证\n请登录'), isNull);
      expect(parseIdentity(''), isNull);
      expect(parseIdentity('   \n  '), isNull);
    });

    test('头像取姓名第一个字', () {
      const String text = '姓名\t张淇森';
      expect(parseIdentity(text)!.initial, '张');
    });
  });

  group('身份信息的展示拼装', () {
    test('副标题与第三行的拼法', () {
      const String text = '''
姓名\t张淇森
学号\t2024463030442
学院\t计算机科学与技术学院
专业\t数据科学与大数据技术
年级\t2024
班级\t大数据2班
''';
      final id = parseIdentity(text)!;
      expect(id.subtitle, '2024463030442 · 数据科学与大数据技术');
      expect(id.detail, '计算机科学与技术学院 · 2024级 · 大数据2班');
    });
  });
}
