import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, required this.offset});

  final ValueNotifier<DgutScrollInfo> offset;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late int _seg = int.tryParse(
        Uri.base.queryParameters['seg'] ?? '',
      )?.clamp(0, 1) ??
      0;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return DgutPageScaffold(
      eyebrow: '',
      title: '消息',
      offset: widget.offset,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, DgutSpace.s1),
          child: _PillSeg(
            labels: const ['待办 4', '通知 3'],
            index: _seg,
            onSelect: (i) => setState(() => _seg = i),
          ),
        ),
        // 分段切换要"推过去"而不是硬切：进的从右侧滑入，出的向左滑走
        AnimatedSwitcher(
          duration: DgutMotion.exit,
          switchInCurve: DgutMotion.easeOutCubic,
          switchOutCurve: DgutMotion.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previous,
              ?current,
            ],
          ),
          transitionBuilder: (child, anim) {
            final bool incoming = child.key == ValueKey<int>(_seg);
            final double dx = incoming ? 0.06 : -0.06;
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(dx, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_seg),
            child: _seg == 0 ? _todoBlock(c) : _noticeBlock(c),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s3, DgutSpace.pad, 0),
          child: Text(
            '消息只显示最近 7 天，过期归档',
            style: DgutType.caption1.copyWith(color: c.ink3),
          ),
        ),
      ],
    );
  }

  Widget _todoBlock(DgutColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 最急一条升为主块
        DgutHero(
          label: '今晚 22:00 截止',
          value: '晚归申请未提交',
          meta: '逾期需线下报备 · 莞工学工',
          foot: Row(
            children: [
              DgutChip(label: '待办', tone: DgutChipTone.danger),
              const Spacer(),
              DgutButton(
                label: '去填写',
                size: DgutButtonSize.sm,
                variant: DgutButtonVariant.filled,
                onTap: () {},
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DgutGroupHead(title: '其余待办'),
              DgutRow(
                title: '形势与政策 · 讲座签到',
                subtitle: '今晚 18:30 开始',
                value: '今天',
                tone: DgutRowTone.soon,
                onTap: () {},
              ),
              DgutRow(
                title: '选课确认',
                subtitle: '周五 17:00 截止',
                value: '10 月 31 日',
                onTap: () {},
              ),
              DgutRow(
                title: '实验报告（三）',
                subtitle: '大数据采集与集成技术',
                value: '11 月 8 日',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noticeBlock(DgutColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: DgutSpace.s2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DgutRow(
              title: '图书馆闭馆通知',
              subtitle: '11 月 9 日 上午检修',
              value: '昨天',
              onTap: () {},
            ),
            DgutRow(
              title: '热水系统维护',
              subtitle: '18:00–20:00 停供',
              value: '11 月 7 日',
              onTap: () {},
            ),
            DgutRow(
              title: '奖学金公示',
              subtitle: '计算机学院 · 名单见附件',
              value: '11 月 6 日',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// 胶囊式二选一（.dg-seg）
class _PillSeg extends StatelessWidget {
  const _PillSeg({
    required this.labels,
    required this.index,
    required this.onSelect,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(DgutRadius.full),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: DgutPressable(
                onTap: () => onSelect(i),
                pressedOpacity: 0.7,
                child: AnimatedContainer(
                  duration: DgutMotion.exit,
                  curve: DgutMotion.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? c.surface2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(DgutRadius.full),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: c.line,
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          i == index ? FontWeight.w600 : FontWeight.w500,
                      color: i == index ? c.ink : c.ink3,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
