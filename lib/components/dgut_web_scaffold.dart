import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/dgut_tokens.dart';
import 'dgut_basics.dart';
import 'dgut_glass_button.dart';
import 'dgut_sheet.dart';

/// 网页模板：所有用 WebView 打开的页面都走这一套。
///
/// **菜单和缩放面板也由模板生成**，页面只传回调 —— 这样每个网页页的
/// 「更多」菜单结构和顺序永远一致，不会再出现"这个页有缩放、那个页没有"。
///
/// 菜单项按能力出现，顺序固定：
/// 刷新 → 缩放 → 切换电脑端/手机版 → 在浏览器打开 → 复制链接
///
/// 页面结构：网页铺满全屏，左上返回、右上操作（玻璃圆钮），底部状态胶囊。
class DgutWebScaffold extends StatefulWidget {
  const DgutWebScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.onRefresh,
    this.onOpenInBrowser,
    this.onCopyLink,
    this.zoom,
    this.onZoomChanged,
    this.mobileUi,
    this.onToggleUi,
    this.menuTitle = '网页',
    this.actions = const <Widget>[],
    this.bottom,
  });

  /// 网页本体
  final Widget child;

  final VoidCallback? onBack;

  /// 菜单：刷新
  final VoidCallback? onRefresh;

  /// 菜单：在浏览器打开
  final Future<void> Function()? onOpenInBrowser;

  /// 菜单：复制链接
  final Future<void> Function()? onCopyLink;

  /// 当前缩放；与 [onZoomChanged] 同时给才启用缩放
  final double? zoom;
  final ValueChanged<double>? onZoomChanged;

  /// 当前是否手机版；与 [onToggleUi] 同时给才出现切换项与右上角切换按钮
  final bool? mobileUi;
  final VoidCallback? onToggleUi;

  /// 菜单顶部的分组标题
  final String menuTitle;

  /// 右上角额外的自定义按钮（排在切换按钮之后、更多之前）
  final List<Widget> actions;

  /// 底部状态胶囊；null 表示不显示
  final Widget? bottom;

  /// 缩放吸附档位
  static const List<double> zoomStops = <double>[
    0.5,
    0.6,
    0.75,
    1.0,
    1.25,
    1.5,
  ];

  static const double zoomMin = 0.4;
  static const double zoomMax = 2.0;

  /// 离档位多近算「吸附」
  static const double _snapRange = 0.035;

  @override
  State<DgutWebScaffold> createState() => _DgutWebScaffoldState();
}

class _DgutWebScaffoldState extends State<DgutWebScaffold> {
  /// 圆钮距屏幕边缘的距离
  static const double _edge = 8;

  /// 拖滑块时的节流，避免每帧都回调页面注入 JS
  Timer? _zoomThrottle;

  @override
  void dispose() {
    _zoomThrottle?.cancel();
    super.dispose();
  }

  bool get _hasZoom => widget.zoom != null && widget.onZoomChanged != null;

  bool get _hasDeviceToggle =>
      widget.mobileUi != null && widget.onToggleUi != null;

  bool get _hasMenu =>
      widget.onRefresh != null ||
      _hasZoom ||
      _hasDeviceToggle ||
      widget.onOpenInBrowser != null ||
      widget.onCopyLink != null;

  /// 把值吸到最近的常用档位
  double _snap(double v) {
    for (final double s in DgutWebScaffold.zoomStops) {
      if ((v - s).abs() <= DgutWebScaffold._snapRange) return s;
    }
    return v.clamp(DgutWebScaffold.zoomMin, DgutWebScaffold.zoomMax);
  }

  void _openMenu() {
    showDgutSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DgutGroupHead(title: widget.menuTitle),
          if (widget.onRefresh != null)
            DgutRow(
              title: '刷新',
              onTap: () {
                Navigator.of(context).pop();
                widget.onRefresh!();
              },
            ),
          if (_hasZoom)
            DgutRow(
              title: '缩放',
              value: '${(widget.zoom! * 100).round()}%',
              onTap: () {
                Navigator.of(context).pop();
                _openZoomSheet();
              },
            ),
          if (_hasDeviceToggle)
            DgutRow(
              title: widget.mobileUi! ? '切换到电脑端' : '切换到手机版',
              onTap: () {
                Navigator.of(context).pop();
                widget.onToggleUi!();
              },
            ),
          if (widget.onOpenInBrowser != null)
            DgutRow(
              title: '在浏览器打开',
              onTap: () {
                Navigator.of(context).pop();
                widget.onOpenInBrowser!();
              },
            ),
          if (widget.onCopyLink != null)
            DgutRow(
              title: '复制链接',
              showDivider:
                  widget.onRefresh == null &&
                  !_hasZoom &&
                  !_hasDeviceToggle &&
                  widget.onOpenInBrowser == null,
              onTap: () {
                Navigator.of(context).pop();
                widget.onCopyLink!();
              },
            ),
        ],
      ),
    );
  }

  /// 缩放面板：无极滑块 + 六个可直接点的档位，拖到附近自动吸附
  void _openZoomSheet() {
    double temp = widget.zoom!;
    Timer? throttle;

    void emit(double v) {
      throttle?.cancel();
      throttle = Timer(
        const Duration(milliseconds: 130),
        () => widget.onZoomChanged!(temp),
      );
    }

    showDgutSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheet) {
          final DgutColors c = ctx.dg;

          void apply(double v) {
            final double s = _snap(v);
            setSheet(() => temp = s);
            emit(s);
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
                value: temp.clamp(
                  DgutWebScaffold.zoomMin,
                  DgutWebScaffold.zoomMax,
                ),
                min: DgutWebScaffold.zoomMin,
                max: DgutWebScaffold.zoomMax,
                activeColor: c.ink,
                inactiveColor: c.line,
                onChanged: apply,
                onChangeEnd: (double v) {
                  throttle?.cancel();
                  widget.onZoomChanged!(temp);
                },
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final double z in DgutWebScaffold.zoomStops)
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
      widget.onZoomChanged!(temp);
    });
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final double topInset = MediaQuery.viewPaddingOf(context).top;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final List<Widget> rightButtons = <Widget>[
      if (_hasDeviceToggle)
        DgutGlassButton(
          icon: widget.mobileUi!
              ? Icons.desktop_windows_outlined
              : Icons.smartphone_rounded,
          onTap: widget.onToggleUi!,
        ),
      ...widget.actions,
      if (_hasMenu)
        DgutGlassButton(icon: Icons.more_horiz_rounded, onTap: _openMenu),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: widget.child),
          if (widget.onBack != null)
            Positioned(
              left: DgutSpace.pad,
              top: topInset + _edge,
              child: DgutGlassButton(
                icon: Icons.arrow_back_rounded,
                onTap: widget.onBack!,
              ),
            ),
          if (rightButtons.isNotEmpty)
            Positioned(
              right: DgutSpace.pad,
              top: topInset + _edge,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < rightButtons.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: DgutSpace.s1),
                    rightButtons[i],
                  ],
                ],
              ),
            ),
          if (widget.bottom != null)
            Positioned(
              left: DgutSpace.pad,
              right: DgutSpace.pad,
              bottom: bottomInset + 24,
              child: Center(child: widget.bottom),
            ),
        ],
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
