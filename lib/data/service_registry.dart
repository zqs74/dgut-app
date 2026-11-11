/// 服务注册表：服务页的全部内容都来自这一张表。
///
/// 为什么要有这张表：v0.14.0 之前，服务页 17 行 `DgutRow` 全硬编码在
/// `pages/services_page.dart` 的 build 里，17 个 `onTap` 是空函数，眉标手写
/// 「22 项」而实际只画了 17 项，副标题（空教室 78/86 座、一网通办 36 个流程）
/// 没有任何来源。这一屏是**画出来的**，不是**读出来的**。
///
/// 有了这张表之后：
/// - 页面只负责渲染，加一项服务只动这个文件；
/// - 眉标的项数由表长算，不会再和内容对不上；
/// - 搜索能按 `aliases` 用大白话找到项（搜「热水」要出「开热水」）。
///
/// 出处：`大三上/莞工统一App方案/修改-文档-F4服务注册表与跳转方案-2026-11-11-v1.md` §三。
library;

import 'package:flutter/material.dart';

/// 接入方式：决定点击之后发生什么。
///
/// 和方案 §2.1 的 D0–D4 对应：`native` = D0，`web` = D2，`browser` / `wechat` = D3。
enum ServiceAccess {
  /// App 内自己的页面，不涉及网络跳转。
  native,

  /// 进 WebView 容器。登录过统一身份认证之后，接入同一 CAS 的系统会自动放行。
  web,

  /// 外跳系统浏览器。仅用于 WebView 打不开的站点（如教务部现网对非浏览器 UA 返 403）。
  browser,

  /// 微信小程序或公众号。没有网页版，只能引导用户去微信搜。
  wechat,

  /// 还没有真去处。点下去要给一句说明，不能静默无反应。
  coming,
}

/// 服务分组。顺序即服务页的展示顺序。
enum ServiceGroup {
  study('教务学习'),
  life('生活后勤'),
  affairs('事务办理'),
  network('网络与资源'),
  other('其他');

  const ServiceGroup(this.label);

  /// 分组标题，直接显示在服务页上。
  final String label;
}

/// 一条服务。
@immutable
class ServiceEntry {
  const ServiceEntry({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.group,
    required this.access,
    required this.icon,
    this.target = '',
    this.aliases = const <String>[],
    this.comingNote,
  }) : assert(
         access != ServiceAccess.coming || comingNote != null,
         '还没有真去处的服务必须写 comingNote —— 点下去什么都不发生，比告诉用户"还没做"更糟',
       ),
       assert(
         access == ServiceAccess.native ||
             access == ServiceAccess.coming ||
             target != '',
         '要跳转的服务必须给 target',
       );

  /// 稳定标识：搜索、最近使用持久化、测试都按它找项。
  ///
  /// 一旦发布就不能改，改了用户的「最近使用」会丢。
  final String id;

  /// 服务名，显示在行首。
  final String name;

  /// 一句「什么时候会用到它」。**不能编数据**：
  /// 旧版写的「空教室 78 / 86 座」「一网通办 36 个流程」没有来源，属虚构。
  final String subtitle;

  final ServiceGroup group;

  final ServiceAccess access;

  final IconData icon;

  /// 去处：`web` / `browser` 是 URL，`wechat` 是小程序或公众号名称。
  final String target;

  /// 搜索别名。用大白话能搜到就行，不必与名称同义。
  final List<String> aliases;

  /// `access == coming` 时点下去显示的那句话。
  final String? comingNote;

  /// 是否需要先登录才能用。
  ///
  /// `web` 项都靠 CAS cookie 放行，没登录进去会被弹回认证页；
  /// 容器层据此决定要不要先提示登录。`browser` / `wechat` 由外部应用承接，不需要。
  bool get needsLogin => access == ServiceAccess.web;

  /// 是否点了有反应（`coming` 之外都有）。
  bool get isActionable => access != ServiceAccess.coming;
}

