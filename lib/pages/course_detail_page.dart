import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../data/default_periods.dart';
import '../model/course.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';
import 'course_edit_page.dart';

/// 课程详情（L2）：从课块、日视图或「已添课程」进来。
///
/// 这里只读不写；编辑是 L3，删除后 `pop` 回上一层 —— 不跳级。
class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({
    super.key,
    required this.courseId,
    this.focusWeekday,
    this.focusStartSlot,
  });

  final String courseId;

  /// 从哪一格点进来的：决定先展示哪一段
  final int? focusWeekday;
  final int? focusStartSlot;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  final ValueNotifier<DgutScrollInfo> _offset = ValueNotifier<DgutScrollInfo>(
    DgutScrollInfo.zero,
  );

  bool _armed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Course? get _course => TimetableRepository.instance.byId(widget.courseId);

  int _focusIndex(Course c) {
    final int i = c.slots.indexWhere(
      (s) =>
          s.weekday == widget.focusWeekday &&
          s.startSlot == widget.focusStartSlot,
    );
    return i < 0 ? 0 : i;
  }

  Future<void> _edit(Course c, int index) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CourseEditPage(course: c, slotIndex: index),
      ),
    );
    if (mounted) setState(() => _armed = false);
  }

  Future<void> _addSlot(Course c) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => CourseEditPage(course: c)),
    );
    if (mounted) setState(() => _armed = false);
  }

  Future<void> _delete(Course c) async {
    await TimetableRepository.instance.removeCourse(c.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TimetableRepository.instance,
      builder: (context, _) {
        final DgutColors c = context.dg;
        final Course? course = _course;

        if (course == null) {
          return Scaffold(
            backgroundColor: c.bg,
            body: DgutPageScaffold(
              eyebrow: '课程',
              title: '已经删除',
              offset: _offset,
              footerHeight: 40,
              onBack: () => Navigator.of(context).maybePop(),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad,
                    DgutSpace.s2,
                    DgutSpace.pad,
                    0,
                  ),
                  child: Text(
                    '这门课已经删掉了。',
                    style: DgutType.body.copyWith(color: c.ink3),
                  ),
                ),
              ],
            ),
          );
        }

        final int index = _focusIndex(course);
        final CourseSlot slot = course.slots[index];
        final String room = slot.room.isEmpty
            ? (course.rooms.isEmpty ? '地点待定' : course.rooms.join(' / '))
            : slot.room;
        final DgutColors palette = c;

        return Scaffold(
          backgroundColor: c.bg,
          body: DgutPageScaffold(
            eyebrow:
                '周${'一二三四五六日'[slot.weekday - 1]} · '
                '第 ${slot.startSlot}–${slot.endSlot} 节',
            title: course.name,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${course.teacherLabel} · $room',
                      style: DgutType.callout.copyWith(color: c.ink2),
                    ),
                    DgutKeyValue(
                      rows: [
                        ('本节', dgutTimeSpan(slot.startSlot, slot.slotCount)),
                        ('周次', formatWeeks(slot.weeks)),
                        if (course.note.isNotEmpty) ('备注', course.note),
                        ('来源', course.source.label),
                      ],
                    ),
                    DgutGroupHead(title: '全部时间段'),
                    for (var i = 0; i < course.slots.length; i++)
                      DgutRow(
                        title:
                            '周${'一二三四五六日'[course.slots[i].weekday - 1]}'
                            ' · 第 ${course.slots[i].startSlot}–${course.slots[i].endSlot} 节',
                        subtitle: [
                          formatWeeks(course.slots[i].weeks),
                          if (course.slots[i].room.isNotEmpty)
                            course.slots[i].room,
                        ].join(' · '),
                        value: dgutTimeSpan(
                          course.slots[i].startSlot,
                          course.slots[i].slotCount,
                        ),
                        showChevron: false,
                        onTap: () => _edit(course, i),
                      ),
                    DgutRow(title: '再加一个时间段', onTap: () => _addSlot(course)),
                    DgutGroupHead(title: '周次分布'),
                    _WeekBars(
                      weeks: slot.weeks,
                      color: switch (course.tone) {
                        0 => palette.blue,
                        1 => palette.green,
                        2 => palette.violet,
                        _ => palette.orange,
                      },
                    ),
                    const SizedBox(height: DgutSpace.s4),
                    Row(
                      children: [
                        Expanded(
                          child: DgutButton(
                            label: '编辑',
                            variant: DgutButtonVariant.tinted,
                            onTap: () => _edit(course, index),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DgutButton(
                            label: _armed ? '再点一次删除' : '删除',
                            variant: DgutButtonVariant.danger,
                            onTap: () {
                              if (_armed) {
                                _delete(course);
                              } else {
                                setState(() => _armed = true);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DgutSpace.s2),
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

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.weeks, required this.color});

  final List<int> weeks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final int count = TimetableRepository.instance.calendar.weekCount;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (var w = 1; w <= count; w++)
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: weeks.contains(w) ? color : c.fill,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$w',
              style: TextStyle(
                fontSize: 8,
                height: 1,
                color: weeks.contains(w) ? Colors.white : c.ink4,
              ),
            ),
          ),
      ],
    );
  }
}
