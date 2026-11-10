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