/// 22 项服务，5 组。
///
/// 目标地址全部来自方案 §三 的「目标」列，以及你后来在原文件上补的备注
/// （教务部改名 jwb、空教室 classroom、桶装水 ds、晚归 sa、图书馆 lib 等）。
/// **没有可信地址的一律标 `coming`**，不编去处。
const List<ServiceEntry> kServiceRegistry = <ServiceEntry>[
  // ── 第 1 组 · 教务学习（6 项）────────────────────────────────────────
  ServiceEntry(
    id: 'timetable',
    name: '课表',
    subtitle: '上课、查周次与教室',
    group: ServiceGroup.study,
    access: ServiceAccess.native,
    icon: Icons.calendar_month_outlined,
    aliases: <String>['课表', '课程', '上课', '时间表', '周课表'],
  ),
  ServiceEntry(
    id: 'score',
    name: '成绩查询',
    subtitle: '上学期成绩与绩点',
    group: ServiceGroup.study,
    access: ServiceAccess.web,
    icon: Icons.bar_chart_outlined,
    target: 'https://jwx.dgut.edu.cn',
    aliases: <String>['成绩', '分数', '绩点', '分'],
  ),
  ServiceEntry(
    id: 'exam',
    name: '考试安排',
    subtitle: '考试时间、地点与座位',
    group: ServiceGroup.study,
    access: ServiceAccess.web,
    icon: Icons.event_note_outlined,
    // 考试安排不在教务系统里，是教务部（原教务处）发在通知公告里的
    target: 'https://jwb.dgut.edu.cn/tzgg/jwtz.htm',
    aliases: <String>['考试', '考场', '座位', '考务', '补考'],
  ),
  ServiceEntry(
    id: 'classroom',
    name: '空教室',
    subtitle: '按时段找能自习的教室',
    group: ServiceGroup.study,
    access: ServiceAccess.web,
    icon: Icons.meeting_room_outlined,
    target: 'https://classroom.dgut.edu.cn/#/emptyClassRoom/emptyClassRoom',
    aliases: <String>['空教室', '自习', '教室', '空闲'],
  ),
  ServiceEntry(
    id: 'calendar',
    name: '校历',
    subtitle: '学期起止、假期与调课',
    group: ServiceGroup.study,
    access: ServiceAccess.coming,
    icon: Icons.date_range_outlined,
    aliases: <String>['校历', '学期', '假期', '放假', '开学'],
    comingNote: '校历还没有可信数据源，要手动录入一次才能用',
  ),
  ServiceEntry(
    id: 'notice',
    name: '教务公告',
    subtitle: '教务部通知与下载专区',
    group: ServiceGroup.study,
    access: ServiceAccess.web,
    icon: Icons.campaign_outlined,
    // 原教务处 jwc 已改名教务部 jwb
    target: 'https://jwb.dgut.edu.cn/',
    aliases: <String>['公告', '通知', '教务', '教务部'],
  ),

  // ── 第 2 组 · 生活后勤（5 项）────────────────────────────────────────
  ServiceEntry(
    id: 'hotwater',
    name: '开热水',
    subtitle: '宿舍热水',
    group: ServiceGroup.life,
    access: ServiceAccess.wechat,
    icon: Icons.water_drop_outlined,
    target: '莞工水电',
    aliases: <String>['热水', '洗澡', '水卡', '开水'],
  ),
  ServiceEntry(
    id: 'utility',
    name: '水电缴费',
    subtitle: '电费水费充值与余额',
    group: ServiceGroup.life,
    access: ServiceAccess.wechat,
    icon: Icons.receipt_long_outlined,
    target: '莞工水电',
    aliases: <String>['电费', '水费', '缴费', '充值', '余额', '充电'],
  ),
  ServiceEntry(
    id: 'water',
    name: '桶装水预定',
    subtitle: '订水与送水进度',
    group: ServiceGroup.life,
    access: ServiceAccess.web,
    icon: Icons.local_drink_outlined,
    target: 'https://ds.dgut.edu.cn/h5/',
    aliases: <String>['桶装水', '饮用水', '送水', '订水'],
  ),
  ServiceEntry(
    id: 'venue',
    name: '场所预约',
    subtitle: '学生活动中心场地',
    group: ServiceGroup.life,
    access: ServiceAccess.wechat,
    icon: Icons.event_seat_outlined,
    target: '莞工场所预约',
    aliases: <String>['场地', '预约', '活动中心', '教室借用'],
  ),
  ServiceEntry(
    id: 'repair',
    name: '报修',
    subtitle: '宿舍教室设施报修',
    group: ServiceGroup.life,
    access: ServiceAccess.wechat,
    icon: Icons.build_outlined,
    target: '莞工快修',
    aliases: <String>['报修', '维修', '坏了', '修理'],
  ),

  // ── 第 3 组 · 事务办理（5 项）────────────────────────────────────────
  ServiceEntry(
    id: 'credit',
    name: '学分中心',
    subtitle: '通识、课外与知行学分',
    group: ServiceGroup.affairs,
    access: ServiceAccess.web,
    icon: Icons.school_outlined,
    target: 'https://kwxf.dgut.edu.cn/pc/credits/creditList',
    aliases: <String>['学分', '通识', '课外', '知行', '第二课堂'],
  ),
  ServiceEntry(
    id: 'latereturn',
    name: '晚归申请',
    subtitle: '晚归报备与记录',
    group: ServiceGroup.affairs,
    access: ServiceAccess.web,
    icon: Icons.night_shelter_outlined,
    target: 'https://sa.dgut.edu.cn/#!/main/lateReturnIntro',
    aliases: <String>['晚归', '报备', '宿舍', '门禁'],
  ),
  ServiceEntry(
    id: 'aid',
    name: '资助与勤工助学',
    subtitle: '助学金状态、岗位与工时',
    group: ServiceGroup.affairs,
    access: ServiceAccess.web,
    icon: Icons.volunteer_activism_outlined,
    target: 'https://stu.dgut.edu.cn',
    aliases: <String>['助学金', '勤工', '助学', '贷款', '奖助', '困难'],
  ),
  ServiceEntry(
    id: 'ywtb',
    name: '一网通办',
    subtitle: '各类办事流程',
    group: ServiceGroup.affairs,
    access: ServiceAccess.web,
    icon: Icons.fact_check_outlined,
    target: 'https://ywtb.dgut.edu.cn',
    aliases: <String>['办事', '流程', '审批', '一网', '申请'],
  ),
  ServiceEntry(
    id: 'zhixing',
    name: '知行活动',
    subtitle: '选课、报名与学分',
    group: ServiceGroup.affairs,
    access: ServiceAccess.web,
    icon: Icons.groups_outlined,
    target: 'https://zxs.dgut.edu.cn/pc/activity',
    aliases: <String>['知行', '活动', '报名', '志愿'],
  ),

  // ── 第 4 组 · 网络与资源（3 项）──────────────────────────────────────
  ServiceEntry(
    id: 'library',
    name: '图书馆',
    subtitle: '检索、借阅与座位',
    group: ServiceGroup.network,
    access: ServiceAccess.web,
    icon: Icons.local_library_outlined,
    target: 'https://lib.dgut.edu.cn/',
    aliases: <String>['图书馆', '借书', '座位', '检索', '知网'],
  ),
  ServiceEntry(
    id: 'webvpn',
    name: 'WebVPN',
    subtitle: '校外查知网与校内资源',
    group: ServiceGroup.network,
    access: ServiceAccess.web,
    icon: Icons.vpn_key_outlined,
    target: 'https://webvpn.dgut.edu.cn',
    aliases: <String>['vpn', '校外', '知网', '内网', '翻墙'],
  ),
  ServiceEntry(
    id: 'official',
    name: '官网与新闻',
    subtitle: '学校新闻与机构导航',
    group: ServiceGroup.network,
    access: ServiceAccess.browser,
    icon: Icons.public_outlined,
    target: 'https://www.dgut.edu.cn',
    aliases: <String>['官网', '新闻', '学校', '首页'],
  ),

  // ── 第 5 组 · 其他（3 项）────────────────────────────────────────────
  ServiceEntry(
    id: 'pay',
    name: '莞工支付',
    subtitle: '校园消费',
    group: ServiceGroup.other,
    access: ServiceAccess.wechat,
    icon: Icons.account_balance_wallet_outlined,
    target: '智慧莞工',
    aliases: <String>['支付', '校园卡', '消费', '饭卡', '钱'],
  ),
  ServiceEntry(
    id: 'photo',
    name: '照片采集',
    subtitle: '证件照与采集',
    group: ServiceGroup.other,
    access: ServiceAccess.wechat,
    icon: Icons.photo_camera_outlined,
    target: '智慧莞工',
    aliases: <String>['照片', '证件照', '采集', '头像'],
  ),
  ServiceEntry(
    id: 'about',
    name: '关于与反馈',
    subtitle: '版本与数据来源声明',
    group: ServiceGroup.other,
    access: ServiceAccess.native,
    icon: Icons.info_outline,
    aliases: <String>['关于', '版本', '反馈', '更新'],
  ),
];

/// 该分组下的服务，保持注册表里的顺序。
List<ServiceEntry> servicesIn(ServiceGroup group) =>
    kServiceRegistry.where((ServiceEntry e) => e.group == group).toList();

/// 按 id 找一条服务；找不到返回 null（最近使用存的是 id，可能指向已删的项）。
ServiceEntry? serviceById(String id) {
  for (final ServiceEntry e in kServiceRegistry) {
    if (e.id == id) return e;
  }
  return null;
}

/// 按名称、别名、副标题做关键词搜索。
///
/// 空关键词返回全部；大小写不敏感。搜「热水」能出「开热水」，
/// 搜「分数」能出「成绩查询」—— 这是 `aliases` 存在的唯一理由。
List<ServiceEntry> searchServices(String keyword) {
  final String k = keyword.trim().toLowerCase();
  if (k.isEmpty) return kServiceRegistry;
  return kServiceRegistry.where((ServiceEntry e) {
    if (e.name.toLowerCase().contains(k)) return true;
    if (e.subtitle.toLowerCase().contains(k)) return true;
    for (final String a in e.aliases) {
      if (a.toLowerCase().contains(k)) return true;
    }
    return false;
  }).toList();
}
