import 'update_models.dart';

/// Web 平台占位实现：不做更新，避免把 dart:io 引进 web 构建
bool get isSupportedImpl => false;

Future<UpdateInfo?> checkImpl(String repo, String currentVersion) async => null;

Future<void> downloadAndInstallImpl(
  UpdateInfo info,
  void Function(double progress) onProgress,
) async {
  throw UnsupportedError('当前平台不支持应用内更新');
}

Future<bool> canInstallImpl() async => true;

Future<bool> openInstallPermissionImpl() async => false;
