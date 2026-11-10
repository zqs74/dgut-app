import 'package:flutter/material.dart';

/// 再点一次当前 tab 的回顶信号。
///
/// 用 `DgutScrollInfo` 那个 ValueNotifier 实例本身当身份：外壳为五个页面各建一个，
/// 天然唯一。这样页面骨架不用新增构造参数，五个页面也不必透传任何东西 ——
/// 骨架自己订阅，判断信号是不是发给自己的。
class DgutReselect extends ChangeNotifier {
  Object? _target;
  int _tick = 0;

  /// 最近一次被点中的页面身份
  Object? get target => _target;

  /// 自增计数，区分连续两次点中同一页
  int get tick => _tick;

  void fire(Object owner) {
    _target = owner;
    _tick += 1;
    notifyListeners();
  }
}

class DgutReselectScope extends InheritedNotifier<DgutReselect> {
  const DgutReselectScope({
    super.key,
    required DgutReselect super.notifier,
    required super.child,
  });

  static DgutReselect? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DgutReselectScope>()?.notifier;
}
