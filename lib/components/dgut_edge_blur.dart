import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 连续边缘模糊（.dg-edge）。
/// 三层不同半径 + 不同高度叠加，每层用同底色渐变把模糊"冲淡"到透明，
/// 最内侧再压一条 30px 的同底色渐变（.dg-edge::after）消掉硬边。
///
/// 与 CSS 的已知差异：CSS 每层还有 saturate(185%)。Flutter 的 BackdropFilter
/// 只能做纯模糊，饱和度增强需要 shader，这里省略（观感差异肉眼难辨）。
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

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    if (strength <= 0.001) {
      return const SizedBox.shrink();
    }

    final double outerH = atTop ? 118 : 132;
    final double h1 = atTop ? 118 : 132;
    final double h2 = atTop ? 74 : 78;
    final double h3 = atTop ? 38 : 38;

    return IgnorePointer(
      child: Opacity(
        opacity: strength.clamp(0.0, 1.0),
        child: SizedBox(
          height: outerH,
          width: double.infinity,
          child: Stack(
            children: [
              _layer(c, sigma * 1.00, h1, 0.62),
              _layer(c, sigma * 0.48, h2, 0.44),
              _layer(c, sigma * 0.19, h3, 0.22),
              // 接缝层
              Positioned(
                left: 0,
                right: 0,
                top: atTop ? 0 : null,
                bottom: atTop ? null : 0,
                height: 30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: atTop
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,
                      end: atTop
                          ? Alignment.bottomCenter
                          : Alignment.topCenter,
                      colors: [
                        c.bg.withValues(alpha: 0.60),
                        c.bg.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layer(DgutColors c, double sigma, double height, double coverAlpha) {
    if (sigma < 0.05) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      top: atTop ? 0 : null,
      bottom: atTop ? null : 0,
      height: height,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:
                    atTop ? Alignment.topCenter : Alignment.bottomCenter,
                end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  c.bg.withValues(alpha: coverAlpha),
                  c.bg.withValues(alpha: coverAlpha * 0.55),
                  c.bg.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
