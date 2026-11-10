import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'update_models.dart';

bool get isSupportedImpl => Platform.isAndroid;

const MethodChannel _installChannel = MethodChannel('dgut/install');

/// 拉 GitHub Releases 的最新版本，与本地比对。
/// 返回 null = 已是最新；抛异常 = 检查失败（由 UI 转成提示文案）。
Future<UpdateInfo?> checkImpl(String repo, String currentVersion) async {
  final Uri uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
  final http.Response res = await http.get(uri, headers: {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'dgut-app',
  }).timeout(const Duration(seconds: 12));

  if (res.statusCode == 404) return null; // 还没有 release
  if (res.statusCode != 200) {
    throw Exception('检查更新失败（HTTP ${res.statusCode}）');
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
  if (apk == null) return null;

  return UpdateInfo(
    version: remote,
    apkUrl: apk['browser_download_url'] as String,
    notes: (json['body'] as String? ?? '').trim(),
    sizeBytes: (apk['size'] as num?)?.toInt() ?? 0,
  );
}

/// 下载到应用私有目录，然后唤起系统安装器
Future<void> downloadAndInstallImpl(
  UpdateInfo info,
  void Function(double progress) onProgress,
) async {
  // 应用私有 cache 目录（dart:io 自带，不依赖 path_provider）。
  // FileProvider 的 cache-path 已覆盖这里，系统安装器能读到。
  final Directory dir = Directory.systemTemp;
  final File target = File('${dir.path}/dgut-update.apk');
  if (await target.exists()) {
    await target.delete();
  }

  final http.Client client = http.Client();
  try {
    final http.StreamedResponse res = await client
        .send(http.Request('GET', Uri.parse(info.apkUrl)))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('下载失败（HTTP ${res.statusCode}）');
    }
    final int total = res.contentLength ?? info.sizeBytes;
    final IOSink sink = target.openWrite();
    int received = 0;
    onProgress(total > 0 ? 0 : -1);
    await for (final List<int> chunk in res.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress((received / total).clamp(0.0, 1.0));
      }
    }
    await sink.flush();
    await sink.close();
  } finally {
    client.close();
  }

  await _installChannel.invokeMethod<bool>('installApk', {'path': target.path});
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
