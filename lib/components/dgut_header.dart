import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 大标题（.dg-ht）：顶部 66px，随滚动收缩。
///
/// `morph` 是"收成小标题"的进度：0 = 34px 大标题，1 = 17px 小标题。
/// 缩放锚在左下角、只作用于文字本身，左边距不跟着缩 —— 早先整块 scale 会把
/// 20px 的边距也缩成 10px，标题就偏了。
///
/// 缩小之后**直接淡到 0**，不再留 8% 的残影：残影会一直挂在原地，
/// 等内容滚上来把它压住，看上去就是"标题沉到底层"。
class DgutLargeHeader extends StatelessWidget {
  const DgutLargeHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.progress = 0.0,
    this.morph = 0.0,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  /// 旧版收缩进度（0~1），保留给外部需要直接控制的场合
  final double progress;

  /// 0 = 大标题；1 = 顶栏小标题（34 → 17px，左边缘不动，尾部淡出）
  final double morph;

  /// 顶部内边距 + 一行眉标 + 标题（大标题行高 38）
  static const double height = 66 + 14 + 10 + 38;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double t = progress.clamp(0.0, 1.0);
    final double m = morph.clamp(0.0, 1.0);
    final double s = (1 - 0.5 * m) * (1 - 0.26 * t);

    // 眉标先走，正文在后半程淡出：滚到 88px 时已完全让位给顶栏标题
    final double fade = ((m - .30) / .60).clamp(0.0, 1.0);
    final double eyebrowFade = ((m - .10) / .35).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(DgutSpace.pad, 66, DgutSpace.pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow.isNotEmpty) ...[
            Opacity(
              opacity: (1 - eyebrowFade).clamp(0.0, 1.0),
              child: Text(
                eyebrow,
                style: DgutType.eyebrow.copyWith(color: c.ink3),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Transform(
            alignment: Alignment.bottomLeft,
            transform: Matrix4.identity()
              ..translateByDouble(0, -5 * t, 0, 1)
              ..scaleByDouble(s, s, 1, 1),
            child: Opacity(
              opacity: (1 - fade).clamp(0.0, 1.0) * (1 - 0.92 * t).clamp(0.0, 1.0),
              child: Text(
                title,
                style: DgutType.largeTitle.copyWith(color: c.ink),
              ),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: DgutSpace.s1),
              child: Text(subtitle!,
                  style: DgutType.footnote.copyWith(color: c.ink2)),
            ),
        ],
      ),
    );
  }
}
