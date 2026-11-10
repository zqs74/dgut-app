import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../data/default_periods.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 上课时间（L3）：固定时长、每节时长、节数、每节开始与结束时间。
///
/// 时间的改法照 WakeUp：每节两个时间小按钮，点哪个改哪个；
/// 开了「固定上课时长」就只有开始时间能改，结束时间由开始 + 时长推出来。
class TimeTablePage extends StatefulWidget {
  const TimeTablePage({super.key});

  @override
  State<TimeTablePage> createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage> {
  final ValueNotifier<DgutScrollInfo> _offset = ValueNotifier<DgutScrollInfo>(
    DgutScrollInfo.zero,
  );
  final FocusNode _durationFocus = FocusNode();

  late final TextEditingController _durationCtrl;

  TimetableRepository get _repo => TimetableRepository.instance;

  @override
  void initState() {
    super.initState();
    _durationCtrl = TextEditingController(text: '${_repo.durationMinutes}');
    _repo.addListener(_syncDuration);
  }

  @override
  void dispose() {
    _repo.removeListener(_syncDuration);
    _durationCtrl.dispose();
    _durationFocus.dispose();
    _offset.dispose();
    super.dispose();
  }

  /// 时长被外部改动（恢复默认）时把输入框拉回一致，打字过程中不打断
  void _syncDuration() {
    final String want = '${_repo.durationMinutes}';
    if (!_durationFocus.hasFocus && _durationCtrl.text != want) {
      _durationCtrl.text = want;
    }
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

  static int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _editStart(int index) async {
    final List<DgutPeriod> list = <DgutPeriod>[..._repo.periods];
    final DgutPeriod current = list[index];

    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: _parse(current.start),
      helpText: '第 ${index + 1} 节 开始',
    );
    if (start == null || !mounted) return;

    int endMinutes = dgutMinutesOf(current.end);
    if (_repo.fixedDuration) {
      endMinutes = _minutesOf(start) + _repo.durationMinutes;
    } else if (endMinutes <= _minutesOf(start)) {
      endMinutes = _minutesOf(start) + _repo.durationMinutes;
    }

    list[index] = DgutPeriod(_format(start), dgutFormatMinutes(endMinutes));
    await _repo.setPeriods(list);
  }

  Future<void> _editEnd(int index) async {
    if (_repo.fixedDuration) return;
    final List<DgutPeriod> list = <DgutPeriod>[..._repo.periods];
    final DgutPeriod current = list[index];

    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: _parse(current.end),
      helpText: '第 ${index + 1} 节 结束',
    );
    if (end == null) return;
    if (_minutesOf(end) <= dgutMinutesOf(current.start)) return;

    list[index] = DgutPeriod(current.start, _format(end));
    await _repo.setPeriods(list);
  }

  void _onDurationChanged(String raw) {
    final int? n = int.tryParse(raw);
    if (n == null || n < 20 || n > 180) return;
    _repo.setDuration(n);
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
                      showChevron: false,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 34,
                            child: TextField(
                              controller: _durationCtrl,
                              focusNode: _durationFocus,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              textAlignVertical: TextAlignVertical.center,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              cursorColor: c.blue,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: c.fill,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    DgutRadius.r1,
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: _onDurationChanged,
                              onSubmitted: _onDurationChanged,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '分钟',
                            style: DgutType.caption1.copyWith(color: c.ink3),
                          ),
                        ],
                      ),
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
                        showChevron: false,
                        showDivider: i < periods.length - 1,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TimeChip(
                              text: periods[i].start,
                              onTap: () => _editStart(i),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '–',
                                style: TextStyle(fontSize: 14, color: c.ink3),
                              ),
                            ),
                            _TimeChip(
                              text: periods[i].end,
                              enabled: !_repo.fixedDuration,
                              onTap: () => _editEnd(i),
                            ),
                          ],
                        ),
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

/// 一个时间小按钮。固定时长时结束时间不可点，压暗。
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.text,
    required this.onTap,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutPressable(
      onTap: enabled ? onTap : null,
      pressedOpacity: 0.7,
      child: Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 66),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? c.fill : Colors.transparent,
          borderRadius: BorderRadius.circular(DgutRadius.r1),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: enabled ? c.ink : c.ink4,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
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
