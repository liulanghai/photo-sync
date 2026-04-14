import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:photo_sync_core/photo_sync_core.dart';

import '../services/sync_database.dart';
import '../services/photo_scanner.dart';

/// 手机端核心 Provider
class SyncProvider extends ChangeNotifier {
  final SyncClient _client = SyncClient();
  final DedupManager _dedupManager = DedupManager();
  final SyncDatabase _db = SyncDatabase();
  final PhotoScanner _scanner = PhotoScanner();
  SyncEngine? _engine;

  String _deviceId = '';
  String _deviceName = '';
  bool _initialized = false;

  // 连接状态
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _serverIp;
  int _serverPort = SyncConstants.defaultPort;
  String? _token;
  String? _serverDeviceName;

  // 同步状态
  SyncTask? _currentTask;
  bool _isScanning = false;
  int _localFileCount = 0;
  int _syncedCount = 0;
  String _statusMessage = '未连接';
  List<PhotoInfo> _pendingFiles = [];

  // Getters
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get serverIp => _serverIp;
  String? get serverDeviceName => _serverDeviceName;
  SyncTask? get currentTask => _currentTask;
  bool get isScanning => _isScanning;
  int get localFileCount => _localFileCount;
  int get syncedCount => _syncedCount;
  String get statusMessage => _statusMessage;
  List<PhotoInfo> get pendingFiles => _pendingFiles;
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;
  bool get isSyncing => _currentTask?.status == SyncStatus.syncing;
  bool get isPaused => _engine?.isPaused ?? false;
  SyncDatabase get database => _db;
  PhotoScanner get scanner => _scanner;

  /// 初始化
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _deviceId = prefs.getString('device_id') ?? const Uuid().v4();
      await prefs.setString('device_id', _deviceId);

      _deviceName = prefs.getString('device_name') ?? 'Xiaomi Phone';
      _token = prefs.getString('auth_token');
      _serverIp = prefs.getString('server_ip');
      _serverPort = prefs.getInt('server_port') ?? SyncConstants.defaultPort;

      _engine = SyncEngine(
        client: _client,
        dedupManager: _dedupManager,
      );

      _engine!.onProgress = (task) {
        _currentTask = task;
        _statusMessage = '同步中 ${task.currentIndex}/${task.totalFiles}';
        notifyListeners();
      };

      _engine!.onFileComplete = (file, status, error) {
        notifyListeners();
      };

      _engine!.onSyncComplete = () {
        _statusMessage = '同步完成';
        _refreshSyncedCount();
        notifyListeners();
      };

      _engine!.onError = (error) {
        _statusMessage = '错误: $error';
        notifyListeners();
      };

      // 恢复已有连接
      if (_serverIp != null && _token != null) {
        _client.setServer(_serverIp!, _serverPort);
        _client.setToken(_token!);
        await _tryReconnect();
      }

