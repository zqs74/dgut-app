import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../components/dgut_theme_sheet.dart';
import '../components/dgut_update_sheet.dart';
import '../data/changelog.dart';
import '../services/update_service.dart';
import '../theme/dgut_tokens.dart';

class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.offset,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onOpenChangelog,
  });

  final ValueNotifier<DgutScrollInfo> offset;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onOpenChangelog;

  String get _themeLabel => switch (themeMode) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '浅色',
        ThemeMode.dark => '深色',
      };

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return DgutPageScaffold(
      eyebrow: '',
      title: '我的',
      showHeader: false,
      offset: offset,
      children: [
        const SizedBox(height: 66),
        // 身份
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: const Alignment(-0.5, -1),
                    end: const Alignment(0.6, 1),
                    colors: [c.brand, c.brandInk],
                  ),
                ),
                child: const Text(
                  '张',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: DgutSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('张淇森',
                        style: DgutType.title3.copyWith(color: c.ink)),
                    const SizedBox(height: 3),
                    Text('2024463030442 · 数据科学与大数据技术',
                        style: DgutType.footnote.copyWith(color: c.ink3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 学分：一个总数字 + 三条进度
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s4, DgutSpace.pad, DgutSpace.s1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('毕业学分',
                  style: DgutType.footnote
                      .copyWith(color: c.ink2, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('22',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.5,
                        height: 1,
                        color: c.ink,
                      )),
                  const SizedBox(width: 4),
                  Text('分待修',
                      style: DgutType.callout.copyWith(color: c.ink3)),
                ],
              ),
              const SizedBox(height: 10),
              DgutMeter(name: '必修', value: '32 / 48', ratio: 32 / 48),
              DgutMeter(
                  name: '选修', value: '6 / 10', ratio: 6 / 10, color: c.green),
              DgutMeter(
                  name: '通识', value: '2 / 6', ratio: 2 / 6, color: c.violet),
            ],
          ),
        ),
        // 设置
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DgutGroupHead(title: '设置'),
              DgutRow(
                title: '外观',
                subtitle: '跟随系统 / 浅色 / 深色',
                value: _themeLabel,
                showChevron: true,
                onTap: () async {
                  final ThemeMode? mode =
                      await showDgutThemeSheet(context, themeMode);
                  if (mode != null) onThemeModeChanged(mode);
                },
              ),
              DgutRow(title: '课表设置', subtitle: '节次时间、周起始日', onTap: () {}),
              DgutRow(title: '通知与提醒', onTap: () {}),
              if (UpdateService.isSupported)
                DgutRow(
                  title: '检查更新',
                  subtitle: '从 GitHub Releases 取最新版',
                  value: 'v$kCurrentVersion',
                  onTap: () => showDgutUpdateSheet(context),
                ),
              DgutRow(
                title: '版本更新历史',
                subtitle: '每次更新改了什么',
                onTap: onOpenChangelog,
              ),
              DgutRow(
                title: '关于莞工 App',
                value: 'v$kCurrentVersion',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
