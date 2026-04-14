import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/device_info.dart';
import '../models/photo_info.dart';
import 'api_routes.dart';

/// 上传进度回调: (已发送字节, 总字节)
typedef UploadProgressCallback = void Function(int sent, int total);

/// 手机端 HTTP 同步客户端
class SyncClient {
  String? _baseUrl;
  String? _token;
  final http.Client _client = http.Client();
  bool _isCancelled = false;

  /// 上传进度回调
  UploadProgressCallback? onUploadProgress;

  /// 连接状态
  bool get isConnected => _baseUrl != null;

  /// 设置服务器地址
  void setServer(String ip, int port) {
    _baseUrl = 'http://$ip:$port';
  }

  /// 设置认证 Token
  void setToken(String token) {
    _token = token;
  }

  /// 取消操作
  void cancel() {
    _isCancelled = true;
  }

  /// 重置取消标记
  void resetCancel() {
    _isCancelled = false;
  }

  /// 获取服务器设备信息
  Future<DeviceInfo> getServerInfo() async {
    final response = await _get(ApiRoutes.info);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DeviceInfo.fromJson(json);
  }

  /// 发送配对请求
  Future<Map<String, dynamic>> pair({
    required String pairingCode,
    required String deviceId,
    required String deviceName,
  }) async {
    final response = await _post(ApiRoutes.pair, body: {
      'pairingCode': pairingCode,
      'deviceId': deviceId,
      'deviceName': deviceName,
    });

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      _token = result['token'] as String?;
      return result;
    } else if (response.statusCode == 401) {
      throw Exception('配对码无效');
    } else {
      throw Exception('配对失败: ${response.body}');
    }
  }

  /// 获取已同步文件指纹列表
  Future<Set<String>> getServerFingerprints() async {
    final response = await _get(ApiRoutes.fileList);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['fingerprints'] as List).cast<String>();
    return list.toSet();
  }

  /// 上传单个文件（流式上传，支持大文件进度）
  /// 返回: {'status': 'ok'/'skipped'/'error', ...}
  Future<Map<String, dynamic>> uploadFile(PhotoInfo photo) async {
    if (_isCancelled) throw CancelledException();
    if (_baseUrl == null) throw Exception('未连接到服务器');

    final file = File(photo.filePath);
    final fileSize = await file.length();

    final uri = Uri.parse('$_baseUrl${ApiRoutes.upload}');

    // 构建 multipart 请求
    final request = http.MultipartRequest('POST', uri);

    // 添加认证头
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    // 添加表单字段
    request.fields['fileName'] = photo.fileName;
    request.fields['album'] = photo.album;
    request.fields['fileSize'] = fileSize.toString();
    request.fields['dateAdded'] = photo.dateAdded.toString();
    request.fields['dateModified'] = photo.dateModified.toString();
    request.fields['fingerprint'] = photo.fingerprint;

    // 添加文件（使用流式读取，不全部加载到内存）
    request.files.add(http.MultipartFile(
      'file',
      file.openRead(),
      fileSize,
      filename: photo.fileName,
    ));

    // 发送请求，监听上传进度
    final streamedResponse = await _sendWithProgress(request, fileSize);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 507) {
      throw DiskFullException();
    } else {
      throw Exception('上传失败 (${response.statusCode}): ${response.body}');
    }
  }

  /// 发送 MultipartRequest 并监听字节进度
  Future<http.StreamedResponse> _sendWithProgress(
    http.MultipartRequest request,
    int fileSize,
  ) async {
    final byteStream = request.finalize();
    final totalLength = request.contentLength;

    // 创建一个监听进度的包装流
    int sent = 0;
    int lastReport = 0;
    final progressStream = byteStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
          sent += data.length;
          // 每传输 64KB 或完成时报告
          if (sent - lastReport > 64 * 1024 || sent >= totalLength) {
            lastReport = sent;
            onUploadProgress?.call(sent, totalLength);
          }
        },
      ),
    );

    final streamedRequest = http.StreamedRequest(request.method, request.url);
    streamedRequest.headers.addAll(request.headers);
    streamedRequest.contentLength = totalLength;

    progressStream.listen(
      streamedRequest.sink.add,
      onError: streamedRequest.sink.addError,
      onDone: streamedRequest.sink.close,
    );

    return await _client.send(streamedRequest);
  }

  /// 获取磁盘空间信息
  Future<Map<String, dynamic>> getDiskInfo() async {
    final response = await _get(ApiRoutes.diskInfo);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 获取服务器状态
  Future<Map<String, dynamic>> getStatus() async {
    final response = await _get(ApiRoutes.status);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      await getServerInfo();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- HTTP 辅助方法 ----

  Future<http.Response> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    return await _client.get(uri, headers: headers).timeout(
      const Duration(seconds: 10),
    );
  }

  Future<http.Response> _post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    return await _client
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
  }

  void dispose() {
    _client.close();
  }
}

/// 用户取消操作异常
class CancelledException implements Exception {
  @override
  String toString() => '操作已取消';
}

/// 磁盘空间不足异常
class DiskFullException implements Exception {
  @override
  String toString() => '电脑端磁盘空间不足';
}
