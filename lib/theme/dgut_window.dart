import 'package:flutter/widgets.dart';

/// Material Design 3 的 window size class，按宽度分三档。
///
/// | 档位 | 宽度 | 布局 |
/// |---|---|---|
/// | compact | < 600 | 底部胶囊 Dock，内容铺满 |
/// | medium | 600 ~ 839 | 底部胶囊 Dock，内容最大 720 居中 |
/// | expanded | ≥ 840 | 左侧 NavigationRail（96），内容最大 840 居中，Dock 收起 |
///
/// 阈值和两侧边距都用 M3 的默认值，不自造一套。
enum DgutWindowClass { compact, medium, expanded }

abstract final class DgutWindow {
  static const double mediumMin = 600;
  static const double expandedMin = 840;

  /// 左侧导航栏宽度（M3 NavigationRail 的推荐宽度区间是 80~96）
  static const double railWidth = 96;

  /// 单栏内容的最大宽度
  static const double compactContentMax = double.infinity;
  static const double mediumContentMax = 720;
  static const double expandedContentMax = 840;

  /// Dock 与内容区之间的横向呼吸（compact/medium 用）
  static const double dockInset = 16;

  static DgutWindowClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static DgutWindowClass fromWidth(double width) {
    if (width >= expandedMin) return DgutWindowClass.expanded;
    if (width >= mediumMin) return DgutWindowClass.medium;
    return DgutWindowClass.compact;
  }

  static bool usesRail(DgutWindowClass c) => c == DgutWindowClass.expanded;

  static double contentMaxOf(DgutWindowClass c) {
    switch (c) {
      case DgutWindowClass.compact:
        return compactContentMax;
      case DgutWindowClass.medium:
        return mediumContentMax;
      case DgutWindowClass.expanded:
        return expandedContentMax;
    }
  }

  /// 底部安全区：平板/折叠屏的手势条会占掉一截，Dock 要抬起来
  static double bottomSafe(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom;

  static double topSafe(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).top;
}
