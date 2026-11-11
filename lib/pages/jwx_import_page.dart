import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_status_pill.dart';
import '../components/dgut_web_scaffold.dart';
import '../services/jwx_parser.dart';
import '../theme/dgut_tokens.dart';
import 'course_edit_page.dart';
import 'import_review_page.dart';

/// 教务导入（L3）：在应用内登录莞工教务，读完课表进预览页。
///
/// 只做本校（`jwx.dgut.edu.cn` 的强智 6）。登录走教务自己的 CAS 页面，
/// 这里不碰账号密码；读课表只读页面上的 HTML，读完即解析。
class JwxImportPage extends StatefulWidget {
  const JwxImportPage({super.key});

  @override
  State<JwxImportPage> createState() => _JwxImportPageState();
}

class _JwxImportPageState extends State<JwxImportPage> {
  static const String _timetableUrl =
      'https://jwx.dgut.edu.cn/xskb/xskb_list.do?viweType=0';
  static const String _fallbackUrl =
      'https://jwx.dgut.edu.cn/jsxsd/xskb/xskb_list.do?viweType=0';

  WebViewController? _web;
  Timer? _timeout;
  String _status = '正在打开教务';
  bool _busy = false;
  int _navigations = 0;

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

  void _boot() {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (url.contains('authserver')) {
              _set('登录教务');
            } else if (url.contains('xskb')) {
              _set('正在读取课表');
            }
          },
          onPageFinished: (String url) => _onLoaded(url),
          onWebResourceError: (WebResourceError e) {
            if (!_busy) _set('打不开教务');
          },
        ),
      )
      ..loadRequest(Uri.parse(_timetableUrl));
    setState(() => _web = controller);
  }

  void _set(String status) {
    if (mounted) setState(() => _status = status);
  }

  Future<void> _onLoaded(String url) async {
    if (_busy) return;
    if (url.contains('authserver')) {
      _set('登录教务');
      return;
    }
    if (url.contains('xskb')) {
      await _scrape();
      return;
    }
    if (url.contains('jwx.dgut.edu.cn')) {
      // 登录后落回了教务框架页：自己再导航到课表本体
      _navigations++;
      _set('正在打开课表');
      final String next = _navigations <= 1 ? _timetableUrl : _fallbackUrl;
      await _web?.loadRequest(Uri.parse(next));
    }
  }

  Future<void> _scrape() async {
    _busy = true;
    _set('正在读取课表');
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 20), () {
      if (_busy && mounted) {
        _busy = false;
        _set('读取超时');
      }
    });

    String html = '';
    // 教务是套娃结构：课表可能在 iframe 里，逐层找，找不到就等一会儿再试
    const String js =
        "(function(){"
        "function grab(doc,depth){"
        "if(!doc||depth>3)return '';"
        "var t=doc.getElementById('timetable')||doc.querySelector('table');"
        "if(t&&t.outerHTML.indexOf('老师')>=0)return t.outerHTML;"
        "var fs=doc.querySelectorAll('iframe,frame');"
        "for(var i=0;i<fs.length;i++){"
        "var h='';try{h=grab(fs[i].contentDocument,depth+1);}catch(e){}"
        "if(h)return h;}"
        "return t?t.outerHTML:'';}"
        "return grab(document,0);})()";

    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final Object raw = await _web!.runJavaScriptReturningResult(js);
        html = raw is String ? raw : '$raw';
        if (html.length > 1 && html.startsWith('"') && html.endsWith('"')) {
          try {
            html = jsonDecode(html) as String;
          } catch (_) {}
        }
      } catch (_) {
        html = '';
      }
      if (html.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
    }

    _timeout?.cancel();
    _busy = false;

    if (html.isEmpty) {
      _set('没读到课表');
      return;
    }

    final JwxParseResult result = JwxParser.parse(html);
    if (result.courses.isEmpty) {
      _set('没读到课表');
      return;
    }

    if (!mounted) return;
    final bool? imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => ImportReviewPage(result: result)),
    );
    if (imported == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return DgutWebScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      menuTitle: '教务导入',
      onRefresh: _boot,
      bottom: DgutStatusPill(
        text: _status,
        actionLabel: _status == '登录教务' ? null : '重试',
        onAction: _status == '登录教务' ? null : _boot,
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
            Text('教务导入在安卓版可用', style: DgutType.body.copyWith(color: c.ink2)),
            const SizedBox(height: DgutSpace.s3),
            DgutButton(
              label: '手动添加课程',
              variant: DgutButtonVariant.tinted,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(builder: (_) => const CourseEditPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
