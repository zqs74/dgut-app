import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';
import 'dgut_glass_button.dart';

/// 网页模板：所有用 WebView 打开的页面都走这一套。
///
/// 结构固定三层：
/// 1. **网页铺满整屏** —— 不加内外边距，网页自己决定怎么排；
/// 2. **顶部玻璃导航栏** —— 返回 + 标题 + 右侧操作，半透明加模糊，
///    网页往下滚时内容会从它下面透出来；
/// 3. **底部可选玻璃胶囊** —— 加载态、错误重试、临时提示都塞这里。
///
/// 为什么不用 [DgutPageScaffold]：那是给可滚动内容用的，内容得塞进
/// `SingleChildScrollView`；WebView 放进去会和外层滚动抢手势、高度也定不下来。
/// 但视觉刻意保持一致 —— 同样的 44 玻璃圆钮、同样的状态栏让位、
/// 同样的 `glassDock` + `glassEdge` 材质。
class DgutWebScaffold extends StatelessWidget {
  const DgutWebScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.actions = const <Widget>[],
    this.bottom,
  });

  /// 服务名。网页自己的 title 通常是系统名，更长，不用它
  final String title;

  /// 网页本体
  final Widget child;

  final VoidCallback? onBack;

  /// 导航栏右侧的操作按钮，按顺序排，间距由模板补
  final List<Widget> actions;

  /// 底部状态胶囊；null 表示不显示
  final Widget? bottom;

  /// 导航栏内容区高度（不含状态栏）
  static const double barHeight = 56;

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
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _NavBar(
              title: title,
              onBack: onBack,
              actions: actions,
              topInset: topInset,
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

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.title,
    required this.onBack,
    required this.actions,
    required this.topInset,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          height: topInset + DgutWebScaffold.barHeight,
          padding: EdgeInsets.only(
            top: topInset,
            left: DgutSpace.pad,
            right: DgutSpace.pad,
          ),
          decoration: BoxDecoration(
            // 和 Dock 同一套玻璃配方
            color: c.glassDock.withValues(alpha: dark ? 0.55 : 0.5),
            border: Border(bottom: BorderSide(color: c.glassEdge, width: 1)),
          ),
          child: Row(
            children: <Widget>[
              if (onBack != null) ...<Widget>[
                DgutGlassButton(icon: Icons.arrow_back_rounded, onTap: onBack!),
                const SizedBox(width: DgutSpace.s2),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DgutType.title3.copyWith(color: c.ink),
                ),
              ),
              for (int i = 0; i < actions.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: DgutSpace.s1),
                actions[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
