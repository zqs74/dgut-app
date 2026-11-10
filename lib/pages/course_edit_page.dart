import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../model/course.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 课程编辑：新建一门课，或改其中某一段。
///
/// **为什么一次只编辑一段**：真实课表里一门课常常有好几段（周三第 1–2 节与第 3–4 节、
/// 同一门课 13–16 周[1-2节] 与 13–16 周[2节]）。把多段塞进一个长表单会看不出在改哪段，
/// 所以本页只负责一段；"再加一段"从课块详情进，两处共用本页。
class CourseEditPage extends StatefulWidget {
  const CourseEditPage({
    super.key,
    this.course,
    this.slotIndex,
    this.initialWeek = 1,
    this.initialWeekday,
    this.initialSlot,
  });

  /// 为 null 表示新建课程
  final Course? course;

  /// 为 null 表示给已有课程再加一段
  final int? slotIndex;

  final int initialWeek;

  /// 长按空白格进来时预填的星期与节次
  final int? initialWeekday;
  final int? initialSlot;

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends State<CourseEditPage> {
  final ValueNotifier<DgutScrollInfo> _offset = ValueNotifier<DgutScrollInfo>(
    DgutScrollInfo.zero,
  );

  late final TextEditingController _name;
  late final TextEditingController _teacher;
  late final TextEditingController _room;
  late final TextEditingController _note;

  late int _weekday;
  late int _startSlot;
  late int _slotCount;
  late Set<int> _weeks;
  late int _tone;

  String? _error;

  bool get _isNewCourse => widget.course == null;

  CourseSlot? get _sourceSlot {
    final Course? c = widget.course;
    final int? i = widget.slotIndex;
    if (c == null || i == null || i < 0 || i >= c.slots.length) return null;
    return c.slots[i];
  }

  @override
  void initState() {
    super.initState();
    final Course? c = widget.course;
    final CourseSlot? slot = _sourceSlot;
    _name = TextEditingController(text: c?.name ?? '');
    _teacher = TextEditingController(text: c?.teacher ?? '');
    _room = TextEditingController(text: slot?.room ?? '');
    _note = TextEditingController(text: c?.note ?? '');
    _weekday = slot?.weekday ?? widget.initialWeekday ?? 1;
    _startSlot = slot?.startSlot ?? widget.initialSlot ?? 1;
    _slotCount = slot?.slotCount ?? 2;
    _weeks = <int>{...(slot?.weeks ?? List<int>.generate(16, (i) => i + 1))};
    _tone = c?.tone ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _teacher.dispose();
    _room.dispose();
    _note.dispose();
    _offset.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '课程名不能为空');
      return;
    }
    if (_weeks.isEmpty) {
      setState(() => _error = '至少选一个上课周');
      return;
    }

    final CourseSlot slot = CourseSlot(
      weekday: _weekday,
      startSlot: _startSlot,
      slotCount: _slotCount,
      weeks: (_weeks.toList()..sort()),
      room: _room.text.trim(),
    );

    final TimetableRepository repo = TimetableRepository.instance;

