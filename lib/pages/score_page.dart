import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../model/score.dart';
import '../store/score_repository.dart';
import 'web_container_page.dart';
import '../theme/dgut_tokens.dart';

/// 成绩查询：**真集成**，不是套浏览器。
///
/// 做法跟课表导入一样 —— 借已登录的 WebView 会话，注入 JS 把表格 HTML 取回来，
/// 本地解析成结构化数据，再用手写的原生列表渲染。用户全程看不到教务网页。
///
/// 为什么不用纯 HTTP：CAS 登录要过滑块与动态码，自己维护一套登录流程代价太大；
/// WebView 在 App 里已经登录好了，直接借它的身份最省事。
///
/// 抓取流程是个四步状态机，靠 [NavigationDelegate.onPageFinished] 推进：
/// 打开教务首页 → 找「成绩」入口链接 → 加载成绩页 → 抓 HTML 并解析。
class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  static const String _entry = 'https://jwx.dgut.edu.cn/';

  /// 递归找「成绩」入口：教务菜单常在左侧 frame 里，只看顶层找不到
  static const String _findLinkJs = '''
(function(){
  function find(doc, depth){
    if(!doc || depth>3) return '';
    try{
      var as = doc.querySelectorAll('a');
      for(var i=0;i<as.length;i++){
        var t = (as[i].textContent||'').replace(/\\s/g,'');
        if(t.indexOf('成绩')>=0){
          var h = as[i].href||'';
          if(h && h.indexOf('javascript')<0) return h;
        }
      }
    }catch(e){}
    try{
      var fs = doc.querySelectorAll('iframe,frame');
      for(var i=0;i<fs.length;i++){
        var d=null; try{d=fs[i].contentDocument;}catch(e){}
        var r = find(d, depth+1);
        if(r) return r;
      }
    }catch(e){}
    return '';
  }
  return find(document, 0);
})()
''';

  /// 把当前页（含所有 iframe）的 HTML 拼起来返回
  static const String _dumpJs = '''
(function(){
  var parts = [];
  try{ parts.push(document.documentElement.outerHTML); }catch(e){}
  function walk(doc, depth){
    if(!doc || depth>3) return;
    try{
      var fs = doc.querySelectorAll('iframe,frame');
      for(var i=0;i<fs.length;i++){
        var d=null; try{d=fs[i].contentDocument;}catch(e){}
        if(d){
          try{ parts.push(d.documentElement.outerHTML); }catch(e){}
          walk(d, depth+1);
        }
      }
    }catch(e){}
  }
  walk(document, 0);
  return parts.join('\\n<!--FRAME-->\\n');
})()
''';

  final ValueNotifier<DgutScrollInfo> _offset = ValueNotifier<DgutScrollInfo>(
    DgutScrollInfo.zero,
  );

  WebViewController? _web;
  List<DgutScore>? _scores;
  DateTime? _fetchedAt;
  String _status = '正在打开教务';
  String? _error;
  bool _fetching = false;
  bool _fromCache = false;

  /// 0 = 还没到首页；1 = 首页到了、在找入口；2 = 成绩页在加载；3 = 已抓完
  int _step = 0;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  /// 先放缓存（有就立刻能看），再后台抓新的
  Future<void> _boot() async {
    final List<DgutScore> cached = await ScoreRepository.instance.load();
    final DateTime? at = await ScoreRepository.instance.lastFetchedAt();
    if (!mounted) return;
    if (cached.isNotEmpty) {
      setState(() {
        _scores = cached;
        _fetchedAt = at;
        _fromCache = true;
      });
    }
    if (!_android) {
      setState(() => _status = '成绩读取在安卓版可用');
      return;
    }
    _startWeb();
  }

  void _startWeb() {
    _step = 0;
    final WebViewController c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) => _onFinished(url),
          onWebResourceError: (WebResourceError e) {
            if (e.isForMainFrame != true) return;
            _fail('打不开教务：${e.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_entry));
    setState(() {
      _web = c;
      _fetching = true;
      _error = null;
      _status = '正在打开教务';
    });
  }

  Future<void> _onFinished(String url) async {
    if (_step == 0) {
      _step = 1;
      await _locateAndLoad();
    } else if (_step == 2) {
      _step = 3;
      await _scrape();
    }
  }

  /// 借用正常的网页容器完成教务登录，回来后自动重抓
  Future<void> _openJwx() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const WebContainerPage(title: '教务系统', url: _entry),
      ),
    );
    if (mounted) _startWeb();
  }

  Future<void> _locateAndLoad() async {
    final WebViewController? web = _web;
    if (web == null) return;
    _setStatus('正在找成绩入口');

    String href = '';
    try {
      href = (await web.runJavaScriptReturningResult(_findLinkJs))
          .toString()
          .replaceAll('"', '')
          .trim();
    } catch (_) {
      // 页面可能还在跳转
    }
    if (href.isEmpty || href == 'null') {
      _fail('没找到成绩入口，登录可能已过期');
      return;
    }
    _step = 2;
    _setStatus('正在打开成绩页');
    try {
      await web.loadRequest(Uri.parse(href));
    } catch (_) {
      _fail('成绩页打不开');
    }
  }

  Future<void> _scrape() async {
    final WebViewController? web = _web;
    if (web == null) return;
    _setStatus('正在读取成绩');

    String html = '';
    try {
      html = (await web.runJavaScriptReturningResult(_dumpJs))
          .toString()
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\"', '"');
    } catch (_) {}
    final List<DgutScore> list = ScoreParser.parse(html);
    if (list.isEmpty) {
      _fail('没读到成绩，可能是空数据或页面结构变了');
      return;
    }
    await ScoreRepository.instance.save(list);
    if (!mounted) return;
    setState(() {
      _scores = list;
      _fetchedAt = DateTime.now();
      _fetching = false;
      _fromCache = false;
      _error = null;
      _status = '';
    });
  }

  void _setStatus(String s) {
    if (!mounted) return;
    setState(() => _status = s);
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _fetching = false;
      _status = '';
    });
  }

  String _subtitle() {
    final DateTime? at = _fetchedAt;
    final String when = at == null
        ? '教务'
        : '${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return _fromCache ? '上次读取 $when' : '更新于 $when';
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final List<DgutScore> scores = _scores ?? const <DgutScore>[];

    return Scaffold(
      backgroundColor: c.bg,
      body: DgutPageScaffold(
        eyebrow: _subtitle(),
        title: '成绩',
        offset: _offset,
        footerHeight: 120,
        onBack: () => Navigator.of(context).maybePop(),
        children: <Widget>[
          if (_error != null) ...<Widget>[
            _Notice(text: _error!, onRetry: _startWeb),
            const SizedBox(height: DgutSpace.s2),
            Center(
              child: DgutButton(
                label: '去登录教务',
                variant: DgutButtonVariant.tinted,
                onTap: _openJwx,
              ),
            ),
          ],
          if (scores.isEmpty && _fetching)
            _Notice(text: _status.isEmpty ? '正在读取' : _status),
          if (scores.isEmpty && !_fetching && _error == null) ...<Widget>[
            _Notice(text: _status.isEmpty ? '还没有成绩数据' : _status),
            const SizedBox(height: DgutSpace.s2),
            Center(
              child: DgutButton(
                label: '重新读取',
                variant: DgutButtonVariant.tinted,
                onTap: _startWeb,
              ),
            ),
          ],
          if (scores.isNotEmpty) ...<Widget>[
            if (_fetching) _Notice(text: _status.isEmpty ? '正在更新' : _status),
            _Summary(scores: scores),
            const SizedBox(height: DgutSpace.s2),
            for (final DgutScore s in scores) _ScoreRow(score: s),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.scores});

  final List<DgutScore> scores;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final ScoreSummary sum = ScoreParser.summarize(scores);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text('${sum.count}', style: DgutType.title1.copyWith(color: c.ink)),
        const SizedBox(width: 6),
        Text('门', style: DgutType.caption1.copyWith(color: c.ink3)),
        if (sum.average != null) ...<Widget>[
          const SizedBox(width: DgutSpace.s2),
          Text(
            '加权平均 ${sum.average!.toStringAsFixed(1)}',
            style: DgutType.caption1.copyWith(color: c.ink2),
          ),
        ],
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.score});

  final DgutScore score;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final List<String> meta = <String>[
      if (score.credit.isNotEmpty) '${score.credit} 学分',
      if (score.nature.isNotEmpty) score.nature,
      if (score.examType.isNotEmpty) score.examType,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  score.course,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DgutType.body.copyWith(color: c.ink),
                ),
                if (meta.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    meta.join(' · '),
                    style: DgutType.caption1.copyWith(color: c.ink3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DgutSpace.s2),
          Text(
            score.score.isEmpty ? '—' : score.score,
            style: DgutType.title3.copyWith(
              color: score.isNumeric ? c.ink : c.ink2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Container(
      margin: const EdgeInsets.only(bottom: DgutSpace.s2),
      padding: const EdgeInsets.all(DgutSpace.s2),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(DgutRadius.r2),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(text, style: DgutType.caption1.copyWith(color: c.ink2)),
          ),
          if (onRetry != null)
            DgutPressable(
              onTap: onRetry,
              child: Text(
                '重试',
                style: DgutType.caption1.copyWith(
                  color: c.blueInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
