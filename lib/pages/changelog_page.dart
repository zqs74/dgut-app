import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../data/changelog.dart';
import '../theme/dgut_tokens.dart';

/// 版本更新历史：时间轴，最新在上。
class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
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
      body: Stack(
        children: [
          DgutPageScaffold(
            eyebrow: '共 ${kChangelog.length} 个版本',
            title: '版本更新历史',
            offset: _offset,
            footerHeight: 120,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad, DgutSpace.s3, DgutSpace.pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < kChangelog.length; i++)
                      _TimelineEntry(
                        entry: kChangelog[i],
                        first: i == 0,
                        last: i == kChangelog.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
          // 返回
          Positioned(
            left: DgutSpace.s2,
            top: DgutSpace.s2,
            child: SafeArea(
              child: DgutPressable(
                onTap: () => Navigator.of(context).maybePop(),
                pressedOpacity: 0.55,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.fill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 20, color: c.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.entry,
    required this.first,
    required this.last,
  });

  final ChangelogEntry entry;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return Stack(
      children: [
        // 竖线（最后一个版本不再往下延伸）
        if (!last)
          Positioned(
            left: 4.5,
            top: first ? 14 : 0,
            bottom: 0,
            width: 1,
            child: Container(color: c.line),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: first ? c.blue : c.bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: first ? c.blue : c.ink4,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: DgutSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(entry.version,
                            style: DgutType.title3.copyWith(color: c.ink)),
                        const SizedBox(width: 8),
                        Text(entry.date,
                            style: DgutType.footnote.copyWith(color: c.ink3)),
                        if (first) ...[
                          const SizedBox(width: 8),
                          DgutChip(
                              label: '当前',
                              tone: DgutChipTone.info),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final section in entry.sections) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          section.title,
                          style: DgutType.groupLabel.copyWith(color: c.ink3),
                        ),
                      ),
                      for (final item in section.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: c.ink4,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item,
                                  style: DgutType.subhead.copyWith(
                                    color: c.ink2,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