      await _refreshSyncedCount();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      _statusMessage = '初始化失败: $e';
      _initialized = true;
      notifyListeners();
    }
  }

  /// 通过扫码配对结果连接
  Future<void> connectWithPairingInfo(PairingInfo info) async {
    _connectionStatus = ConnectionStatus.connecting;
    _statusMessage = '正在连接...';
    notifyListeners();

    try {
      _client.setServer(info.ip, info.port);

      // 发送配对请求
      final result = await _client.pair(
        pairingCode: info.pairingCode,
        deviceId: _deviceId,
        deviceName: _deviceName,
      );

      _token = result['token'] as String?;
      _serverDeviceName = result['deviceName'] as String?;
      _serverIp = info.ip;
      _serverPort = info.port;

      // 持久化连接信息
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('server_ip', _serverIp!);
      await prefs.setInt('server_port', _serverPort);

      _connectionStatus = ConnectionStatus.connected;
      _statusMessage = '已连接到 $_serverDeviceName';
      notifyListeners();
    } catch (e) {
      _connectionStatus = ConnectionStatus.disconnected;
      _statusMessage = '连接失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 手动连接（输入 IP）
  Future<void> connectManually(String ip, int port) async {
    _connectionStatus = ConnectionStatus.connecting;
    _statusMessage = '正在连接...';
    notifyListeners();

    try {
      _client.setServer(ip, port);
      final serverInfo = await _client.getServerInfo();
      _serverDeviceName = serverInfo.deviceName;
      _serverIp = ip;
      _serverPort = port;

      _connectionStatus = ConnectionStatus.connected;
      _statusMessage = '已连接到 $_serverDeviceName';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', ip);
      await prefs.setInt('server_port', port);

      notifyListeners();
    } catch (e) {
      _connectionStatus = ConnectionStatus.disconnected;
      _statusMessage = '连接失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 扫描并开始同步
  Future<void> startSync() async {
    if (!isConnected || _engine == null) {
      _statusMessage = '请先连接电脑';
      notifyListeners();
      return;
    }

    // 1. 请求权限
    final hasPermission = await _scanner.requestPermission();
    if (!hasPermission) {
      _statusMessage = '需要存储权限才能同步照片';
      notifyListeners();
      return;
    }

    // 2. 扫描手机相册
    _isScanning = true;
    _statusMessage = '正在扫描照片...';
    notifyListeners();

    try {
      final allFiles = await _scanner.scanAll();
      _localFileCount = allFiles.length;
      _isScanning = false;
      _statusMessage = '扫描完成，共 $_localFileCount 个文件';
      notifyListeners();

      // 3. 获取本地同步记录
      final localFingerprints = await _db.getAllFingerprints();

      // 4. 启动同步引擎
      _client.resetCancel();
      final task = await _engine!.performSync(
        allFiles: allFiles,
        localSyncedFingerprints: localFingerprints,
        onRecordSync: (fingerprint) async {
          // 从 allFiles 中找到对应的文件信息
          final file = allFiles.firstWhere(
            (f) => f.fingerprint == fingerprint,
            orElse: () => allFiles.first,
          );
          await _db.markSynced(
            fingerprint: fingerprint,
            filePath: file.filePath,
            album: file.album,
            fileSize: file.fileSize,
            dateAdded: file.dateAdded,
          );
        },
      );

      _currentTask = task;
      _statusMessage = '同步完成: 成功 ${task.successCount}, '
          '跳过 ${task.skippedCount}, 失败 ${task.failedCount}';
      notifyListeners();
    } catch (e) {
      _isScanning = false;
      _statusMessage = '同步出错: $e';
      notifyListeners();
    }
  }

  /// 暂停同步
  void pauseSync() {
    _engine?.pause();
    _statusMessage = '已暂停';
    notifyListeners();
  }

  /// 恢复同步
  void resumeSync() {
    _engine?.resume();
    _statusMessage = '同步中...';
    notifyListeners();
  }

  /// 取消同步
  void cancelSync() {
    _engine?.cancel();
    _statusMessage = '已取消';
    notifyListeners();
  }

  // ======== 重置功能 ========

  /// 完全重新同步
  Future<void> resetAll() async {
    final count = await _db.clearAll();
    _dedupManager.clearAll();
    await _refreshSyncedCount();
    _statusMessage = '已清除全部同步记录 ($count 条)';
    notifyListeners();
  }

  /// 从指定日期重新同步
  Future<void> resetSince(DateTime date) async {
    final timestamp = date.millisecondsSinceEpoch ~/ 1000;
    final count = await _db.clearSince(timestamp);
    _dedupManager.clearSince(timestamp);
    await _refreshSyncedCount();
    _statusMessage = '已清除 ${date.toString().substring(0, 10)} 之后的同步记录 ($count 条)';
    notifyListeners();
  }

  /// 重新同步指定相册
  Future<void> resetAlbums(List<String> albums) async {
    final count = await _db.clearAlbums(albums);
    for (final album in albums) {
      _dedupManager.clearAlbum(album);
    }
    await _refreshSyncedCount();
    _statusMessage = '已清除 ${albums.join(", ")} 的同步记录 ($count 条)';
    notifyListeners();
  }

  /// 断开连接
  void disconnect() {
    _connectionStatus = ConnectionStatus.disconnected;
    _serverDeviceName = null;
    _statusMessage = '未连接';
    notifyListeners();
  }

  Future<void> _tryReconnect() async {
    try {
      _connectionStatus = ConnectionStatus.connecting;
      notifyListeners();

      final isAlive = await _client.testConnection();
      if (isAlive) {
        final info = await _client.getServerInfo();
        _serverDeviceName = info.deviceName;
        _connectionStatus = ConnectionStatus.connected;
        _statusMessage = '已连接到 $_serverDeviceName';
      } else {
        _connectionStatus = ConnectionStatus.disconnected;
        _statusMessage = '电脑端未响应';
      }
    } catch (_) {
      _connectionStatus = ConnectionStatus.disconnected;
      _statusMessage = '无法连接到电脑';
    }
    notifyListeners();
  }

  Future<void> _refreshSyncedCount() async {
    try {
      _syncedCount = await _db.getSyncedCount();
    } catch (_) {
      _syncedCount = 0;
    }
  }

  @override
  void dispose() {
    _client.dispose();
    _db.close();
    super.dispose();
  }
}

enum ConnectionStatus { disconnected, connecting, connected }
