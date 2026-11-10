/// 莞工作息表。
///
/// 来源：2026-11-10 用户手机上的课表截图（第 1 节 08:30–09:15，上午四节、
/// 下午 14:30 起三节、晚上 19:00 起）。**只做莞工，不引入多套作息**；
/// 课程数据里只存节次，时间由这里提供，所以以后学校调作息只改这一张表。
class DgutPeriod {
  const DgutPeriod(this.start, this.end);

  /// "08:30"
  final String start;

  /// "09:15"
  final String end;
}

const List<DgutPeriod> kDgutPeriods = <DgutPeriod>[
  DgutPeriod('08:30', '09:15'),
  DgutPeriod('09:25', '10:10'),
  DgutPeriod('10:25', '11:10'),
  DgutPeriod('11:20', '12:05'),
  DgutPeriod('14:30', '15:15'),
  DgutPeriod('15:25', '16:10'),
  DgutPeriod('16:20', '17:05'),
  DgutPeriod('19:00', '19:45'),
  DgutPeriod('19:55', '20:40'),
  DgutPeriod('20:50', '21:35'),
  DgutPeriod('21:45', '22:30'),
  DgutPeriod('22:40', '23:25'),
];

/// 当前生效的作息。仓储启动时把本机存的那一套塞进来，改作息后再塞一次；
/// 课表轴、详情页、现在线都从这里读，所以改完不用重启页面。
class DgutClock {
  DgutClock._();

  static List<DgutPeriod> periods = kDgutPeriods;

  static void set(List<DgutPeriod> next) {
    periods = List<DgutPeriod>.unmodifiable(next);
  }
}

int get dgutPeriodCount => DgutClock.periods.length;

DgutPeriod? dgutPeriodAt(int slot) =>
    slot >= 1 && slot <= DgutClock.periods.length
    ? DgutClock.periods[slot - 1]
    : null;

/// "10:25–12:05"；越界时返回空串，不让详情页因为脏数据崩
String dgutTimeSpan(int startSlot, int slotCount) {
  final DgutPeriod? a = dgutPeriodAt(startSlot);
  final DgutPeriod? b = dgutPeriodAt(startSlot + slotCount - 1);
  if (a == null || b == null) return '';
  return '${a.start}–${b.end}';
}

/// 当前分钟数（用于课表里的"现在"红线）
int get dgutNowMinutes {
  final DateTime now = DateTime.now();
  return now.hour * 60 + now.minute;
}

int dgutMinutesOf(String hhmm) {
  final List<String> p = hhmm.split(':');
  if (p.length != 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

/// 现在落在第几节：节内返回 (节次, 0~1 的进度)；课间返回下一节的起点。
/// 返回 null 表示今天已经没有课（早于第 1 节或晚于最后一节）。
(double row, double progress)? dgutNowPosition() {
  final int now = dgutNowMinutes;
  for (var i = 0; i < DgutClock.periods.length; i++) {
    final DgutPeriod p = DgutClock.periods[i];
    final int a = dgutMinutesOf(p.start);
    final int b = dgutMinutesOf(p.end);
    if (now >= a && now <= b) {
      return (i.toDouble(), (now - a) / (b - a));
    }
    if (now < a) return (i.toDouble(), 0);
  }
  return null;
}
