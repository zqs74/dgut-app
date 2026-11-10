import 'package:flutter/material.dart';

/// DGUT Glass 的颜色 / 字号 / 圆角 / 间距 / 阴影。
/// 真源：motion/dgut.css 的 :root 与 :root[data-theme="dark"]，共 31 个颜色变量。
@immutable
class DgutColors extends ThemeExtension<DgutColors> {
  // 表面与墨色
  final Color bg, bgDeep, surface, surface2;
  final Color ink, ink2, ink3, ink4;
  final Color line, lineStrong, fill, fillStrong;
  // 强调色：填充用原色，承载文字用 -ink
  final Color blue, blueInk;
  final Color green, greenInk;
  final Color orange, orangeInk;
  final Color red, redInk;
  final Color violet, violetInk;
  final Color brand, brandInk;
  // 玻璃
  final Color glass, glassThick, glassDock, glassEdge, glassFallback;
  // 环境光
  final Color ambient1, ambient2;

  const DgutColors({
    required this.bg,
    required this.bgDeep,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.line,
    required this.lineStrong,
    required this.fill,
    required this.fillStrong,
    required this.blue,
    required this.blueInk,
    required this.green,
    required this.greenInk,
    required this.orange,
    required this.orangeInk,
    required this.red,
    required this.redInk,
    required this.violet,
    required this.violetInk,
    required this.brand,
    required this.brandInk,
    required this.glass,
    required this.glassThick,
    required this.glassDock,
    required this.glassEdge,
    required this.glassFallback,
    required this.ambient1,
    required this.ambient2,
  });

  @override
  DgutColors copyWith({
    Color? bg,
    Color? bgDeep,
    Color? surface,
    Color? surface2,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? ink4,
    Color? line,
    Color? lineStrong,
    Color? fill,
    Color? fillStrong,
    Color? blue,
    Color? blueInk,
    Color? green,
    Color? greenInk,
    Color? orange,
    Color? orangeInk,
    Color? red,
    Color? redInk,
    Color? violet,
    Color? violetInk,
    Color? brand,
    Color? brandInk,
    Color? glass,
    Color? glassThick,
    Color? glassDock,
    Color? glassEdge,
    Color? glassFallback,
    Color? ambient1,
    Color? ambient2,
  }) {
    return DgutColors(
      bg: bg ?? this.bg,
      bgDeep: bgDeep ?? this.bgDeep,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      ink4: ink4 ?? this.ink4,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      fill: fill ?? this.fill,
      fillStrong: fillStrong ?? this.fillStrong,
      blue: blue ?? this.blue,
      blueInk: blueInk ?? this.blueInk,
      green: green ?? this.green,
      greenInk: greenInk ?? this.greenInk,
      orange: orange ?? this.orange,
      orangeInk: orangeInk ?? this.orangeInk,
      red: red ?? this.red,
      redInk: redInk ?? this.redInk,
      violet: violet ?? this.violet,
      violetInk: violetInk ?? this.violetInk,
      brand: brand ?? this.brand,
      brandInk: brandInk ?? this.brandInk,
      glass: glass ?? this.glass,
      glassThick: glassThick ?? this.glassThick,
      glassDock: glassDock ?? this.glassDock,
      glassEdge: glassEdge ?? this.glassEdge,
      glassFallback: glassFallback ?? this.glassFallback,
      ambient1: ambient1 ?? this.ambient1,
      ambient2: ambient2 ?? this.ambient2,
    );
  }

  @override
  DgutColors lerp(covariant DgutColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DgutColors(
      bg: c(bg, other.bg),
      bgDeep: c(bgDeep, other.bgDeep),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      ink4: c(ink4, other.ink4),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      fill: c(fill, other.fill),
      fillStrong: c(fillStrong, other.fillStrong),
      blue: c(blue, other.blue),
      blueInk: c(blueInk, other.blueInk),
      green: c(green, other.green),
      greenInk: c(greenInk, other.greenInk),
      orange: c(orange, other.orange),
      orangeInk: c(orangeInk, other.orangeInk),
      red: c(red, other.red),
      redInk: c(redInk, other.redInk),
      violet: c(violet, other.violet),
      violetInk: c(violetInk, other.violetInk),
      brand: c(brand, other.brand),
      brandInk: c(brandInk, other.brandInk),
      glass: c(glass, other.glass),
      glassThick: c(glassThick, other.glassThick),
      glassDock: c(glassDock, other.glassDock),
      glassEdge: c(glassEdge, other.glassEdge),
      glassFallback: c(glassFallback, other.glassFallback),
      ambient1: c(ambient1, other.ambient1),
      ambient2: c(ambient2, other.ambient2),
    );
  }
}

const dgutLight = DgutColors(
  bg: Color(0xFFF6F6F9),
  bgDeep: Color(0xFFEFEFF4),
  surface: Color(0x8CFFFFFF),
  surface2: Color(0xC7FFFFFF),
  ink: Color(0xFF0B0B0F),
  ink2: Color(0x8F0B0B0F),
  ink3: Color(0x520B0B0F),
  ink4: Color(0x240B0B0F),
  line: Color(0x120B0B0F),
  lineStrong: Color(0x1F0B0B0F),
  fill: Color(0x0D0B0B0F),
  fillStrong: Color(0x170B0B0F),
  blue: Color(0xFF0A84FF),
  blueInk: Color(0xFF0060DF),
  green: Color(0xFF30D158),
  greenInk: Color(0xFF0F6B33),
  orange: Color(0xFFFF9F0A),
  orangeInk: Color(0xFF8A5000),
  red: Color(0xFFFF453A),
  redInk: Color(0xFFC7150B),
  violet: Color(0xFFBF5AF2),
  violetInk: Color(0xFF7A2E9E),
  brand: Color(0xFF0E7A5F),
  brandInk: Color(0xFF0B6350),
  glass: Color(0x9EFFFFFF),
  glassThick: Color(0xD1FFFFFF),
  glassDock: Color(0x85FFFFFF),
  glassEdge: Color(0xD9FFFFFF),
  glassFallback: Color(0xF2FFFFFF),
  ambient1: Color(0x290E7A5F),
  ambient2: Color(0x240A84FF),
);

