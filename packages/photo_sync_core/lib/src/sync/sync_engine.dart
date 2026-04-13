import 'dart:async';
import '../models/photo_info.dart';
import '../models/sync_task.dart';
import '../protocol/sync_client.dart';
import 'dedup_manager.dart';
import 'package:uuid/uuid.dart';

/// 同步状态回调
typedef SyncProgressCallback = void Function(SyncTask task);
typedef SyncFileCallback = void Function(PhotoInfo file, SyncStatus status, String? error);

/// 同步引擎（手机端使用）
class SyncEngine {
  final SyncClient client;
  final DedupManager dedupManager;

  SyncTask? _currentTask;
  bool _isPaused = false;
  bool _isCancelled = false;
  final _pauseCompleter = <Completer<void>>[];

  SyncProgressCallback? onProgress;
  SyncFileCallback? onFileComplete;
  void Function()? onSyncComplete;
  void Function(String error)? onError;

  SyncEngine({
    required this.client,
    required this.dedupManager,
  });

  /// 当前任务
  SyncTask? get currentTask => _currentTask;

  /// 是否暂停中
  bool get isPaused => _isPaused;

  /// 执行同步
  /// [allFiles] 手机端扫描出的所有文件
  /// [localSyncedFingerprints] 本地数据库中已同步的指纹列表
  /// [onRecordSync] 回调：需要记录到本地数据库的指纹
  Future<SyncTask> performSync({
    required List<PhotoInfo> allFiles,
    required List<String> localSyncedFingerprints,
    required void Function(String fingerprint) onRecordSync,
  }) async {
    _isPaused = false;
    _isCancelled = false;

    // 1. 加载本地同步记录
    dedupManager.loadLocalRecords(localSyncedFingerprints);

    // 2. 获取服务器端已有指纹
    try {
      final serverFingerprints = await client.getServerFingerprints();
      dedupManager.setServerFingerprints(serverFingerprints);
    } catch (e) {
      onError?.call('无法连接到电脑端: $e');
      rethrow;
    }

    // 3. 分层去重
    final dedupResult = dedupManager.filterFiles(allFiles);

    // 4. 补记服务器已有但本地未记录的
    for (final photo in dedupResult.toRecord) {
      onRecordSync(photo.fingerprint);
      dedupManager.markSynced(photo.fingerprint);
    }

    // 5. 创建同步任务
    final task = SyncTask(
      id: const Uuid().v4(),
      files: dedupResult.toSync,
    );
    _currentTask = task;
    task.status = SyncStatus.syncing;
    onProgress?.call(task);

    if (dedupResult.toSync.isEmpty) {
      task.status = SyncStatus.success;
      task.endTime = DateTime.now();
      onProgress?.call(task);
      onSyncComplete?.call();
      return task;
    }

    // 6. 逐个上传
    for (var i = 0; i < task.files.length; i++) {
      // 检查暂停
      await _checkPause();

      // 检查取消
      if (_isCancelled) {
        task.status = SyncStatus.paused;
        onProgress?.call(task);
        return task;
      }

      final file = task.files[i];
      task.currentIndex = i;
      onProgress?.call(task);

      try {
        final result = await client.uploadFile(file);
        final status = result['status'] as String;

        if (status == 'ok') {
          task.results.add(SyncFileResult(
            file: file,
            status: SyncStatus.success,
            remotePath: result['path'] as String?,
          ));
          // 记录到本地数据库
          onRecordSync(file.fingerprint);
          dedupManager.markSynced(file.fingerprint);
        } else if (status == 'skipped') {
          task.results.add(SyncFileResult(
            file: file,
            status: SyncStatus.skipped,
          ));
          onRecordSync(file.fingerprint);
        } else {
          task.results.add(SyncFileResult(
            file: file,
            status: SyncStatus.failed,
            errorMessage: result['reason'] as String?,
          ));
        }

        task.transferredBytes += file.fileSize;
        onFileComplete?.call(file, task.results.last.status, null);
      } on DiskFullException {
        task.results.add(SyncFileResult(
          file: file,
          status: SyncStatus.failed,
          errorMessage: '电脑端磁盘空间不足',
        ));
        onError?.call('电脑端磁盘空间不足，同步已停止');
        break;
      } on CancelledException {
        task.status = SyncStatus.paused;
        onProgress?.call(task);
        return task;
      } catch (e) {
        task.results.add(SyncFileResult(
          file: file,
          status: SyncStatus.failed,
          errorMessage: e.toString(),
        ));
        onFileComplete?.call(file, SyncStatus.failed, e.toString());
        // 继续下一个文件
      }
    }

    // 7. 完成
    task.currentIndex = task.files.length;
    task.status = task.failedCount > 0 ? SyncStatus.failed : SyncStatus.success;
    task.endTime = DateTime.now();
    onProgress?.call(task);
    onSyncComplete?.call();

    _currentTask = null;
    return task;
  }

  /// 暂停同步
  void pause() {
    _isPaused = true;
    if (_currentTask != null) {
      _currentTask!.status = SyncStatus.paused;
      onProgress?.call(_currentTask!);
    }
  }

  /// 恢复同步
  void resume() {
    _isPaused = false;
    for (final completer in _pauseCompleter) {
      if (!completer.isCompleted) completer.complete();
    }
    _pauseCompleter.clear();
    if (_currentTask != null) {
      _currentTask!.status = SyncStatus.syncing;
      onProgress?.call(_currentTask!);
    }
  }

  /// 取消同步
  void cancel() {
    _isCancelled = true;
    client.cancel();
    resume(); // 解除暂停以便退出循环
  }

  /// 等待暂停恢复
  Future<void> _checkPause() async {
    if (_isPaused) {
      final completer = Completer<void>();
      _pauseCompleter.add(completer);
      await completer.future;
    }
  }
}
