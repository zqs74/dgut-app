import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 大标题（.dg-ht）：顶部 66px，随滚动收缩并淡出。
/// CSS: translateY(-5t) scale(1 - .26t)；opacity: 1 - .92t；transform-origin: left bottom
class DgutLargeHeader extends StatelessWidget {
  const DgutLargeHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.progress = 0.0,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double t = progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DgutSpace.pad, 66, DgutSpace.pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow.isNotEmpty) ...[
            Text(
              eyebrow,
              style: DgutType.eyebrow.copyWith(color: c.ink3),
            ),
            const SizedBox(height: 10),
          ],
          Transform(
            alignment: Alignment.bottomLeft,
            transform: Matrix4.identity()
              ..translateByDouble(0, -5 * t, 0, 1)
              ..scaleByDouble(1 - 0.26 * t, 1 - 0.26 * t, 1, 1),
            child: Opacity(
              opacity: (1 - 0.92 * t).clamp(0.0, 1.0),
              child: Text(
                title,
                style: DgutType.largeTitle.copyWith(color: c.ink),
              ),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: DgutSpace.s1),
              child: Text(subtitle!,
                  style: DgutType.footnote.copyWith(color: c.ink2)),
            ),
        ],
      ),
    );
  }
}