const dgutDark = DgutColors(
  bg: Color(0xFF0B0B0F),
  bgDeep: Color(0xFF07070A),
  surface: Color(0x0BFFFFFF),
  surface2: Color(0x13FFFFFF),
  ink: Color(0xFFF5F5F7),
  ink2: Color(0x9EF5F5F7),
  ink3: Color(0x61F5F5F7),
  ink4: Color(0x2EF5F5F7),
  line: Color(0x1AFFFFFF),
  lineStrong: Color(0x29FFFFFF),
  fill: Color(0x12FFFFFF),
  fillStrong: Color(0x1FFFFFFF),
  blue: Color(0xFF0A84FF),
  blueInk: Color(0xFF5AA9FF),
  green: Color(0xFF30D158),
  greenInk: Color(0xFF4ADE80),
  orange: Color(0xFFFF9F0A),
  orangeInk: Color(0xFFFFBE5C),
  red: Color(0xFFFF453A),
  redInk: Color(0xFFFF8A80),
  violet: Color(0xFFBF5AF2),
  violetInk: Color(0xFFDDA2FF),
  brand: Color(0xFF1FA98A),
  brandInk: Color(0xFF3ED0AC),
  glass: Color(0x9E1C1C20),
  glassThick: Color(0xD618181C),
  glassDock: Color(0x8C1E1E22),
  glassEdge: Color(0x24FFFFFF),
  glassFallback: Color(0xF518181C),
  ambient1: Color(0x331FA98A),
  ambient2: Color(0x2E0A84FF),
);

/// 12 级字阶。height 是倍数（行高 / 字号），letterSpacing 是逻辑像素（em × 字号）。
class DgutType {
  static const hero = TextStyle(
      fontSize: 40,
      height: 44 / 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.040 * 40);
  static const largeTitle = TextStyle(
      fontSize: 34,
      height: 38 / 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.035 * 34);
  static const title1 = TextStyle(
      fontSize: 28,
      height: 33 / 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.030 * 28);
  static const title2 = TextStyle(
      fontSize: 22,
      height: 27 / 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.020 * 22);
  static const title3 = TextStyle(
      fontSize: 19,
      height: 24 / 19,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.015 * 19);
  static const headline = TextStyle(
      fontSize: 17,
      height: 22 / 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.010 * 17);
  static const body = TextStyle(
      fontSize: 16,
      height: 23 / 16,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.005 * 16);
  static const callout =
      TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w400);
  static const subhead =
      TextStyle(fontSize: 14, height: 19 / 14, fontWeight: FontWeight.w400);
  static const footnote =
      TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  static const caption1 =
      TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400);
  static const caption2 =
      TextStyle(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w400);

  /// 大标题上方的小标签（.dg-ht__eyebrow）
  static const eyebrow = TextStyle(
      fontSize: 11,
      height: 14 / 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.13 * 11);

  /// 分组标题（.dg-grouphead__title）
  static const groupLabel = TextStyle(
      fontSize: 11,
      height: 14 / 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.12 * 11);
}

class DgutRadius {
  static const r1 = 8.0, r2 = 12.0, r3 = 18.0, r4 = 26.0, r5 = 34.0;
  static const full = 999.0;
}

class DgutSpace {
  static const s1 = 8.0, s2 = 16.0, s3 = 24.0, s4 = 32.0, s5 = 40.0, s6 = 56.0;

  /// 页面左右边距（--dg-pad），20 是固定值，不是 8 的倍数
  static const pad = 20.0;
}

class DgutShadows {
  static const List<BoxShadow> float = [
    BoxShadow(color: Color(0x2E0B0B0F), offset: Offset(0, 18), blurRadius: 44),
    BoxShadow(color: Color(0x140B0B0F), offset: Offset(0, 3), blurRadius: 10),
  ];
  static const List<BoxShadow> floatDark = [
    BoxShadow(color: Color(0x8C000000), offset: Offset(0, 18), blurRadius: 44),
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 3), blurRadius: 10),
  ];
  static const List<BoxShadow> pane = [
    BoxShadow(color: Color(0x290B0B0F), offset: Offset(0, 20), blurRadius: 50),
    BoxShadow(color: Color(0x0F0B0B0F), offset: Offset(0, 2), blurRadius: 8),
  ];
  static const List<BoxShadow> flight = [
    BoxShadow(color: Color(0x470B0B0F), offset: Offset(0, 30), blurRadius: 70),
  ];

  static List<BoxShadow> forBrightness(Brightness b) =>
      b == Brightness.dark ? floatDark : float;
}

/// 一条滚动信息：pixels 供大标题与顶栏，rest/max 供边缘模糊。
@immutable
class DgutScrollInfo {
  const DgutScrollInfo({
    this.pixels = 0,
    this.rest = 0,
    this.max = 0,
  });

  final double pixels;
  final double rest;
  final double max;

  static const DgutScrollInfo zero = DgutScrollInfo();
}

/// 便捷取色
extension DgutColorX on BuildContext {
  DgutColors get dg =>
      Theme.of(this).extension<DgutColors>() ?? dgutLight;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
