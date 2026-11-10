import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';
import 'dgut_basics.dart';
import 'dgut_theme_sheet.dart';

/// 二次确认浮层，与外观浮层同一套材质。
///
/// 返回 true 表示用户点了确认按钮。
Future<bool> showDgutConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
}) async {
  final bool? ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (BuildContext ctx) {
      final DgutColors c = ctx.dg;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DgutSpace.s2,
            0,
            DgutSpace.s2,
            DgutSpace.s2,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(DgutRadius.r4),
              boxShadow: DgutShadows.forBrightness(Theme.of(ctx).brightness),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad,
                    DgutSpace.s3,
                    DgutSpace.pad,
                    DgutSpace.s1,
                  ),
                  child: Row(
                    children: [
                      Text(title, style: DgutType.title3.copyWith(color: c.ink)),
                      const Spacer(),
                      DgutSheetClose(onTap: () => Navigator.of(ctx).pop(false)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad,
                    0,
                    DgutSpace.pad,
                    DgutSpace.s3,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message,
                      style: DgutType.footnote.copyWith(
                        color: c.ink3,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad,
                    0,
                    DgutSpace.pad,
                    DgutSpace.s3,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DgutButton(
                          label: cancelLabel,
                          variant: DgutButtonVariant.gray,
                          block: true,
                          onTap: () => Navigator.of(ctx).pop(false),
                        ),
                      ),
                      const SizedBox(width: DgutSpace.s2),
                      Expanded(
                        child: DgutButton(
                          label: confirmLabel,
                          variant: danger
                              ? DgutButtonVariant.danger
                              : DgutButtonVariant.filled,
                          block: true,
                          onTap: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DgutSpace.s1),
              ],
            ),
          ),
        ),
      );
    },
  );
  return ok ?? false;
}
