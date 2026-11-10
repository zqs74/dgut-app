import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../model/course.dart';
import '../services/jwx_parser.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 导入预览（L4）：勾选要导入的课，标出与现有课表的冲突。
///
/// 导入后只替换 `source == jwx` 的记录，手动录入与粘贴进来的一条不动。
class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({super.key, required this.result});

  final JwxParseResult result;

  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  final ValueNotifier<DgutScrollInfo> _offset =
      ValueNotifier<DgutScrollInfo>(DgutScrollInfo.zero);

  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <String>{
      for (final Course c in widget.result.courses) c.id,
    };
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  /// 与现有非教务课程逐段比对：同一天 ∧ 节次相交 ∧ 周次有交集
  List<String> _conflictsOf(Course c) {
    final List<String> out = <String>[];
    for (final Course other in TimetableRepository.instance.courses) {
      if (other.id == c.id || other.name == c.name) continue;
      for (final CourseSlot mine in c.slots) {
        for (final CourseSlot theirs in other.slots) {
          if (mine.weekday != theirs.weekday) continue;
          final int mineEnd = mine.startSlot + mine.slotCount - 1;
          final int theirEnd = theirs.startSlot + theirs.slotCount - 1;
          if (mine.startSlot > theirEnd || theirs.startSlot > mineEnd) continue;
          if (!mine.weeks.any(theirs.weeks.contains)) continue;
          if (!out.contains(other.name)) out.add(other.name);
        }
      }
    }
    return out;
  }

  Future<void> _import() async {
    final List<Course> picked = widget.result.courses
        .where((Course c) => _selected.contains(c.id))
        .toList();
    await TimetableRepository.instance
        .replaceBySource(CourseSource.jwx, picked);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          DgutPageScaffold(
            eyebrow: '教务导入',
            title: '核对课表',
            offset: _offset,
            footerHeight: 120,
            onBack: () => Navigator.of(context).maybePop(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '识别到 ${widget.result.courses.length} 门课 · '
                      '${widget.result.blockCount} 个时间段',
                      style: DgutType.caption1.copyWith(color: c.ink3),
                    ),
                    const SizedBox(height: DgutSpace.s2),
                    for (final Course course in widget.result.courses)
                      _ReviewRow(
                        course: course,
                        selected: _selected.contains(course.id),
                        conflicts: _conflictsOf(course),
                        onToggle: () => setState(() {
                          if (!_selected.remove(course.id)) {
                            _selected.add(course.id);
                          }
                        }),
                      ),
                    for (final String issue in widget.result.issues)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          issue,
                          style:
                              DgutType.caption1.copyWith(color: c.orangeInk),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.line, width: 1)),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(
                    DgutSpace.pad, 10, DgutSpace.pad, 10),
                child: DgutButton(
                  label: '导入 ${_selected.length} 门',
                  size: DgutButtonSize.lg,
                  variant: DgutButtonVariant.filled,
                  block: true,
                  onTap: _selected.isEmpty ? null : _import,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.course,
    required this.selected,
    required this.conflicts,
    required this.onToggle,
  });

  final Course course;
  final bool selected;
  final List<String> conflicts;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final String slots = <String>[
      for (final CourseSlot s in course.slots)
        '周${JwxParser.weekdayLabel(s.weekday)} ${s.startSlot}–${s.endSlot}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line, width: 1)),
      ),
      child: DgutPressable(
        onTap: onToggle,
        pressedOpacity: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? c.blue : c.ink4,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name,
                        style: DgutType.body.copyWith(color: c.ink)),
                    const SizedBox(height: 3),
                    Text(
                      slots,
                      style: DgutType.caption1.copyWith(color: c.ink3),
                    ),
                    if (conflicts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '与 ${conflicts.join('、')} 冲突',
                        style:
                            DgutType.caption1.copyWith(color: c.orangeInk),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${course.slots.length} 段',
                style: DgutType.caption1.copyWith(color: c.ink4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
