import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 全项目统一的浮层底板：顶部圆角、上下留白、顶部一条抓手。
///
/// 之前直接用 `showModalBottomSheet` 会贴到底边、内容顶到左右边，看着像没收尾。
/// 这里统一处理三件事：圆角、内边距、底部安全区。
Future<T?> showDgutSheet<T>(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    isScrollControlled: true,
    builder: (BuildContext ctx) => DgutSheetShell(child: child),
  );
}

class DgutSheetShell extends StatelessWidget {
  const DgutSheetShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(DgutRadius.r4),
      ),
      child: ColoredBox(
        color: c.bg,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(DgutRadius.full),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
                child: child,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
