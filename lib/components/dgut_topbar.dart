import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 滚动浮现的顶栏（.dg-topbar）：高 96，标题底部对齐、左对齐。
///
/// 三条约定：
/// 1. **自己不做模糊**。顶上那层模糊只由 `DgutEdgeBlur` 提供，两边各画一次
///    会看出两层。
/// 2. **标题左对齐、左边距 20**，和 `DgutLargeHeader` 缩到 17px 后的位置完全重合，
///    大标题落位后交棒看不出跳变。
/// 3. 出现窗口挪到 62~88px：早先 34px 就冒出来，会和还很大的大标题同时存在。
class DgutTopBar extends StatelessWidget {
  const DgutTopBar({
    super.key,
    required this.title,
    required this.offset,
  });

  final String title;
  final double offset;

  /// 与大标题收缩同步：40 开始淡入，66 完全到位
  static const double _riseStart = 24;
  static const double _riseSpan = 26;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double p =
        ((offset - _riseStart) / _riseSpan).clamp(0.0, 1.0);

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
            offset: Offset(0, 4 * (1 - p)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  DgutSpace.pad, 0, DgutSpace.pad, 11),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  title,
                  style: DgutType.headline.copyWith(color: c.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
