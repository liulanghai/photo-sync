/// API 路由定义
class ApiRoutes {
  ApiRoutes._();

  static const String prefix = '/api';

  /// 获取设备信息
  static const String info = '$prefix/info';

  /// 配对请求
  static const String pair = '$prefix/pair';

  /// 获取已同步文件指纹列表
  static const String fileList = '$prefix/file-list';

  /// 上传文件
  static const String upload = '$prefix/upload';

  /// 服务状态
  static const String status = '$prefix/status';

  /// 磁盘空间信息
  static const String diskInfo = '$prefix/disk-info';
}
