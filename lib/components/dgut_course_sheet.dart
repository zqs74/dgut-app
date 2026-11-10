import 'package:flutter/material.dart';

import '../model/course.dart';

import '../theme/dgut_tokens.dart';
import 'dgut_basics.dart';
import 'dgut_theme_sheet.dart';

/// 课块详情的三种出口。用 sealed 是为了让调用方必须处理完三种，不会漏。
sealed class CourseSheetAction {
  const CourseSheetAction();
}

class CourseSheetEdit extends CourseSheetAction {
  const CourseSheetEdit(this.slotIndex);
  final int slotIndex;
}

class CourseSheetAdd extends CourseSheetAction {
  const CourseSheetAdd();
}

class CourseSheetDelete extends CourseSheetAction {
  const CourseSheetDelete();
}

/// 课块详情浮层：列出这门课的所有时段，逐段可编辑。
///
/// 用的是 `.dg-sheet` 的材质（页面底色 + r4 圆角 + 浮层阴影），与外观选择浮层同款，
/// 全项目只有这一套浮层样式。侧滑式 `.dg-sheet` 与 Hero 飞行留到详情页规范化那一轮。
Future<CourseSheetAction?> showCourseSheet(
  BuildContext context, {
  required Course course,
  int focusIndex = 0,
}) {
  return showModalBottomSheet<CourseSheetAction>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (ctx) => _CourseSheet(course: course, focusIndex: focusIndex),
  );
}

class _CourseSheet extends StatelessWidget {
  const _CourseSheet({required this.course, required this.focusIndex});

  final Course course;
  final int focusIndex;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            DgutSpace.s2, 0, DgutSpace.s2, DgutSpace.s2),
        child: Container(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(DgutRadius.r4),
            boxShadow: DgutShadows.forBrightness(Theme.of(context).brightness),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad, DgutSpace.s3, DgutSpace.pad, DgutSpace.s1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.name,
                              style: DgutType.title3.copyWith(color: c.ink)),
                          const SizedBox(height: 4),
                          Text(
                            [
                              course.teacherLabel,
                              '${course.slots.length} 个时段',
                              course.source.label,
                            ].join(' · '),
                            style: DgutType.caption1.copyWith(color: c.ink3),
                          ),
                        ],
                      ),
                    ),
                    DgutSheetClose(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < course.slots.length; i++)
                      DgutRow(
                        title:
                            '周${_cnWeekday(course.slots[i].weekday)} ${course.slots[i].slotsLabel}',
                        subtitle: [
                          course.slots[i].weeksLabel,
                          if (course.slots[i].room.isNotEmpty)
                            course.slots[i].room,
                        ].join(' · '),
                        showDivider: i != course.slots.length - 1,
                        onTap: () =>
                            Navigator.of(context).pop(CourseSheetEdit(i)),
                      ),
                    if (course.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(course.note,
                            style:
                                DgutType.footnote.copyWith(color: c.ink3)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad, DgutSpace.s3, DgutSpace.pad, DgutSpace.s2),
                child: Row(
                  children: [
                    Expanded(
                      child: DgutButton(
                        label: '再加一段',
                        variant: DgutButtonVariant.tinted,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        onTap: () =>
                            Navigator.of(context).pop(const CourseSheetAdd()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DgutButton(
                      label: '删除这门课',
                      variant: DgutButtonVariant.danger,
                      onTap: () =>
                          Navigator.of(context).pop(const CourseSheetDelete()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cnWeekday(int weekday) =>
    const ['一', '二', '三', '四', '五', '六', '日'][(weekday - 1).clamp(0, 6)];
