import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

/// 滚动浮现的顶栏（.dg-topbar）：高 96，模糊 σ 随滚动从 0 涨到 30（平方曲线）。
///
/// 只有模糊、不叠底色：叠了一层 rgba 白之后，顶栏会变成一块"磨砂白板"，
/// 把下面内容的颜色一起冲淡。纯模糊则保留内容自身的颜色层次，
/// 文字靠本身对比度（ink 压模糊底）读，边界只用一条 1px 发丝线交代。
class DgutTopBar extends StatelessWidget {
  const DgutTopBar({
    super.key,
    required this.title,
    required this.offset,
  });

  final String title;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double p = DgutMotion.barProgress(offset);
    final double sigma = DgutMotion.barSigma(offset);

    if (p <= 0.001) {
      return const SizedBox(height: 96, width: double.infinity);
    }

    Widget bar = Container(
      height: 96,
      padding: const EdgeInsets.only(bottom: 11),
      alignment: Alignment.bottomCenter,
      // 不加底边框、不叠底色：顶栏与内容的边界交给模糊本身去交代，
      // 拉一条线反而像"分割条"，把玻璃的连续感切断
      color: Colors.transparent,
      child: Text(
        title,
        style: DgutType.headline.copyWith(color: c.ink),
      ),
    );

    if (sigma > 0.01) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: bar,
        ),
      );
    }

    return IgnorePointer(
      child: SizedBox(
        height: 96,
        width: double.infinity,
        child: Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, -6 * (1 - p)),
            child: bar,
          ),
        ),
      ),
    );
  }
}
