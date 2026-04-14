import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:photo_sync_core/photo_sync_core.dart';

/// 电脑端核心 Provider：管理服务器生命周期和状态
class SyncServerProvider extends ChangeNotifier {
  late SyncServer _server;
  late PairingManager _pairingManager;
  late TokenManager _tokenManager;
  late DeviceInfo _deviceInfo;

  String _storageRoot = '';
  bool _isRunning = false;
  bool _isPaired = false;
  String? _pairingCode;
  String? _pairedDeviceName;
  int _syncedCount = 0;
  int? _freeDiskSpace;
  final List<String> _logs = [];

  // 同步进度
  String? _currentFileName;
  int _currentFileIndex = 0;
  int _totalFiles = 0;
  bool _isSyncing = false;

  // 当前文件传输进度（字节级）
  int _currentFileReceivedBytes = 0;
  int _currentFileTotalBytes = 0;
  double _transferSpeed = 0; // 字节/秒
  DateTime? _lastSpeedCalcTime;
  int _lastSpeedCalcBytes = 0;

  // Getters
  bool get isRunning => _isRunning;
  bool get isPaired => _isPaired;
  String? get pairingCode => _pairingCode;
  String? get confirmCode => _pairingManager.confirmCode;
  String? get pairedDeviceName => _pairedDeviceName;
  int get syncedCount => _syncedCount;
  int? get freeDiskSpace => _freeDiskSpace;
  String get storageRoot => _storageRoot;
  List<String> get logs => List.unmodifiable(_logs);
  DeviceInfo get deviceInfo => _deviceInfo;
  String? get currentFileName => _currentFileName;
  int get currentFileIndex => _currentFileIndex;
  int get totalFiles => _totalFiles;
  bool get isSyncing => _isSyncing;
  int get currentFileReceivedBytes => _currentFileReceivedBytes;
  int get currentFileTotalBytes => _currentFileTotalBytes;
  double get transferSpeed => _transferSpeed;

  /// 当前文件传输进度 0.0 - 1.0
  double get currentFileProgress {
    if (_currentFileTotalBytes <= 0) return 0.0;
    return (_currentFileReceivedBytes / _currentFileTotalBytes).clamp(0.0, 1.0);
  }

  /// 磁盘空间是否不足（< 1GB）
  bool get isDiskLow =>
      _freeDiskSpace != null && _freeDiskSpace! < 1024 * 1024 * 1024;

  /// 初始化
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 设备 ID（持久化）
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    // 存储路径
    _storageRoot = prefs.getString('storage_root') ?? '';
    if (_storageRoot.isEmpty) {
      final home = await getApplicationDocumentsDirectory();
      _storageRoot = p.join(home.path, 'PhotoSync');
      await prefs.setString('storage_root', _storageRoot);
    }
    Directory(_storageRoot).createSync(recursive: true);

    // 获取本机 IP
    final ip = await _getLocalIp();

    // Token 管理
    var secret = prefs.getString('jwt_secret');
    if (secret == null) {
      secret = const Uuid().v4();
      await prefs.setString('jwt_secret', secret);
    }
    _tokenManager = TokenManager(secret: secret);

    // 配对管理
    _pairingManager = PairingManager(tokenManager: _tokenManager);

    // 设备信息
    _deviceInfo = DeviceInfo(
      deviceId: deviceId,
      deviceName: Platform.localHostname,
      platform: Platform.operatingSystem,
      appVersion: SyncConstants.appVersion,
      ip: ip,
      port: SyncConstants.defaultPort,
    );

    // 创建服务器
    _server = SyncServer(
      deviceInfo: _deviceInfo,
      pairingManager: _pairingManager,
      tokenManager: _tokenManager,
      storageRoot: _storageRoot,
    );

    _server.onLog = (msg) {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
      if (_logs.length > 500) _logs.removeAt(0);
      notifyListeners();
    };

    _server.onFileReceived = (fileName, album, size) {
      _currentFileName = fileName;
      _syncedCount = _server.syncedFileCount;
      _isSyncing = true;
      // 文件接收完成，重置当前文件进度
      _currentFileReceivedBytes = 0;
      _currentFileTotalBytes = 0;
      _transferSpeed = 0;
      notifyListeners();
    };

    // 大文件传输进度回调
    _server.onFileProgress = (receivedBytes, totalBytes, fileName) {
      _currentFileName = fileName;
      _currentFileReceivedBytes = receivedBytes;
      _currentFileTotalBytes = totalBytes;
      _isSyncing = true;

      // 计算传输速度（每 500ms 更新一次）
      final now = DateTime.now();
      if (_lastSpeedCalcTime != null) {
        final elapsed = now.difference(_lastSpeedCalcTime!).inMilliseconds;
        if (elapsed >= 500) {
          final bytesDelta = receivedBytes - _lastSpeedCalcBytes;
          _transferSpeed = bytesDelta / (elapsed / 1000.0);
          _lastSpeedCalcTime = now;
          _lastSpeedCalcBytes = receivedBytes;
        }
      } else {
        _lastSpeedCalcTime = now;
        _lastSpeedCalcBytes = receivedBytes;
      }

      notifyListeners();
    };

    _server.onDevicePaired = (deviceName) {
      _isPaired = true;
      _pairedDeviceName = deviceName;
      _pairingCode = null;
      notifyListeners();
    };

    // 自动启动服务
    await startServer();
  }

  /// 启动服务器
  Future<void> startServer() async {
    try {
      await _server.start();
      _isRunning = true;

      // 生成配对信息
      final pairingInfo = _pairingManager.generatePairingInfo(
        ip: _deviceInfo.ip,
        port: _deviceInfo.port,
        deviceName: _deviceInfo.deviceName,
        deviceId: _deviceInfo.deviceId,
      );
      _pairingCode = pairingInfo.toQrString();

      notifyListeners();
    } catch (e) {
      _addLog('启动失败: $e');
    }
  }

  /// 停止服务器
  Future<void> stopServer() async {
    await _server.stop();
    _isRunning = false;
    notifyListeners();
  }

  /// 重新生成配对码
  void regeneratePairingCode() {
    _pairingManager.unpair();
    _isPaired = false;
    _pairedDeviceName = null;
    final pairingInfo = _pairingManager.generatePairingInfo(
      ip: _deviceInfo.ip,
      port: _deviceInfo.port,
      deviceName: _deviceInfo.deviceName,
      deviceId: _deviceInfo.deviceId,
    );
    _pairingCode = pairingInfo.toQrString();
    notifyListeners();
  }

  /// 修改存储路径
  Future<void> setStorageRoot(String path) async {
    _storageRoot = path;
    Directory(path).createSync(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storage_root', path);
    notifyListeners();
  }

  /// 获取已同步文件的相册列表
  List<String> getSyncedAlbums() {
    final dir = Directory(_storageRoot);
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .where((name) => !name.startsWith('.'))
        .toList()
      ..sort();
  }

  /// 获取指定相册下的文件列表
  List<FileSystemEntity> getAlbumFiles(String album) {
    final dir = Directory(p.join(_storageRoot, album));
    if (!dir.existsSync()) return [];
    return dir.listSync()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  void _addLog(String msg) {
    _logs.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
    notifyListeners();
  }

  /// 获取本机局域网 IP
  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168')) {
            return addr.address;
          }
        }
      }
      // fallback: 返回第一个非回环地址
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '0.0.0.0';
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}
