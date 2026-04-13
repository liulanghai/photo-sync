/// 同步任务模型
enum SyncStatus {
  pending,   // 待同步
  syncing,   // 同步中
  success,   // 成功
  failed,    // 失败
  skipped,   // 跳过（去重/已存在）
  paused,    // 暂停
}

class SyncTask {
  final String id;
  final List<PhotoInfo> files;
  SyncStatus status;
  int currentIndex;
  int totalFiles;
  int transferredBytes;
  int totalBytes;
  String? errorMessage;
  DateTime startTime;
  DateTime? endTime;
  final List<SyncFileResult> results;

  SyncTask({
    required this.id,
    required this.files,
    this.status = SyncStatus.pending,
    this.currentIndex = 0,
    this.transferredBytes = 0,
    this.errorMessage,
    DateTime? startTime,
    this.endTime,
    List<SyncFileResult>? results,
  })  : totalFiles = files.length,
        totalBytes = files.fold(0, (sum, f) => sum + f.fileSize),
        startTime = startTime ?? DateTime.now(),
        results = results ?? [];

  /// 当前进度百分比 0.0 - 1.0
  double get progress =>
      totalFiles == 0 ? 0.0 : currentIndex / totalFiles;

  /// 已传输大小（可读格式）
  String get transferredSizeFormatted => _formatBytes(transferredBytes);

  /// 总大小（可读格式）
  String get totalSizeFormatted => _formatBytes(totalBytes);

  /// 成功数量
  int get successCount =>
      results.where((r) => r.status == SyncStatus.success).length;

  /// 失败数量
  int get failedCount =>
      results.where((r) => r.status == SyncStatus.failed).length;

  /// 跳过数量
  int get skippedCount =>
      results.where((r) => r.status == SyncStatus.skipped).length;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 单个文件同步结果
class SyncFileResult {
  final PhotoInfo file;
  final SyncStatus status;
  final String? remotePath;
  final String? errorMessage;

  SyncFileResult({
    required this.file,
    required this.status,
    this.remotePath,
    this.errorMessage,
  });
}
