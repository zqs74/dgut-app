import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';
import 'dgut_glass_button.dart';

/// 网页模板：所有用 WebView 打开的页面都走这一套。
///
/// 结构固定三层，**没有顶栏** —— 网页是全屏的，任何一条实色横条都会白白
/// 吃掉一段可视区：
/// 1. 网页铺满整屏，不加内外边距；
/// 2. 左上返回、右上操作按钮，都是悬浮的玻璃圆钮，压在网页上但面积很小；
/// 3. 底部可选玻璃状态胶囊（加载中 / 失败重试 / 临时提示）。
///
/// 为什么不用 [DgutPageScaffold]：那是给可滚动内容用的，内容得塞进
/// `SingleChildScrollView`；WebView 放进去会和外层滚动抢手势、高度也定不下来。
///
/// 用它的地方：网页容器（服务页 D2 档）、教务导入、统一身份认证登录。
class DgutWebScaffold extends StatelessWidget {
  const DgutWebScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.actions = const <Widget>[],
    this.bottom,
  });

  /// 网页本体
  final Widget child;

  /// 左上返回；null 表示不显示
  final VoidCallback? onBack;

  /// 右上操作按钮，按顺序排，间距由模板补
  final List<Widget> actions;

  /// 底部状态胶囊；null 表示不显示
  final Widget? bottom;

  /// 圆钮距屏幕边缘的距离
  static const double _edge = 8;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double topInset = MediaQuery.viewPaddingOf(context).top;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: child),
          if (onBack != null)
            Positioned(
              left: DgutSpace.pad,
              top: topInset + _edge,
              child: DgutGlassButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack!,
              ),
            ),
          if (actions.isNotEmpty)
            Positioned(
              right: DgutSpace.pad,
              top: topInset + _edge,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < actions.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: DgutSpace.s1),
                    actions[i],
                  ],
                ],
              ),
            ),
          if (bottom != null)
            Positioned(
              left: DgutSpace.pad,
              right: DgutSpace.pad,
              bottom: bottomInset + 24,
              child: Center(child: bottom),
            ),
        ],
      ),
    );
  }
}
