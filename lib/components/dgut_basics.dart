import 'package:flutter/material.dart';

import '../theme/dgut_motion.dart';
import '../theme/dgut_tokens.dart';

/// 统一按压：contact 120ms + settle 曲线。整个设计语言里所有可点元素都走这里。
class DgutPressable extends StatefulWidget {
  const DgutPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedOpacity = 0.45,
    this.pressedScale = 1.0,
    this.pressedFill,
    this.radius,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedOpacity;
  final double pressedScale;
  final Color? pressedFill;
  final BorderRadius? radius;
  final HitTestBehavior behavior;

  @override
  State<DgutPressable> createState() => _DgutPressableState();
}

class _DgutPressableState extends State<DgutPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget w = AnimatedOpacity(
      opacity: _pressed ? widget.pressedOpacity : 1,
      duration: DgutMotion.contact,
      curve: Curves.linear,
      child: widget.child,
    );

    if (widget.pressedScale != 1.0) {
      w = AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: DgutMotion.contact,
        curve: DgutMotion.settle,
        child: w,
      );
    }

    if (widget.pressedFill != null) {
      w = AnimatedContainer(
        duration: DgutMotion.contact,
        curve: Curves.linear,
        decoration: BoxDecoration(
          color: _pressed ? widget.pressedFill : Colors.transparent,
          borderRadius: widget.radius,
        ),
        child: w,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: w,
    );
  }
}

enum DgutRowTone { none, urgent, soon }

/// 行：不卡片化之后承载所有列表信息的主力（.dg-row）
class DgutRow extends StatelessWidget {
  const DgutRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.trailing,
    this.tone = DgutRowTone.none,
    this.showChevron = true,
    this.showDivider = true,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? value;
  final Widget? trailing;
  final DgutRowTone tone;
  final bool showChevron;
  final bool showDivider;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final Color? bar = switch (tone) {
      DgutRowTone.urgent => c.red,
      DgutRowTone.soon => c.orange,
      DgutRowTone.none => null,
    };

    final Widget body = Padding(
      padding: EdgeInsets.only(top: 14, bottom: 14, left: bar != null ? 12 : 0),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(width: 22, child: Center(child: leading)),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DgutType.body.copyWith(color: c.ink, height: 1.35),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle!,
                      style: DgutType.footnote.copyWith(
                        color: c.ink3,
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            Text(value!, style: DgutType.callout.copyWith(color: c.ink3)),
          ],
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          if (showChevron) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.ink3),
          ],
        ],
      ),
    );

    Widget row = Stack(
      children: [
        if (bar != null)
          Positioned(
            left: 0,
            top: 10,
            bottom: 10,
            child: Container(width: 2, color: bar),
          ),
        body,
      ],
    );

    if (showDivider) {
      row = Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line, width: 1)),
        ),
        child: row,
      );
    }

    return DgutPressable(onTap: onTap, onLongPress: onLongPress, child: row);
  }
}

enum DgutButtonVariant { filled, tinted, gray, plain, danger }

enum DgutButtonSize { sm, md, lg }

class DgutButton extends StatelessWidget {
  const DgutButton({
    super.key,
    required this.label,
    this.variant = DgutButtonVariant.gray,
    this.size = DgutButtonSize.md,
    this.icon,
    this.onTap,
    this.block = false,
  });

  final String label;
  final DgutButtonVariant variant;
  final DgutButtonSize size;
  final Widget? icon;
  final VoidCallback? onTap;
  final bool block;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    final (double h, double pad, double fs, FontWeight fw) = switch (size) {
      DgutButtonSize.sm => (34, 14, 13, FontWeight.w500),
      DgutButtonSize.md => (42, 20, 15, FontWeight.w600),
      DgutButtonSize.lg => (52, 26, 16, FontWeight.w600),
    };

    final (Color bg, Color fg) = switch (variant) {
      DgutButtonVariant.filled => (c.blue, Colors.white),
      DgutButtonVariant.tinted => (c.blue.withValues(alpha: 0.12), c.blueInk),
      DgutButtonVariant.gray => (c.fill, c.ink),
      DgutButtonVariant.plain => (Colors.transparent, c.blueInk),
      DgutButtonVariant.danger => (c.red.withValues(alpha: 0.12), c.redInk),
    };

    return DgutPressable(
      onTap: onTap,
      pressedScale: 0.96,
      pressedOpacity: 1,
      pressedFill: variant == DgutButtonVariant.gray
          ? c.fillStrong
          : bg.withValues(alpha: (bg.a * 0.8).clamp(0.0, 1.0)),
      radius: BorderRadius.circular(DgutRadius.full),
      child: Container(
        height: h,
        width: block ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: variant == DgutButtonVariant.plain ? 6 : pad,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DgutRadius.full),
        ),
        child: Row(
          mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                fontSize: fs,
                fontWeight: fw,
                letterSpacing: -0.005 * fs,
                color: fg,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum DgutChipTone { neutral, info, ok, warn, danger, brand }

class DgutChip extends StatelessWidget {
  const DgutChip({
    super.key,
    required this.label,
    this.tone = DgutChipTone.neutral,
  });

  final String label;
  final DgutChipTone tone;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final (Color bg, Color fg) = switch (tone) {
      DgutChipTone.neutral => (c.fill, c.ink2),
      DgutChipTone.info => (c.blue.withValues(alpha: 0.11), c.blueInk),
      DgutChipTone.ok => (c.green.withValues(alpha: 0.14), c.greenInk),
      DgutChipTone.warn => (c.orange.withValues(alpha: 0.15), c.orangeInk),
      DgutChipTone.danger => (c.red.withValues(alpha: 0.12), c.redInk),
      DgutChipTone.brand => (c.brand.withValues(alpha: 0.12), c.brandInk),
    };
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DgutRadius.full),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: fg,
          height: 1.1,
        ),
      ),
    );
  }
}

