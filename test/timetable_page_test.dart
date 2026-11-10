import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dgut_app/pages/timetable_page.dart';
import 'package:dgut_app/store/timetable_repository.dart';
import 'package:dgut_app/theme/dgut_theme.dart';
import 'package:dgut_app/theme/dgut_tokens.dart';

/// 空态是最容易被"数据一有就正常"掩盖的一屏，单独把它渲染一遍。
/// 2026-11-10 真机（Chrome release）上曾出现整页空白，本测试就是为了钉住这类回归。
void main() {
  testWidgets('课表空态能渲染出引导与按钮', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await TimetableRepository.instance.load();
    await TimetableRepository.instance.clearCourses();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDgutTheme(Brightness.light),
        home: Scaffold(
          body: TimetablePage(
            offset: ValueNotifier<DgutScrollInfo>(DgutScrollInfo.zero),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('课表'), findsWidgets);
    expect(find.text('还没有课表'), findsOneWidget);
    expect(find.text('从教务导入'), findsOneWidget);
    expect(find.text('手动添加'), findsOneWidget);
  });

  testWidgets('有课时渲染网格与统计', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final TimetableRepository repo = TimetableRepository.instance;
    await repo.load();
    await repo.clearCourses();
    await repo.seedDemo();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDgutTheme(Brightness.light),
        home: Scaffold(
          body: TimetablePage(
            offset: ValueNotifier<DgutScrollInfo>(DgutScrollInfo.zero),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('机器学习'), findsWidgets);
    expect(find.text('还没有课表'), findsNothing);
    // 撞课格只画课名不画教室，所以两门撞在一起的课都要在
    expect(find.text('形势与政策5'), findsOneWidget);
    // 普通课块里的教室（统计行是 RichText，find.text 抓不到）
    expect(find.text('7B-412'), findsOneWidget);
  });
}
