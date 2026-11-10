/// 登录态：App 只记「有没有登录」和「登录后从学工页面读到的身份」，
/// **不记密码、不记 cookie、不记 ticket**。
///
/// 为什么不需要"把 token 传给各个系统"：Android WebView 的 CookieManager
/// 是进程级共享的（同一个 App 内所有 WebView 用同一份 cookie 罐），
/// 所以只要用户在任一处登录过统一身份认证（CAS），其余接入同一 CAS 的
/// 系统在被打开时，浏览器会把 `auth.dgut.edu.cn` 的 TGC 一起带上，
/// CAS 认出人已认证过，直接发票放行 —— 不需要我们做任何转交。
///
/// 也就是说：这个类只负责**记账**（登录了没、叫什么），
/// 真正的单点登录是 WebView 自己完成的。
library;

import 'package:flutter/foundation.dart';

import '../model/identity.dart';
import '../store/store.dart';

class Session extends ChangeNotifier {
  Session._();

  static final Session instance = Session._();

  /// 存本机的键（跟其余数据一样带 `.v1` 后缀，将来改结构能识别旧数据）
  static const String keyIdentity = 'identity.v1';

  DgutIdentity? _identity;
  bool _loaded = false;

  DgutIdentity? get identity => _identity;

  bool get isLoggedIn => _identity != null;

  bool get loaded => _loaded;

  Future<void> load() async {
    await Store.instance.init();
    final Map<String, dynamic>? json = Store.instance.readJsonObject(
      keyIdentity,
    );
    if (json != null) {
      try {
        _identity = DgutIdentity.fromJson(json);
      } catch (_) {
        // 结构对不上就当没登录过，不让 App 因为一条脏数据起不来
        _identity = null;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setIdentity(DgutIdentity identity) async {
    _identity = identity;
    await Store.instance.writeJson(keyIdentity, identity.toJson());
    notifyListeners();
  }

  /// 退出登录：只清本机这一份记账。
  /// **清 cookie 与通知 CAS 注销由调用方负责**（要用 WebView 才做得到）。
  Future<void> clear() async {
    _identity = null;
    await Store.instance.remove(keyIdentity);
    notifyListeners();
  }

  /// cookie 被清掉之后（比如用户在系统设置里清了应用数据），
  /// 记账和实际登录态会不一致 —— 抓取失败时用它对齐。
  Future<void> invalidate() => clear();
}
