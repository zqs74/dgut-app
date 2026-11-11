import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_glass_button.dart';
import '../components/dgut_sheet.dart';
import '../components/dgut_status_pill.dart';
import '../components/dgut_web_scaffold.dart';
import '../model/identity.dart';
import '../services/identity_parser.dart';
import '../services/session.dart';
import '../theme/dgut_tokens.dart';

/// 登录莞工统一身份认证。
///
/// 做三件事：把学工系统的页面打开（没登录它会自己跳 CAS）、
/// 用户登录完之后从页面上把身份读出来、存进本机。
///
/// **不碰密码**：输入发生在校方自己的 CAS 页面上，App 拿不到也不需要。
/// **不需要"把登录态传给别的系统"**：Android WebView 的 cookie 是进程级共享的，
/// 这次登录种下的 CAS cookie，其余接入同一 CAS 的系统被打开时会自动带上。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// 学工系统首页。没登录时它会 302 到 `auth.dgut.edu.cn`，
  /// 登录完落回这里 —— 但**不一定**落在基本信息页：学工会记住上次访问的功能页
  /// （实测落到过「综合测评管理」），所以下面还要主动拉一次。
  static const String _entryUrl = 'https://stu.dgut.edu.cn/index.jsp';

  /// 基本信息页：七个字段都在这张表里。它是首页 iframe 的 src，
  /// 单独打开也是完整页面。
  static const String _infoUrl =
      'https://stu.dgut.edu.cn/student/basicinfo/basicInfo.jsp';

  /// 递归往下找 iframe，拿到第一个同时含「学号」「姓名」的正文。
  ///
  /// 学工的外壳页只有姓名（顶栏），学号/学院那些都在 iframe 的
  /// `basicInfo.jsp` 里；两者同域，`contentDocument` 能直接读。
  static const String _grabJs =
      "(function(){"
      "function txt(doc,depth){"
      "if(!doc||depth>4)return '';"
      "var t='';try{t=doc.body?doc.body.innerText:'';}catch(e){t='';}"
      "if(t&&t.indexOf('学号')>=0&&t.indexOf('姓名')>=0)return t;"
      "var fs=[];try{fs=doc.querySelectorAll('iframe,frame');}catch(e){}"
      "for(var i=0;i<fs.length;i++){"
      "var h='';try{h=txt(fs[i].contentDocument,depth+1);}catch(e){}"
      "if(h)return h;}"
      "return t;}"
      "return txt(document,0);})()";

  WebViewController? _web;
  Timer? _timeout;
  bool _busy = false;
  bool _failed = false;
  bool _pulledToInfo = false;
  String _status = '正在打开学工系统';

  /// 显示模式：默认按手机宽度重排；切到「电脑端」时按 1280 宽渲染，
  /// 看得到 PC 版的完整表格（缩小后可双指放大）。
  ///
  /// 学工是 PC 站，`basicInfo.jsp` 那张表在窄屏上会挤成一列一列的字；
  /// 但它的菜单和表单又是为宽屏排的 —— 两种都有用，所以给个开关。
  bool _mobileUi = true;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_android) _boot();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _set(String status, {bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _failed = failed;
    });
  }

  void _boot() {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (url.contains('authserver')) {
              _set('请在上方登录');
            } else if (url.contains('stu.dgut.edu.cn')) {
              _set('正在读取身份');
            }
          },
          onPageFinished: (String url) => _onLoaded(url),
          onWebResourceError: (WebResourceError e) {
            if (!_busy && _web != null) _set('打不开学工系统', failed: true);
          },
        ),
      )
      ..loadRequest(Uri.parse(_entryUrl));
    setState(() {
      _web = controller;
      _failed = false;
      _pulledToInfo = false;
      _status = '正在打开学工系统';
    });
  }

  Future<void> _onLoaded(String url) async {
    if (_busy) return;
    if (url.contains('authserver')) {
      _set('请在上方登录');
      return;
    }
    if (!url.contains('stu.dgut.edu.cn')) return;

    // 学工会记住上次打开的菜单，登录后常常落在某个功能页上（实测「综合测评管理」）。
    // 那里没有身份字段，所以自己拉一次基本信息页。
    if (!url.contains('basicInfo')) {
      if (_pulledToInfo) return;
      _pulledToInfo = true;
      _set('正在打开身份信息');
      await _web?.loadRequest(Uri.parse(_infoUrl));
      return;
    }
    await _scrape();
  }

  Future<void> _scrape() async {
    _busy = true;
    _set('正在读取身份');
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 25), () {
      if (_busy && mounted) {
        _busy = false;
        _set('读取超时', failed: true);
      }
    });

    String text = '';
    DgutIdentity? identity;
    // iframe 是异步加载的：一次读不到就等一会儿再读，最多 6 次
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final Object raw = await _web!.runJavaScriptReturningResult(_grabJs);
        text = raw is String ? raw : '$raw';
        // runJavaScriptReturningResult 会把字符串结果再包一层引号
        if (text.length > 1 && text.startsWith('"') && text.endsWith('"')) {
          try {
            text = jsonDecode(text) as String;
          } catch (_) {}
        }
      } catch (_) {
        text = '';
      }
      identity = parseIdentity(text);
      if (identity != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
    }

    _timeout?.cancel();
    _busy = false;

    if (identity == null) {
      _set('没读到身份信息', failed: true);
      return;
    }

    await Session.instance.setIdentity(identity);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// 手机 / 电脑端显示切换。
  ///
  /// 改的是页面自己的 `viewport` —— 递归给所有 iframe 一起改，
  /// 只改外层的话内层那张表还是按原来的宽度排。
  Future<void> _toggleUi() async {
    final WebViewController? web = _web;
    if (web == null) return;
    setState(() => _mobileUi = !_mobileUi);
    final String content = _mobileUi
        ? 'width=device-width,initial-scale=1,maximum-scale=3,user-scalable=yes'
        : 'width=1280';
    final String js =
        "(function(){"
        "var c='$content';"
        "function apply(doc,depth){"
        "if(!doc||depth>4)return;"
        "try{var m=doc.querySelector('meta[name=viewport]');"
        "if(!m){m=doc.createElement('meta');m.setAttribute('name','viewport');"
        "doc.head.appendChild(m);}"
        "m.setAttribute('content',c);}catch(e){}"
        "try{var fs=doc.querySelectorAll('iframe,frame');"
        "for(var i=0;i<fs.length;i++){"
        "try{apply(fs[i].contentDocument,depth+1);}catch(e){}}}catch(e){}"
        "}"
        "apply(document,0);return 1;})()";
    try {
      await web.runJavaScript(js);
      await web.reload();
    } catch (_) {}
  }

  Future<void> _openInBrowser() async {
    try {
      await launchUrl(
        Uri.parse(_entryUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // 没有浏览器可用时不打断登录流程
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(const ClipboardData(text: _entryUrl));
  }

  void _openMenu() {
    showDgutSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DgutGroupHead(title: '统一身份认证'),
          DgutRow(
            title: '刷新',
            onTap: () {
              Navigator.of(context).pop();
              _boot();
            },
          ),
          DgutRow(
            title: '在浏览器打开',
            onTap: () {
              Navigator.of(context).pop();
              _openInBrowser();
            },
          ),
          DgutRow(
            title: '复制链接',
            showDivider: false,
            onTap: () {
              Navigator.of(context).pop();
              _copyLink();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return DgutWebScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      actions: <Widget>[
        DgutGlassButton(
          icon: _mobileUi
              ? Icons.desktop_windows_outlined
              : Icons.smartphone_rounded,
          onTap: _toggleUi,
        ),
        DgutGlassButton(icon: Icons.more_horiz_rounded, onTap: _openMenu),
      ],
      bottom: DgutStatusPill(
        text: _status,
        // 登录中不给「重试」：重试会把用户正在输的密码页刷掉
        actionLabel: _failed ? '重试' : null,
        onAction: _failed ? _boot : null,
      ),
      child: _web == null ? _unsupported(c) : WebViewWidget(controller: _web!),
    );
  }

  Widget _unsupported(DgutColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DgutSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('登录在安卓版可用', style: DgutType.body.copyWith(color: c.ink2)),
            const SizedBox(height: DgutSpace.s3),
            Text(
              '网页预览里没有 WebView，登录与抓取都跑不起来',
              textAlign: TextAlign.center,
              style: DgutType.footnote.copyWith(color: c.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玻璃圆钮：与二级页的返回按钮、Dock 同一套材质
/// （半透明 + 模糊 + 发丝边 + 外阴影）。
