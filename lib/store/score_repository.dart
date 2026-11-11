import '../model/score.dart';
import 'store.dart';

/// 成绩本地缓存。
///
/// 抓一次就存下来，下次进来先显示旧的、再后台刷新 —— 教务系统偶尔抽风，
/// 不该让用户对着空白页等。
class ScoreRepository {
  ScoreRepository._();

  static final ScoreRepository instance = ScoreRepository._();

  static const String _key = 'scores.v1';
  static const String _fetchedAtKey = 'scores.fetchedAt.v1';

  Future<List<DgutScore>> load() async {
    await Store.instance.init();
    final List<dynamic>? list = Store.instance.readJsonList(_key);
    if (list == null) return const <DgutScore>[];
    final List<DgutScore> out = <DgutScore>[];
    for (final dynamic e in list) {
      if (e is! Map) continue;
      final Map<String, String> cells = <String, String>{};
      e.forEach((dynamic k, dynamic v) {
        if (k is String && v is String) cells[k] = v;
      });
      if (cells.isNotEmpty) out.add(DgutScore(cells: cells));
    }
    return out;
  }

  Future<void> save(List<DgutScore> scores) async {
    await Store.instance.init();
    await Store.instance.writeJson(_key, <Map<String, String>>[
      for (final DgutScore s in scores) s.cells,
    ]);
    await Store.instance.writeString(
      _fetchedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> lastFetchedAt() async {
    await Store.instance.init();
    final String? raw = Store.instance.readString(_fetchedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clear() async {
    await Store.instance.init();
    await Store.instance.remove(_key);
    await Store.instance.remove(_fetchedAtKey);
  }
}
