import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

/// 外观选择：底部浮层三选一（跟随系统 / 浅色 / 深色）。
/// 代替原来"点一下循环切一档"的隐式交互 —— 隐式循环用户看不出当前是哪档。
Future<ThemeMode?> showDgutThemeSheet(
  BuildContext context,
  ThemeMode current,
) {
  return showModalBottomSheet<ThemeMode>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (ctx) {
      final DgutColors c = ctx.dg;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.s2, 0, DgutSpace.s2, DgutSpace.s2),
          child: Container(
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(DgutRadius.r4),
              boxShadow: DgutShadows.forBrightness(
                  Theme.of(ctx).brightness),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      DgutSpace.pad, DgutSpace.s3, DgutSpace.pad, DgutSpace.s1),
                  child: Row(
                    children: [
                      Text('外观',
                          style: DgutType.title3
                              .copyWith(color: c.ink)),
                      const Spacer(),
                      DgutSheetClose(onTap: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                ),
                _ThemeOption(
                  label: '跟随系统',
                  hint: '随系统深色模式自动切换',
                  selected: current == ThemeMode.system,
                  onTap: () => Navigator.of(ctx).pop(ThemeMode.system),
                ),
                _ThemeOption(
                  label: '浅色',
                  hint: '始终使用浅色',
                  selected: current == ThemeMode.light,
                  onTap: () => Navigator.of(ctx).pop(ThemeMode.light),
                ),
                _ThemeOption(
                  label: '深色',
                  hint: '始终使用深色',
                  selected: current == ThemeMode.dark,
                  last: true,
                  onTap: () => Navigator.of(ctx).pop(ThemeMode.dark),
                ),
                const SizedBox(height: DgutSpace.s1),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
    this.last = false,
  });

  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutSheetPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: DgutSpace.pad, vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: c.line, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: DgutType.body.copyWith(
                          color: c.ink,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400)),
                  const SizedBox(height: 2),
                  Text(hint,
                      style: DgutType.footnote.copyWith(color: c.ink3)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: c.blueInk)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

/// 浮层右上角关闭
class DgutSheetClose extends StatelessWidget {
  const DgutSheetClose({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutSheetPressable(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.fill,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.close_rounded, size: 18, color: c.ink3),
      ),
    );
  }
}

/// 浮层内的按压（只降不透明度）
class DgutSheetPressable extends StatefulWidget {
  const DgutSheetPressable({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<DgutSheetPressable> createState() => _DgutSheetPressableState();
}

class _DgutSheetPressableState extends State<DgutSheetPressable> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) => setState(() => _p = false),
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedOpacity(
        opacity: _p ? 0.55 : 1,
        duration: DgutMotion.contact,
        curve: Curves.linear,
        child: widget.child,
      ),
    );
  }
}
