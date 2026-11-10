import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';
import 'dgut_edge_blur.dart';
import 'dgut_header.dart';
import 'dgut_reselect.dart';
import 'dgut_topbar.dart';

/// 页面骨架：可滚动内容 + 随滚动收成小标题的大标题。
///
/// 传 `onBack` 就是「二级页面模板」：返回按钮、顶栏模糊、小标题的摆位全由这里
/// 统一负责，页面自己不要再摆一个按钮 —— 自己摆的按钮和顶栏标题用的是两套坐标，
/// 必然会撞。左侧让位（56）同时作用在大标题、顶栏标题上，所以缩小时也是对齐的。
class DgutPageScaffold extends StatefulWidget {
  const DgutPageScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.offset,
    required this.children,
    this.footerHeight = 180,
    this.showHeader = true,
    this.contentBuilder,
    this.topInset = 0,
    this.onBack,
  });

  final String eyebrow;
  final String title;
  final ValueNotifier<DgutScrollInfo> offset;
  final List<Widget> children;
  final double footerHeight;
  final bool showHeader;

  /// 渐进式运动：外部可注入一个 Wrap，把内容按页面滑动进度做分层位移
  final Widget Function(Widget child)? contentBuilder;

  /// 页面自绘导航（如返回按钮）时，把标题整体下移，避免与按钮重叠
  final double topInset;

  /// 传了就按二级页面处理：自带返回按钮 + 顶栏模糊 + 小标题
  final VoidCallback? onBack;

  /// 收成小标题的滚动距离
  static const double _morphSpan = 70;

  /// 返回按钮占的横向宽度（44 按钮 + 12 间距）
  static const double _backLane = 56;

  @override
  State<DgutPageScaffold> createState() => _DgutPageScaffoldState();
}

class _DgutPageScaffoldState extends State<DgutPageScaffold>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();
  DgutReselect? _reselect;

  // PageView 会把离屏页从树上摘掉，保持存活 = 保住各自的滚动位置
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_report);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DgutReselect? next = DgutReselectScope.maybeOf(context);
    if (identical(next, _reselect)) return;
    _reselect?.removeListener(_onReselect);
    _reselect = next;
    _reselect?.addListener(_onReselect);
  }

  /// 再点一次当前 tab：信号带的是"哪一页"，用 offset 这个 notifier 实例认领
  void _onReselect() {
    if (!identical(_reselect?.target, widget.offset)) return;
    if (!_controller.hasClients) return;
    if (_controller.offset <= 0.5) return;
    _controller.animateTo(
      0,
      duration: DgutMotion.enter,
      curve: DgutMotion.easeOutCubic,
    );
  }

  void _report() {
    if (!_controller.hasClients) return;
    final double px = _controller.offset;
    final double max = _controller.position.maxScrollExtent;
    widget.offset.value = DgutScrollInfo(
      pixels: px,
      rest: (max - px).clamp(0.0, double.infinity),
      max: max,
    );
  }

  @override
  void dispose() {
    _reselect?.removeListener(_onReselect);
    _controller.removeListener(_report);
    _controller.dispose();
    super.dispose();
  }

  bool get _hasBack => widget.onBack != null;

  /// 有返回按钮时，状态栏那段也得算进顶栏高度
  double get _topInset {
    if (!_hasBack) return widget.topInset;
    final double safe = MediaQuery.viewPaddingOf(context).top;
    return widget.topInset > safe ? widget.topInset : safe;
  }

  double get _leading => _hasBack ? DgutPageScaffold._backLane : 0;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_topInset > 0) SizedBox(height: _topInset),
        if (widget.showHeader)
          AnimatedBuilder(
            animation: widget.offset,
            builder: (context, _) {
              final double px = widget.offset.value.pixels;
              final double t =
                  (px / DgutPageScaffold._morphSpan).clamp(0.0, 1.0);
              return Transform.translate(
                // 净上移 0.614·px：滚 70px 时走完 43px，标题底部正好落到顶栏标题的基线
                offset: Offset(0, px * 0.386),
                child: DgutLargeHeader(
                  eyebrow: widget.eyebrow,
                  title: widget.title,
                  morph: t,
                  leftInset: _leading,
                ),
              );
            },
          ),
        ...widget.children,
        SizedBox(height: widget.footerHeight),
      ],
    );

    if (widget.contentBuilder != null) {
      content = widget.contentBuilder!(content);
    }

    final Widget scroller = SingleChildScrollView(
      controller: _controller,
      physics: const ClampingScrollPhysics(),
      child: content,
    );

    if (!_hasBack) return scroller;

    return Stack(
      children: [
        Positioned.fill(child: scroller),
        // 顶栏：模糊 + 小标题。模糊从 0 起就跟着滚上来，字出现时已经在了
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: widget.offset,
              builder: (context, _) {
                final double px = widget.offset.value.pixels;
                // 与收缩同步上涨：标题还在缩的时候别急着糊满
                final double s = (px / 72).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    DgutEdgeBlur(
                      atTop: true,
                      sigma: DgutMotion.edgeSigmaMax,
                      strength: s,
                      extent: DgutEdgeBlur.topExtent + _topInset,
                    ),
                    DgutTopBar(
                      title: widget.title,
                      offset: px,
                      leftInset: _leading,
                      topInset: _topInset,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Positioned(
          left: DgutSpace.pad,
          top: _topInset + 8,
          child: _GlassBackButton(onTap: widget.onBack!),
        ),
      ],
    );
  }
}

/// 玻璃圆钮：与 Dock 同一套材质（半透明 + 模糊 + 发丝边 + 外阴影）
class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: DgutShadows.forBrightness(Theme.of(context).brightness),
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: c.glassDock.withValues(alpha: context.isDark ? 0.46 : 0.42),
              shape: BoxShape.circle,
              border: Border.all(color: c.glassEdge, width: 1),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Center(
                child: Icon(Icons.arrow_back_rounded, size: 21, color: c.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
