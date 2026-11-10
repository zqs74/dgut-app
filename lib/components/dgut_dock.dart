import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

class DgutDockItem {
  const DgutDockItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// 底部 Dock（.dg-dock）。
/// 结构刻意保持最小：外层 Container 负责玻璃与边框，里面一个 Stack
/// 放"指示胶囊 + 五个入口"，不加 LayoutBuilder、不用 Expanded，
/// 避免约束在嵌套里被吃掉。
class DgutDock extends StatefulWidget {
  const DgutDock({
    super.key,
    required this.items,
    required this.page,
    required this.onSelect,
  });

  final List<DgutDockItem> items;
  final ValueListenable<double> page;
  final ValueChanged<int> onSelect;

  @override
  State<DgutDock> createState() => _DgutDockState();
}

class _DgutDockState extends State<DgutDock> with SingleTickerProviderStateMixin {
  late final AnimationController _jelly = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));

  int? _jellyIndex;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.page.value.round();
    widget.page.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final int i = widget.page.value.round();
    if (i != _lastIndex) {
      _lastIndex = i;
      setState(() => _jellyIndex = i);
      _jelly
        ..reset()
        ..forward().whenComplete(() {
          if (mounted) setState(() => _jellyIndex = null);
        });
    }
  }

  @override
  void dispose() {
    widget.page.removeListener(_onPageChanged);
    _jelly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    // 材质：半透明底 + 顶部高光条 + 外阴影（不用 BackdropFilter，也不在
    // decoration 里用 gradient —— 这两条在本页的层级里都会让子件消失）
    return Container(
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.glassDock.withValues(alpha: context.isDark ? 0.46 : 0.38),
        borderRadius: BorderRadius.circular(DgutRadius.full),
        border: Border.all(color: c.glassEdge, width: 1),
        boxShadow: DgutShadows.forBrightness(Theme.of(context).brightness),
      ),
      child: Stack(
        children: [
          // 顶部高光：一条 1px 亮线，暗示玻璃厚度
          Positioned(
            top: 0,
            left: DgutRadius.full,
            right: DgutRadius.full,
            child: Container(
              height: 1,
              color: Colors.white
                  .withValues(alpha: context.isDark ? 0.22 : 0.98),
            ),
          ),
          AnimatedBuilder(
            animation: widget.page,
            builder: (context, _) {
              final double raw = widget.page.value;
              final int active = raw.isFinite
                  ? raw.round().clamp(0, widget.items.length - 1)
                  : 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    _DockEntry(
                      item: widget.items[i],
                      active: i == active,
                      jelly: _jellyIndex == i ? _jelly : null,
                      onTap: () => widget.onSelect(i),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DockEntry extends StatelessWidget {
  const _DockEntry({
    required this.item,
    required this.active,
    required this.jelly,
    required this.onTap,
  });

  final DgutDockItem item;
  final bool active;
  final Animation<double>? jelly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    Widget icon = Icon(item.icon, size: 22, color: active ? c.ink : c.ink3);

    if (jelly != null) {
      final double t = DgutMotion.easeOutCubic.transform(jelly!.value);
      icon = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          DgutMotion.jellyX(t),
          DgutMotion.jellyY(t),
          1,
        ),
        child: icon,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.fillStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(DgutRadius.full),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: active ? c.ink : c.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
