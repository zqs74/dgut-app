import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 玻璃圆按钮：压在网页或内容之上的圆形操作按钮。
///
/// **全项目统一用这一个**。之前每个页面各写一份私有类：登录页是玻璃，
/// 网页容器和教务导入是实色底板 —— 后者压在白色教务页上就是一块黑饼，
/// 看起来像两套东西。
///
/// 几何与材质沿用登录页那版：44×44 圆、`blur(20)`、`glassDock` 半透明底、
/// `glassEdge` 描边、阴影按明暗取 [DgutShadows.forBrightness]。
class DgutGlassButton extends StatelessWidget {
  const DgutGlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 21,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// 直径。网页容器顶栏两个按钮用默认 44，别处可放大
  final double size;

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: DgutShadows.forBrightness(Theme.of(context).brightness),
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: c.glassDock.withValues(alpha: dark ? 0.46 : 0.42),
              shape: BoxShape.circle,
              border: Border.all(color: c.glassEdge, width: 1),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Center(
                child: Icon(icon, size: iconSize, color: c.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
