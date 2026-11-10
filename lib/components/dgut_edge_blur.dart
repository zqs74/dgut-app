import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 边缘模糊（.dg-edge）。
///
/// 只有一层，没有羽化带。曾经试过两种"让边界更软"的写法，都不留：
///
/// * 主层 + 44px 羽化带：屏幕上确实还是一条分层线（上密下疏），看上去仍是两层。
/// * `ShaderMask(dstIn)` 做遮罩：CanvasKit 下 dstIn 不生效，白色渐变被当 srcOver
///   画出来，整块变白。
/// * 三层叠加：CanvasKit 直接卡住输入，滚轮完全无响应。
///
/// 现在就一条 96px（顶部，与顶栏同高）/ 132px（底部）的模糊，加 6~8% 的压暗。
/// 边界就是模糊的边界，一眼只有一层。
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

  /// 顶部与顶栏（.dg-topbar 96）同高，边界才落在同一条线上
  static const double topExtent = 96;
  static const double bottomExtent = 132;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    if (strength <= 0.001 || sigma < 0.05) {
      return const SizedBox.shrink();
    }

    final double extent = atTop ? topExtent : bottomExtent;

    return IgnorePointer(
      child: Opacity(
        opacity: strength.clamp(0.0, 1.0),
        child: SizedBox(
          height: extent,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              _shade(c, extent),
            ],
          ),
        ),
      ),
    );
  }

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
