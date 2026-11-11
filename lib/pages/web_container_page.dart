import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_sheet.dart';
import '../theme/dgut_tokens.dart';

/// 通用 WebView 容器：服务页里 D2 档（进容器）的去处。
///
/// 管五件事：
/// 1. **加载 / 失败 / 重试三态** —— 不让用户对着白屏猜；
/// 2. **手机 / 电脑端切换** —— 改页面 viewport（`width=device-width` ↔ `width=1280`），
///    递归应用到 iframe；切换后自动重新加载一次；
/// 3. **缩放** —— 改页面 zoom，档位 50%–150%，电脑端默认 60%；
/// 4. **两个出路**：在浏览器打开、复制链接（D4 兜底），外加刷新；
/// 5. **返回键优先走网页历史**，退到底才退出容器。
///
/// **不额外处理登录** —— 登录过统一身份认证之后，接入同一 CAS 的系统打开时
/// 会自己带上 cookie（进程级 CookieManager 共享，见 `session.dart`）。
///
/// 刻意**不复用** `jwx_import_page.dart`：那是有专门课表解析逻辑的专用页。
class WebContainerPage extends StatefulWidget {
  const WebContainerPage({super.key, required this.title, required this.url});

  /// 顶栏标题（用服务名，不用网页自己的 title —— 那通常是系统名，更长）
  final String title;

  final String url;

  @override
  State<WebContainerPage> createState() => _WebContainerPageState();
}

class _WebContainerPageState extends State<WebContainerPage> {
  WebViewController? _web;
  bool _loading = true;
  String? _error;
  bool _canGoBack = false;
  String _notice = '';

  /// 是否按手机宽度重排。false = 电脑端（宽度按 1280 渲染）
  bool _mobileUi = true;

  /// 页面缩放。电脑端默认 0.6，手机端默认 1.0
  double _zoom = 1.0;

