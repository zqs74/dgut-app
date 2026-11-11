import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dgut_app/data/service_registry.dart';
import 'package:dgut_app/pages/services_page.dart';
import 'package:dgut_app/theme/dgut_theme.dart';
import 'package:dgut_app/theme/dgut_tokens.dart';

/// S2 验收：22 项全列出、分组正确、眉标由表长算、点没接通的有反馈。
///
/// 这一屏以前是硬编码的，眉标写「22 项」而实际只画了 17 行 —— 这类
/// 「说的和画的对不上」只能靠测试钉住，靠肉眼看容易漏。
void main() {
  Future<void> pumpServices(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDgutTheme(Brightness.light),
        home: Scaffold(
          body: ServicesPage(
            offset: ValueNotifier<DgutScrollInfo>(DgutScrollInfo.zero),
            onOpenTab: (int _) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('眉标是「22 项」，与表长一致', (WidgetTester tester) async {
    await pumpServices(tester);
    expect(find.text('${kServiceRegistry.length} 项'), findsOneWidget);
  });

  testWidgets('5 个分组标题都在', (WidgetTester tester) async {
    await pumpServices(tester);
    for (final ServiceGroup group in ServiceGroup.values) {
      expect(find.text(group.label), findsWidgets, reason: group.label);
    }
  });

  testWidgets('第一组默认展开，能点到组内服务', (WidgetTester tester) async {
    await pumpServices(tester);
    // 「教务学习」6 项里的几个
    expect(find.text('课表'), findsWidgets);
    expect(find.text('成绩查询'), findsOneWidget);
    expect(find.text('校历'), findsOneWidget);
  });

  testWidgets('每组折叠头显示组内项数', (WidgetTester tester) async {
    await pumpServices(tester);
    expect(find.text('6 项'), findsWidgets); // 教务学习
    expect(find.text('5 项'), findsWidgets); // 生活后勤 / 事务办理
    expect(find.text('3 项'), findsWidgets); // 网络与资源 / 其他
  });

  testWidgets('点还没接通的服务会给一句说明，不是毫无反应', (WidgetTester tester) async {
    await pumpServices(tester);
    await tester.tap(find.text('校历'));
    await tester.pump(); // 让 SnackBar 出现
    await tester.pump(const Duration(milliseconds: 100));

    final String note = serviceById('calendar')!.comingNote!;
    expect(find.text(note), findsOneWidget);
  });

  testWidgets('页面上不再出现没有来源的统计数字', (WidgetTester tester) async {
    await pumpServices(tester);
    // 旧版这三句都是编的
    expect(find.text('78 / 86 座'), findsNothing);
    expect(find.text('36 个流程'), findsNothing);
    expect(find.text('22:00 截止'), findsNothing);
  });
}
