/// 全局常量
class SyncConstants {
  SyncConstants._();

  /// 默认 HTTP 服务端口
  static const int defaultPort = 53317;

  /// mDNS 服务类型
  static const String mdnsServiceType = '_photosync._tcp';

  /// mDNS 服务名称
  static const String mdnsServiceName = 'PhotoSync';

  /// API 路径前缀
  static const String apiPrefix = '/api';

  /// Token 过期时间（天）
  static const int tokenExpireDays = 365;

  /// 配对码长度
  static const int pairingCodeLength = 6;

  /// 确认码长度（配对码后 N 位）
  static const int confirmCodeLength = 4;

  /// App 版本
  static const String appVersion = '1.0.0';

  /// App 名称
  static const String appName = 'PhotoSync';
}
