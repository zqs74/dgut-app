import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'dgut_basics.dart';
import '../theme/dgut_tokens.dart';

/// 底部玻璃状态胶囊：加载中、加载失败重试、临时提示共用一套。
///
/// 网页模板（[DgutWebScaffold]）的 `bottom` 槽位放的就是它。
class DgutStatusPill extends StatelessWidget {
  const DgutStatusPill({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;

  /// 右侧动作文案（如「重试」）；null 表示只显示文字
  final String? actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(DgutRadius.full),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: c.glassDock.withValues(alpha: dark ? 0.55 : 0.52),
            borderRadius: BorderRadius.circular(DgutRadius.full),
            border: Border.all(color: c.glassEdge, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DgutType.caption1.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(width: 10),
                DgutPressable(
                  onTap: onAction,
                  child: Text(
                    actionLabel!,
                    style: DgutType.caption1.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.blueInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
