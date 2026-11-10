import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

/// 滚动浮现的顶栏（.dg-topbar）：高 96，标题底部对齐。
///
/// 顶栏自己**不做模糊**。顶上那层模糊由 `DgutEdgeBlur` 统一提供：
/// 两边各画一次模糊时，边缘高度(118)与顶栏高度(96)对不齐，会看出两层。
/// 现在顶栏只是一块透明画布 + 渐显的标题，压在连续模糊之上。
class DgutTopBar extends StatelessWidget {
  const DgutTopBar({
    super.key,
    required this.title,
    required this.offset,
  });

  final String title;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double p = DgutMotion.barProgress(offset);

    if (p <= 0.001) {
      return const SizedBox(height: 96, width: double.infinity);
    }

    return IgnorePointer(
      child: SizedBox(
        height: 96,
        width: double.infinity,
        child: Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, -6 * (1 - p)),
            child: Container(
              padding: const EdgeInsets.only(bottom: 11),
              alignment: Alignment.bottomCenter,
              child: Text(
                title,
                style: DgutType.headline.copyWith(color: c.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}