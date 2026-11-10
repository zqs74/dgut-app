import 'package:flutter/material.dart';

import 'shell/dgut_shell.dart';
import 'theme/dgut_motion.dart';
import 'theme/dgut_theme.dart';

void main() {
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
      title: '莞工',
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
