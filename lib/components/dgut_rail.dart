import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';
import '../theme/dgut_window.dart';
import 'dgut_dock.dart' show DgutDockItem;

/// 宽屏（≥840）时替换底部 Dock 的左侧导航栏（M3 NavigationRail）。
///
/// 与 Dock 共用同一套"连续位置"语义：`page` 是 0…n-1 的浮点数，
/// 指示胶囊按它纵向滑动，图标与文字的颜色按 proximity 在灰与墨之间插值 ——
/// 手指滑内容时，rail 上的高亮也是滑过去的，不是跳的。
class DgutRail extends StatelessWidget {
  const DgutRail({
    super.key,
    required this.items,
    required this.page,
    required this.onSelect,
    this.onReselect,
  });

  final List<DgutDockItem> items;
  final ValueListenable<double> page;
  final ValueChanged<int> onSelect;
  final ValueChanged<int>? onReselect;

  static const double _laneHeight = 60;
  static const double _pillWidth = 60;
  static const double _pillHeight = 48;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double topPad = DgutWindow.topSafe(context) + 16;

    return Container(
      width: DgutWindow.railWidth,
      decoration: BoxDecoration(
        color: c.glassDock.withValues(alpha: context.isDark ? 0.32 : 0.28),
        border: Border(right: BorderSide(color: c.line, width: 1)),
      ),
      child: AnimatedBuilder(
        animation: page,
        builder: (context, _) {
          final double pos = page.value.isFinite ? page.value : 0;
          return SizedBox.expand(
            child: Stack(
              children: [
                // 指示胶囊：跟着 page 纵向滑
                Positioned(
                  left: (DgutWindow.railWidth - _pillWidth) / 2,
                  top: topPad + (pos + .5) * _laneHeight - _pillHeight / 2,
                  width: _pillWidth,
                  height: _pillHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.fillStrong,
                      borderRadius: BorderRadius.circular(DgutRadius.full),
                    ),
                  ),
                ),
                Positioned(
                  top: topPad,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _entry(context, c, i, pos),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _entry(BuildContext context, DgutColors c, int i, double pos) {
    final double proximity = (1 - (pos - i).abs()).clamp(0.0, 1.0);
    final Color color = Color.lerp(c.ink3, c.ink, proximity)!;
    final bool current = pos.round() == i;

    return SizedBox(
      height: _laneHeight,
      width: DgutWindow.railWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (current && onReselect != null) {
            onReselect!(i);
          } else {
            onSelect(i);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(items[i].icon, size: 23, color: color),
            const SizedBox(height: 5),
            Text(
              items[i].label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: proximity > .5 ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
