import '../models/photo_info.dart';

/// 分层去重管理器
class DedupManager {
  /// 本地已同步指纹集合（手机端数据库中的记录）
  final Set<String> _localSyncedFingerprints = {};

  /// 服务器端已有指纹集合
  Set<String> _serverFingerprints = {};

  /// 加载本地已同步记录
  void loadLocalRecords(List<String> fingerprints) {
    _localSyncedFingerprints.clear();
    _localSyncedFingerprints.addAll(fingerprints);
  }

  /// 设置服务器端指纹列表
  void setServerFingerprints(Set<String> fingerprints) {
    _serverFingerprints = fingerprints;
  }

  /// 判断文件是否需要同步
  /// 返回: true=需要同步, false=跳过
  bool needsSync(PhotoInfo photo) {
    final fp = photo.fingerprint;

    // 第一层：本地数据库已有记录 → 跳过
    if (_localSyncedFingerprints.contains(fp)) {
      return false;
    }

    // 第二层：服务器端已有 → 跳过（但需要补记到本地）
    if (_serverFingerprints.contains(fp)) {
      return false;
    }

    // 需要同步
    return true;
  }

  /// 检查文件是否在服务器端已存在但本地未记录
  /// 用于补记本地数据库
  bool existsOnServerOnly(PhotoInfo photo) {
    final fp = photo.fingerprint;
    return !_localSyncedFingerprints.contains(fp) &&
        _serverFingerprints.contains(fp);
  }

  /// 过滤出需要同步的文件列表
  DedupResult filterFiles(List<PhotoInfo> allFiles) {
    final toSync = <PhotoInfo>[];
    final toRecord = <PhotoInfo>[]; // 服务器有但本地没记录的
    final skipped = <PhotoInfo>[];

    for (final photo in allFiles) {
      if (_localSyncedFingerprints.contains(photo.fingerprint)) {
        skipped.add(photo);
      } else if (_serverFingerprints.contains(photo.fingerprint)) {
        toRecord.add(photo); // 需要补记
        skipped.add(photo);
      } else {
        toSync.add(photo);
      }
    }

    return DedupResult(
      toSync: toSync,
      toRecord: toRecord,
      skipped: skipped,
    );
  }

  /// 记录已同步
  void markSynced(String fingerprint) {
    _localSyncedFingerprints.add(fingerprint);
  }

  /// 清空全部记录（完全重新同步）
  void clearAll() {
    _localSyncedFingerprints.clear();
  }

  /// 清除指定时间之后的记录（从时间点重新同步）
  void clearSince(int dateAdded) {
    _localSyncedFingerprints.removeWhere((fp) {
      // fingerprint 格式: album/fileName|fileSize|dateAdded
      final parts = fp.split('|');
      if (parts.length >= 3) {
        final ts = int.tryParse(parts[2]);
        return ts != null && ts >= dateAdded;
      }
      return false;
    });
  }

  /// 清除指定相册的记录
  void clearAlbum(String album) {
    _localSyncedFingerprints.removeWhere((fp) => fp.startsWith('$album/'));
  }
}

/// 去重过滤结果
class DedupResult {
  final List<PhotoInfo> toSync;    // 需要同步的
  final List<PhotoInfo> toRecord;  // 需要补记的（服务器有，本地没记录）
  final List<PhotoInfo> skipped;   // 跳过的

  DedupResult({
    required this.toSync,
    required this.toRecord,
    required this.skipped,
  });
}