  static const List<double> _zoomOptions = <double>[
    0.5,
    0.6,
    0.75,
    1.0,
    1.25,
    1.5,
  ];

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_android) _boot();
  }

  void _boot() {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() => _loading = false);
            _syncCanGoBack();
            // 重新加载会把 viewport 与 zoom 冲掉，每次加载完重新套一遍
            _applyViewport();
          },
          onWebResourceError: (WebResourceError e) {
            // 子资源（图片、脚本）加载失败不该把整页判成失败
            if (e.isForMainFrame != true) return;
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = e.description.isEmpty ? '打不开这个页面' : e.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    setState(() => _web = controller);
  }

  Future<void> _syncCanGoBack() async {
    final bool v = await _web?.canGoBack() ?? false;
    if (mounted && v != _canGoBack) setState(() => _canGoBack = v);
  }

  /// 把 viewport 与缩放递归写进页面（含所有 iframe）。
  ///
  /// 为什么要递归：教务、学工这类系统是套娃结构，只改外层的话，
  /// 内层那张表还是按它原来的宽度排版，看起来就像"没生效"。
  Future<void> _applyViewport() async {
    final WebViewController? web = _web;
    if (web == null) return;
    final String content = _mobileUi
        ? 'width=device-width,initial-scale=1,maximum-scale=5,user-scalable=yes'
        : 'width=1280';
    final String z = _zoom.toStringAsFixed(2);
    final String js =
        "(function(){"
        "var c='$content';"
        "var z='$z';"
        "function apply(doc,depth){"
        "if(!doc||depth>4)return;"
        "try{"
        "var m=doc.querySelector('meta[name=viewport]');"
        "if(!m){m=doc.createElement('meta');m.setAttribute('name','viewport');"
        "if(doc.head)doc.head.appendChild(m);}"
        "m.setAttribute('content',c);"
        "}catch(e){}"
        "try{if(doc.documentElement)doc.documentElement.style.zoom=z;}catch(e){}"
        "try{"
        "var fs=doc.querySelectorAll('iframe,frame');"
        "for(var i=0;i<fs.length;i++){"
        "var d=null;try{d=fs[i].contentDocument;}catch(e){}"
        "if(d)apply(d,depth+1);}"
        "}catch(e){}"
        "}"
        "apply(document,0);"
        "})()";
    try {
      await web.runJavaScript(js);
    } catch (_) {
      // 页面还在跳转时注入会失败，下一次 onPageFinished 还会再来一次
    }
  }

  /// 手机 / 电脑端切换：改 viewport，然后**重新加载一遍**。
  ///
  /// 为什么要重载：viewport 改了之后，页面自身按旧宽度算好的布局不会自动
  /// 重排（尤其表格）。重载一次最干净；重载后 onPageFinished 会把新的
  /// viewport 与缩放重新套上去。
  Future<void> _toggleUi() async {
    final bool next = !_mobileUi;
    setState(() {
      _mobileUi = next;
      // 电脑端按 1280 宽渲染，手机上必须缩一点才看得全；手机端还原
      _zoom = next ? 1.0 : 0.6;
      _loading = true;
      _error = null;
    });
    _flash(next ? '已切到手机版' : '已切到电脑版');
    await _applyViewport();
    await _web?.reload();
  }

  void _setZoom(double z) {
    setState(() => _zoom = z);
    _applyViewport();
  }

  /// 返回：有网页历史就先退网页，退到底才退出容器
  Future<void> _goBack() async {
    if (await _web?.canGoBack() ?? false) {
      await _web!.goBack();
      await _syncCanGoBack();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _web?.reload();
  }

  Future<void> _openInBrowser() async {
    final Uri uri = Uri.parse(widget.url);
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _flash('打不开浏览器');
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (mounted) _flash('链接已复制');
  }

  void _flash(String text) {
    setState(() => _notice = text);
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _notice == text) setState(() => _notice = '');
    });
  }

  void _openMenu() {
    showDgutSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DgutGroupHead(title: widget.title),
          DgutRow(
            title: '刷新',
            subtitle: '重新加载这个页面',
            onTap: () {
              Navigator.of(context).pop();
              _reload();
            },
          ),
          DgutRow(
            title: '缩放',
            subtitle: '页面显示比例',
            value: '${(_zoom * 100).round()}%',
            onTap: () {
              Navigator.of(context).pop();
              _openZoomSheet();
            },
          ),
          DgutRow(
            title: _mobileUi ? '切换到电脑端' : '切换到手机版',
            subtitle: _mobileUi ? '按 1280 宽渲染，看得到完整表格' : '按手机宽度重新排版',
            onTap: () {
              Navigator.of(context).pop();
              _toggleUi();
            },
          ),
          DgutRow(
            title: '在浏览器打开',
            subtitle: '这里打不开时用系统浏览器',
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

  void _openZoomSheet() {
    showDgutSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DgutGroupHead(title: '缩放'),
          for (int i = 0; i < _zoomOptions.length; i++)
            DgutRow(
              title: '${(_zoomOptions[i] * 100).round()}%',
              value: _zoomOptions[i] == _zoom ? '当前' : null,
              showDivider: i != _zoomOptions.length - 1,
              onTap: () {
                Navigator.of(context).pop();
                _setZoom(_zoomOptions[i]);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      backgroundColor: c.bg,
      body: PopScope(
        // 有网页历史时拦下系统返回，交给 _goBack 先退网页。
        // 退到底（canGoBack 变 false）就恢复允许返回，不长期拦住。
        canPop: !_canGoBack,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (didPop) return;
          _goBack();
        },
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: _web == null
                  ? _unsupported()
                  : WebViewWidget(controller: _web!),
            ),
            // 返回
            Positioned(
              left: DgutSpace.pad,
              top: topInset + 8,
              child: _RoundButton(
                icon: Icons.arrow_back_rounded,
                onTap: _goBack,
              ),
            ),
            // 手机 / 电脑端切换 + 更多
            if (_web != null)
              Positioned(
                right: DgutSpace.pad,
                top: topInset + 8,
                child: Row(
                  children: <Widget>[
                    _RoundButton(
                      icon: _mobileUi
                          ? Icons.desktop_windows_outlined
                          : Icons.smartphone_rounded,
                      onTap: _toggleUi,
                    ),
                    const SizedBox(width: 8),
                    _RoundButton(
                      icon: Icons.more_horiz_rounded,
                      onTap: _openMenu,
                    ),
                  ],
                ),
              ),
            // 底部状态：加载中 / 出错 / 临时提示
            Positioned(
              left: DgutSpace.pad,
              right: DgutSpace.pad,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
              child: Center(child: _bottomPill(c)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomPill(DgutColors c) {
    if (_notice.isNotEmpty) {
      return _StatusPill(text: _notice);
    }
    if (_error != null) {
      return _StatusPill(text: _error!, actionLabel: '重试', onAction: _reload);
    }
    if (_loading) {
      return _StatusPill(text: '正在打开${widget.title}');
    }
    return const SizedBox.shrink();
  }

  Widget _unsupported() {
    final DgutColors c = context.dg;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DgutSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('网页容器在安卓版可用', style: DgutType.body.copyWith(color: c.ink2)),
            const SizedBox(height: DgutSpace.s2),
            Text(
              widget.url,
              textAlign: TextAlign.center,
              style: DgutType.caption1.copyWith(color: c.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 1,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.bg.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: DgutShadows.float,
        ),
        child: Icon(icon, size: 20, color: c.ink),
      ),
    );
  }
}

/// 底部玻璃胶囊：加载态、错误态与临时提示共用
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DgutRadius.full),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: c.glassDock.withValues(alpha: dark ? 0.55 : 0.52),
            borderRadius: BorderRadius.circular(DgutRadius.full),
            border: Border.all(color: c.glassEdge, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DgutType.caption1.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(width: 10),
                DgutPressable(
                  onTap: onAction,
                  child: Text(
                    actionLabel!,
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
