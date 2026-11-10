/// 更新检查的数据类型（门面与平台实现共用，避免循环导入）
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
    required this.sizeBytes,
  });

  /// 远端版本号，已去掉前缀 v，如 "0.4.0"
  final String version;
  final String apkUrl;
  final String notes;
  final int sizeBytes;

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    final double mb = sizeBytes / 1024 / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// 更新链路的可读错误。
///
/// 直接把 `HandshakeException: Connection terminated during handshake` 摆给用户
/// 没有意义 —— 他要的是"哪里坏了、我现在能做什么"。所以所有失败都收敛成这个
/// 类型：`message` 可以直接显示，`needsInstallPermission` 决定 UI 要不要给
/// 一个「去开启」的按钮。
class UpdateException implements Exception {
  const UpdateException(this.message, {this.needsInstallPermission = false});

  final String message;
  final bool needsInstallPermission;

  @override
  String toString() => message;
}
