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
/// 只管四件事（方案 §五 D2）：
/// 1. **加载 / 失败 / 重试三态** —— 不让用户对着白屏猜；
/// 2. **两个出路**：在浏览器打开、复制链接（D4 兜底）；
/// 3. **返回键优先走网页历史**，退到底才退出容器；
/// 4. **不额外处理登录** —— 登录过统一身份认证之后，接入同一 CAS 的系统
///    打开时会自己带上 cookie（进程级 CookieManager 共享，见 `session.dart`）。
///
/// 刻意**不复用** `jwx_import_page.dart`：那是有专门课表解析逻辑的专用页，
/// 这个容器不解析任何内容。
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

  /// 返回：有网页历史就先退网页，退到底才退出容器
  Future<void> _goBack() async {
    if (await _web?.canGoBack() ?? false) {
      await _web!.goBack();
      await _syncCanGoBack();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
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
            title: '在浏览器打开',
            subtitle: '这里打不开时用系统浏览器',
            onTap: () {
              Navigator.of(context).pop();
              _openInBrowser();
            },
          ),
          DgutRow(
            title: '复制链接',
            onTap: () {
              Navigator.of(context).pop();
              _copyLink();
            },
          ),
          DgutRow(
            title: '重新加载',
            showDivider: false,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _loading = true;
                _error = null;
              });
              _web?.loadRequest(Uri.parse(widget.url));
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
            // 菜单
            if (_web != null)
              Positioned(
                right: DgutSpace.pad,
                top: topInset + 8,
                child: _RoundButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: _openMenu,
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
      return _StatusPill(
        text: _error!,
        actionLabel: '重试',
        onAction: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _web?.loadRequest(Uri.parse(widget.url));
        },
      );
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
