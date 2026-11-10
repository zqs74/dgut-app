import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../theme/dgut_tokens.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key, required this.offset});

  final ValueNotifier<DgutScrollInfo> offset;

  @override
  Widget build(BuildContext context) {
    return DgutPageScaffold(
      eyebrow: '22 项',
      title: '服务',
      offset: offset,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DgutSpace.pad, DgutSpace.s2, DgutSpace.pad, 0),
          child: const DgutSearchField(hint: '搜索服务、办事'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DgutGroupHead(title: '最近使用'),
              DgutRow(
                leading: Icon(Icons.water_drop_outlined,
                    size: 18, color: context.dg.ink2),
                title: '开热水',
                subtitle: '莞工水电',
                onTap: () {},
              ),
              DgutRow(
                leading: Icon(Icons.receipt_long_outlined,
                    size: 18, color: context.dg.ink2),
                title: '水电缴费',
                onTap: () {},
              ),
              DgutRow(
                leading: Icon(Icons.vpn_key_outlined,
                    size: 18, color: context.dg.ink2),
                title: 'WebVPN',
                onTap: () {},
              ),
              const SizedBox(height: DgutSpace.s1),
              // 22 项不能一次铺开：默认只展开第一组
              DgutDisclosure(
                title: '教务学习',
                count: '6 项',
                initiallyOpen: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DgutRow(title: '课表', subtitle: '上课、查周次与教室', onTap: () {}),
                    DgutRow(title: '成绩查询', onTap: () {}),
                    DgutRow(title: '空教室', subtitle: '78 / 86 座', onTap: () {}),
                    DgutRow(title: '校历', onTap: () {}),
                  ],
                ),
              ),
              DgutDisclosure(
                title: '生活后勤',
                count: '5 项',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DgutRow(title: '开热水', onTap: () {}),
                    DgutRow(title: '水电缴费', onTap: () {}),
                    DgutRow(title: '桶装水预定', onTap: () {}),
                    DgutRow(title: '场所预约', onTap: () {}),
                  ],
                ),
              ),
              DgutDisclosure(
                title: '事务办理',
                count: '5 项',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DgutRow(title: '学分中心', onTap: () {}),
                    DgutRow(title: '晚归申请', subtitle: '22:00 截止', onTap: () {}),
                    DgutRow(title: '一网通办', subtitle: '36 个流程', onTap: () {}),
                  ],
                ),
              ),
              DgutDisclosure(
                title: '网络与资源',
                count: '3 项',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DgutRow(title: 'WebVPN', subtitle: '校外查知网', onTap: () {}),
                    DgutRow(title: '图书馆', onTap: () {}),
                    DgutRow(title: '校园网', onTap: () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
