import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../model/timetable_appearance.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';
import 'course_edit_page.dart';
import 'appearance_page.dart';
import 'course_list_page.dart';
import 'jwx_import_page.dart';
import 'current_week_page.dart';
import 'table_list_page.dart';
import 'time_table_page.dart';

/// 课表设置（L2）。只放"校方数据之外、学生自己要调"的东西。
class TimetableSettingsPage extends StatefulWidget {
  const TimetableSettingsPage({super.key});

  @override
  State<TimetableSettingsPage> createState() => _TimetableSettingsPageState();
}

class _TimetableSettingsPageState extends State<TimetableSettingsPage> {
  final ValueNotifier<DgutScrollInfo> _offset = ValueNotifier<DgutScrollInfo>(
    DgutScrollInfo.zero,
  );

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final TimetableRepository repo = TimetableRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final int week = repo.currentWeek == 0 ? 1 : repo.currentWeek;
        final DateTime monday = repo.calendar.mondayOf(1);

        return Scaffold(
          backgroundColor: c.bg,
          body: DgutPageScaffold(
            eyebrow: '课表',
            title: '设置',
            offset: _offset,
            footerHeight: 40,
            onBack: () => Navigator.of(context).maybePop(),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DgutGroupHead(title: '课表'),
                    DgutRow(
                      title: '我的课表',
                      value: repo.activeName,
                      onTap: () => _push(const TableListPage()),
                    ),
                    DgutRow(
                      title: '当前第几周',
                      value: '第 $week 周',
                      onTap: () => _push(const CurrentWeekPage()),
                    ),
                    DgutRow(
                      title: '上课时间',
                      value: repo.periods.isEmpty
                          ? '—'
                          : '${repo.periods.first.start}–${repo.periods.last.end}',
                      onTap: () => _push(const TimeTablePage()),
                    ),
                    DgutRow(
                      title: '课表外观',
                      value: _styleName(repo.appearance.style),
                      onTap: () => _push(const AppearancePage()),
                    ),
                    DgutRow(
                      title: '已添课程',
                      value: '${repo.courses.length} 门',
                      onTap: () => _push(const CourseListPage()),
                    ),
                    DgutRow(
                      title: '添加课程',
                      onTap: () => _push(const CourseEditPage()),
                    ),
                    DgutRow(
                      title: '教务导入',
                      value: '强智系统',
                      onTap: () => _push(const JwxImportPage()),
                    ),
                    const DgutGroupHead(title: '学期'),
                    DgutRow(
                      title: '学期周数',
                      value: '${repo.calendar.weekCount} 周',
                      showChevron: false,
                    ),
                    DgutRow(
                      title: '第 1 周周一',
                      value: '${monday.year}/${monday.month}/${monday.day}',
                      showChevron: false,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _styleName(BlockStyle style) => switch (style) {
  BlockStyle.paper => '纸卡',
  BlockStyle.solid => '实心',
  BlockStyle.outline => '线框',
  BlockStyle.tick => '色签',
};
