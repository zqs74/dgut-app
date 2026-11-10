import 'package:flutter/material.dart';

/// 动效词表。数值全部来自 motion/dgut.css 与 motion/dgut.js 的实现。
class DgutMotion {
  static const Duration contact = Duration(milliseconds: 120);
  static const Duration enter = Duration(milliseconds: 420);
  static const Duration exit = Duration(milliseconds: 320);
  static const Duration flight = Duration(milliseconds: 1000);
  static const Duration themeFade = Duration(milliseconds: 240);

  static const Cubic easeOutCubic = Cubic(0.215, 0.610, 0.355, 1.000);
  static const Cubic easeInCubic = Cubic(0.550, 0.055, 0.675, 0.190);
  static const Cubic settle = Cubic(0.200, 1.080, 0.340, 1.000);
  static const Cubic easeInOutCubic = Cubic(0.645, 0.045, 0.355, 1.000);

  /// 接触态曲线复用 settle（--dg-d-contact 只给时长）
  static const Curve contactCurve = settle;

  /// 真弹簧（Wenku8 NovelMotion 同参）；CSS 里 cubic-bezier(.34,1.24,.42,1) 只是近似
  static const SpringDescription spring =
      SpringDescription(mass: 0.64, stiffness: 270, damping: 19);

  // ---- 顶栏：σ = 30 · t²，滚过 34 后 60px 内涨到满 ----
  static const double barRiseStart = 34;
  static const double barRiseSpan = 60;
  static const double barSigmaMax = 30;

  static double barProgress(double offset) =>
      ((offset - barRiseStart) / barRiseSpan).clamp(0.0, 1.0);

  static double barSigma(double offset) {
    final t = barProgress(offset);
    return barSigmaMax * t * t;
  }

  // ---- 边缘：线性 9~20px，不归零；strength 独立 ----
  static const double edgeSpan = 120;
  static const double edgeSigmaMax = 20;

  /// depth = 剩余可滚距离 / 120，截断 0~1
  static double edgeDepth(double rest) => (rest / edgeSpan).clamp(0.0, 1.0);

  static double edgeSigma(double depth) => edgeSigmaMax * (1 - 0.55 * (1 - depth));

  static double edgeStrength(double depth) => 1 - depth;

  // ---- 大标题：t = offset / 68 ----
  static const double titleSpan = 68;
  static double titleProgress(double offset) => (offset / titleSpan).clamp(0.0, 1.0);

  // ---- 果冻：四段关键帧双轴挤压（.dg-dock__item.is-jelly）----
  static const List<double> _jellyT = [0.0, 0.28, 0.54, 0.78, 1.0];
  static const List<double> _jellyX = [1.0, 1.20, 0.93, 1.04, 1.0];
  static const List<double> _jellyY = [1.0, 0.84, 1.07, 0.97, 1.0];

  static double jellyX(double t) => _sample(t, _jellyT, _jellyX);
  static double jellyY(double t) => _sample(t, _jellyT, _jellyY);

  static double _sample(double t, List<double> kt, List<double> v) {
    if (t <= kt.first) return v.first;
    if (t >= kt.last) return v.last;
    for (var i = 0; i < kt.length - 1; i++) {
      if (t >= kt[i] && t <= kt[i + 1]) {
        final span = kt[i + 1] - kt[i];
        final f = span == 0 ? 0.0 : (t - kt[i]) / span;
        return v[i] + (v[i + 1] - v[i]) * f;
      }
    }
    return v.last;
  }

  /// 共享元素飞行收尾的淡出（dgut.js: opacity = 1 - max(0,(e-.74)/.26)）
  static double flightOpacity(double e) =>
      (1 - ((e - 0.74) / 0.26).clamp(0.0, 1.0)).clamp(0.0, 1.0);
}

/// 页面进入 / 退出过渡：translateY(10px) + scale(.988) + opacity。
/// CSS: 进入 420ms easeOutCubic；退出 320ms easeInCubic。
class DgutPageTransition extends StatefulWidget {
  const DgutPageTransition({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<DgutPageTransition> createState() => _DgutPageTransitionState();
}

class _DgutPageTransitionState extends State<DgutPageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.active ? DgutMotion.enter : DgutMotion.exit,
    value: widget.active ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(covariant DgutPageTransition old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    _c.duration = widget.active ? DgutMotion.enter : DgutMotion.exit;
    if (widget.active) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final Curve curve =
            widget.active ? DgutMotion.easeOutCubic : DgutMotion.easeInCubic;
        final double t = curve.transform(_c.value.clamp(0.0, 1.0));
        return IgnorePointer(
          ignoring: !widget.active,
          child: Opacity(
            opacity: t,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..translateByDouble(0, 10 * (1 - t), 0, 1)
                ..scaleByDouble(0.988 + 0.012 * t, 0.988 + 0.012 * t, 1, 1),
              child: t <= 0.001 ? const SizedBox.shrink() : child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
