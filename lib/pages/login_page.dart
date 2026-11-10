import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../components/dgut_basics.dart';
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
              _set('请在下方登录');
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
      _set('请在下方登录');
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

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: _web == null
                ? _unsupported(c)
                : WebViewWidget(controller: _web!),
          ),
          Positioned(
            left: DgutSpace.pad,
            top: topInset + 8,
            child: _GlassRoundButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          // 右下角：切手机 / 电脑端显示
          Positioned(
            right: DgutSpace.pad,
            bottom: 24,
            child: _GlassRoundButton(
              icon: _mobileUi
                  ? Icons.desktop_windows_outlined
                  : Icons.smartphone_rounded,
              onTap: _toggleUi,
            ),
          ),
          Positioned(
            left: DgutSpace.pad + 52,
            right: DgutSpace.pad + 52,
            bottom: 24,
            child: Center(
              child: _StatusBar(
                text: _status,
                // 登录中不给"重试"：重试会把用户正在输的密码页刷掉
                onRetry: _failed ? _boot : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unsupported(DgutColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DgutSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '登录在安卓版可用',
              style: DgutType.body.copyWith(color: c.ink2),
            ),
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
class _GlassRoundButton extends StatelessWidget {
  const _GlassRoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: DgutShadows.forBrightness(Theme.of(context).brightness),
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: c.glassDock.withValues(
                alpha: context.isDark ? 0.46 : 0.42,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: c.glassEdge, width: 1),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Center(child: Icon(icon, size: 21, color: c.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DgutRadius.full),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: c.glassDock.withValues(alpha: dark ? 0.55 : 0.52),
            borderRadius: BorderRadius.circular(DgutRadius.full),
            border: Border.all(color: c.glassEdge, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DgutType.caption1.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 10),
                DgutPressable(
                  onTap: onRetry,
                  child: Text(
                    '重试',
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
