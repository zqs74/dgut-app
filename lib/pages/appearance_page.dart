import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../components/dgut_timetable.dart';
import '../model/course.dart';
import '../model/timetable_appearance.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 课表外观（L3）：样式、配色、色块透明度、文字颜色/字号/字重。
///
/// 改哪一项都立刻写进存储并重画上方预览，跟 WakeUp 那套"边调边看"一致。
class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  final ValueNotifier<DgutScrollInfo> _offset = ValueNotifier<DgutScrollInfo>(
    DgutScrollInfo.zero,
  );

  TimetableRepository get _repo => TimetableRepository.instance;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _update(TimetableAppearance next) => _repo.setAppearance(next);

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return ListenableBuilder(
      listenable: _repo,
      builder: (BuildContext context, Widget? _) {
        final TimetableAppearance a = _repo.appearance;

        return Scaffold(
          backgroundColor: c.bg,
          body: DgutPageScaffold(
            eyebrow: '课表设置',
            title: '外观',
            offset: _offset,
            footerHeight: 40,
            onBack: () => Navigator.of(context).maybePop(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DgutSpace.pad,
                  DgutSpace.s3,
                  DgutSpace.pad,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Preview(appearance: a),
                    const SizedBox(height: DgutSpace.s4),
                    const DgutGroupHead(title: '课程块'),
                    const SizedBox(height: DgutSpace.s2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (BlockStyle style, String label)
                            in <(BlockStyle, String)>[
                              (BlockStyle.paper, '纸卡'),
                              (BlockStyle.solid, '实心'),
                              (BlockStyle.outline, '线框'),
                              (BlockStyle.tick, '色签'),
                            ])
                          _Choice(
                            label: label,
                            selected: a.style == style,
                            onTap: () => _update(a.copyWith(style: style)),
                          ),
                      ],
                    ),
                    const SizedBox(height: DgutSpace.s4),
                    const DgutGroupHead(title: '配色'),
                    const SizedBox(height: DgutSpace.s2),
                    Row(
                      children: [
                        for (var i = 0; i < kDgutPalettes.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _PaletteChip(
                                palette: kDgutPalettes[i],
                                selected: a.palette == i,
                                onTap: () => _update(a.copyWith(palette: i)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: DgutSpace.s4),
                    DgutRow(
                      title: '透明度',
                      value: '${(a.opacity * 100).round()}%',
                      showChevron: false,
                      showDivider: false,
                      trailing: SizedBox(
                        width: 150,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: a.opacity,
                            min: 0.15,
                            max: 1,
                            activeColor: c.blue,
                            inactiveColor: c.fill,
                            onChanged: (double v) =>
                                _update(a.copyWith(opacity: v)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DgutSpace.s4),
                    const DgutGroupHead(title: '文字'),
                    const SizedBox(height: DgutSpace.s2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (BlockTextColor mode, String label)
                            in <(BlockTextColor, String)>[
                              (BlockTextColor.tone, '跟随块'),
                              (BlockTextColor.ink, '墨色'),
                              (BlockTextColor.white, '白色'),
                            ])
                          _Choice(
                            label: label,
                            selected: a.textColor == mode,
                            onTap: () => _update(a.copyWith(textColor: mode)),
                          ),
                      ],
                    ),
                    const SizedBox(height: DgutSpace.s3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (double scale, String label)
                            in <(double, String)>[
                              (0.92, '小'),
                              (1.0, '中'),
                              (1.1, '大'),
                            ])
                          _Choice(
                            label: label,
                            selected: (a.fontScale - scale).abs() < 0.01,
                            onTap: () => _update(a.copyWith(fontScale: scale)),
                          ),
                      ],
                    ),
                    const SizedBox(height: DgutSpace.s3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (int w, String label) in <(int, String)>[
                          (400, '常规'),
                          (600, '中等'),
                          (700, '加粗'),
                        ])
                          _Choice(
                            label: label,
                            selected: a.weight == w,
                            onTap: () => _update(a.copyWith(weight: w)),
                          ),
                      ],
                    ),
                    const SizedBox(height: DgutSpace.s4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DgutButton(
                        label: '恢复默认',
                        size: DgutButtonSize.sm,
                        variant: DgutButtonVariant.plain,
                        onTap: () => _update(const TimetableAppearance()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 上方实时预览：三块不同 tone 的课，直接复用真实课块
class _Preview extends StatelessWidget {
  const _Preview({required this.appearance});

  final TimetableAppearance appearance;

  static Course _demo(String name, String room, int tone, int count) => Course(
    id: 'demo$tone',
    name: name,
    tone: tone,
    slots: <CourseSlot>[
      CourseSlot(
        weekday: 1,
        startSlot: 1,
        slotCount: count,
        weeks: <int>[1],
        room: room,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    final List<Course> demos = <Course>[
      _demo('机器学习', '7B311', 0, 2),
      _demo('大数据采集', '7B412', 1, 2),
      _demo('Python', '6F202', 2, 3),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.bgDeep,
        borderRadius: BorderRadius.circular(DgutRadius.r2),
        border: Border.all(color: c.line, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < demos.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 144,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 96,
                    height: 48.0 * demos[i].slots.first.slotCount,
                    child: DgutCourseBlock(
                      placed: PlacedSlot(
                        course: demos[i],
                        slot: demos[i].slots.first,
                      ),
                      width: 96,
                      height: 48.0 * demos[i].slots.first.slotCount,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
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
      pressedOpacity: 0.8,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.fill,
          borderRadius: BorderRadius.circular(DgutRadius.full),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: DgutType.caption1.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? c.bg : c.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final DgutPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;
    return DgutPressable(
      onTap: onTap,
      pressedOpacity: 0.8,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.fill,
          borderRadius: BorderRadius.circular(DgutRadius.r1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final Color color in palette.colors)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              palette.name,
              style: DgutType.caption1.copyWith(
                fontSize: 10.5,
                color: selected ? c.bg : c.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
