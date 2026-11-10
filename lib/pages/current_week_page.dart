import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../model/term_calendar.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 当前第几周（L3）：把学期锚点前后挪，让"今天"落在选中的周。
///
/// 只改锚点（`week1Monday`），不动任何课程的周次 —— 改完周条、首页、统计一起变。
class CurrentWeekPage extends StatefulWidget {
  const CurrentWeekPage({super.key});

  @override
  State<CurrentWeekPage> createState() => _CurrentWeekPageState();
}

class _CurrentWeekPageState extends State<CurrentWeekPage> {
  final ValueNotifier<DgutScrollInfo> _offset =
      ValueNotifier<DgutScrollInfo>(DgutScrollInfo.zero);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Future<void> _pick(int week) async {
    final TimetableRepository repo = TimetableRepository.instance;
    final TermCalendar cal = repo.calendar;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime thisMonday = today.subtract(Duration(days: now.weekday - 1));
    final DateTime anchor = thisMonday.subtract(Duration(days: 7 * (week - 1)));
    await repo.setCalendar(
      TermCalendar(
        week1Monday: anchor,
        weekCount: cal.weekCount,
        exceptions: cal.exceptions,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final TimetableRepository repo = TimetableRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final int current = repo.currentWeek == 0 ? 1 : repo.currentWeek;
        final int count = repo.calendar.weekCount;

        return Scaffold(
          backgroundColor: c.bg,
          body: DgutPageScaffold(
            eyebrow: '课表设置',
            title: '现在是第几周',
            offset: _offset,
            footerHeight: 40,
            onBack: () => Navigator.of(context).maybePop(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad, DgutSpace.s1, DgutSpace.pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var w = 1; w <= count; w++)
                          DgutPressable(
                            onTap: () => _pick(w),
                            pressedOpacity: 1,
                            pressedScale: 0.94,
                            child: Container(
                              width: 44,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: w == current ? c.ink : c.fill,
                                borderRadius:
                                    BorderRadius.circular(DgutRadius.r1),
                              ),
                              child: Text(
                                '$w',
                                style: DgutType.caption1.copyWith(
                                  color: w == current ? c.bg : c.ink2,
                                  fontWeight: w == current
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
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
