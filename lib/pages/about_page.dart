import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../components/dgut_update_sheet.dart';
import '../data/changelog.dart';
import '../services/update_service.dart';
import '../theme/dgut_tokens.dart';
import 'changelog_page.dart';

/// 关于：当前版本 + 检查更新 + 版本更新历史。
///
/// 「检查更新」「版本更新历史」原本在「我的」的列表里，跟外观、通知那些
/// 日常设置混在一起 —— 它们是低频的、关于这个 App 本身的事，收到这里更合适，
/// 「我的」那一屏也就只剩真正会天天动的东西。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final ValueNotifier<DgutScrollInfo> _offset =
      ValueNotifier<DgutScrollInfo>(DgutScrollInfo.zero);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return Scaffold(
      backgroundColor: c.bg,
      body: DgutPageScaffold(
        eyebrow: '莞工统一 App',
        title: '关于',
        offset: _offset,
        onBack: () => Navigator.of(context).maybePop(),
        footerHeight: 120 + MediaQuery.viewPaddingOf(context).bottom,
        children: [
          // 当前版本：一眼能看到这个数字，不用再进一层
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad,
              DgutSpace.s3,
              DgutSpace.pad,
              DgutSpace.s2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本',
                  style: DgutType.footnote.copyWith(
                    color: c.ink2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'v$kCurrentVersion',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    height: 1,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '共 ${kChangelog.length} 个版本记录',
                  style: DgutType.caption1.copyWith(color: c.ink3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DgutGroupHead(title: '关于'),
                if (UpdateService.isSupported)
                  DgutRow(
                    title: '检查更新',
                    value: 'v$kCurrentVersion',
                    onTap: () => showDgutUpdateSheet(context),
                  ),
                DgutRow(
                  title: '版本更新历史',
                  showDivider: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChangelogPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
