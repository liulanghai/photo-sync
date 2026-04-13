import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../models/device_info.dart';
import '../auth/pairing_manager.dart';
import '../auth/token_manager.dart';
import '../constants.dart';
import 'api_routes.dart';

/// 电脑端 HTTP 同步服务器
class SyncServer {
  final DeviceInfo deviceInfo;
  final PairingManager pairingManager;
  final TokenManager tokenManager;
  final String storageRoot;

  HttpServer? _server;
  bool _isRunning = false;

  /// 已同步文件指纹集合
  final Set<String> _syncedFingerprints = {};

  /// 回调
  void Function(String message)? onLog;
  void Function(String fileName, String album, int fileSize)? onFileReceived;
  void Function(String pairingCode)? onPairingCodeGenerated;
  void Function(String deviceName)? onDevicePaired;
  void Function()? onSyncComplete;

  SyncServer({
    required this.deviceInfo,
    required this.pairingManager,
    required this.tokenManager,
    required this.storageRoot,
  });

  bool get isRunning => _isRunning;
  int get syncedFileCount => _syncedFingerprints.length;

  /// 启动服务器
  Future<void> start({int? port}) async {
    if (_isRunning) return;

    await _loadSyncedFingerprints();

    final router = Router();
    router.get(ApiRoutes.info, _handleInfo);
    router.post(ApiRoutes.pair, _handlePair);
    router.get(ApiRoutes.fileList, _handleFileList);
    router.post(ApiRoutes.upload, _handleUpload);
    router.get(ApiRoutes.status, _handleStatus);
    router.get(ApiRoutes.diskInfo, _handleDiskInfo);

    final handler = const Pipeline()
        .addMiddleware(logRequests(logger: (msg, isError) {
          onLog?.call(msg);
        }))
        .addHandler(router.call);

    final serverPort = port ?? SyncConstants.defaultPort;
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, serverPort);
    _isRunning = true;
    onLog?.call('服务已启动: http://${deviceInfo.ip}:$serverPort');
  }

  /// 停止服务器
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    onLog?.call('服务已停止');
  }

  /// GET /api/info
  Response _handleInfo(Request request) {
    return Response.ok(
      jsonEncode(deviceInfo.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /api/pair
  Future<Response> _handlePair(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final pairingCode = body['pairingCode'] as String?;
      final remoteDeviceId = body['deviceId'] as String?;
      final remoteDeviceName = body['deviceName'] as String?;

      if (pairingCode == null || remoteDeviceId == null || remoteDeviceName == null) {
        return Response(400, body: jsonEncode({'error': '缺少必要参数'}));
      }

      final token = pairingManager.verifyPairingRequest(
        pairingCode: pairingCode,
        remoteDeviceId: remoteDeviceId,
        remoteDeviceName: remoteDeviceName,
      );

      if (token == null) {
        return Response(401, body: jsonEncode({'error': '配对码无效'}));
      }

      onDevicePaired?.call(remoteDeviceName);

      return Response.ok(
        jsonEncode({
          'token': token,
          'confirmCode': pairingManager.confirmCode,
          'deviceName': deviceInfo.deviceName,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response(400, body: jsonEncode({'error': '请求格式错误: $e'}));
    }
  }

  /// GET /api/file-list
  Response _handleFileList(Request request) {
    final authError = _checkAuth(request);
    if (authError != null) return authError;

    return Response.ok(
      jsonEncode({
        'fingerprints': _syncedFingerprints.toList(),
        'count': _syncedFingerprints.length,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /api/upload
  Future<Response> _handleUpload(Request request) async {
    final authError = _checkAuth(request);
    if (authError != null) return authError;

    try {
      // 检查磁盘空间
      final diskFree = await _getFreeDiskSpace();
      if (diskFree != null && diskFree < 500 * 1024 * 1024) {
        return Response(507, body: jsonEncode({
          'status': 'error',
          'reason': 'disk_full',
          'freeSpace': diskFree,
        }));
      }

      // 解析 multipart 请求
      final contentType = request.headers['content-type'] ?? '';
      if (!contentType.contains('multipart/form-data')) {
        return Response(400, body: jsonEncode({'error': '需要 multipart/form-data'}));
      }

      final boundary = contentType.split('boundary=').last;
      final transformer = MimeMultipartTransformer(boundary);
      final parts = await transformer
          .bind(request.read())
          .map((part) async {
            final disposition = part.headers['content-disposition'] ?? '';
            final nameMatch = RegExp(r'name="([^"]*)"').firstMatch(disposition);
            final name = nameMatch?.group(1) ?? '';
            final bytes = await part.fold<List<int>>(
              [],
              (prev, chunk) => prev..addAll(chunk),
            );
            return MapEntry(name, bytes);
          })
          .toList();

      final partMap = <String, List<int>>{};
      for (final future in parts) {
        final entry = await future;
        partMap[entry.key] = entry.value;
      }

      // 提取字段
      final fileName = utf8.decode(partMap['fileName'] ?? []);
      final album = utf8.decode(partMap['album'] ?? []);
      final fingerprint = utf8.decode(partMap['fingerprint'] ?? []);
      final fileData = partMap['file'];

      if (fileName.isEmpty || album.isEmpty || fileData == null || fileData.isEmpty) {
        return Response(400, body: jsonEncode({'error': '缺少必要字段'}));
      }

      // 去重检查
      if (_syncedFingerprints.contains(fingerprint)) {
        return Response.ok(jsonEncode({
          'status': 'skipped',
          'reason': 'duplicate',
        }), headers: {'Content-Type': 'application/json'});
      }

      // 按相册创建目录并保存文件
      final albumDir = Directory(p.join(storageRoot, _sanitizeDirName(album)));
      if (!albumDir.existsSync()) {
        albumDir.createSync(recursive: true);
      }

      final filePath = p.join(albumDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(fileData);

      // 记录指纹
      _syncedFingerprints.add(fingerprint);
      await _saveFingerprintIndex();

      onFileReceived?.call(fileName, album, fileData.length);

      return Response.ok(jsonEncode({
        'status': 'ok',
        'path': '$album/$fileName',
      }), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      onLog?.call('上传错误: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': '服务器内部错误: $e'}),
      );
    }
  }

  /// GET /api/status
  Response _handleStatus(Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'running',
        'isPaired': pairingManager.isPaired,
        'syncedCount': _syncedFingerprints.length,
        'storageRoot': storageRoot,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// GET /api/disk-info
  Future<Response> _handleDiskInfo(Request request) async {
    final authError = _checkAuth(request);
    if (authError != null) return authError;

    final freeSpace = await _getFreeDiskSpace();
    return Response.ok(
      jsonEncode({
        'freeSpace': freeSpace,
        'storageRoot': storageRoot,
        'warning': freeSpace != null && freeSpace < 1024 * 1024 * 1024,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Token 鉴权检查
  Response? _checkAuth(Request request) {
    // 如果还没配对，不需要鉴权（允许文件列表查询用于首次同步）
    if (!pairingManager.isPaired) return null;

    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401, body: jsonEncode({'error': '未授权'}));
    }

    final token = authHeader.substring(7);
    final deviceId = tokenManager.verifyToken(token);
    if (deviceId == null) {
      return Response(401, body: jsonEncode({'error': 'Token 无效或已过期'}));
    }

    return null;
  }

  /// 加载已同步文件指纹索引
  Future<void> _loadSyncedFingerprints() async {
    final indexFile = File(p.join(storageRoot, '.sync_index.json'));
    if (indexFile.existsSync()) {
      try {
        final content = await indexFile.readAsString();
        final list = (jsonDecode(content) as List).cast<String>();
        _syncedFingerprints.addAll(list);
        onLog?.call('已加载 ${_syncedFingerprints.length} 条同步记录');
      } catch (e) {
        onLog?.call('加载索引失败: $e');
      }
    }
  }

  /// 保存指纹索引到文件
  Future<void> _saveFingerprintIndex() async {
    final indexFile = File(p.join(storageRoot, '.sync_index.json'));
    await indexFile.writeAsString(jsonEncode(_syncedFingerprints.toList()));
  }

  /// 获取磁盘可用空间（字节）
  Future<int?> _getFreeDiskSpace() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('wmic', [
          'logicaldisk',
          'where',
          'DeviceID="${p.rootPrefix(storageRoot)}"',
          'get',
          'FreeSpace',
          '/format:value'
        ]);
        final match = RegExp(r'FreeSpace=(\d+)').firstMatch(result.stdout);
        return match != null ? int.tryParse(match.group(1)!) : null;
      } else {
        final result = await Process.run('df', ['-B1', storageRoot]);
        final lines = result.stdout.toString().split('\n');
        if (lines.length >= 2) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) return int.tryParse(parts[3]);
        }
      }
    } catch (_) {}
    return null;
  }

  /// 清理目录名（移除非法字符）
  String _sanitizeDirName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
