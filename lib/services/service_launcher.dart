import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/dgut_wip.dart';
import '../data/service_registry.dart';
import '../pages/web_container_page.dart';

/// 服务分发器：按 [ServiceAccess] 决定点下去发生什么。
///
/// 这一层存在的意义是把「跳转策略」从页面里拿出来 —— 服务页只管画和收点击，
/// 什么时候进容器、什么时候交给系统浏览器、什么时候只能说"还没做"，
/// 全部集中在这里。以后加一项服务不需要动页面。
///
/// `native` 不在这里处理：它们要动 App 内部状态（切 tab、开页面），
/// 由调用方自己分发。
Future<void> openService(BuildContext context, ServiceEntry entry) async {
  switch (entry.access) {
    case ServiceAccess.web:
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              WebContainerPage(title: entry.name, url: entry.target),
        ),
      );

    case ServiceAccess.browser:
      // 只在两种情况下用：官网首页、以及 WebView 里注定白屏的站点
      final bool ok = await _launchExternal(entry.target);
      if (!ok && context.mounted) {
        showDgutWip(context, entry.name, note: '打不开浏览器');
      }

    case ServiceAccess.wechat:
      // S4 的微信引导页还没做。这里如实说"只有小程序"，不假装能唤起
      if (context.mounted) {
        showDgutWip(
          context,
          entry.name,
          note: '「${entry.name}」只有微信「${entry.target}」，引导页还没做',
        );
      }

    case ServiceAccess.coming:
      if (context.mounted) {
        showDgutWip(context, entry.name, note: entry.comingNote);
      }

    case ServiceAccess.native:
      // 交给调用方（服务页自己处理切 tab / 开关于页）
      break;
  }
}

Future<bool> _launchExternal(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
