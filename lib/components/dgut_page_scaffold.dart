import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';
import 'dgut_header.dart';
import 'dgut_reselect.dart';

/// 页面骨架：可滚动内容 + 随滚动收缩的大标题 + 顶部 66px 留白。
///
/// 大标题的收缩要"看得见"，关键是**速度差**：标题比内容慢 55% 地滚出去
/// （translateY 反向补偿），同时缩到 0.74、淡到 0.08。
/// 只做缩放不做补偿的话，缩放会被滚动位移吃掉，看起来就是"标题直接滚没了"。
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
  });

  final String eyebrow;
  final String title;
  final ValueNotifier<DgutScrollInfo> offset;
  final List<Widget> children;
  final double footerHeight;
  final bool showHeader;

  /// 渐进式运动：外部可注入一个 Wrap，把内容按页面滑动进度做分层位移
  final Widget Function(Widget child)? contentBuilder;

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

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          AnimatedBuilder(
            animation: widget.offset,
            builder: (context, _) {
              final double px = widget.offset.value.pixels;
              return Transform.translate(
                // 反向补偿 55%：标题比内容滚得慢，收缩才看得见
                offset: Offset(0, px * 0.55),
                child: DgutLargeHeader(
                  eyebrow: widget.eyebrow,
                  title: widget.title,
                  progress: (px / 88).clamp(0.0, 1.0),
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

    return SingleChildScrollView(
      controller: _controller,
      physics: const ClampingScrollPhysics(),
      child: content,
    );
  }
}
