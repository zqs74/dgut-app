import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

enum DgutTimelineState { past, now, todo }

class DgutTimelineItemData {
  const DgutTimelineItemData({
    required this.time,
    required this.title,
    this.subtitle,
    this.state = DgutTimelineState.todo,
    this.onTap,
  });

  final String time;
  final String title;
  final String? subtitle;
  final DgutTimelineState state;
  final VoidCallback? onTap;
}

/// 一天的时间线（.dg-timeline）：44 时间列 + 10 圆点列 + 正文。
/// 竖线用 Stack 的 Positioned(top/bottom) 贯穿整行，行高由文字自然撑开。
class DgutTimeline extends StatelessWidget {
  const DgutTimeline({super.key, required this.items});

  final List<DgutTimelineItemData> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _TimelineRow(
              data: items[i],
              isFirst: i == 0,
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.data,
    required this.isFirst,
    required this.isLast,
  });

  final DgutTimelineItemData data;
  final bool isFirst;
  final bool isLast;

  static const double _timeW = 44;
  static const double _gapW = 14;
  static const double _markW = 10;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool now = data.state == DgutTimelineState.now;
    final bool past = data.state == DgutTimelineState.past;
    final bool single = isFirst && isLast;

    final Widget row = Stack(
      children: [
        if (!single)
          Positioned(
            left: _timeW + _gapW + _markW / 2 - 0.5,
            top: isFirst ? 14 : 0,
            bottom: isLast ? 22 : 0,
            width: 1,
            child: Container(color: c.line),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeW,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  data.time,
                  style: DgutType.caption1
                      .copyWith(color: c.ink3, letterSpacing: -0.12),
                ),
              ),
            ),
            const SizedBox(width: _gapW),
            SizedBox(
              width: _markW,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: now ? c.blue : c.bg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: now ? c.blue : c.ink4,
                        width: 1.5,
                      ),
                      boxShadow: now
                          ? [
                              BoxShadow(
                                color: c.blue.withValues(alpha: 0.28),
                                blurRadius: 0,
                                spreadRadius: 4,
                              )
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: _gapW),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      style: DgutType.body.copyWith(
                        color: c.ink,
                        height: 1.35,
                        fontWeight: now ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (data.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          data.subtitle!,
                          style: DgutType.footnote
                              .copyWith(color: c.ink3, height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return DgutTappableRow(
      onTap: data.onTap,
      child: Opacity(opacity: past ? 0.45 : 1, child: row),
    );
  }
}

/// 时间线行用的极简按压（只降不透明度，与 .dg-timeline__item 一致）
class DgutTappableRow extends StatefulWidget {
  const DgutTappableRow({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<DgutTappableRow> createState() => _DgutTappableRowState();
}

class _DgutTappableRowState extends State<DgutTappableRow> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) => setState(() => _p = false),
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedOpacity(
        opacity: _p ? 0.45 : 1,
        duration: DgutMotion.contact,
        curve: Curves.linear,
        child: widget.child,
      ),
    );
  }
}
