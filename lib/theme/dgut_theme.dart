import 'package:flutter/material.dart';

import 'dgut_tokens.dart';

const List<String> kDgutFontFallback = <String>[
  'PingFang SC',
  'HarmonyOS Sans SC',
  'Noto Sans SC',
  'Microsoft YaHei',
];

ThemeData buildDgutTheme(Brightness brightness) {
  final DgutColors c = brightness == Brightness.dark ? dgutDark : dgutLight;
  final ThemeData base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    extensions: <ThemeExtension<dynamic>>[c],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(fontFamilyFallback: kDgutFontFallback)
        .apply(bodyColor: c.ink, displayColor: c.ink),
    primaryTextTheme:
        base.primaryTextTheme.apply(fontFamilyFallback: kDgutFontFallback),
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: Colors.white,
      secondary: c.blue,
      onSecondary: Colors.white,
      error: c.red,
      onError: Colors.white,
      surface: c.bg,
      onSurface: c.ink,
    ),
    dividerColor: c.line,
    focusColor: c.fill,
    splashColor: Colors.transparent,
  );
}
