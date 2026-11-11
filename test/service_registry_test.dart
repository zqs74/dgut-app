import 'package:dgut_app/data/service_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// S1 验收：单测能数出 22 项 / 5 组 / 每组数量对；每项都有 subtitle 与 access。
///
/// 这些断言的作用不是"证明代码能跑"，而是**把方案钉死**：
/// 以后有人往服务页加项、删项、改分组，这里会先响，不会等到界面上
/// 眉标写「22 项」而实际只画了 17 项那种事再被用户发现。
void main() {
  group('注册表形状', () {
    test('一共 22 项', () {
      expect(kServiceRegistry.length, 22);
    });

    test('5 个分组，数量分别是 6 / 5 / 5 / 3 / 3', () {
      expect(ServiceGroup.values.length, 5);
      expect(servicesIn(ServiceGroup.study).length, 6);
      expect(servicesIn(ServiceGroup.life).length, 5);
      expect(servicesIn(ServiceGroup.affairs).length, 5);
      expect(servicesIn(ServiceGroup.network).length, 3);
      expect(servicesIn(ServiceGroup.other).length, 3);
    });

    test('分组标签与方案一致', () {
      expect(ServiceGroup.study.label, '教务学习');
      expect(ServiceGroup.life.label, '生活后勤');
      expect(ServiceGroup.affairs.label, '事务办理');
      expect(ServiceGroup.network.label, '网络与资源');
      expect(ServiceGroup.other.label, '其他');
    });

    test('id 全局唯一', () {
      final Set<String> ids = <String>{};
      for (final ServiceEntry e in kServiceRegistry) {
        expect(ids.add(e.id), isTrue, reason: 'id 重复：${e.id}');
      }
    });

    test('每项都有非空的 name 与 subtitle', () {
      for (final ServiceEntry e in kServiceRegistry) {
        expect(e.name.trim(), isNotEmpty, reason: '${e.id} 缺 name');
        expect(e.subtitle.trim(), isNotEmpty, reason: '${e.id} 缺 subtitle');
      }
    });

    test('subtitle 里不许出现「数字 / 数字」这类没有来源的统计', () {
      // 旧版写的「空教室 78 / 86 座」「一网通办 36 个流程」都是编的。
      // 这条断言把"编数据"挡在数据层，界面就不会再显示假数字。
      final RegExp madeUpStat = RegExp(r'\d+\s*[/／]\s*\d+\s*(座|个|项)');
      for (final ServiceEntry e in kServiceRegistry) {
        expect(
          madeUpStat.hasMatch(e.subtitle),
          isFalse,
          reason: '${e.id} 的 subtitle 含无来源统计：${e.subtitle}',
        );
      }
    });
  });

  group('接入方式', () {
    test('coming 的项必须写 comingNote，且不可点', () {
      final List<ServiceEntry> coming = kServiceRegistry
          .where((ServiceEntry e) => e.access == ServiceAccess.coming)
          .toList();
      for (final ServiceEntry e in coming) {
        expect(e.comingNote, isNotNull, reason: '${e.id} 标了 coming 却没写说明');
        expect(e.comingNote!.trim(), isNotEmpty);
        expect(e.isActionable, isFalse);
      }
    });

    test('web / browser 的项必须有 target', () {
      for (final ServiceEntry e in kServiceRegistry) {
        if (e.access == ServiceAccess.web ||
            e.access == ServiceAccess.browser) {
          expect(e.target, isNotEmpty, reason: '${e.id} 要跳转却没给地址');
          expect(
            e.target.startsWith('http'),
            isTrue,
            reason: '${e.id} 的 target 不是 URL：${e.target}',
          );
        }
      }
    });

    test('wechat 的项 target 是小程序或公众号名，不是 URL', () {
      for (final ServiceEntry e in kServiceRegistry) {
        if (e.access == ServiceAccess.wechat) {
          expect(e.target.trim(), isNotEmpty, reason: '${e.id} 缺小程序名');
          expect(
            e.target.startsWith('http'),
            isFalse,
            reason: '${e.id} 是微信项，target 不该是 URL',
          );
        }
      }
    });

    test('只有校历一项还没真去处', () {
      // 方案里标 ⚠️ 的六项，补上真实地址后只剩校历没数据源。
      final List<String> comingIds = kServiceRegistry
          .where((ServiceEntry e) => e.access == ServiceAccess.coming)
          .map((ServiceEntry e) => e.id)
          .toList();
      expect(comingIds, <String>['calendar']);
    });

    test('needsLogin 只对 web 项为真', () {
      for (final ServiceEntry e in kServiceRegistry) {
        expect(e.needsLogin, e.access == ServiceAccess.web, reason: e.id);
      }
    });
  });

  group('查找', () {
    test('按 id 能找到', () {
      expect(serviceById('timetable')?.name, '课表');
      expect(serviceById('score')?.name, '成绩查询');
    });

    test('按 id 找不到时返回 null，不抛异常', () {
      expect(serviceById('not-a-real-id'), isNull);
    });

    test('搜「热水」出「开热水」', () {
      final List<ServiceEntry> hits = searchServices('热水');
      expect(hits.map((ServiceEntry e) => e.id), contains('hotwater'));
    });

    test('搜「分数」出「成绩查询」', () {
      final List<ServiceEntry> hits = searchServices('分数');
      expect(hits.map((ServiceEntry e) => e.id), contains('score'));
    });

    test('搜「电费」出「水电缴费」', () {
      final List<ServiceEntry> hits = searchServices('电费');
      expect(hits.map((ServiceEntry e) => e.id), contains('utility'));
    });

    test('空关键词返回全部', () {
      expect(searchServices('').length, 22);
      expect(searchServices('   ').length, 22);
    });

    test('搜不到时返回空列表', () {
      expect(searchServices('量子计算机'), isEmpty);
    });

    test('大小写不敏感', () {
      expect(
        searchServices('VPN').map((ServiceEntry e) => e.id),
        contains('webvpn'),
      );
      expect(
        searchServices('vpn').map((ServiceEntry e) => e.id),
        contains('webvpn'),
      );
    });
  });
}
