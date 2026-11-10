import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本机存储门面。
///
/// 只用一个依赖（`shared_preferences`，Android / iOS / Web / Windows 四端都有实现），
/// 结构化数据一律存成 JSON 字符串。**不引 `sqflite`**：它没有 Web 与 Windows 实现，
/// 会把两个预览目标砍掉；本机数据量只有几十门课、几百条待办，JSON 完全够。
///
/// 所有键都带 `dgut.` 前缀，清数据时按前缀整批清，不碰同应用内的其他键。
/// 带 `.v1` 后缀是为了以后改结构时能识别旧数据（见 `文档-功能实现路线` 五条规矩第 2 条）。
class Store {
  Store._();

  static final Store instance = Store._();
  static const String _prefix = 'dgut.';

  SharedPreferences? _prefs;

  bool get ready => _prefs != null;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String? readString(String key) => _prefs?.getString('$_prefix$key');

  Future<void> writeString(String key, String value) async {
    final p = await _ensure();
    await p.setString('$_prefix$key', value);
  }

  Map<String, dynamic>? readJsonObject(String key) {
    final raw = readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  List<dynamic>? readJsonList(String key) {
    final raw = readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) =>
      writeString(key, jsonEncode(value));

  Future<void> remove(String key) async {
    final p = await _ensure();
    await p.remove('$_prefix$key');
  }

  /// 清掉本应用写过的全部键（「我的 → 数据与隐私 → 清缓存」用）
  Future<void> clearAll() async {
    final p = await _ensure();
    final keys = p.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await p.remove(k);
    }
  }
}
