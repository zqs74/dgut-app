import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dgut_app/model/course.dart';
import 'package:dgut_app/model/term_calendar.dart';
import 'package:dgut_app/store/timetable_repository.dart';

void main() {
  group('TermCalendar 周次换算', () {
    final TermCalendar term = TermCalendar(
      week1Monday: DateTime(2026, 8, 31),
      weekCount: 20,
    );

    test('第 1 周周一算第 1 周，前一天不算', () {
      expect(term.weekOf(DateTime(2026, 8, 31)), 1);
      expect(term.weekOf(DateTime(2026, 8, 30)), 0);
    });

    test('2026-11-09 起是第 11 周（与教务页显示的"第 11 周"一致）', () {
      expect(term.weekOf(DateTime(2026, 11, 9)), 11);
      expect(term.weekOf(DateTime(2026, 11, 10)), 11);
      expect(term.weekOf(DateTime(2026, 11, 15)), 11);
      expect(term.weekOf(DateTime(2026, 11, 16)), 12);
    });

    test('学期结束后返回 0', () {
      expect(term.weekOf(DateTime(2027, 2, 1)), 0);
    });

    test('mondayOf / dateOf 与 weekOf 互为反函数', () {
      expect(term.mondayOf(11), DateTime(2026, 11, 9));
      expect(term.dateOf(11, 6), DateTime(2026, 11, 14));
      for (var w = 1; w <= 20; w++) {
        expect(term.weekOf(term.mondayOf(w)), w);
      }
    });

    test('日期范围文案', () {
      expect(term.rangeLabel(11), '11 月 9 日 – 11 月 15 日');
    });

    test('调休与停课只改"按哪一周上"，不改锚点', () {
      final TermCalendar withException = term.copyWith(
        exceptions: [
          DayException(
            date: DateTime(2026, 11, 14),
            followsWeek: 12,
            followsWeekday: 1,
          ),
          DayException(date: DateTime(2026, 11, 20), holiday: true),
        ],
      );
      expect(withException.teachingWeekOn(DateTime(2026, 11, 14)), 12);
      expect(withException.teachingWeekdayOn(DateTime(2026, 11, 14)), 1);
      expect(withException.teachingWeekOn(DateTime(2026, 11, 20)), 0);
      expect(withException.weekOf(DateTime(2026, 11, 14)), 11);
    });
  });

  group('Course 与 CourseSlot', () {
    test('周集合压缩成可读文案', () {
      expect(formatWeeks([1, 2, 3, 5, 7]), '1-3,5,7周');
      expect(formatWeeks([12]), '12周');
      expect(formatWeeks([2, 3, 4, 5, 6, 7, 8, 9, 10, 11]), '2-11周');
      expect(formatWeeks([]), '—');
    });

    test('一门课多段：当周生效判断与节数累加', () {
      final Course c = Course(
        id: 'x',
        name: '自然语言处理',
        teacher: '张剑副研究员',
        slots: const [
          CourseSlot(
              weekday: 3, startSlot: 1, slotCount: 2, weeks: [1, 2, 3],
              room: '7B-411'),
          CourseSlot(
              weekday: 3, startSlot: 3, slotCount: 2, weeks: [1, 2, 3],
              room: '7B-411'),
          CourseSlot(
              weekday: 6, startSlot: 9, slotCount: 3, weeks: [12],
              room: '6E-207'),
        ],
      );
      expect(c.activeIn(1), isTrue);
      expect(c.activeIn(12), isTrue);
      expect(c.activeIn(5), isFalse);
      expect(c.weeklySlots, 7);
      expect(c.rooms, ['7B-411', '6E-207']);
    });

    test('JSON 往返不丢字段', () {
      final Course c = Course(
        id: 'c1',
        name: '机器学习',
        teacher: '阮奕邦讲师',
        tone: 1,
        source: CourseSource.jwx,
        slots: const [
          CourseSlot(
              weekday: 1, startSlot: 1, slotCount: 2, weeks: [1, 2, 3],
              room: '7号楼(7B-311)'),
        ],
        note: '带笔记本',
      );
      final Course back = Course.fromJson(c.toJson());
      expect(back.id, c.id);
      expect(back.name, c.name);
      expect(back.teacher, c.teacher);
      expect(back.tone, 1);
      expect(back.source, CourseSource.jwx);
      expect(back.note, '带笔记本');
      expect(back.slots.single.weeks, [1, 2, 3]);
      expect(back.slots.single.room, '7号楼(7B-311)');
    });
  });

  group('TimetableRepository 存取与按来源合并', () {
    test('写入后能读回；抓取只替换同来源，手动录入不受影响', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final TimetableRepository repo = TimetableRepository.instance;
      await repo.load();
      expect(repo.isEmpty, isTrue);

      final Course manual = Course(
        id: 'm1',
        name: '手动课',
        source: CourseSource.manual,
        slots: const [
          CourseSlot(weekday: 1, startSlot: 1, slotCount: 2, weeks: [1]),
        ],
      );
      await repo.upsert(manual);

      final Course scraped = Course(
        id: 'j1',
        name: '教务课',
        source: CourseSource.jwx,
        slots: const [
          CourseSlot(weekday: 2, startSlot: 3, slotCount: 2, weeks: [1]),
        ],
      );
      await repo.replaceBySource(CourseSource.jwx, [scraped]);
      expect(repo.courses.length, 2);

      // 再抓一次：只换掉 jwx，手动课还在
      final Course again = Course(
        id: 'j2',
        name: '教务课二期',
        source: CourseSource.jwx,
        slots: const [
          CourseSlot(weekday: 3, startSlot: 1, slotCount: 2, weeks: [1]),
        ],
      );
      await repo.replaceBySource(CourseSource.jwx, [again]);
      expect(repo.courses.length, 2);
      expect(repo.byId('m1'), isNotNull);
      expect(repo.byId('j1'), isNull);
      expect(repo.byId('j2'), isNotNull);

      // 统计口径
      expect(repo.courseCountIn(1), 2);
      expect(repo.slotCountIn(1), 4);
    });
  });
}
