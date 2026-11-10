import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'update_models.dart';

bool get isSupportedImpl => Platform.isAndroid;

const MethodChannel _installChannel = MethodChannel('dgut/install');

/// 拉 GitHub Releases 的最新版本，与本地比对。
/// 返回 null = 已是最新；抛 [UpdateException] = 失败（message 已经是可以显示的中文）
Future<UpdateInfo?> checkImpl(String repo, String currentVersion) async {
  final Uri uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  final http.Response res;
  try {
    res = await http.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'dgut-app',
    }).timeout(const Duration(seconds: 12));
  } catch (e) {
    throw _mapNetworkError(e, action: '检查更新');
  }

  if (res.statusCode == 404) return null; // 仓库还没有 Release
  if (res.statusCode != 200) {
    throw UpdateException(
      'GitHub 返回 HTTP ${res.statusCode}，暂时取不到版本信息。稍后重试。',
    );
  }

  final Map<String, dynamic> json =
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final String tag = (json['tag_name'] as String? ?? '').trim();
  final String remote = tag.replaceFirst(RegExp(r'^[vV]'), '');
  if (remote.isEmpty) return null;

  if (!_isNewer(remote, currentVersion)) return null;

  final List<dynamic> rawAssets = (json['assets'] as List<dynamic>? ?? const []);
  Map<String, dynamic>? apk;
  for (final dynamic a in rawAssets) {
    if (a is Map<String, dynamic>) {
      final String name = (a['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apk = a;
        break;
      }
    }
  }
  if (apk == null) {
    throw const UpdateException('这版 Release 里没有 apk 文件，去 GitHub 发布页看一眼。');
  }

  return UpdateInfo(
    version: remote,
    apkUrl: apk['browser_download_url'] as String,
    notes: (json['body'] as String? ?? '').trim(),
    sizeBytes: (apk['size'] as num?)?.toInt() ?? 0,
  );
}

/// 下载到应用私有目录，然后唤起系统安装器。
///
/// 顺序是「先查权限、再下载」：系统不允许安装未知应用时，47 MB 白下一遍没有意义。
Future<void> downloadAndInstallImpl(
  UpdateInfo info,
  void Function(double progress) onProgress,
) async {
  if (!await canInstallImpl()) {
    throw const UpdateException(
      '系统还没允许这个 App 安装 APK。点下面的「去开启」，在「安装未知应用」里打开，返回后会自动继续。',
      needsInstallPermission: true,
    );
  }

  // 应用私有 cache 目录（dart:io 自带，不依赖 path_provider）。
  // FileProvider 的 cache-path 已覆盖这里，系统安装器能读到。
  final Directory dir = Directory.systemTemp;
  final File target = File('${dir.path}/dgut-update.apk');
  if (await target.exists()) {
    await target.delete();
  }

  final http.Client client = http.Client();
  try {
    final http.StreamedResponse res;
    try {
      res = await client
          .send(http.Request('GET', Uri.parse(info.apkUrl)))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw _mapNetworkError(e, action: '下载安装包');
    }
    if (res.statusCode != 200) {
      throw UpdateException('下载返回 HTTP ${res.statusCode}，换一次网络再试。');
    }
    final int total = res.contentLength ?? info.sizeBytes;
    final IOSink sink = target.openWrite();
    int received = 0;
    onProgress(total > 0 ? 0 : -1);
    try {
      await for (final List<int> chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress((received / total).clamp(0.0, 1.0));
        }
      }
    } catch (e) {
      throw _mapNetworkError(e, action: '下载安装包');
    } finally {
      await sink.flush();
      await sink.close();
    }
  } finally {
    client.close();
  }

  try {
    await _installChannel.invokeMethod<bool>('installApk', {'path': target.path});
  } on PlatformException catch (e) {
    if (e.code == 'permission_denied') {
      throw const UpdateException(
        '系统还没允许这个 App 安装 APK。点下面的「去开启」，在「安装未知应用」里打开，返回后会自动继续。',
        needsInstallPermission: true,
      );
    }
    throw UpdateException('唤起系统安装器失败：${e.message ?? e.code}');
  } on MissingPluginException {
    throw const UpdateException('当前平台没有安装能力（只有 Android 支持应用内更新）。');
  }
}

/// 系统是否已允许「安装未知应用」
Future<bool> canInstallImpl() async {
  try {
    final bool? ok = await _installChannel.invokeMethod<bool>('canInstall');
    return ok ?? true;
  } on PlatformException {
    return true; // 查不出来就当已授权，让安装那一步自己报错
  } on MissingPluginException {
    return true;
  }
}

/// 直接跳本应用的「安装未知应用」授权页
Future<bool> openInstallPermissionImpl() async {
  try {
    final bool? ok =
        await _installChannel.invokeMethod<bool>('openInstallPermission');
    return ok ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

/// 把网络层异常翻成人话。GitHub 在国内最常翻的是握手被掐断，单独点名。
UpdateException _mapNetworkError(Object e, {required String action}) {
  if (e is UpdateException) return e;
  final String s = e.toString();

  if (s.contains('HandshakeException') ||
      s.contains('Connection terminated') ||
      s.contains('handshake')) {
    return UpdateException(
      '$action失败：和 GitHub 的加密握手被中断。国内网络直连 GitHub 常被掐，'
      '换 Wi-Fi 或移动数据再试；能开代理的话更稳。',
    );
  }
  if (e is SocketException || s.contains('SocketException')) {
    return UpdateException(
      '$action失败：连不上 GitHub（域名解析或端口被拦）。检查手机网络后重试。',
    );
  }
  if (e is TimeoutException || s.contains('TimeoutException')) {
    return UpdateException('$action超时：12 秒内 GitHub 没有响应。网络太慢或被拦，换个网络再试。');
  }
  if (e is http.ClientException || s.contains('ClientException')) {
    return UpdateException('$action中断：连接被对端关掉了，重试一次。');
  }
  return UpdateException('$action失败：$s');
}

/// 语义化版本比较：remote 是否比 local 新
bool _isNewer(String remote, String local) {
  List<int> parts(String v) => v
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();

  final List<int> a = parts(remote);
  final List<int> b = parts(local);
  for (var i = 0; i < 3; i++) {
    final int x = i < a.length ? a[i] : 0;
    final int y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
