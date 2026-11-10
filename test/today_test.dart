import 'package:flutter_test/flutter_test.dart';

import 'package:dgut_app/data/today.dart';
import 'package:dgut_app/model/course.dart';
import 'package:dgut_app/model/term_calendar.dart';

/// 第 1 周周一 = 2026-08-31（与 `default_term.dart` 同一个锚点，
/// 这里写死是为了哪天学期换了、这个文件只红自己）
TermCalendar term() => TermCalendar(
  week1Monday: DateTime(2026, 8, 31),
  weekCount: 20,
);

Course course({
  String id = 'c1',
  String name = '机器学习',
  String teacher = '阮奕邦',
  int weekday = 2,
  int startSlot = 1,
  int slotCount = 2,
  List<int>? weeks,
  String room = '7B-311',
}) => Course(
  id: id,
  name: name,
  teacher: teacher,
  slots: <CourseSlot>[
    CourseSlot(
      weekday: weekday,
      startSlot: startSlot,
      slotCount: slotCount,
      weeks: weeks ?? <int>[for (int w = 1; w <= 16; w++) w],
      room: room,
    ),
  ],
);

void main() {
  group('视图日 · 什么时候切到明天', () {
    test('今天还有待上的课 → 留在今天', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course(startSlot: 5)], // 14:30 那节，09:00 时还没到
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.showingTomorrow, isFalse);
      expect(s.title, '今天');
      expect(s.items.length, 1);
      expect(s.items.first.state, TodayState.todo);
    });

    test('今天的课全上完了 → 切明天，内容是明天的课', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a', name: '机器学习', weekday: 2, startSlot: 1),
          course(id: 'b', name: '大数据技术', weekday: 3, startSlot: 3, room: '7B-408'),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 10, 23, 0),
      );
      expect(s.showingTomorrow, isTrue);
      expect(s.title, '明天');
      expect(s.items.length, 1);
      expect(s.items.first.course.name, '大数据技术');
      // 明天的课一律是「待上」
      expect(s.items.first.state, TodayState.todo);
      expect(s.daySpan, '10:25–12:00');
    });

    test('今天本来就没课 → 也切明天（不是留着空白）', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course(weekday: 3, name: '大数据技术')],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0), // 周二
      );
      expect(s.showingTomorrow, isTrue);
      expect(s.items.length, 1);
      expect(s.items.first.course.name, '大数据技术');
    });

    test('正在上的那节算「还没上完」，不切', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course()],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0), // 第 1-2 节 08:30–10:10 之内
      );
      expect(s.showingTomorrow, isFalse);
      expect(s.items.first.state, TodayState.now);
    });

    test('午休时上午的课已过、下午还有 → 不切', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a', startSlot: 1),
          course(id: 'b', name: '自然语言处理', startSlot: 5),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 10, 13, 0),
      );
      expect(s.showingTomorrow, isFalse);
      expect(s.pastCount, 1);
      expect(s.todoCount, 1);
    });
  });

  group('视图日 · 眉标与标题', () {
    test('今天视图给时刻', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course()],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.title, '今天');
      expect(s.eyebrow(DateTime(2026, 11, 10, 9, 0)), '周二 · 第 11 周 · 09:00');
    });

    test('明天视图给日期，不给时刻', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a', weekday: 2, startSlot: 1),
          course(id: 'b', name: '大数据技术', weekday: 3, startSlot: 3),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 10, 23, 0),
      );
      expect(s.title, '明天');
      expect(s.viewWeekday, DateTime.wednesday);
      expect(s.eyebrow(DateTime(2026, 11, 10, 23, 0)), '周三 · 11 月 11 日 · 第 11 周');
    });

    test('跨周那天：周日晚上看周一，周次与日期都跟着视图日走', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a', weekday: 7, startSlot: 1), // 周日有课
          course(id: 'b', name: '大数据技术', weekday: 1, startSlot: 3),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 15, 23, 0), // 第 11 周周日
      );
      expect(s.showingTomorrow, isTrue);
      expect(s.week, 12);
      expect(s.weekLabel, '第 12 周');
      expect(s.viewWeekday, DateTime.monday);
    });

    test('开学前是「未开学」，学期后是「假期」', () {
      final TodaySnapshot before = buildToday(
        courses: const <Course>[],
        calendar: term(),
        now: DateTime(2026, 8, 20, 10, 0),
      );
      expect(before.week, 0);
      expect(before.weekLabel, '未开学');

      final TodaySnapshot after = buildToday(
        courses: const <Course>[],
        calendar: term(),
        now: DateTime(2027, 3, 1, 10, 0),
      );
      expect(after.week, 0);
      expect(after.weekLabel, '假期');
    });
  });

  group('三态', () {
    test('09:00 时第一节正在上、第二节待上', () {
      final List<Course> two = <Course>[
        course(id: 'a', name: '机器学习', startSlot: 1),
        course(id: 'b', name: '大数据技术', startSlot: 3),
      ];
      final TodaySnapshot s = buildToday(
        courses: two,
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.items.length, 2);
      expect(s.items[0].course.name, '机器学习');
      expect(s.items[0].state, TodayState.now);
      expect(s.items[1].state, TodayState.todo);
      expect(s.items[0].spanLabel, '08:30–10:10');
      expect(s.pastCount, 0);
    });

    test('12:10（课间）上一节已过、下一节待上', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a', startSlot: 1),
          course(id: 'b', name: '自然语言处理', startSlot: 5),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 10, 12, 10),
      );
      expect(s.items[0].state, TodayState.past);
      expect(s.items[1].state, TodayState.todo);
    });

    test('同一天同一门课两段会各算一节，并按开始时间排序', () {
      final Course multi = Course(
        id: 'm',
        name: '自然语言处理',
        teacher: '李四',
        slots: <CourseSlot>[
          CourseSlot(
            weekday: 3,
            startSlot: 3,
            slotCount: 2,
            weeks: <int>[for (int w = 1; w <= 16; w++) w],
            room: '7B-411',
          ),
          CourseSlot(
            weekday: 3,
            startSlot: 1,
            slotCount: 2,
            weeks: <int>[for (int w = 1; w <= 16; w++) w],
            room: '7B-411',
          ),
        ],
      );
      final TodaySnapshot s = buildToday(
        courses: <Course>[multi],
        calendar: term(),
        now: DateTime(2026, 11, 11, 7, 0),
      );
      expect(s.items.length, 2);
      expect(s.items[0].slot.startSlot, 1);
      expect(s.items[1].slot.startSlot, 3);
    });
  });

  group('周次与调休', () {
    test('只上单周的课在第 2 周不出现', () {
      final Course odd = course(weeks: <int>[1, 3, 5, 7, 9, 11]);
      final TodaySnapshot w2 = buildToday(
        courses: <Course>[odd],
        calendar: term(),
        now: DateTime(2026, 9, 8, 9, 0), // 第 2 周周二
      );
      expect(w2.items, isEmpty);

      final TodaySnapshot w3 = buildToday(
        courses: <Course>[odd],
        calendar: term(),
        now: DateTime(2026, 9, 15, 9, 0), // 第 3 周周二
      );
      expect(w3.items.length, 1);
    });

    test('调休：周六按周一课表上课时，周一的课出现在周六', () {
      final TermCalendar withMakeup = TermCalendar(
        week1Monday: DateTime(2026, 8, 31),
        weekCount: 20,
        exceptions: <DayException>[
          DayException(date: DateTime(2026, 9, 26), followsWeekday: 1), // 周六
        ],
      );
      final TodaySnapshot s = buildToday(
        courses: <Course>[course(weekday: 1)],
        calendar: withMakeup,
        now: DateTime(2026, 9, 26, 9, 0),
      );
      expect(s.items.length, 1);
      expect(s.viewWeekday, DateTime.saturday);
    });

    test('停课日今天没课', () {
      final TermCalendar holiday = TermCalendar(
        week1Monday: DateTime(2026, 8, 31),
        weekCount: 20,
        exceptions: <DayException>[
          DayException(date: DateTime(2026, 11, 10), holiday: true),
        ],
      );
      final TodaySnapshot s = buildToday(
        courses: <Course>[course()],
        calendar: holiday,
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.items, isEmpty);
    });
  });

  group('下一节：只在视图日没课时才给', () {
    test('视图日有课 → 不给下一节（已经在看那天的课了）', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course(startSlot: 5)],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.next, isNull);
      expect(s.nextSummary, isNull);
    });

    test('今天上完了、明天也有课 → 不给（明天就在眼前）', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a', weekday: 2),
          course(id: 'b', name: '大数据技术', weekday: 3, startSlot: 3),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 10, 23, 0),
      );
      expect(s.showingTomorrow, isTrue);
      expect(s.next, isNull);
    });

    test('明天也没课 → 给出再往后那天', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a', weekday: 2, startSlot: 1),
          course(id: 'c', name: 'Python数据分析与应用', weekday: 5, startSlot: 5, room: '6F-202'),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 10, 23, 0), // 周二晚；周三无课，周四无课，周五有
      );
      expect(s.showingTomorrow, isTrue);
      expect(s.items, isEmpty);
      expect(s.nextDayLabel, '周五');
      expect(s.nextSummary, startsWith('周五 14:30 Python数据分析与应用'));
      expect(s.nextSummary, contains('6F-202'));
    });

    test('整学期没课 → 保持 null', () {
      final TodaySnapshot s = buildToday(
        courses: const <Course>[],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.next, isNull);
      expect(s.nextSummary, isNull);
    });
  });

  group('本周概况', () {
    test('门数 / 节数 / 撞课位置', () {
      final List<Course> clash = <Course>[
        course(id: 'a', name: '机器学习', startSlot: 1),
        course(id: 'b', name: '形势与政策5', startSlot: 1), // 与 a 同格
        course(id: 'c', name: '大数据技术', startSlot: 3),
      ];
      final TodaySnapshot s = buildToday(
        courses: clash,
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.courseCount, 3);
      expect(s.slotCount, 6);
      expect(s.clashLabels.length, 1);
      expect(s.clashLabels.first, '周二 1–2');
      expect(s.weekSummary, '3 门课 · 6 节 · 1 处撞课（周二 1–2）');
    });

    test('没有撞课时写「无撞课」，不写「0 处」', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course()],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.clashLabels, isEmpty);
      expect(s.clashText, '无撞课');
    });

    test('课表为空时给的是出路，不是「暂无数据」', () {
      final TodaySnapshot s = buildToday(
        courses: const <Course>[],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.hasCourses, isFalse);
      expect(s.weekSummary, '课表为空，去课表页添加课程');
    });

    test('假期里统计落到第 1 周，门数仍是真的', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course()],
        calendar: term(),
        now: DateTime(2027, 3, 1, 10, 0),
      );
      expect(s.week, 0);
      expect(s.weekSummary, '假期中 · 全学期 1 门课');
    });
  });

  group('副标题', () {
    test('地点 · 状态 · 教师，教师名在后（会被截断的是它）', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a', startSlot: 1),
          course(id: 'b', name: '自然语言处理', startSlot: 5),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 10, 11, 0), // 第 1-2 节已过，下午还有课 → 留在今天
      );
      expect(s.items.first.subtitle, '7B-311 · 已结束 · 阮奕邦');
    });

    test('空地点与空教师都不留下多余的分隔点', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course(room: '', teacher: '')],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.items.first.subtitle, '08:30–10:10');
    });
  });
}
