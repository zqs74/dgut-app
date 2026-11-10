import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../data/default_periods.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 上课时间（L3）：12 节的起止时间，改完立即反映到课表轴与详情。
class TimeTablePage extends StatefulWidget {
  const TimeTablePage({super.key});

  @override
  State<TimeTablePage> createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage> {
  final ValueNotifier<DgutScrollInfo> _offset = ValueNotifier<DgutScrollInfo>(
    DgutScrollInfo.zero,
  );

  TimetableRepository get _repo => TimetableRepository.instance;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  static TimeOfDay _parse(String hhmm) {
    final List<String> p = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(p.first) ?? 0,
      minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
    );
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _edit(int index) async {
    final List<DgutPeriod> list = <DgutPeriod>[..._repo.periods];
    final DgutPeriod current = list[index];

    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: _parse(current.start),
      helpText: '第 ${index + 1} 节 开始',
    );
    if (start == null || !mounted) return;

    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: _parse(current.end),
      helpText: '第 ${index + 1} 节 结束',
    );
    if (end == null) return;

    final int startMinutes = start.hour * 60 + start.minute;
    final int endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) return;

    list[index] = DgutPeriod(_format(start), _format(end));
    await _repo.setPeriods(list);
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return ListenableBuilder(
      listenable: _repo,
      builder: (BuildContext context, Widget? _) {
        final List<DgutPeriod> periods = _repo.periods;
        final String span = periods.isEmpty
            ? ''
            : '${periods.first.start}–${periods.last.end}';

        return Scaffold(
          backgroundColor: c.bg,
          body: DgutPageScaffold(
            eyebrow: '课表设置',
            title: '上课时间',
            offset: _offset,
            footerHeight: 40,
            onBack: () => Navigator.of(context).maybePop(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DgutSpace.pad,
                  DgutSpace.s1,
                  DgutSpace.pad,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      span,
                      style: DgutType.caption1.copyWith(color: c.ink3),
                    ),
                    const SizedBox(height: DgutSpace.s2),
                    for (var i = 0; i < periods.length; i++)
                      DgutRow(
                        title: '第 ${i + 1} 节',
                        value: '${periods[i].start}–${periods[i].end}',
                        showChevron: false,
                        showDivider: i < periods.length - 1,
                        onTap: () => _edit(i),
                      ),
                    const SizedBox(height: DgutSpace.s3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DgutButton(
                        label: '恢复默认',
                        size: DgutButtonSize.sm,
                        variant: DgutButtonVariant.plain,
                        onTap: _repo.resetPeriods,
                      ),
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
