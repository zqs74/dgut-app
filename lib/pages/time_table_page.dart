import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../data/default_periods.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 上课时间（L3）：固定时长、每节时长、节数、每节开始时间。
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

  Future<void> _editPeriod(int index) async {
    final List<DgutPeriod> list = <DgutPeriod>[..._repo.periods];
    final DgutPeriod current = list[index];

    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: _parse(current.start),
      helpText: '第 ${index + 1} 节 开始',
    );
    if (start == null || !mounted) return;

    TimeOfDay end;
    if (_repo.fixedDuration) {
      final int minutes =
          start.hour * 60 + start.minute + _repo.durationMinutes;
      end = TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);
    } else {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: _parse(current.end),
        helpText: '第 ${index + 1} 节 结束',
      );
      if (picked == null) return;
      end = picked;
    }

    final int startMinutes = start.hour * 60 + start.minute;
    final int endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) return;

    list[index] = DgutPeriod(_format(start), _format(end));
    await _repo.setPeriods(list);
  }

  Future<void> _pickDuration() async {
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.dg.bg,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final int m in <int>[35, 40, 45, 50, 55, 60])
              DgutRow(
                title: '$m 分钟',
                value: m == _repo.durationMinutes ? '当前' : null,
                showChevron: false,
                showDivider: m != 60,
                onTap: () => Navigator.of(ctx).pop(m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await _repo.setDuration(picked);
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return ListenableBuilder(
      listenable: _repo,
      builder: (BuildContext context, Widget? _) {
        final List<DgutPeriod> periods = _repo.periods;

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
                  DgutSpace.s3,
                  DgutSpace.pad,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DgutRow(
                      title: '固定上课时长',
                      showChevron: false,
                      trailing: DgutSwitch(
                        value: _repo.fixedDuration,
                        onChanged: _repo.setFixedDuration,
                      ),
                      onTap: () => _repo.setFixedDuration(!_repo.fixedDuration),
                    ),
                    DgutRow(
                      title: '每节课时长',
                      value: '${_repo.durationMinutes} 分钟',
                      onTap: _pickDuration,
                    ),
                    DgutRow(
                      title: '节数',
                      value: '${periods.length} 节',
                      showChevron: false,
                      showDivider: false,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StepButton(
                            icon: Icons.remove_rounded,
                            onTap: periods.length > 1
                                ? () => _repo.setPeriodCount(periods.length - 1)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          _StepButton(
                            icon: Icons.add_rounded,
                            onTap: periods.length < 16
                                ? () => _repo.setPeriodCount(periods.length + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DgutSpace.s3),
                    for (var i = 0; i < periods.length; i++)
                      DgutRow(
                        title: '第 ${i + 1} 节',
                        value: '${periods[i].start}–${periods[i].end}',
                        showDivider: i < periods.length - 1,
                        onTap: () => _editPeriod(i),
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

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool enabled = onTap != null;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 1,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: enabled ? c.ink2 : c.ink4),
      ),
    );
  }
}
