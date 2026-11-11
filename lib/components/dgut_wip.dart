import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

/// 顶部下滑提示：还没接通的功能点下去给一句说明。
///
/// 为什么不用 `SnackBar`：它固定贴底，会被底部 Dock 压住（Dock 悬浮在
/// `bottom: 20 + 安全区`），而且自带 Material 默认配色，明暗两套主题下
/// 都跟 DGUT 色板打架。这里自己做一层 Overlay：
///
/// * 位置在**顶部**、状态栏之下留 [DgutSpace.s3]，左右各留 [DgutSpace.pad]，
///   不和 Dock 抢地方；
/// * 材质沿用 Dock 那套玻璃配方（`blur(26)` + `glassDock` + `glassEdge` 描边），
///   半透明能看到下面的内容，才不会像一块板子硬盖在标题上；
/// * 动效用 `DgutMotion.enter / exit`，从上方 36px 内滑入。
///
/// 同一时刻只留一条：新提示进来先把旧的摘掉。
void showDgutWip(BuildContext context, String name, {String? note}) {
  try {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _active?.remove();
    _active = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) => _WipToast(
        text: note ?? '「$name」还没有接上',
        onFinished: () {
          if (entry.mounted) entry.remove();
          if (identical(_active, entry)) _active = null;
        },
      ),
    );
    _active = entry;
    overlay.insert(entry);
  } catch (_) {
    // 提示只是提示：没有 Overlay（极端情况下刚销毁）也不能把点击流程搞崩
  }
}

OverlayEntry? _active;

class _WipToast extends StatefulWidget {
  const _WipToast({required this.text, required this.onFinished});

  final String text;
  final VoidCallback onFinished;

  @override
  State<_WipToast> createState() => _WipToastState();
}

class _WipToastState extends State<_WipToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: DgutMotion.enter,
    reverseDuration: DgutMotion.exit,
  );

  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _hold = Timer(const Duration(milliseconds: 2000), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _c.reverse();
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double topSafe = MediaQuery.viewPaddingOf(context).top;
    final BorderRadius radius = BorderRadius.circular(DgutRadius.r3);

    return Positioned(
      top: topSafe + DgutSpace.s3,
      left: DgutSpace.pad,
      right: DgutSpace.pad,
      child: IgnorePointer(
        // 必须有 Material 祖先：Overlay 挂在 Navigator 之下、不在 Scaffold 里，
        // 少了它 Text 会继承 Flutter 的 debug 错误样式（黄色双下划线 + 等宽字体）
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? child) {
              final double t = DgutMotion.easeOutCubic.transform(
                _c.value.clamp(0.0, 1.0),
              );
              // 这里**不加 Opacity**：它会把整棵子树（含 BackdropFilter）包进
              // 合成层，动画期间模糊采样不跟随位移，表现就是"滑下来时还是实色
              // 背景，滑完才变成玻璃"。只用位移，模糊才会实时跟手。
              return Transform.translate(
                offset: Offset(0, -56 * (1 - t)),
                child: child,
              );
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: dark ? DgutShadows.pane : DgutShadows.float,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: Container(
                    decoration: BoxDecoration(
                      // 和底部 Dock 同一套玻璃配方，否则会变成"一块实心板"
                      color: c.glassDock.withValues(alpha: dark ? 0.56 : 0.48),
                      borderRadius: radius,
                      border: Border.all(color: c.glassEdge, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DgutSpace.s2,
                        13,
                        DgutSpace.s2,
                        13,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.info_outline, size: 17, color: c.ink3),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.text,
                              style: DgutType.callout.copyWith(color: c.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
