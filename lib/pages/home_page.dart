import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../components/dgut_timeline.dart';
import '../theme/dgut_tokens.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.offset});

  final ValueNotifier<DgutScrollInfo> offset;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return DgutPageScaffold(
      eyebrow: '周一 · 第 11 周 · 10:05',
      title: '今天',
      offset: offset,
      footerHeight: 520,
      children: [
        DgutStatLine(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, 2),
          spans: [
            dgutPlain('今天 '),
            dgutStrong(context, '3'),
            dgutPlain(' 件事 · 已过 '),
            dgutStrong(context, '1'),
            dgutPlain(' · 还有 '),
            dgutStrong(context, '2'),
          ],
        ),
        const SizedBox(height: DgutSpace.s1),
        const DgutTimeline(
          items: [
            DgutTimelineItemData(
              time: '08:00',
              title: '机器学习',
              subtitle: '7B-311 · 阮老师 · 已结束',
              state: DgutTimelineState.past,
            ),
            DgutTimelineItemData(
              time: '10:20',
              title: '大数据采集与集成技术',
              subtitle: '7B-412 · 肖老师 · 10:20–11:55',
              state: DgutTimelineState.now,
            ),
            DgutTimelineItemData(
              time: '18:30',
              title: '形势与政策 · 讲座签到',
              subtitle: '学术会议厅 · 需要扫码',
            ),
          ],
        ),
        // 待办：只露最急一条
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DgutGroupHead(
                title: '待办',
                action: '全部 2 条',
                onAction: () {},
              ),
              DgutRow(
                title: '晚归申请未提交',
                subtitle: '今晚 22:00 截止',
                tone: DgutRowTone.urgent,
                showDivider: false,
                onTap: () {},
              ),
            ],
          ),
        ),
        // 本周概况：一行统计，不重复课程清单
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s1, DgutSpace.pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DgutGroupHead(
                title: '本周',
                action: '查看课表 ›',
                onAction: () {},
              ),
              const DgutLegend('4 门课 · 18 节 · 周一 1–2 有 1 处撞课'),
            ],
          ),
        ),
        // 控件区：与内容用留白隔开（HIG: differentiate controls from content）
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s3, DgutSpace.pad, 0),
          child: Row(
            children: [
              _QuickItem(
                icon: Icons.qr_code_2_rounded,
                label: '莞工码',
                color: c.greenInk,
              ),
              const SizedBox(width: 2),
              _QuickItem(
                icon: Icons.water_drop_outlined,
                label: '开热水',
                color: c.blueInk,
              ),
              const SizedBox(width: 2),
              _QuickItem(
                icon: Icons.calendar_month_outlined,
                label: '课表',
                color: c.orangeInk,
              ),
              const SizedBox(width: 2),
              _QuickItem(
                icon: Icons.pie_chart_outline_rounded,
                label: '学分',
                color: c.violetInk,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Expanded(
      child: DgutPressable(
        onTap: () {},
        pressedScale: 0.94,
        pressedOpacity: 1,
        pressedFill: c.fill,
        radius: BorderRadius.circular(DgutRadius.r2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 9),
              Text(
                label,
                style: DgutType.caption1.copyWith(
                    color: c.ink2, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
