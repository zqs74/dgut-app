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
  group('首页今天 · 眉标', () {
    test('第 11 周周二 09:00', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course()],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.week, 11);
      expect(s.weekday, 2);
      expect(s.eyebrow(DateTime(2026, 11, 10, 9, 0)), '周二 · 第 11 周 · 09:00');
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

  group('首页今天 · 三态', () {
    // 第 1-2 节 08:30–10:10；第 3-4 节 10:25–12:00；第 5-6 节 14:30–16:10
    final List<Course> two = <Course>[
      course(id: 'a', name: '机器学习', startSlot: 1),
      course(id: 'b', name: '大数据技术', startSlot: 3),
    ];

    test('09:00 时第一节正在上、第二节待上', () {
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

    test('13:00 午休时两节都算已过，且没有"正在上"', () {
      final TodaySnapshot s = buildToday(
        courses: two,
        calendar: term(),
        now: DateTime(2026, 11, 10, 13, 0),
      );
      expect(s.items[0].state, TodayState.past);
      expect(s.items[1].state, TodayState.past);
      expect(s.pastCount, 2);
      expect(s.todoCount, 0);
    });

    test('12:10（课间）上一节已过、下一节待上', () {
      final TodaySnapshot s = buildToday(
        courses: two,
        calendar: term(),
        now: DateTime(2026, 11, 10, 12, 10),
      );
      expect(s.items[0].state, TodayState.past);
      expect(s.items[1].state, TodayState.past);
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

  group('首页今天 · 周次与调休', () {
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
          DayException(
            date: DateTime(2026, 9, 26), // 周六
            followsWeekday: 1,
          ),
        ],
      );
      final TodaySnapshot s = buildToday(
        courses: <Course>[course(weekday: 1)],
        calendar: withMakeup,
        now: DateTime(2026, 9, 26, 9, 0),
      );
      expect(s.items.length, 1);
      expect(s.weekday, DateTime.saturday);
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

  group('首页今天 · 下一节', () {
    test('今天还有课 → 今天', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course(startSlot: 5)],
        calendar: term(),
        now: DateTime(2026, 11, 10, 9, 0),
      );
      expect(s.nextDayLabel, '今天');
      expect(s.nextSummary, startsWith('今天 14:30 机器学习'));
    });

    test('今天上完了 → 明天', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[
          course(id: 'a'),
          course(id: 'b', name: '大数据技术', weekday: 3, room: '7B-412'),
        ],
        calendar: term(),
        now: DateTime(2026, 11, 10, 23, 0),
      );
      expect(s.nextDayLabel, '明天');
      expect(s.nextSummary, startsWith('明天 08:30 大数据技术'));
    });

    test('一周只有周二有课，周二晚上看到的下一节是下周二', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course()],
        calendar: term(),
        now: DateTime(2026, 11, 10, 23, 0),
      );
      expect(s.nextDayLabel, '周二');
      expect(s.nextSummary, startsWith('周二 08:30 机器学习'));
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

  group('首页今天 · 本周概况', () {
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

  group('首页今天 · 副标题', () {
    test('地点 · 状态 · 教师，教师名在后（会被截断的是它）', () {
      final TodaySnapshot s = buildToday(
        courses: <Course>[course(teacher: '张剑副研究员')],
        calendar: term(),
        now: DateTime(2026, 11, 10, 23, 0),
      );
      expect(s.items.first.subtitle, '7B-311 · 已结束 · 张剑副研究员');
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
