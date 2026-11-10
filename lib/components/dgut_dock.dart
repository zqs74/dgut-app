import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

class DgutDockItem {
  const DgutDockItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// 底部 Dock（.dg-dock）。
///
/// 交互移植自 Wenku8_Flutter 的 `GlassDock`（mikufoxxx/Wenku8_Flutter，
/// lib/glass_dock.dart），几何按本项目 token 重新给：
///
/// * 指示胶囊的位置是一个**连续量**（`_position`，0…n-1），不是选中的整数。
///   按下瞬间弹簧跟到手指，拖动时带着 0.8 的阻尼跟随，松手用速度预测落点，
///   再由弹簧收进格子 —— 胶囊是"滑"过去的，不是跳过去的。
/// * 图标与文字的颜色按 `proximity = 1 - |pos - i|` 在灰与墨之间插值，
///   手指经过时颜色是流过去的。
/// * 整条胶囊在按压时轻微上浮并纵向拉伸（scaleY 1.065 / scaleX 1.022），
///   在 dock 上左右拖动时被拉出一点形变，像有弹性的实体。
/// * 在 dock 上左右拖动可以切页，松手才提交，页面 1:1 跟手的仍是 PageView。
/// * 尊重系统"减少动态效果"：动画关闭时直接落位。
class DgutDock extends StatefulWidget {
  const DgutDock({
    super.key,
    required this.items,
    required this.page,
    required this.onSelect,
    this.onReselect,
    this.itemWidth = 68,
  });

  final List<DgutDockItem> items;
  final ValueListenable<double> page;
  final ValueChanged<int> onSelect;

  /// 点中的就是当前页：交回给外壳做「回到顶部」，不切页
  final ValueChanged<int>? onReselect;
  final double itemWidth;

  @override
  State<DgutDock> createState() => _DgutDockState();
}

class _DgutDockState extends State<DgutDock> with TickerProviderStateMixin {
  static const double _inset = 8;
  static const double _height = 58;
  static const double _iconSize = 21;

  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.page.value,
  );
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _stretch = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _jelly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  int? _jellyIndex;
  int _lastSelected = 0;
  double _segmentWidth = 1;
  double _lastX = 0;
  Duration _lastTime = Duration.zero;
  int? _pointer;
  bool _dragging = false;
  bool _pointerCancelled = false;
  bool _reduceMotion = false;

  /// 用户刚操作过 dock：这段时间里不要被 PageView 的位置覆盖
  bool _hold = false;
  Timer? _holdTimer;
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
    _lastSelected = widget.page.value.round();
    widget.page.addListener(_onPage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _restTimer?.cancel();
    widget.page.removeListener(_onPage);
    _position.dispose();
    _press.dispose();
    _stretch.dispose();
    _jelly.dispose();
    super.dispose();
  }

  /// 手指不在 dock 上时，胶囊位置由 PageView 驱动：滑内容，胶囊跟着走
  void _onPage() {
    if (_pointer != null || _dragging || _hold) return;
    final double v = widget.page.value;
    if (!v.isFinite) return;
    if (_position.isAnimating) _position.stop();
    _position.value = v;
    final int i = v.round();
    if (i != _lastSelected) {
      _lastSelected = i;
      _runJelly(i);
    }
  }

