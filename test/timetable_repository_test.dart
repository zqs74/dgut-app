import 'package:dgut_app/data/default_periods.dart';
import 'package:dgut_app/store/store.dart';
import 'package:dgut_app/store/timetable_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _v1Course = '[{"id":"c1","name":"机器学习","tone":1,'
    '"source":"manual","note":"点名","slots":[{"weekday":1,"startSlot":1,'
    '"slotCount":2,"weeks":[1,2,3],"room":"7B-311"}]}]';

Future<void> _boot(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  await Store.instance.reload();
  await TimetableRepository.instance.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1 单表迁进 v2，课程与备注都不丢，旧键保留', () async {
    await _boot(<String, Object>{'dgut.timetable.v1': _v1Course});
    final TimetableRepository repo = TimetableRepository.instance;

    expect(repo.tables.length, 1);
    expect(repo.activeName, '我的课表');
    expect(repo.courses.single.name, '机器学习');
    expect(repo.courses.single.note, '点名');
    expect(repo.courses.single.slots.single.room, '7B-311');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dgut.tables.v2'), isNotNull);
    expect(prefs.getString('dgut.timetable.v1'), _v1Course);
  });

  test('新建课表后课程隔离，切回原表还在', () async {
    await _boot(<String, Object>{'dgut.timetable.v1': _v1Course});
    final TimetableRepository repo = TimetableRepository.instance;
    final String first = repo.activeId;

    await repo.createTable('下学期');
    expect(repo.tables.length, 2);
    expect(repo.courses, isEmpty);

    await repo.switchTable(first);
    expect(repo.courses.single.name, '机器学习');
  });

  test('只剩一张课表时删不掉', () async {
    await _boot(<String, Object>{'dgut.timetable.v1': _v1Course});
    final TimetableRepository repo = TimetableRepository.instance;
    await repo.deleteTable(repo.activeId);
    expect(repo.tables.length, 1);
  });

  test('固定时长开启后，结束时间由开始时间推出', () async {
    await _boot(<String, Object>{});
    final TimetableRepository repo = TimetableRepository.instance;
    await repo.setDuration(40);
    await repo.setFixedDuration(true);
    expect(repo.periods.first.end, dgutShift(repo.periods.first.start, 40));
  });

  test('节数可以增减，加出来的节接在末尾', () async {
    await _boot(<String, Object>{});
    final TimetableRepository repo = TimetableRepository.instance;
    await repo.setPeriodCount(13);
    expect(repo.periods.length, 13);
    expect(repo.periods.last.start.compareTo(repo.periods[11].end), greaterThan(0));
    await repo.setPeriodCount(5);
    expect(repo.periods.length, 5);
  });
  test('改作息同时更新 DgutClock，重载后还在', () async {
    await _boot(<String, Object>{});
    final TimetableRepository repo = TimetableRepository.instance;

    final List<DgutPeriod> next = List<DgutPeriod>.of(repo.periods);
    next[0] = const DgutPeriod('08:00', '08:45');
    await repo.setPeriods(next);
    expect(DgutClock.periods.first.start, '08:00');

    await repo.load();
    expect(DgutClock.periods.first.start, '08:00');
  });
}
