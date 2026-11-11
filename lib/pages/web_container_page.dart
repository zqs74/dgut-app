import 'dart:async';

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

  /// 拖滑块时的注入节流：不节流的话每一帧都会往 WebView 里灌一次 JS
  Timer? _zoomThrottle;

  /// 吸附档位：拖到附近会自动吸过去，也可以直接点
  static const List<double> _zoomStops = <double>[
    0.5,
    0.6,
    0.75,
    1.0,
    1.25,
    1.5,
  ];

  static const double _zoomMin = 0.4;
  static const double _zoomMax = 2.0;

  /// 离档位多近算「吸附」
  static const double _snapRange = 0.035;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_android) _boot();
  }

  @override
  void dispose() {
    _zoomThrottle?.cancel();
    super.dispose();
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

  /// 无极调节时把值吸到最近的常用档位，其余按原值走
  double _snap(double v) {
    for (final double s in _zoomStops) {
      if ((v - s).abs() <= _snapRange) return s;
    }
    return v.clamp(_zoomMin, _zoomMax);
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
            onTap: () {
              Navigator.of(context).pop();
              _reload();
            },
          ),
          DgutRow(
            title: '缩放',
            value: '${(_zoom * 100).round()}%',
            onTap: () {
              Navigator.of(context).pop();
              _openZoomSheet();
            },
          ),
          DgutRow(
            title: _mobileUi ? '切换到电脑端' : '切换到手机版',
            onTap: () {
              Navigator.of(context).pop();
              _toggleUi();
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

  /// 缩放面板：一条无极滑块 + 六个可直接点的常用档位。
  ///
  /// 拖滑块时实时预览（节流注入），拖到档位附近自动吸附；
  /// 面板关闭时再补一次注入，保证最终值和页面一致。
  void _openZoomSheet() {
    double temp = _zoom;
    Timer? throttle;

    showDgutSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheet) {
          final DgutColors c = ctx.dg;

          void apply(double v) {
            final double s = _snap(v);
            setSheet(() => temp = s);
            setState(() => _zoom = s);
            throttle?.cancel();
            throttle = Timer(const Duration(milliseconds: 130), _applyViewport);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DgutGroupHead(title: '缩放'),
              Center(
                child: Text(
                  '${(temp * 100).round()}%',
                  style: DgutType.title1.copyWith(color: c.ink),
                ),
              ),
              Slider(
                value: temp.clamp(_zoomMin, _zoomMax),
                min: _zoomMin,
                max: _zoomMax,
                activeColor: c.ink,
                inactiveColor: c.line,
                onChanged: apply,
                onChangeEnd: (_) => _applyViewport(),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final double z in _zoomStops)
                    _ZoomChip(
                      label: '${(z * 100).round()}%',
                      selected: (z - temp).abs() < 0.001,
                      onTap: () => apply(z),
                    ),
                ],
              ),
              const SizedBox(height: DgutSpace.s2),
              Text(
                '拖到附近会自动吸附到常用比例',
                textAlign: TextAlign.center,
                style: DgutType.caption1.copyWith(color: c.ink3),
              ),
              const SizedBox(height: DgutSpace.s1),
            ],
          );
        },
      ),
    ).then((_) {
      throttle?.cancel();
      _applyViewport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 有网页历史时拦下系统返回，交给 _goBack 先退网页。
      // 退到底（canGoBack 变 false）就恢复允许返回，不长期拦住。
      canPop: !_canGoBack,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) return;
        _goBack();
      },
      child: DgutWebScaffold(
        onBack: _goBack,
        actions: _web == null
            ? const <Widget>[]
            : <Widget>[
                DgutGlassButton(
                  icon: _mobileUi
                      ? Icons.desktop_windows_outlined
                      : Icons.smartphone_rounded,
                  onTap: _toggleUi,
                ),
                DgutGlassButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: _openMenu,
                ),
              ],
        bottom: _bottomPill(),
        child: _web == null ? _unsupported() : WebViewWidget(controller: _web!),
      ),
    );
  }

  Widget? _bottomPill() {
    if (_notice.isNotEmpty) {
      return DgutStatusPill(text: _notice);
    }
    if (_error != null) {
      return DgutStatusPill(
        text: _error!,
        actionLabel: '重试',
        onAction: _reload,
      );
    }
    if (_loading) {
      return DgutStatusPill(text: '正在打开${widget.title}');
    }
    return null;
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

/// 缩放档位小胶囊：点一下直接跳到该比例
class _ZoomChip extends StatelessWidget {
  const _ZoomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.fill,
          borderRadius: BorderRadius.circular(DgutRadius.full),
        ),
        child: Text(
          label,
          style: DgutType.caption1.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? c.bgDeep : c.ink2,
          ),
        ),
      ),
    );
  }
}
