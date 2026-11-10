import 'update_models.dart';
import 'update_service_stub.dart'
    if (dart.library.io) 'update_service_io.dart' as impl;

/// 自动更新（只做 Android）。
///
/// 链路：GitHub Releases 取最新 tag → 与本地版本比对 → 下载 apk 到应用私有目录
/// → 通过 FileProvider 唤起系统安装器。
/// 说明：Android 8.0 起不允许静默安装，最后一步必须用户在系统弹窗里点一次「安装」。
///
/// 这个文件是门面，真实实现按平台走条件导入：
/// Android / Windows 用 io 版，Web 用 stub 版（否则 web 构建会因为 dart:io 失败）。
class UpdateService {
  /// 更新源仓库：建好 Releases 后改这里
  static const String repo = 'zqs74/dgut-app';

  /// 返回 null 表示已是最新（或检查失败）
  static Future<UpdateInfo?> check(String currentVersion) =>
      impl.checkImpl(repo, currentVersion);

  /// 下载并唤起安装；onProgress 给 0~1（总量未知时给 -1）
  static Future<void> downloadAndInstall(
    UpdateInfo info,
    void Function(double progress) onProgress,
  ) =>
      impl.downloadAndInstallImpl(info, onProgress);

  /// 当前平台是否支持自动更新（只有 Android 做）
  static bool get isSupported => impl.isSupportedImpl;
}
