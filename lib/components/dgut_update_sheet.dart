import 'package:flutter/material.dart';

import '../data/changelog.dart';
import '../services/update_models.dart';
import '../services/update_service.dart';
import '../theme/dgut_tokens.dart';
import 'dgut_basics.dart';
import 'dgut_theme_sheet.dart' show DgutSheetClose;

enum _Phase { checking, latest, available, downloading, done, error }

/// 检查更新浮层：检查 → 有新版/已最新 → 下载进度 → 唤起系统安装器
Future<void> showDgutUpdateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    isScrollControlled: true,
    builder: (_) => const _UpdateSheet(),
  );
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet();

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  _Phase _phase = _Phase.checking;
  UpdateInfo? _info;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _phase = _Phase.checking;
      _error = null;
    });
    try {
      final UpdateInfo? info = await UpdateService.check(kCurrentVersion);
      if (!mounted) return;
      setState(() {
        _info = info;
        _phase = info == null ? _Phase.latest : _Phase.available;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = _friendly(e);
      });
    }
  }

  Future<void> _download() async {
    final UpdateInfo? info = _info;
    if (info == null) return;
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
    });
    try {
      await UpdateService.downloadAndInstall(info, (double p) {
        if (!mounted) return;
        setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _phase = _Phase.done);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    final String s = e.toString();
    if (s.contains('SocketException') || s.contains('timeout')) {
      return '连不上更新服务器，检查网络后再试';
    }
    if (s.contains('install_failed')) {
      return '唤起安装失败：请在系统设置里允许本应用安装未知应用';
    }
    if (s.contains('HTTP')) return s;
    return '出了点问题：$s';
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            DgutSpace.s2, 0, DgutSpace.s2, DgutSpace.s2),
        child: Container(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(DgutRadius.r4),
            boxShadow:
                DgutShadows.forBrightness(Theme.of(context).brightness),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad, DgutSpace.s3, DgutSpace.pad, DgutSpace.s1),
                child: Row(
                  children: [
                    Text('检查更新',
                        style: DgutType.title3.copyWith(color: c.ink)),
                    const Spacer(),
                    DgutSheetClose(
                        onTap: () => Navigator.of(context).maybePop()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DgutSpace.pad, 0, DgutSpace.pad, DgutSpace.s3),
                child: _body(c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(DgutColors c) {
    switch (_phase) {
      case _Phase.checking:
        return Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.ink3,
              ),
            ),
            const SizedBox(width: 12),
            Text('正在检查新版本…',
                style: DgutType.subhead.copyWith(color: c.ink2)),
          ],
        );

      case _Phase.latest:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已是最新版本',
                style: DgutType.body.copyWith(
                    color: c.ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('当前 v$kCurrentVersion',
                style: DgutType.footnote.copyWith(color: c.ink3)),
          ],
        );

      case _Phase.available:
        final UpdateInfo info = _info!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('发现新版本 v${info.version}',
                    style: DgutType.body.copyWith(
                        color: c.ink, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('当前 v$kCurrentVersion',
                    style: DgutType.footnote.copyWith(color: c.ink3)),
              ],
            ),
            if (info.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Text(
                    info.notes,
                    style: DgutType.footnote
                        .copyWith(color: c.ink2, height: 1.6),
                  ),
                ),
              ),
            ],
            const SizedBox(height: DgutSpace.s3),
            Row(
              children: [
                Text(info.sizeLabel,
                    style: DgutType.caption1.copyWith(color: c.ink3)),
                const Spacer(),
                DgutButton(
                  label: '下载并安装',
                  variant: DgutButtonVariant.filled,
                  onTap: _download,
                ),
              ],
            ),
          ],
        );

      case _Phase.downloading:
        final bool known = _progress >= 0;
        final double value = known ? _progress : 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('正在下载…',
                    style: DgutType.body.copyWith(color: c.ink)),
                const Spacer(),
                Text(known ? '${(value * 100).round()}%' : '下载中',
                    style: DgutType.footnote.copyWith(color: c.ink3)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: known ? value : null,
                minHeight: 6,
                backgroundColor: c.fillStrong,
                valueColor: AlwaysStoppedAnimation<Color>(c.blue),
              ),
            ),
            const SizedBox(height: 12),
            Text('下完会弹系统安装界面，点「安装」即可完成',
                style: DgutType.caption1.copyWith(color: c.ink3)),
          ],
        );

      case _Phase.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已交给系统安装',
                style: DgutType.body.copyWith(
                    color: c.ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('在系统弹窗里点「安装」完成更新；若没看到弹窗，请允许本应用安装未知应用后重试',
                style: DgutType.footnote
                    .copyWith(color: c.ink3, height: 1.6)),
          ],
        );

      case _Phase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('没能更新',
                style: DgutType.body.copyWith(
                    color: c.ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_error ?? '未知错误',
                style: DgutType.footnote
                    .copyWith(color: c.ink3, height: 1.6)),
            const SizedBox(height: DgutSpace.s2),
            Align(
              alignment: Alignment.centerRight,
              child: DgutButton(
                label: '重试',
                size: DgutButtonSize.sm,
                onTap: _check,
              ),
            ),
          ],
        );
    }
  }
}
