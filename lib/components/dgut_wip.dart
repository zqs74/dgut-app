import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';

/// 未接通功能的统一占位反馈。
///
/// 服务页里总会有些项还没有真去处：校历缺数据源、微信小程序项还没有引导页、
/// 容器页还没做出来。**点下去什么都不发生，比告诉用户"还没做"更糟** ——
/// 用户会以为 App 卡了，然后反复点。
///
/// 这个名字借自 NUIST++ 的 `core/wip.dart`（它只有 10 行，作用一样）。
void showDgutWip(BuildContext context, String name, {String? note}) {
  final DgutColors c = context.dg;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          note ?? '「$name」还没有接上',
          style: DgutType.callout.copyWith(color: c.bgDeep),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        elevation: 0,
        duration: const Duration(milliseconds: 2200),
        margin: const EdgeInsets.fromLTRB(
          DgutSpace.pad,
          0,
          DgutSpace.pad,
          DgutSpace.s2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DgutRadius.r2),
        ),
      ),
    );
}
