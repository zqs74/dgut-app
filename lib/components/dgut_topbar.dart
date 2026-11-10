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
    this.leftInset = 0,
    this.topInset = 0,
    this.verticalCenter = false,
  });

  final String title;
  final double offset;

  /// 左侧让出的宽度（页面有返回按钮时传 56，标题才不会压在按钮上）
  final double leftInset;

  /// 状态栏高度：顶栏整体下移，标题仍贴在顶栏底部
  final double topInset;

  /// 有返回按钮时与按钮同一条中轴；没有按钮就照旧贴底
  final bool verticalCenter;

  /// 与大标题收缩同步：40 开始淡入，66 完全到位
  static const double _riseStart = 62;
  static const double _riseSpan = 28;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double p =
        ((offset - _riseStart) / _riseSpan).clamp(0.0, 1.0);

    if (title.isEmpty) return SizedBox(height: 96 + topInset);

    if (p <= 0.001) {
      return SizedBox(height: 96 + topInset, width: double.infinity);
    }

    return IgnorePointer(
      child: SizedBox(
        height: 96 + topInset,
        width: double.infinity,
        child: Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 4 * (1 - p)),
            child: Padding(
              // 垂直居中于 96 的顶栏带，跟返回按钮同一条中轴
              padding: EdgeInsets.fromLTRB(
                  DgutSpace.pad + leftInset,
                  topInset + (verticalCenter ? 37 : 63),
                  DgutSpace.pad,
                  0),
              child: Align(
                alignment: Alignment.topLeft,
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
