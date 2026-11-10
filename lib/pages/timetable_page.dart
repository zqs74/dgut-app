import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../theme/dgut_tokens.dart';

class _Course {
  const _Course({
    required this.name,
    required this.room,
    required this.day,
    required this.start,
    required this.len,
    required this.week,
    required this.tone,
    this.dim = false,
  });

  final String name;
  final String room;
  final int day; // 0 = 周一
  final int start; // 0 = 第 1 节
  final int len;
  final String week; // 右上角周次标记：周 / 单 / 双
  final int tone; // 0 blue / 1 green / 2 violet / 3 orange
  final bool dim; // 非本周
}

const List<_Course> _courses = [
  _Course(
      name: '大数据采集与集成技术',
      room: '7B-412',
      day: 0,
      start: 2,
      len: 2,
      week: '周',
      tone: 0),
  _Course(
      name: '机器学习',
      room: '7B-311',
      day: 0,
      start: 0,
      len: 2,
      week: '单',
      tone: 1),
  _Course(
      name: '形势与政策',
      room: '8B-403',
      day: 0,
      start: 0,
      len: 2,
      week: '双',
      tone: 3,
      dim: true),
  _Course(
      name: '机器学习',
      room: '7B-311',
      day: 2,
      start: 4,
      len: 2,
      week: '周',
      tone: 1),
  _Course(
      name: '自然语言处理',
      room: '7B-306',
      day: 4,
      start: 4,
      len: 2,
      week: '周',
      tone: 2),
];

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key, required this.offset});

  final ValueNotifier<DgutScrollInfo> offset;

  @override
  Widget build(BuildContext context) {
    return DgutPageScaffold(
      eyebrow: '11 月 2 日 – 11 月 8 日',
      title: '课表',
      offset: offset,
      footerHeight: 240,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, DgutSpace.s1),
          child: _WeekTabs(
            labels: const ['本周', '下周', '全部'],
            index: 0,
            onSelect: (_) {},
          ),
        ),
        const _TimetableGrid(courses: _courses),
        DgutStatLine(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, 0),
          spans: [
            dgutPlain('本周 '),
            dgutStrong(context, '4'),
            dgutPlain(' 门课 · 共 '),
            dgutStrong(context, '18'),
            dgutPlain(' 节 · 周一 1–2 有 '),
            dgutStrong(context, '1'),
            dgutPlain(' 处撞课'),
          ],
        ),
      ],
    );
  }
}

/// 下划线式多选一（.dg-tabs）
class _WeekTabs extends StatelessWidget {
  const _WeekTabs({
    required this.labels,
    required this.index,
    required this.onSelect,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          DgutPressable(
            onTap: () => onSelect(i),
            pressedOpacity: 0.5,
            child: Padding(
              padding: const EdgeInsets.only(right: DgutSpace.s3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            i == index ? FontWeight.w600 : FontWeight.w400,
                        color: i == index ? c.ink : c.ink3,
                        height: 1.2,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    height: 2,
                    width: i == index ? 18 : 0,
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({required this.courses});

  final List<_Course> courses;

  static const double _rh = 24;
  static const double _gap = 3;
  static const double _lab = 22;
  static const int _rows = 12;
  static const int _cols = 7;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    const List<String> heads = ['一', '二', '三', '四', '五', '六', '日'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, 0),
      child: LayoutBuilder(
        builder: (context, cons) {
          final double tw = (cons.maxWidth - _lab - _gap * _cols) / _cols;
          final double gridH = _rows * (_rh + _gap) - _gap;

          // 同一列同一节起点的课视为撞课：左右分栏，各自保留原高度与文字
          final Map<String, List<_Course>> groups = {};
          for (final cr in courses) {
            groups.putIfAbsent('${cr.day}:${cr.start}', () => []).add(cr);
          }

          final List<Widget> blocks = [];
          for (final list in groups.values) {
            final int n = list.length;
            for (var i = 0; i < n; i++) {
              final cr = list[i];
              final double baseTop = cr.start * (_rh + _gap) + 1;
              // 撞课：同一格上下各占一半，全宽显示，字号收到 7.5 只留课名
              final double blockH = n == 1
                  ? cr.len * _rh + (cr.len - 1) * _gap - 2
                  : _rh / n - 2;
              blocks.add(Positioned(
                left: _lab + _gap + cr.day * (tw + _gap) + 1,
                top: n == 1 ? baseTop : baseTop + i * (_rh / n),
                width: tw - 2,
                height: blockH,
                child: _CourseBlock(
                  course: cr,
                  clash: n > 1,
                  width: tw,
                ),
              ));
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: _lab),
                  for (var i = 0; i < _cols; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: i == 0 ? _gap : _gap / 2,
                            right: _gap / 2),
                        child: Text(
                          heads[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: i == 0 ? c.blueInk : c.ink3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: gridH,
                child: Stack(
                  children: [
                    for (var r = 0; r < _rows; r++) ...[
                      Positioned(
                        left: 0,
                        width: _lab,
                        top: r * (_rh + _gap),
                        height: _rh,
                        child: Text(
                          '${r + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            height: _rh / 9,
                            color: c.ink4,
                          ),
                        ),
                      ),
                      for (var day = 0; day < _cols; day++)
                        Positioned(
                          left: _lab + _gap + day * (tw + _gap),
                          top: r * (_rh + _gap),
                          width: tw,
                          height: _rh,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.fill,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                    ],
                    ...blocks,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.course,
    required this.clash,
    required this.width,
  });

  final _Course course;
  final bool clash;
  final double width;

  Color _lineColor(DgutColors c) => switch (course.tone) {
        0 => c.blue,
        1 => c.green,
        2 => c.violet,
        _ => c.orange,
      };

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    if (clash) {
      // 撞课格只有 10px 高：一行小字 + 色条，不显示教室与周次
      return Opacity(
        opacity: course.dim ? 0.34 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(5, 0, 2, 0),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: c.fill,
              border: Border(
                left: BorderSide(color: _lineColor(c), width: 2),
              ),
            ),
            child: Text(
              course.name,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 7.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
        ),
      );
    }

    final bool narrow = width < 46;

    return Opacity(
      opacity: course.dim ? 0.34 : 1,
      child: DgutPressable(
        onTap: () {},
        pressedScale: 0.955,
        pressedOpacity: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: EdgeInsets.fromLTRB(narrow ? 6 : 8, 5, narrow ? 3 : 6, 5),
            decoration: BoxDecoration(
              color: c.fill,
              border: Border(
                left: BorderSide(color: _lineColor(c), width: 3),
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      course.name,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: narrow ? 9 : 9.5,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.room,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: c.ink3,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Text(
                    course.week,
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink3,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
