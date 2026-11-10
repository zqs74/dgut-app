import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../model/course.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';
import 'course_detail_page.dart';

/// 已添课程（L3）：搜索 + 列表，点一门进详情（L4）。
class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  final ValueNotifier<DgutScrollInfo> _offset =
      ValueNotifier<DgutScrollInfo>(DgutScrollInfo.zero);
  final TextEditingController _query = TextEditingController();

  String _q = '';

  @override
  void dispose() {
    _offset.dispose();
    _query.dispose();
    super.dispose();
  }

  List<Course> _sorted(List<Course> all) {
    final List<Course> list = [...all];
    list.sort((a, b) {
      final CourseSlot? sa = a.slots.isEmpty ? null : a.slots.first;
      final CourseSlot? sb = b.slots.isEmpty ? null : b.slots.first;
      final int byDay =
          (sa?.weekday ?? 9).compareTo(sb?.weekday ?? 9);
      return byDay != 0
          ? byDay
          : (sa?.startSlot ?? 99).compareTo(sb?.startSlot ?? 99);
    });
    return list;
  }

  bool _match(Course c, String q) {
    if (q.isEmpty) return true;
    final String hay = '${c.name}${c.teacher}${c.rooms.join()}'.toLowerCase();
    return hay.contains(q.toLowerCase());
  }

  Future<void> _open(Course c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailPage(courseId: c.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final TimetableRepository repo = TimetableRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final List<Course> list =
            _sorted(repo.courses).where((e) => _match(e, _q)).toList();

        return Scaffold(
          backgroundColor: c.bg,
          body: DgutPageScaffold(
            eyebrow: '课表设置',
            title: '已添课程',
            offset: _offset,
            footerHeight: 40,
            onBack: () => Navigator.of(context).maybePop(),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: DgutSpace.s3),
                    DgutSearchField(
                      hint: '搜课程、老师或教室',
                      controller: _query,
                      onChanged: (String v) => setState(() => _q = v.trim()),
                    ),
                    const SizedBox(height: DgutSpace.s3),
                    if (list.isEmpty)
                      Text('没有匹配的课程。',
                          style: DgutType.body.copyWith(color: c.ink3))
                    else
                      for (final Course course in list)
                        DgutRow(
                          title: course.name,
                          subtitle: [
                            for (final CourseSlot s in course.slots)
                              '周${'一二三四五六日'[s.weekday - 1]} '
                                  '${s.startSlot}–${s.endSlot}',
                          ].join(' · '),
                          value: course.slots.length > 1
                              ? '${course.slots.length} 段'
                              : null,
                          onTap: () => _open(course),
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
