import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/session.dart';
import '../theme/dgut_tokens.dart';

/// 退出登录。
///
/// 顺序不能反：
/// 1. **先**带着现有 cookie 去访问 CAS 的注销地址 —— 服务端收到之后才会销毁
///    TGC。如果只清本地 cookie，服务端那边还记着"这个人已认证"，
///    下次进第一个系统时会**自动重新登进去**，用户会以为退出没生效。
/// 2. **再**清 WebView 的 cookie（顺带清掉各系统自己的会话）。
/// 3. 最后清本机的身份记录。
class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key});

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  static const String _logoutUrl = 'https://auth.dgut.edu.cn/authserver/logout';

  WebViewController? _web;
  Timer? _fallback;
  bool _done = false;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_android) {
      _boot();
    } else {
      // 网页预览没有 WebView：直接清本机那一份
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  void _boot() {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) => _finish(),
        ),
      )
      ..loadRequest(Uri.parse(_logoutUrl));
    // 兜底：CAS 有时会停在中转页不再触发 onPageFinished，
    // 但本地该清的照清，不能让用户卡在"正在退出"
    _fallback = Timer(const Duration(seconds: 6), _finish);
    setState(() => _web = controller);
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    _fallback?.cancel();
    try {
      await WebViewCookieManager().clearCookies();
    } catch (_) {
      // 清 cookie 失败也要继续清本机记录，否则界面会显示"还登录着"
    }
    await Session.instance.clear();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: _web == null
                ? const SizedBox.shrink()
                : WebViewWidget(controller: _web!),
          ),
          // 盖住 WebView：用户不需要看 CAS 的注销中转页
          Positioned.fill(child: ColoredBox(color: c.bg)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(c.ink3),
                  ),
                ),
                const SizedBox(height: DgutSpace.s3),
                Text(
                  '正在退出登录',
                  style: DgutType.body.copyWith(color: c.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
