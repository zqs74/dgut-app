import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 连续边缘模糊（.dg-edge）。
///
/// 这一版把三个历史问题一并收拾掉：
///
/// 1. **不能有两层**。顶栏（`DgutTopBar`）曾自己画过一次 BackdropFilter，高 96；
///    边缘高 118。两条边界对不齐，看上去就是两块玻璃叠着。现在模糊只由这里
///    提供，主层高度与顶栏同为 96，边界就落在顶栏的底边。
/// 2. **衰减不能靠底色**。早期拿 `bg` 60% 的渐变把模糊"冲淡"，浅色主题下那是
///    一块 62% 的白板，比模糊本身更刺眼。现在只留 8% 的压暗，用来稳文字。
/// 3. **BackdropFilter 不能堆**。`ShaderMask(dstIn)` 包 BackdropFilter 在
///    CanvasKit 下 dstIn 不生效，白色渐变被当成 srcOver 画出来（顶栏直接变白）；
///    三层叠加会让 CanvasKit 卡住输入 —— 实测 3 层时滚轮完全无响应。
///    所以只保留「主层 + 一条 44px 羽化带」两个，边界从硬切变成两级过渡。
class DgutEdgeBlur extends StatelessWidget {
  const DgutEdgeBlur({
    super.key,
    required this.atTop,
    required this.sigma,
    required this.strength,
  });

  final bool atTop;

  /// 9~20px（线性回落，永不为 0）
  final double sigma;

  /// 0~1，整组的不透明度
  final double strength;

  /// 主层高度：顶部与顶栏（.dg-topbar 96）同高，边界才落在同一条线上
  static const double topExtent = 96;
  static const double bottomExtent = 132;

  /// 主层外侧的羽化带
  static const double feather = 44;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    if (strength <= 0.001 || sigma < 0.05) {
      return const SizedBox.shrink();
    }

    final double main = atTop ? topExtent : bottomExtent;
    final double total = main + feather;

    return IgnorePointer(
      child: Opacity(
        opacity: strength.clamp(0.0, 1.0),
        child: SizedBox(
          height: total,
          width: double.infinity,
          child: Stack(
            children: [
              // 主层：满强度
              Positioned(
                left: 0,
                right: 0,
                top: atTop ? 0 : null,
                bottom: atTop ? null : 0,
                height: main,
                child: _blur(sigma, 1.0),
              ),
              // 羽化带：贴着主层外侧，半径更大、强度一半，把硬切化成两级
              Positioned(
                left: 0,
                right: 0,
                top: atTop ? main : null,
                bottom: atTop ? null : main,
                height: feather,
                child: _blur(sigma * 1.15, 0.66),
              ),
              _shade(c, total),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blur(double sigma, double alpha) => Opacity(
        opacity: alpha,
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: const SizedBox.expand(),
          ),
        ),
      );

  /// 稳定文字对比度的极淡压暗（CSS .dg-edge::after 的收敛版）：只压不画边
  Widget _shade(DgutColors c, double height) {
    final bool dark = c.ink.computeLuminance() > 0.5;
    final Color tint = dark ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B0F);
    final double top = dark ? 0.05 : 0.08;
    return Positioned(
      left: 0,
      right: 0,
      top: atTop ? 0 : null,
      bottom: atTop ? null : 0,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: atTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              tint.withValues(alpha: top),
              tint.withValues(alpha: top * .45),
              tint.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.62, 1.0],
          ),
        ),
      ),
    );
  }
}
