import 'package:flutter/material.dart';

import 'services/session.dart';
import 'shell/dgut_shell.dart';
import 'store/store.dart';
import 'store/timetable_repository.dart';
import 'theme/dgut_motion.dart';
import 'theme/dgut_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先把本机存储与课表读进来，再起界面 —— 否则第一帧会先闪一下空课表再被数据顶掉
  await Store.instance.init();
  final TimetableRepository repo = TimetableRepository.instance;
  await repo.load();
  // 登录态也一起读：进「我的」时不该先闪一下"未登录"
  await Session.instance.load();

  // 验收用的深链：?seed=1 写入示例课表（仅在为空时），?seed=reset 清空
  final String seed = Uri.base.queryParameters['seed'] ?? '';
  if (seed == '1') {
    await repo.seedDemo();
  } else if (seed == 'reset') {
    await repo.clearCourses();
  }

  runApp(const DgutApp());
}

class DgutApp extends StatefulWidget {
  const DgutApp({super.key});

  @override
  State<DgutApp> createState() => _DgutAppState();
}

class _DgutAppState extends State<DgutApp> {
  late ThemeMode _mode;
  late int _start;

  @override
  void initState() {
    super.initState();
    // 深链：?p=0..4 指定首屏，?dark=1 强制深色，?demo=1 自动轮播
    final Map<String, String> q = Uri.base.queryParameters;
    _start = (int.tryParse(q['p'] ?? '') ?? 0).clamp(0, 4);
    _mode = q['dark'] == '1' ? ThemeMode.dark : ThemeMode.system;
  }

  void _setMode(ThemeMode m) => setState(() => _mode = m);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '一莞通',
      debugShowCheckedModeBanner: false,
      theme: buildDgutTheme(Brightness.light),
      darkTheme: buildDgutTheme(Brightness.dark),
      themeMode: _mode,
      themeAnimationDuration: DgutMotion.themeFade,
      home: DgutShell(
        themeMode: _mode,
        onThemeModeChanged: _setMode,
        initialIndex: _start,
      ),
    );
  }
}