  void _holdFor(int ms) {
    _hold = true;
    _holdTimer?.cancel();
    _holdTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _hold = false);
    });
  }

  double _fingerPosition(double x) => ((x - _inset) / _segmentWidth - .5).clamp(
    0.0,
    (widget.items.length - 1).toDouble(),
  );

  Future<void> _spring(
    AnimationController controller,
    double target, {
    double velocity = 0,
  }) async {
    if (_reduceMotion) {
      controller.value = target;
      return;
    }
    try {
      await controller
          .animateWith(
            SpringSimulation(
              DgutMotion.spring,
              controller.value,
              target,
              velocity.clamp(-5.0, 5.0),
            ),
          )
          .orCancel;
      if (mounted) controller.value = target;
    } on TickerCanceled {
      // 新的触摸接管了控制器
    }
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointerCancelled = false;
    _pointer = event.pointer;
    _lastX = event.localPosition.dx;
    _lastTime = event.timeStamp;
    _restTimer?.cancel();
    _position.stop();
    _press.stop();
    if (!_reduceMotion) {
      _press.animateTo(
        1,
        duration: DgutMotion.contact,
        curve: DgutMotion.easeOutCubic,
      );
    }
    _holdFor(420);
    _spring(_position, _fingerPosition(event.localPosition.dx));
  }

  void _release() {
    _pointer = null;
    _restTimer?.cancel();
    _spring(_press, 0);
    _spring(_stretch, 0);
  }

  void _dragStart(DragStartDetails d) {
    _dragging = true;
    _position.stop();
    _lastX = d.localPosition.dx;
    _lastTime = d.sourceTimeStamp ?? _lastTime;
    _position.value = _fingerPosition(_lastX);
  }

  void _dragUpdate(DragUpdateDetails d) {
    final Duration t = d.sourceTimeStamp ?? _lastTime;
    final int micros = (t - _lastTime).inMicroseconds;
    final double speed = micros > 0
        ? (d.localPosition.dx - _lastX) * 1e6 / micros
        : d.delta.dx * 60;
    _lastX = d.localPosition.dx;
    _lastTime = t;
    final double finger = _fingerPosition(d.localPosition.dx);
    // 不在每个 pointer 事件上重启动画，只做空间滞后跟随
    _position.value = _reduceMotion
        ? finger
        : _position.value + (finger - _position.value) * .8;
    if (!_reduceMotion) {
      _stretch.stop();
      final double target = (speed * .028).clamp(-24.0, 24.0);
      _stretch.value += (target - _stretch.value) * .55;
      _restTimer?.cancel();
      _restTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) _spring(_stretch, 0);
      });
    }
  }

  void _dragEnd(DragEndDetails d) {
    if (_pointerCancelled) {
      _cancel();
      return;
    }
    final double velocity = (d.primaryVelocity ?? 0) / _segmentWidth;
    final double projected =
        _fingerPosition(_lastX) + (velocity * .055).clamp(-.22, .22);
    _commit(
      projected.round().clamp(0, widget.items.length - 1),
      velocity: velocity,
      fromDrag: true,
    );
  }

  void _cancel() {
    if (!mounted) return;
    _dragging = false;
    _release();
    _spring(_position, widget.page.value);
  }

  void _commit(int index, {double velocity = 0, bool fromDrag = false}) {
    _dragging = false;
    _release();
    _spring(_position, index.toDouble(), velocity: velocity);
    _holdFor(600);
    final int current = widget.page.value.round();
    if (index != _lastSelected) {
      _lastSelected = index;
      _runJelly(index);
    }
    // 点中的就是当前页 → 交回外壳做「回到顶部」（拖动落到同一格不算）
    if (!fromDrag && index == current && widget.onReselect != null) {
      widget.onReselect!(index);
    } else {
      widget.onSelect(index);
    }
  }

  void _runJelly(int index) {
    if (_reduceMotion) return;
    setState(() => _jellyIndex = index);
    _jelly
      ..reset()
      ..forward().whenComplete(() {
        if (mounted) setState(() => _jellyIndex = null);
      });
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double totalWidth =
        widget.items.length * widget.itemWidth + _inset * 2;
    _segmentWidth = widget.itemWidth;

    return AnimatedBuilder(
      animation: Listenable.merge([_position, _press, _stretch]),
      builder: (context, _) {
        final double pressure = _reduceMotion
            ? 0
            : _press.value.clamp(0.0, 1.0);
        final double flow = _reduceMotion ? 0 : _stretch.value;

        return Transform.translate(
          offset: Offset(flow * .16, -pressure * .6),
          child: Transform.scale(
            scaleX: 1 + pressure * .022 + flow.abs() * .00125,
            scaleY: 1 + pressure * .065 - flow.abs() * .0006,
            child: SizedBox(
              width: totalWidth,
              height: _height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DgutRadius.full),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.glassDock.withValues(
                        alpha: context.isDark ? 0.46 : 0.38,
                      ),
                      borderRadius: BorderRadius.circular(DgutRadius.full),
                      border: Border.all(color: c.glassEdge, width: 1),
                    ),
                    child: Stack(
                      children: [
                        // 顶部高光：一条亮线 + 上缘 52% 高的柔光，暗示玻璃厚度
                        Positioned(
                          top: 0,
                          left: DgutRadius.full,
                          right: DgutRadius.full,
                          height: _height * .52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(DgutRadius.full),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: context.isDark ? .10 : .55,
                                  ),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 指示胶囊
                        _pill(c),
                        // 五个入口
                        Positioned.fill(
                          child: Listener(
                            onPointerDown: _down,
                            onPointerUp: (e) {
                              if (e.pointer == _pointer) _release();
                            },
                            onPointerCancel: (e) {
                              if (e.pointer == _pointer) {
                                _pointerCancelled = true;
                                _cancel();
                              }
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (d) {
                                if (!_dragging && !_pointerCancelled) {
                                  _commit(
                                    _fingerPosition(d.localPosition.dx)
                                        .round()
                                        .clamp(0, widget.items.length - 1),
                                  );
                                }
                              },
                              onHorizontalDragStart: _dragStart,
                              onHorizontalDragUpdate: _dragUpdate,
                              onHorizontalDragEnd: _dragEnd,
                              onHorizontalDragCancel: _cancel,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _inset,
                                ),
                                child: Row(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < widget.items.length;
                                      i++
                                    )
                                      _entry(i, c),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 指示胶囊：宽度固定，横坐标由连续位置算出 —— 所以它是滑过去的
  Widget _pill(DgutColors c) {
    final double w = (widget.itemWidth - 8).clamp(48.0, 84.0);
    final double pos = _position.value.isFinite ? _position.value : 0;
    final double x = _inset + (pos + .5) * _segmentWidth - w / 2;
    return Positioned(
      left: x,
      top: (_height - 48) / 2,
      width: w,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.fillStrong,
          borderRadius: BorderRadius.circular(DgutRadius.full),
        ),
      ),
    );
  }

  Widget _entry(int i, DgutColors c) {
    final double pos = _position.value.isFinite ? _position.value : 0;
    final double proximity = (1 - (pos - i).abs()).clamp(0.0, 1.0);
    final double fingerIdx = _pointer != null ? _fingerPosition(_lastX) : -9;
    final bool pressedHere = _pointer != null && fingerIdx.round() == i;

    Color color = Color.lerp(c.ink3, c.ink, proximity)!;
    double scale = 1 + .14 * proximity;
    if (pressedHere) scale = .88;

    Widget icon = Icon(widget.items[i].icon, size: _iconSize, color: color);

    if (_jellyIndex == i) {
      final double t = DgutMotion.easeOutCubic.transform(_jelly.value);
      icon = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          DgutMotion.jellyX(t),
          DgutMotion.jellyY(t),
          1,
        ),
        child: icon,
      );
    } else {
      icon = Transform.scale(scale: scale, child: icon);
    }

    return Expanded(
      child: SizedBox(
        height: _height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 4),
              Text(
                widget.items[i].label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: proximity > .5
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
