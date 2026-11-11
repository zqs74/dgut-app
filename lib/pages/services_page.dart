import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../components/dgut_wip.dart';
import '../data/service_registry.dart';
import '../services/service_launcher.dart';
import '../theme/dgut_tokens.dart';
import 'about_page.dart';

/// 服务页：22 项全部来自 [kServiceRegistry]，这一页只负责画。
///
/// v0.14.0 之前这里是 108 行硬编码：17 个 `DgutRow` 写在 build 里，17 个 `onTap`
/// 全是空函数，眉标手写「22 项」而实际只画了 17 行，副标题（78 / 86 座、36 个流程）
/// 没有任何来源。现在是表的投影 —— 加一项服务只动 `data/service_registry.dart`。
///
/// 「搜索」与「最近使用」不在这里：它们要真数据（最近使用要持久化、搜索要按
/// aliases 匹配），归 S5。先把这一段留空，好过留两个假的。
class ServicesPage extends StatelessWidget {
  const ServicesPage({
    super.key,
    required this.offset,
    required this.onOpenTab,
  });

  final ValueNotifier<DgutScrollInfo> offset;

  /// 切到别的 tab：0 首页 / 1 课表 / 2 服务 / 3 消息 / 4 我的
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return DgutPageScaffold(
      // 眉标由表长算，不再手写 —— 这一行以前会和下面实际画出来的行数对不上
      eyebrow: '${kServiceRegistry.length} 项',
      title: '服务',
      offset: offset,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DgutSpace.pad,
            DgutSpace.s1,
            DgutSpace.pad,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final ServiceGroup group in ServiceGroup.values)
                _ServiceGroupBlock(
                  group: group,
                  onOpen: (ServiceEntry e) => _open(context, e),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 点一项会发生什么。
  ///
  /// App 内自己的页（课表、关于）在这里分发；其余交给 `service_launcher.dart`
  /// —— 进 WebView 容器、外跳浏览器、或者如实告诉用户"只有小程序"。
  void _open(BuildContext context, ServiceEntry entry) {
    if (entry.access == ServiceAccess.native) {
      switch (entry.id) {
        case 'timetable':
          onOpenTab(1);
          return;
        case 'about':
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
          return;
        default:
          showDgutWip(context, entry.name);
          return;
      }
    }
    openService(context, entry);
  }
}

/// 一组：折叠头 + 组内各行。组副标题不写（方案 §二 第 2 条）。
class _ServiceGroupBlock extends StatelessWidget {
  const _ServiceGroupBlock({required this.group, required this.onOpen});

  final ServiceGroup group;
  final ValueChanged<ServiceEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final List<ServiceEntry> items = servicesIn(group);
    if (items.isEmpty) return const SizedBox.shrink();
    final DgutColors c = context.dg;

    return DgutDisclosure(
      title: group.label,
      count: '${items.length} 项',
      // 只有第一组默认展开：22 项一次铺开会让人找不到东西
      initiallyOpen: group == ServiceGroup.study,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            DgutRow(
              leading: Icon(items[i].icon, size: 18, color: c.ink2),
              title: items[i].name,
              subtitle: items[i].subtitle,
              showDivider: i != items.length - 1,
              onTap: () => onOpen(items[i]),
            ),
        ],
      ),
    );
  }
}
