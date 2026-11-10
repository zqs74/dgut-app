import 'package:flutter/material.dart';

/// 课程块样式：纸卡 / 实心 / 线框 / 色签
enum BlockStyle { paper, solid, outline, tick }

/// 块里文字的颜色取向
enum BlockTextColor { ink, white, tone }

/// 一套配色：四个课程色（按课程 tone 取）
class DgutPalette {
  const DgutPalette(this.name, this.colors);

  final String name;
  final List<Color> colors;

  Color colorOf(int tone) => colors[tone % colors.length];
}

const List<DgutPalette> kDgutPalettes = <DgutPalette>[
  DgutPalette('原色', <Color>[
    Color(0xFF2F6BFF),
    Color(0xFF1F9D63),
    Color(0xFF7A5AF8),
    Color(0xFFE08A1E),
  ]),
  DgutPalette('莫兰迪', <Color>[
    Color(0xFF7E96B8),
    Color(0xFF8FA89B),
    Color(0xFFA79AB0),
    Color(0xFFC39B7E),
  ]),
  DgutPalette('深墨', <Color>[
    Color(0xFF3E5C76),
    Color(0xFF4F6F52),
    Color(0xFF6B5B95),
    Color(0xFF8C5E3C),
  ]),
  DgutPalette('明亮', <Color>[
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
  ]),
  DgutPalette('单色', <Color>[
    Color(0xFF6B7280),
    Color(0xFF6B7280),
    Color(0xFF6B7280),
    Color(0xFF6B7280),
  ]),
];

/// 课表外观：样式、配色、色块透明度、文字颜色/字号/字重
@immutable
class TimetableAppearance {
  const TimetableAppearance({
    this.style = BlockStyle.paper,
    this.palette = 0,
    this.opacity = 1.0,
    this.textColor = BlockTextColor.tone,
    this.fontScale = 1.0,
    this.weight = 600,
  });

  final BlockStyle style;
  final int palette;
  final double opacity;
  final BlockTextColor textColor;
  final double fontScale;
  final int weight;

  DgutPalette get paletteData => kDgutPalettes[palette % kDgutPalettes.length];

  Color colorOf(int tone) => paletteData.colorOf(tone);

  TimetableAppearance copyWith({
    BlockStyle? style,
    int? palette,
    double? opacity,
    BlockTextColor? textColor,
    double? fontScale,
    int? weight,
  }) {
    return TimetableAppearance(
      style: style ?? this.style,
      palette: palette ?? this.palette,
      opacity: opacity ?? this.opacity,
      textColor: textColor ?? this.textColor,
      fontScale: fontScale ?? this.fontScale,
      weight: weight ?? this.weight,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'style': style.name,
    'palette': palette,
    'opacity': opacity,
    'text': textColor.name,
    'font': fontScale,
    'weight': weight,
  };

  static TimetableAppearance fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TimetableAppearance();
    final String styleName = '${json['style'] ?? 'paper'}';
    final String textName = '${json['text'] ?? 'tone'}';
    return TimetableAppearance(
      style: BlockStyle.values.firstWhere(
        (BlockStyle s) => s.name == styleName,
        orElse: () => BlockStyle.paper,
      ),
      palette: (json['palette'] as num?)?.toInt() ?? 0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      textColor: BlockTextColor.values.firstWhere(
        (BlockTextColor t) => t.name == textName,
        orElse: () => BlockTextColor.tone,
      ),
      fontScale: (json['font'] as num?)?.toDouble() ?? 1.0,
      weight: (json['weight'] as num?)?.toInt() ?? 600,
    );
  }
}