/// 分组标题（.dg-grouphead）
class DgutGroupHead extends StatelessWidget {
  const DgutGroupHead({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Padding(
      padding: const EdgeInsets.only(top: DgutSpace.s3, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: DgutType.groupLabel.copyWith(color: c.ink3)),
          const Spacer(),
          if (action != null)
            DgutPressable(
              onTap: onAction,
              pressedOpacity: 0.5,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  action!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.blueInk,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一行统计（.dg-stat-line）
class DgutStatLine extends StatelessWidget {
  const DgutStatLine({super.key, required this.spans, this.padding});

  final List<InlineSpan> spans;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final TextStyle base = DgutType.footnote.copyWith(color: c.ink3);
    return Padding(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: DgutSpace.pad,
            vertical: DgutSpace.s2,
          ),
      child: RichText(
        text: TextSpan(style: base, children: spans),
      ),
    );
  }
}

/// 行内加粗（配 DgutStatLine 用）
InlineSpan dgutStrong(BuildContext context, String text) => TextSpan(
  text: text,
  style: TextStyle(color: context.dg.ink, fontWeight: FontWeight.w600),
);

InlineSpan dgutPlain(String text) => TextSpan(text: text);

/// 搜索框（.dg-search）
class DgutSearchField extends StatelessWidget {
  const DgutSearchField({
    super.key,
    this.hint = '搜索',
    this.controller,
    this.onChanged,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(DgutRadius.r2),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: c.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: c.blueInk,
              style: DgutType.subhead.copyWith(color: c.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: DgutType.subhead.copyWith(color: c.ink3),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 渐进披露（.dg-disclosure）
class DgutDisclosure extends StatefulWidget {
  const DgutDisclosure({
    super.key,
    required this.title,
    required this.count,
    required this.child,
    this.initiallyOpen = false,
  });

  final String title;
  final String count;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<DgutDisclosure> createState() => _DgutDisclosureState();
}

class _DgutDisclosureState extends State<DgutDisclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line, width: 1)),
      ),
      child: Column(
        children: [
          DgutPressable(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: DgutType.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Spacer(),
                  Text(
                    widget.count,
                    style: DgutType.footnote.copyWith(color: c.ink3),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: DgutMotion.exit,
                    curve: DgutMotion.settle,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: c.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: DgutMotion.exit,
            curve: DgutMotion.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

/// 进度条（.dg-meter）
class DgutMeter extends StatelessWidget {
  const DgutMeter({
    super.key,
    required this.name,
    required this.value,
    required this.ratio,
    this.color,
  });

  final String name;
  final String value;
  final double ratio;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final Color fill = color ?? c.blue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: DgutType.footnote.copyWith(
                  color: c.ink2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(value, style: DgutType.caption1.copyWith(color: c.ink3)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 6,
              color: c.fillStrong,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(color: fill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情键值行（.dg-kv）
class DgutKeyValue extends StatelessWidget {
  const DgutKeyValue({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Container(
      margin: const EdgeInsets.only(top: DgutSpace.s4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line, width: 1)),
      ),
      child: Column(
        children: [
          for (final (k, v) in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.line, width: 1)),
              ),
              child: Row(
                children: [
                  Text(k, style: DgutType.body.copyWith(color: c.ink3)),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      v,
                      textAlign: TextAlign.right,
                      style: DgutType.body.copyWith(color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 说明文字（.dg-legend）
class DgutLegend extends StatelessWidget {
  const DgutLegend(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        text,
        style: DgutType.caption1.copyWith(color: context.dg.ink3, height: 1.65),
      ),
    );
  }
}

/// 页首主块（.dg-hero）：label / value / meta / foot
class DgutHero extends StatelessWidget {
  const DgutHero({
    super.key,
    required this.label,
    required this.value,
    this.meta,
    this.foot,
    this.padding = const EdgeInsets.fromLTRB(
      DgutSpace.pad,
      DgutSpace.s4,
      DgutSpace.pad,
      DgutSpace.s3,
    ),
  });

  final String label;
  final String value;
  final String? meta;
  final Widget? foot;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.brand,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: DgutType.caption2.copyWith(
                    color: c.brandInk,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12 * 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: DgutType.title1.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (meta != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                meta!,
                style: DgutType.callout.copyWith(color: c.ink2),
              ),
            ),
          if (foot != null)
            Container(
              margin: const EdgeInsets.only(top: DgutSpace.s3),
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line, width: 1)),
              ),
              child: foot,
            ),
        ],
      ),
    );
  }
}

/// 开关：50×30 胶囊，开时 brand 底白钮，关时浅灰底。
class DgutSwitch extends StatelessWidget {
  const DgutSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutPressable(
      onTap: () => onChanged(!value),
      pressedOpacity: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? c.blue : c.line,
          borderRadius: BorderRadius.circular(DgutRadius.full),
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