    if (_isNewCourse) {
      await repo.upsert(
        Course(
          id: Course.newId(),
          name: name,
          teacher: _teacher.text.trim(),
          tone: _tone,
          source: CourseSource.manual,
          note: _note.text.trim(),
          slots: [slot],
        ),
      );
    } else {
      final Course base = widget.course!;
      final List<CourseSlot> slots = [...base.slots];
      if (widget.slotIndex == null) {
        slots.add(slot);
      } else {
        slots[widget.slotIndex!] = slot;
      }
      await repo.upsert(
        base.copyWith(
          name: name,
          teacher: _teacher.text.trim(),
          tone: _tone,
          note: _note.text.trim(),
          slots: slots,
          // 手动改过就转成 manual，下一次抓教务不再覆盖这门课（仓储的合并规则靠这个）
          source: CourseSource.manual,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  /// 与已有课程逐段比对：同一天 ∧ 节次相交 ∧ 周次有交集 ⇒ 冲突
  List<String> _conflictLines() {
    final int end = _startSlot + _slotCount - 1;
    final List<String> out = <String>[];
    for (final Course c in TimetableRepository.instance.courses) {
      if (c.id == widget.course?.id) continue;
      for (final CourseSlot s in c.slots) {
        if (s.weekday != _weekday) continue;
        if (s.startSlot > end || s.endSlot < _startSlot) continue;
        final List<int> common = s.weeks.where(_weeks.contains).toList()
          ..sort();
        if (common.isEmpty) continue;
        out.add(
          '与《${c.name}》周${'一二三四五六日'[_weekday - 1]} '
          '${s.startSlot}–${s.endSlot} 节冲突（${formatWeeks(common)}）',
        );
        break;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final int weekCount = TimetableRepository.instance.calendar.weekCount;
    final List<String> conflicts = _conflictLines();

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          DgutPageScaffold(
            eyebrow: _isNewCourse ? '手动录入' : '课程',
            title: _isNewCourse ? '添加课程' : '编辑课程',
            offset: _offset,
            footerHeight: 170,
            onBack: () => Navigator.of(context).maybePop(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DgutSpace.pad,
                  DgutSpace.s2,
                  DgutSpace.pad,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(label: '课程名', controller: _name, hint: ''),
                    _Field(label: '教师', controller: _teacher, hint: ''),
                    _Field(label: '地点', controller: _room, hint: '7B-311'),
                    _Field(label: '备注', controller: _note, hint: '点名、水课'),

                    const DgutGroupHead(title: '星期'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          _Pill(
                            label: const [
                              '一',
                              '二',
                              '三',
                              '四',
                              '五',
                              '六',
                              '日',
                            ][d - 1],
                            selected: _weekday == d,
                            onTap: () => setState(() => _weekday = d),
                          ),
                      ],
                    ),

                    const DgutGroupHead(title: '节次'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var s = 1; s <= 12; s++)
                          _Pill(
                            label: '$s',
                            selected: _startSlot == s,
                            onTap: () => setState(() => _startSlot = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '连上',
                          style: DgutType.footnote.copyWith(color: c.ink3),
                        ),
                        const SizedBox(width: 10),
                        for (var n = 1; n <= 4; n++) ...[
                          _Pill(
                            label: '$n 节',
                            selected: _slotCount == n,
                            onTap: () => setState(() => _slotCount = n),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),

                    const DgutGroupHead(title: '上课周'),
                    Row(
                      children: [
                        DgutButton(
                          label: '全选',
                          size: DgutButtonSize.sm,
                          variant: DgutButtonVariant.plain,
                          onTap: () => setState(
                            () => _weeks = <int>{
                              for (var w = 1; w <= weekCount; w++) w,
                            },
                          ),
                        ),
                        DgutButton(
                          label: '单周',
                          size: DgutButtonSize.sm,
                          variant: DgutButtonVariant.plain,
                          onTap: () => setState(
                            () => _weeks = <int>{
                              for (var w = 1; w <= weekCount; w += 2) w,
                            },
                          ),
                        ),
                        DgutButton(
                          label: '双周',
                          size: DgutButtonSize.sm,
                          variant: DgutButtonVariant.plain,
                          onTap: () => setState(
                            () => _weeks = <int>{
                              for (var w = 2; w <= weekCount; w += 2) w,
                            },
                          ),
                        ),
                        DgutButton(
                          label: '清空',
                          size: DgutButtonSize.sm,
                          variant: DgutButtonVariant.plain,
                          onTap: () => setState(() => _weeks = <int>{}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var w = 1; w <= weekCount; w++)
                          _WeekDot(
                            week: w,
                            selected: _weeks.contains(w),
                            onTap: () => setState(() {
                              if (!_weeks.remove(w)) _weeks.add(w);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _weeks.isEmpty ? '未选周次' : formatWeeks(_weeks.toList()),
                      style: DgutType.caption1.copyWith(color: c.ink3),
                    ),

                    const DgutGroupHead(title: '颜色'),
                    Row(
                      children: [
                        for (var t = 0; t < 4; t++) ...[
                          _ToneDot(
                            tone: t,
                            selected: _tone == t,
                            onTap: () => setState(() => _tone = t),
                          ),
                          const SizedBox(width: 14),
                        ],
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: DgutType.footnote.copyWith(color: c.redInk),
                      ),
                    ],

                    const SizedBox(height: DgutSpace.s4),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(conflicts: conflicts, onSave: _save),
          ),
        ],
      ),
    );
  }
}

/// 底部固定条：冲突提示 + 主按钮。表单再长也不用滚到底去找保存。
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.conflicts, required this.onSave});

  final List<String> conflicts;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          DgutSpace.pad,
          10,
          DgutSpace.pad,
          10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (conflicts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.orange.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(DgutRadius.r1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: c.orangeInk,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conflicts.join('\n'),
                        style: DgutType.caption1.copyWith(
                          color: c.orangeInk,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            DgutButton(
              label: conflicts.isEmpty ? '保存' : '仍然保存',
              size: DgutButtonSize.lg,
              variant: DgutButtonVariant.filled,
              block: true,
              onTap: onSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, this.hint});

  final String label;
  final TextEditingController controller;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DgutType.footnote.copyWith(color: c.ink3)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: c.fill,
              borderRadius: BorderRadius.circular(DgutRadius.r2),
            ),
            child: TextField(
              controller: controller,
              cursorColor: c.blueInk,
              style: DgutType.body.copyWith(color: c.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: DgutType.body.copyWith(color: c.ink4),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 1,
      pressedScale: 0.96,
      // 注意：Container 一旦带 alignment，在 Wrap 里就会撑满整行 ——
      // 这里用 Row(mainAxisSize.min) 让胶囊按文字宽度收缩，再用 minWidth 兜住单字。
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 34),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? c.blue.withValues(alpha: 0.12) : c.fill,
            borderRadius: BorderRadius.circular(DgutRadius.full),
            border: Border.all(
              color: selected
                  ? c.blue.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: DgutType.subhead.copyWith(
                  color: selected ? c.blueInk : c.ink2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({
    required this.week,
    required this.selected,
    required this.onTap,
  });

  final int week;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 1,
      pressedScale: 0.92,
      child: Container(
        width: 34,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.ink : c.fill,
          borderRadius: BorderRadius.circular(DgutRadius.r1),
        ),
        child: Text(
          '$week',
          style: DgutType.caption1.copyWith(
            color: selected ? c.bg : c.ink3,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ToneDot extends StatelessWidget {
  const _ToneDot({
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final int tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final Color color = switch (tone) {
      0 => c.blue,
      1 => c.green,
      2 => c.violet,
      _ => c.orange,
    };
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 1,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
